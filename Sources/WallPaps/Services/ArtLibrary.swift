import Foundation
import AppKit
import ImageIO

/// One artwork in the rotation pool. We keep the original source image so that
/// wallpaper variants (per screen size / frame style) and the 4K master can be
/// (re)rendered on demand without re-downloading.
struct LibraryEntry: Codable, Identifiable, Hashable {
    let artwork: Artwork
    /// Original downloaded (or local) image file.
    var sourcePath: String
    /// 4K archival master (3840×2160).
    var masterPath: String
    var id: String { artwork.id }
}

/// Builds and maintains the pool of artworks and renders wallpaper variants on
/// demand. Heavy work (download + render) is awaited / run off the main thread;
/// only the cheap pointer swap happens on each scheduler tick.
@MainActor
final class ArtLibrary: ObservableObject {
    @Published private(set) var entries: [LibraryEntry] = []
    @Published private(set) var current: LibraryEntry?
    @Published private(set) var isWorking = false

    private var index = -1
    private let aic = ArticProvider()
    private let met = MetProvider()
    private let cleveland = ClevelandProvider()

    let lowWaterMark = 5
    var needsMore: Bool { entries.count < lowWaterMark }

    // MARK: - Rotation

    @discardableResult
    func next() -> LibraryEntry? {
        guard !entries.isEmpty else { current = nil; return nil }
        index = (index + 1) % entries.count
        current = entries[index]
        return current
    }

    func setCurrent(_ entry: LibraryEntry) {
        if let i = entries.firstIndex(of: entry) { index = i }
        current = entry
    }

    /// Remove the current entry from the pool. Files are deleted unless `keepFiles`
    /// (used when the artwork is a favorite and should remain re-applicable).
    func removeCurrent(keepFiles: Bool = false) {
        guard entries.indices.contains(index) else { return }
        let removed = entries.remove(at: index)
        if !keepFiles { deleteFiles(removed) }
        if index >= entries.count { index = entries.count - 1 }
        current = entries.indices.contains(index) ? entries[index] : nil
        persist()
    }

    // MARK: - Variant rendering (per screen size / style), cached on disk

    /// URL of a wallpaper rendered for `pixelSize` in the given style, rendering
    /// and caching it from the source image if not already present.
    func variantURL(for entry: LibraryEntry, pixelSize: CGSize, options: RenderOptions) async -> URL? {
        let w = Int(pixelSize.width.rounded()), h = Int(pixelSize.height.rounded())
        guard w > 0, h > 0 else { return nil }
        let opts = themedOptions(options, for: entry.artwork)
        let name = "\(entry.artwork.fileStem)@\(w)x\(h)-\(opts.styleSignature).jpg"
        let url = LibraryPaths.wallpapersDir.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: url.path) { return url }

