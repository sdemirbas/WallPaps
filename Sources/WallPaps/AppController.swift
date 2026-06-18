import Foundation
import AppKit

/// Central coordinator: owns settings, the artwork library, favorites and the
/// scheduler, and exposes the actions the menu UI triggers.
@MainActor
final class AppController: ObservableObject {
    static let shared = AppController()

    let settings = Settings()
    let library = ArtLibrary()
    let favorites = FavoritesStore()
    private var scheduler: RefreshScheduler!
    private let network = NetworkMonitor()

    /// High-level state surfaced to the UI.
    enum LibraryState: Equatable { case loading, ready, offline, empty }
    @Published var state: LibraryState = .loading
    @Published var statusText = "Hazırlanıyor…"

    private var retrying = false

    private init() {
        scheduler = RefreshScheduler { [weak self] in
            Task { @MainActor in await self?.advanceAndApply() }
        }
        network.onBecameOnline = { [weak self] in
            Task { @MainActor in await self?.handleBackOnline() }
        }
    }

    let catalog = CatalogService.shared

    func start() {
        network.start()
        library.loadPersisted()
        applyInterval()
        // Refresh the remote catalog (new artists/collections post-deploy). Never
        // blocks: falls back to cached/bundled on any failure.
        Task { await catalog.refresh() }
        // First launch: open the window so the user sees a welcome (agent app
        // has no Dock icon, so otherwise nothing visible happens).
        if !settings.hasOnboarded {
            GalleryWindowController.shared.show()
        }
        Task { await bootstrap() }
    }

    private func bootstrap() async {
        if library.entries.isEmpty {
            await ensurePool(quick: true)
        } else {
            state = .ready
        }
        await advanceAndApply()
        if library.needsMore && network.isOnline {
            await library.replenish(settings: settings)
            refreshState()
        }
    }

    /// Try to (quickly) fill the pool and reflect the outcome in `state`.
    private func ensurePool(quick: Bool) async {
        state = .loading
        statusText = "Tablolar indiriliyor…"
        await library.replenish(settings: settings, quick: quick)
        refreshState()
        if library.entries.isEmpty { scheduleRetry() }
    }

    /// Derive the UI state from the pool + connectivity.
    private func refreshState() {
        if !library.entries.isEmpty {
            state = .ready
        } else if !network.isOnline {
            state = .offline
            statusText = "Çevrimdışı — bağlantı bekleniyor"
        } else {
            state = .empty
            statusText = "Eser bulunamadı"
        }
    }

    /// Network came back: top up if we're short, then show something.
    private func handleBackOnline() async {
        guard library.needsMore else { return }
        await ensurePool(quick: true)
        await advanceAndApply()
        if library.needsMore { await library.replenish(settings: settings); refreshState() }
    }

    /// Backoff retry while the pool is empty (covers a launch with no network
    /// where connectivity never produces a transition event).
    private func scheduleRetry() {
        guard !retrying, library.entries.isEmpty else { return }
        retrying = true
        Task {
            for delaySeconds in [8, 20, 45, 90] {
                try? await Task.sleep(nanoseconds: UInt64(delaySeconds) * 1_000_000_000)
                if !library.entries.isEmpty { break }
                await library.replenish(settings: settings, quick: true)
                refreshState()
                if !library.entries.isEmpty { await advanceAndApply(); break }
            }
            retrying = false
        }
    }

    // MARK: - Scheduling

    func applyInterval() {
        scheduler.start(interval: settings.refreshInterval.seconds)
    }

    // MARK: - Applying wallpaper

    /// Advance the rotation and set the wallpaper. Honors "favorites only" (cycle
    /// through favorites) and "distinct per screen" (different artwork per display).
    func advanceAndApply() async {
        let screens = WallpaperManager.screens()
        guard !screens.isEmpty else { return }
        let options = settings.renderOptions
        let useFavorites = settings.favoritesOnly && !favorites.favorites.isEmpty

        if settings.distinctPerScreen && screens.count > 1 {
            var firstEntry: LibraryEntry?
            for (i, screen) in screens.enumerated() {
                guard let entry = await nextEntry(useFavorites: useFavorites, options: options) else { break }
                if i == 0 { firstEntry = entry }
                await apply(entry, to: screen, options: options)
            }
            guard let first = firstEntry else { refreshState(); scheduleRetry(); return }
            library.setCurrent(first)
            state = .ready
            statusText = first.artwork.displayCaption
            notifyIfEnabled(first)
        } else {
            guard let entry = await nextEntry(useFavorites: useFavorites, options: options) else {
                refreshState(); scheduleRetry(); return
            }
            for screen in screens { await apply(entry, to: screen, options: options) }
            library.setCurrent(entry)
            state = .ready
            statusText = entry.artwork.displayCaption
            notifyIfEnabled(entry)
        }
    }

    // MARK: - First-run & recovery (used by the UI)

    /// Manual retry from the gallery's offline/empty state.
    func retryNow() {
        Task {
            await ensurePool(quick: true)
            await advanceAndApply()
            if library.needsMore && network.isOnline {
                await library.replenish(settings: settings); refreshState()
            }
        }
    }

    var isOnline: Bool { network.isOnline }

    /// Finish the welcome flow; optionally enabling notifications.
    func completeOnboarding(enableNotifications: Bool) {
        if enableNotifications { setNotifications(true) }
        settings.hasOnboarded = true
    }

    /// Next entry from either the favorites ring or the museum/local pool.
    private func nextEntry(useFavorites: Bool, options: RenderOptions) async -> LibraryEntry? {
        if useFavorites { return await nextFavoriteEntry(options) }
        return library.next()
    }

    private var favoritesIndex = -1
    private func nextFavoriteEntry(_ options: RenderOptions) async -> LibraryEntry? {
        let favs = favorites.favorites
        guard !favs.isEmpty else { return nil }
        favoritesIndex = (favoritesIndex + 1) % favs.count
        return await library.ensureEntry(for: favs[favoritesIndex], options: options)
    }

    private func notifyIfEnabled(_ entry: LibraryEntry) {
        guard settings.notifyOnChange else { return }
        let detail = entry.artwork.displayCaption
        let body = (detail.isEmpty || detail == entry.artwork.title)
            ? entry.artwork.title
            : "\(entry.artwork.title) — \(detail)"
        NotificationManager.post(title: "WallPaps — Yeni tablo", body: body,
                                 imagePath: entry.masterPath)
    }

    /// Toggle notifications, requesting authorization when turning them on.
    func setNotifications(_ on: Bool) {
        settings.notifyOnChange = on
        if on { NotificationManager.requestAuthorization() }
    }

    /// Apply a specific pool entry now (from the gallery), without advancing.
    func show(entry: LibraryEntry) {
        Task {
            let options = settings.renderOptions
            for screen in WallpaperManager.screens() {
                await apply(entry, to: screen, options: options)
            }
            library.setCurrent(entry)
            statusText = entry.artwork.displayCaption
        }
    }

    // MARK: - Settings mutations with side effects (used by menu & settings GUI)

    func setTheme(_ theme: FrameTheme)      { settings.frameTheme = theme; reapplyCurrent() }
    func setCaption(_ on: Bool)             { settings.showCaption = on; reapplyCurrent() }
    func setMatWidth(_ value: Double)       { settings.matWidthPercent = value }
    func applyMatWidth()                    { reapplyCurrent() }
    func setInterval(_ interval: RefreshInterval) { settings.refreshInterval = interval; applyInterval() }
    func setSourceMode(_ mode: SourceMode)  { settings.sourceMode = mode; rebuildLibrary() }
    func setOrientation(_ o: Orientation)   { settings.orientation = o; rebuildLibrary() }
    func setFavoritesOnly(_ on: Bool)       { settings.favoritesOnly = on; userNext() }
    func setLibrarySize(_ size: Int)        { settings.librarySize = size; refreshLibrary() }

    func setArtist(_ name: String, enabled: Bool) {
        if enabled { settings.selectedArtists.insert(name) }
        else { settings.selectedArtists.remove(name) }
    }