        guard let sourceData = try? Data(contentsOf: URL(fileURLWithPath: entry.sourcePath)),
              !sourceData.isEmpty else { return nil }
        let caption = entry.artwork.caption, title = entry.artwork.title
        let detail = entry.artwork.medium ?? ""
        let jpeg = await Task.detached(priority: .userInitiated) {
            WallpaperRenderer.render(sourceData: sourceData, caption: caption, title: title,
                                     detail: detail, canvasPixelSize: pixelSize, options: opts,
                                     useJPEG: true)
        }.value
        guard let jpeg else { return nil }
        LibraryPaths.ensureDirs()
        try? jpeg.write(to: url, options: .atomic)
        return url
    }

    /// Apply period-appropriate framing when enabled.
    private func themedOptions(_ options: RenderOptions, for artwork: Artwork) -> RenderOptions {
        var opts = options
        if opts.autoFrameByPeriod, let theme = PeriodFraming.theme(for: artwork.artist) {
            opts.frameTheme = theme
        }
        return opts
    }

    /// Return an existing pool entry for `artwork`, or build one (download +
    /// master render) on the fly — used to apply favorites that left the pool.
    func ensureEntry(for artwork: Artwork, options: RenderOptions) async -> LibraryEntry? {
        if let existing = entries.first(where: { $0.id == artwork.id }) { return existing }
        return await makeEntry(artwork, options: options)
    }

    /// Render (and cache) a 4K share image with a "made with WallPaps" credit.
    func shareImageURL(for entry: LibraryEntry, options: RenderOptions) async -> URL? {
        var opts = themedOptions(options, for: entry.artwork)
        opts.shareCredit = true
        let name = "\(entry.artwork.fileStem)-share-\(opts.styleSignature).png"
        let url = LibraryPaths.wallpapersDir.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: url.path) { return url }

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: entry.sourcePath)),
              !data.isEmpty else { return nil }
        let caption = entry.artwork.caption, title = entry.artwork.title
        let detail = entry.artwork.medium ?? ""
        let png = await Task.detached(priority: .userInitiated) {
            WallpaperRenderer.render(sourceData: data, caption: caption, title: title,
                                     detail: detail, canvasPixelSize: WallpaperManager.masterCanvasSize, options: opts)
        }.value
        guard let png else { return nil }
        LibraryPaths.ensureDirs()
        try? png.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Replenishment

    /// Fetch + prepare more artworks per the user's source mode.
    /// `quick` does a small first batch so a wallpaper appears fast.
    func replenish(settings: Settings, quick: Bool = false) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false; persist() }

        let options = settings.renderOptions
        // An active curated collection overrides the manual artist selection (and
        // may pin an orientation).
        let activeCollection = settings.activeCollection
            .flatMap { id in CatalogService.shared.collections.first { $0.id == id } }
        let orientation = activeCollection?.orientation ?? settings.orientation
        let target = quick ? min(6, settings.librarySize) : settings.librarySize
        var seen = Set(entries.map(\.id))

        // 1) Local folder images.
        if settings.sourceMode.usesLocal {
            let locals = LocalFolderProvider.artworks(bookmark: settings.localFolderBookmark,
                                                      fallbackPath: settings.localFolderPath)
            for art in locals.shuffled() {
                if entries.count >= target { break }
                if seen.contains(art.id) { continue }
                if let entry = await makeEntry(art, options: options, orientation: orientation) {
                    seen.insert(art.id); entries.append(entry)
                    if current == nil { next() }
                }
            }
        }

        // 2) Museum (public-domain) images — fill toward target across paginated
        //    rounds until it's reached or the sources run dry.
        guard settings.sourceMode.usesMuseums else { return }
        let selected: Set<String> = {
            if let collection = activeCollection { return Set(collection.artists) }
            return settings.selectedArtists.isEmpty
                ? Set(CatalogService.shared.artists.map(\.name))
                : settings.selectedArtists
        }()

        var dryRounds = 0, round = 0
        let maxRounds = quick ? 1 : 30
        while entries.count < target && dryRounds < 2 && round < maxRounds {
            round += 1
            var addedThisRound = 0
            for artistName in selected.shuffled() {
                if entries.count >= target { break }
                var candidates: [Artwork] = []
                if let a = try? await aic.fetchArtworks(artist: artistName, limit: 25, page: round) {
                    candidates.append(contentsOf: a)
                }
                if let c = try? await cleveland.fetchArtworks(artist: artistName, limit: 15, skip: (round - 1) * 15) {
                    candidates.append(contentsOf: c)
                }
                // The Met's per-object scan is request-heavy; only tap it early.
                if round <= 3, let m = try? await met.fetchArtworks(artist: artistName, limit: 8) {
                    candidates.append(contentsOf: m)
                }
                for art in candidates.shuffled() {
                    if entries.count >= target { break }
                    if seen.contains(art.id) { continue }
                    if !art.matchesPreFilter(orientation) { continue } // cheap AIC pre-filter
                    if let entry = await makeEntry(art, options: options, orientation: orientation) {
                        seen.insert(art.id); entries.append(entry); addedThisRound += 1
                        if current == nil { next() }
                    }
                }
            }
            if addedThisRound == 0 { dryRounds += 1 } else { dryRounds = 0 }
        }
    }

    /// Ensure the source image is on disk (download if needed) and the 4K master
    /// is rendered. Skips images that don't match `orientation`. Returns the
    /// entry, or nil on failure / orientation mismatch.
    private func makeEntry(_ art: Artwork, options: RenderOptions,
                           orientation: Orientation = .any) async -> LibraryEntry? {
        LibraryPaths.ensureDirs()
        let ext = art.imageURL.pathExtension.isEmpty ? "jpg" : art.imageURL.pathExtension.lowercased()
        let sourceURL = LibraryPaths.sourcesDir.appendingPathComponent("\(art.fileStem).\(ext)")

        let sourceData: Data
        if let cached = try? Data(contentsOf: sourceURL), !cached.isEmpty {
            sourceData = cached
        } else {
            guard let data = await Self.loadSource(art.imageURL), !data.isEmpty else { return nil }
            sourceData = data
            try? sourceData.write(to: sourceURL, options: .atomic)
        }

        // Orientation gate (verifies sources without known dimensions, e.g. Met / local).
        if orientation != .any {
            let dims = art.knownPixelSize ?? Self.headerPixelSize(sourceData)
            if let d = dims, !orientation.accepts(width: d.width, height: d.height) {
                try? FileManager.default.removeItem(at: sourceURL)
                return nil
            }
        }

        let masterURL = LibraryPaths.mastersDir.appendingPathComponent("\(art.fileStem).png")
        if !FileManager.default.fileExists(atPath: masterURL.path) {
            let opts = themedOptions(options, for: art)
            let caption = art.caption, title = art.title, detail = art.medium ?? ""
            let masterData = await Task.detached(priority: .utility) {
                WallpaperRenderer.render(sourceData: sourceData, caption: caption, title: title,
                                         detail: detail, canvasPixelSize: WallpaperManager.masterCanvasSize,
                                         options: opts)
            }.value
            guard let masterData else { return nil }
            try? masterData.write(to: masterURL, options: .atomic)
        }
        return LibraryEntry(artwork: art, sourcePath: sourceURL.path, masterPath: masterURL.path)
    }

    /// Read pixel dimensions from image header bytes only (no full decode).
    private static func headerPixelSize(_ data: Data) -> (width: Int, height: Int)? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return (w, h)
    }

    /// Load image bytes from a remote URL or a local file URL.
    private static func loadSource(_ url: URL) async -> Data? {
        if url.isFileURL { return try? Data(contentsOf: url) }
        guard let (data, response) = try? await artNetwork.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }

    private func deleteFiles(_ entry: LibraryEntry) {
        let fm = FileManager.default
        try? fm.removeItem(atPath: entry.sourcePath)
        try? fm.removeItem(atPath: entry.masterPath)
        // Remove both .jpg variants (new) and legacy .png variants
        let stem = entry.artwork.fileStem + "@"
        if let files = try? fm.contentsOfDirectory(atPath: LibraryPaths.wallpapersDir.path) {
            for f in files where f.hasPrefix(stem) {
                try? fm.removeItem(at: LibraryPaths.wallpapersDir.appendingPathComponent(f))
            }
        }
    }

    /// Wipe the pool and all its files (favorites are stored separately and survive).
    func reset() {
        for e in entries { deleteFiles(e) }
        entries.removeAll()
        index = -1
        current = nil
        persist()
    }

    // MARK: - Persistence

    private struct PersistedState: Codable { var entries: [LibraryEntry]; var index: Int }

    func loadPersisted() {
        LibraryPaths.ensureDirs()
        guard let data = try? Data(contentsOf: LibraryPaths.libraryFile),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data)
        else { return }
        entries = state.entries.filter {
            FileManager.default.fileExists(atPath: $0.sourcePath)
        }
        index = min(state.index, entries.count - 1)
        current = entries.indices.contains(index) ? entries[index] : nil
    }

    func persist() {
        LibraryPaths.ensureDirs()
        let state = PersistedState(entries: entries, index: index)
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: LibraryPaths.libraryFile, options: .atomic)
        }
    }
}

/// Filesystem locations for the rendered library. Kept outside the `@MainActor`
/// class so they are safe to touch from background work (e.g. self-test).
enum LibraryPaths {
    static let baseDir: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("WallPaps", isDirectory: true)
    static let sourcesDir = baseDir.appendingPathComponent("sources", isDirectory: true)
    static let mastersDir = baseDir.appendingPathComponent("masters", isDirectory: true)
    static let wallpapersDir = baseDir.appendingPathComponent("wallpapers", isDirectory: true)
    static let libraryFile = baseDir.appendingPathComponent("library.json")
    static let favoritesFile = baseDir.appendingPathComponent("favorites.json")
    static let catalogFile = baseDir.appendingPathComponent("catalog.json")

    static func ensureDirs() {
        for dir in [baseDir, sourcesDir, mastersDir, wallpapersDir] {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}