    func setCollection(_ id: String?) { settings.activeCollection = id; rebuildLibrary() }
    func setLanguage(_ lang: AppLanguage) { settings.language = lang; objectWillChange.send() }
    func setGalleryAmbiance(_ on: Bool) { settings.galleryAmbiance = on; reapplyCurrent() }
    func setAutoFrame(_ on: Bool) { settings.autoFrameByPeriod = on; reapplyCurrent() }

    // MARK: - Share

    /// Render (and cache) a share image for the gallery's ShareLink.
    func shareURL(for entry: LibraryEntry) async -> URL? {
        await library.shareImageURL(for: entry, options: settings.renderOptions)
    }

    func saveCurrentShare() {
        Task {
            guard let entry = library.current else { return }
            statusText = t("share.preparing")
            if let url = await shareURL(for: entry) { ShareManager.save(imageURL: url) }
            statusText = entry.artwork.displayCaption
        }
    }

    func copyCurrentShare() {
        Task {
            guard let entry = library.current else { return }
            if let url = await shareURL(for: entry) { ShareManager.copyToClipboard(imageURL: url) }
        }
    }

    /// Re-render and re-apply the current artwork (e.g. after a style change),
    /// without advancing the rotation.
    func reapplyCurrent() {
        Task {
            guard let entry = library.current else { await advanceAndApply(); return }
            let options = settings.renderOptions
            for screen in WallpaperManager.screens() {
                await apply(entry, to: screen, options: options)
            }
        }
    }

    private func apply(_ entry: LibraryEntry, to screen: NSScreen, options: RenderOptions) async {
        let pixelSize = WallpaperManager.pixelSize(of: screen)
        if let url = await library.variantURL(for: entry, pixelSize: pixelSize, options: options) {
            WallpaperManager.setWallpaper(url, on: screen)
        }
    }

    // MARK: - User actions

    func userNext() {
        Task {
            if library.needsMore { await library.replenish(settings: settings) }
            await advanceAndApply()
        }
    }

    func skipCurrent() {
        let keep = library.current.map { favorites.contains($0.id) } ?? false
        library.removeCurrent(keepFiles: keep)
        Task {
            if library.needsMore { await library.replenish(settings: settings) }
            await advanceAndApply()
        }
    }

    func refreshLibrary() {
        Task { await library.replenish(settings: settings) }
    }

    /// Rebuild the pool from scratch (used after big source/style changes).
    func rebuildLibrary() {
        Task {
            library.reset()
            statusText = "Kütüphane yeniden oluşturuluyor…"
            await library.replenish(settings: settings, quick: true)
            await advanceAndApply()
            await library.replenish(settings: settings)
        }
    }

    func openMastersFolder() {
        LibraryPaths.ensureDirs()
        NSWorkspace.shared.open(LibraryPaths.mastersDir)
    }

    // MARK: - Favorites

    /// Star/unstar the currently shown artwork.
    func toggleFavoriteCurrent() {
        guard let art = library.current?.artwork else { return }
        favorites.toggle(art)
    }

    var isCurrentFavorite: Bool {
        guard let id = library.current?.id else { return false }
        return favorites.contains(id)
    }

    /// Apply a favorite as the wallpaper now (re-rendering/downloading if needed).
    func applyFavorite(_ artwork: Artwork) {
        Task {
            let options = settings.renderOptions
            statusText = "Favori uygulanıyor…"
            guard let entry = await library.ensureEntry(for: artwork, options: options) else {
                statusText = "Favori uygulanamadı"
                return
            }
            for screen in WallpaperManager.screens() {
                await apply(entry, to: screen, options: options)
            }
            library.setCurrent(entry)
            statusText = artwork.displayCaption
        }
    }

    // MARK: - Local folder

    /// Show an open panel to choose the user's image folder.
    func chooseLocalFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Klasörü Seç"
        panel.message = "Kendi görsellerinizin bulunduğu klasörü seçin"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            settings.localFolderPath = url.path
            // Security-scoped bookmark so it keeps working under the App Store sandbox.
            settings.localFolderBookmark = try? url.bookmarkData(
                options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            if settings.sourceMode == .museums { settings.sourceMode = .both }
            rebuildLibrary()
        }
    }
}

private extension Artwork {
    /// Caption for the menu/status: artist+date, or the title for local images.
    var displayCaption: String {
        caption.isEmpty ? title : caption
    }
}
