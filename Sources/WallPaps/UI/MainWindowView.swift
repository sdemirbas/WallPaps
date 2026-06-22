import SwiftUI
import AppKit
import ImageIO

/// Shared "museum" visual language for the gallery window.
enum Gallery {
    static let wallTop    = Color(red: 0.17, green: 0.16, blue: 0.17)
    static let wallBottom = Color(red: 0.085, green: 0.08, blue: 0.085)
    static let brass      = Color(red: 0.82, green: 0.68, blue: 0.40)
    static let ivory      = Color(red: 0.94, green: 0.92, blue: 0.87)
    static let muted      = Color(red: 0.62, green: 0.60, blue: 0.57)
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

/// The window: a custom museum-style header with two "rooms" (Koleksiyon / Atölye).
struct MainWindowView: View {
    enum Room { case exhibit, collection, studio }
    @State private var room: Room = .exhibit
    @ObservedObject private var settings = AppController.shared.settings

    var body: some View {
        ZStack {
            LinearGradient(colors: [Gallery.wallTop, Gallery.wallBottom],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Rectangle().fill(Gallery.brass.opacity(0.22)).frame(height: 1)
                Group {
                    switch room {
                    case .exhibit:    ExhibitView()
                    case .collection: GalleryView()
                    case .studio:     StudioView()
                    }
                }
            }
        }
        .frame(minWidth: 880, minHeight: 600)
        .preferredColorScheme(.dark)
        .sheet(isPresented: Binding(get: { !settings.hasOnboarded }, set: { _ in })) {
            WelcomeView()
        }
        .interactiveDismissDisabled(!settings.hasOnboarded)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("WallPaps")
                    .font(Gallery.serif(27, .semibold))
                    .foregroundStyle(Gallery.ivory)
                Text(t("gallery.subtitle"))
                    .font(.system(size: 10, weight: .medium))
                    .tracking(3.5)
                    .foregroundStyle(Gallery.brass)
            }
            Spacer()
            HStack(spacing: 26) {
                roomTab(t("room.exhibit"), .exhibit)
                roomTab(t("room.collection"), .collection)
                roomTab(t("room.studio"), .studio)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 34)
        .padding(.bottom, 16)
    }

    private func roomTab(_ title: String, _ value: Room) -> some View {
        Button { room = value } label: {
            VStack(spacing: 6) {
                Text(title)
                    .font(Gallery.serif(15, room == value ? .semibold : .regular))
                    .foregroundStyle(room == value ? Gallery.ivory : Gallery.muted)
                Rectangle()
                    .fill(room == value ? Gallery.brass : Color.clear)
                    .frame(height: 1.5)
            }
            .fixedSize()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Exhibit (immersive single piece)

struct ExhibitView: View {
    @ObservedObject private var controller = AppController.shared
    @ObservedObject private var library = AppController.shared.library
    @State private var zoom = false
    @State private var shareURL: URL?

    var body: some View {
        Group {
            if let entry = library.current {
                exhibit(entry)
            } else {
                VStack(spacing: 12) {
                    ProgressView().controlSize(.large)
                    Text(controller.statusText).font(Gallery.serif(14)).foregroundStyle(Gallery.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder private func exhibit(_ entry: LibraryEntry) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 16) {
                Text("\(t("exhibit.today")) · \(todayString())")
                    .font(.system(size: 10, weight: .semibold)).tracking(2.5)
                    .foregroundStyle(Gallery.brass)

                // Framed artwork with a slow Ken Burns drift.
                ArtThumbnail(path: entry.sourcePath, maxPixel: 1400, contentMode: .fit)
                    .scaleEffect(zoom ? 1.05 : 1.0)
                    .frame(maxWidth: 560, maxHeight: 340)
                    .clipped()
                    .padding(22)
                    .background(Color(red: 0.96, green: 0.95, blue: 0.93))
                    .overlay(Rectangle().strokeBorder(Color(red: 0.10, green: 0.09, blue: 0.08), lineWidth: 9))
                    .shadow(color: .black.opacity(0.55), radius: 26, x: 0, y: 16)

                // Placard
                VStack(spacing: 3) {
                    Text(entry.artwork.title).font(Gallery.serif(18, .semibold)).foregroundStyle(Gallery.ivory)
                    Text(entry.artwork.caption).font(Gallery.serif(13)).italic().foregroundStyle(Gallery.brass)
                }
                .multilineTextAlignment(.center)

                HStack(spacing: 18) {
                    Button { controller.userNext() } label: {
                        Label(t("featured.next"), systemImage: "arrow.right").font(Gallery.serif(13))
                    }
                    Button { controller.toggleFavoriteCurrent() } label: {
                        Label(controller.isCurrentFavorite ? t("fav.in") : t("fav.add"),
                              systemImage: controller.isCurrentFavorite ? "star.fill" : "star").font(Gallery.serif(13))
                    }
                    .foregroundStyle(controller.isCurrentFavorite ? Gallery.brass : Gallery.muted)
                    if let shareURL {
                        ShareLink(item: shareURL) {
                            Label(t("share.button"), systemImage: "square.and.arrow.up").font(Gallery.serif(13))
                        }.foregroundStyle(Gallery.muted)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(28)

            CuratorPanel(entry: entry).frame(width: 290)
        }
        .background(
            RadialGradient(colors: [Gallery.brass.opacity(0.08), .clear],
                           center: .top, startRadius: 0, endRadius: 520)
        )
        .task(id: entry.id) {
            zoom = false
            shareURL = await controller.shareURL(for: entry)
            withAnimation(.easeInOut(duration: 26).repeatForever(autoreverses: true)) { zoom = true }
        }
    }

    private func todayString() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: Localization.resolved() == .tr ? "tr_TR" : "en_US")
        f.dateStyle = .long
        return f.string(from: Date())
    }
}

/// Wall-text panel: the museum's own note + factual details.
private struct CuratorPanel: View {
    let entry: LibraryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("exhibit.curatorNote"))
                .font(.system(size: 10, weight: .semibold)).tracking(2).foregroundStyle(Gallery.brass)
            Rectangle().fill(Gallery.brass.opacity(0.3)).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let note = entry.artwork.museumDescription, !note.isEmpty {
                        Text(note).font(Gallery.serif(13)).foregroundStyle(Gallery.ivory.opacity(0.9)).lineSpacing(4)
                    } else {
                        Text(t("exhibit.noNote")).font(Gallery.serif(12)).italic().foregroundStyle(Gallery.muted)
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        fact(t("details.medium"), entry.artwork.medium)
                        fact(t("details.dimensions"), entry.artwork.dimensions)
                        fact(t("details.department"), entry.artwork.department)
                        fact("", entry.artwork.source)
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.black.opacity(0.18))
    }

    @ViewBuilder private func fact(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            VStack(alignment: .leading, spacing: 1) {
                if !label.isEmpty {
                    Text(label.uppercased()).font(.system(size: 9, weight: .semibold)).tracking(1)
                        .foregroundStyle(Gallery.muted)
                }
                Text(value).font(.system(size: 11)).foregroundStyle(Gallery.ivory.opacity(0.8))
            }
        }
    }
}

// MARK: - Collection (gallery)

struct GalleryView: View {
    @ObservedObject private var controller = AppController.shared
    @ObservedObject private var library = AppController.shared.library
    @ObservedObject private var favorites = AppController.shared.favorites

    private let columns = [GridItem(.adaptive(minimum: 210), spacing: 22)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                FeaturedBanner()
                CollectionsBar()

                if let current = library.current {
                    FeaturedPiece(entry: current)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(t("gallery.header")).font(Gallery.serif(18, .semibold)).foregroundStyle(Gallery.ivory)
                    Text("·").foregroundStyle(Gallery.muted)
                    Text("\(library.entries.count) \(t("unit.artworks"))").font(Gallery.serif(14)).foregroundStyle(Gallery.muted)
                    Spacer()
                    if library.isWorking {
                        HStack(spacing: 7) {
                            ProgressView().controlSize(.small)
                            Text(t("gallery.fetching")).font(.system(size: 11)).foregroundStyle(Gallery.muted)
                        }
                    }
                }

                if library.entries.isEmpty {
                    GalleryStatusView(state: controller.state) { controller.retryNow() }
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    LazyVGrid(columns: columns, spacing: 26) {
                        ForEach(library.entries) { entry in
                            FramedPiece(
                                entry: entry,
                                isCurrent: library.current?.id == entry.id,
                                isFavorite: favorites.contains(entry.id),
                                onSelect: { controller.show(entry: entry) },
                                onFavorite: { favorites.toggle(entry.artwork) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
    }
}

/// Editorial "collection of the week" banner (from the remote manifest).
private struct FeaturedBanner: View {
    @ObservedObject private var controller = AppController.shared
    @ObservedObject private var catalog = AppController.shared.catalog

    var body: some View {
        if let featured = catalog.featured,
           let collection = catalog.collections.first(where: { $0.id == featured.collectionId }) {
            Button { controller.setCollection(collection.id) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles").foregroundStyle(Gallery.brass)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(featured.localizedTitle)
                            .font(Gallery.serif(13, .semibold)).foregroundStyle(Gallery.ivory)
                        Text(collection.localizedName)
                            .font(.system(size: 11)).foregroundStyle(Gallery.brass)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Gallery.muted)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Gallery.brass.opacity(0.10)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Gallery.brass.opacity(0.3)))
            }
            .buttonStyle(.plain)
        }
    }
}

/// Horizontal row of curated-collection chips.
private struct CollectionsBar: View {
    @ObservedObject private var controller = AppController.shared
    @ObservedObject private var settings = AppController.shared.settings
    @ObservedObject private var catalog = AppController.shared.catalog

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(t("col.none"), active: settings.activeCollection == nil) {
                    controller.setCollection(nil)
                }
                ForEach(catalog.collections) { collection in
                    chip(collection.localizedName, active: settings.activeCollection == collection.id) {
                        controller.setCollection(collection.id)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Gallery.serif(12, active ? .semibold : .regular))
                .padding(.horizontal, 13).padding(.vertical, 6)
                .background(Capsule().fill(active ? Gallery.brass.opacity(0.9) : Color.white.opacity(0.06)))
                .foregroundStyle(active ? Color.black.opacity(0.85) : Gallery.ivory.opacity(0.85))
                .overlay(Capsule().stroke(Gallery.brass.opacity(active ? 0 : 0.22)))
        }
        .buttonStyle(.plain)
    }
}

/// The currently-displayed artwork, shown large with a museum placard.
private struct FeaturedPiece: View {
    let entry: LibraryEntry
    @ObservedObject private var controller = AppController.shared
    @State private var shareURL: URL?

    var body: some View {
        HStack(alignment: .top, spacing: 26) {
            ArtThumbnail(path: entry.masterPath, maxPixel: 1000, contentMode: .fit)
                .frame(width: 420, height: 236)
                .shadow(color: .black.opacity(0.6), radius: 26, x: 0, y: 16)

            VStack(alignment: .leading, spacing: 9) {
                Text(t("featured.nowShowing"))
                    .font(.system(size: 10, weight: .semibold)).tracking(3)
                    .foregroundStyle(Gallery.brass)
                Text(entry.artwork.artistDisplay)
                    .font(Gallery.serif(15)).italic()
                    .foregroundStyle(Gallery.ivory.opacity(0.85))
                Text(entry.artwork.title)
                    .font(Gallery.serif(25, .semibold))
                    .foregroundStyle(Gallery.ivory)
                    .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                if !entry.artwork.date.isEmpty {
                    Text(entry.artwork.date).font(Gallery.serif(14)).foregroundStyle(Gallery.muted)
                }
                placard

                Spacer(minLength: 6)

                HStack(spacing: 16) {
                    Button { controller.userNext() } label: {
                        Label(t("featured.next"), systemImage: "arrow.right").font(Gallery.serif(13))
                    }
                    Button { controller.toggleFavoriteCurrent() } label: {
                        Label(controller.isCurrentFavorite ? t("fav.in") : t("fav.add"),
                              systemImage: controller.isCurrentFavorite ? "star.fill" : "star")
                            .font(Gallery.serif(13))
                    }
                    .foregroundStyle(controller.isCurrentFavorite ? Gallery.brass : Gallery.muted)
                    if let shareURL {
                        ShareLink(item: shareURL) {
                            Label(t("share.button"), systemImage: "square.and.arrow.up").font(Gallery.serif(13))
                        }
                        .foregroundStyle(Gallery.muted)
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(22)
        .background(RoundedRectangle(cornerRadius: 14).fill(.black.opacity(0.22)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Gallery.brass.opacity(0.18)))
        .task(id: entry.id) { shareURL = await controller.shareURL(for: entry) }
    }

    /// Factual museum context (source + medium/dimensions + optional description).
    @ViewBuilder private var placard: some View {
        Text(entry.artwork.source).font(.system(size: 11)).foregroundStyle(Gallery.muted)
        let facts = [entry.artwork.medium, entry.artwork.dimensions]
            .compactMap { $0 }.filter { !$0.isEmpty }
        if !facts.isEmpty {
            Text(facts.joined(separator: " · "))
                .font(.system(size: 11)).foregroundStyle(Gallery.muted)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
        }
        if let desc = entry.artwork.museumDescription, !desc.isEmpty {
            DisclosureGroup(t("details.show")) {
                Text(desc)
                    .font(.system(size: 11)).foregroundStyle(Gallery.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(8)
            }
            .font(.system(size: 11)).tint(Gallery.brass)
            .frame(maxWidth: 320)
        }
    }
}

/// A grid cell: framed thumbnail + a placard with artist (italic) and title.
private struct FramedPiece: View {
    let entry: LibraryEntry
    let isCurrent: Bool
    let isFavorite: Bool
    let onSelect: () -> Void
    let onFavorite: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 9) {
            ZStack(alignment: .topTrailing) {
                ArtThumbnail(path: entry.sourcePath, maxPixel: 480, contentMode: .fit)
                    .frame(height: 124)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(isCurrent ? Gallery.brass : Color.white.opacity(0.07),
                                    lineWidth: isCurrent ? 2 : 1)
                    )
                    .shadow(color: .black.opacity(0.5), radius: hovering ? 13 : 6, y: hovering ? 8 : 4)

                Button(action: onFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 12, weight: .bold))
                        .padding(5)
                        .background(.black.opacity(0.4), in: Circle())
                        .foregroundStyle(isFavorite ? Gallery.brass : .white.opacity(0.9))
                }
                .buttonStyle(.plain)
                .padding(7)
            }

            VStack(spacing: 2) {
                Text(entry.artwork.artistDisplay)
                    .font(Gallery.serif(11)).italic()
                    .foregroundStyle(Gallery.brass.opacity(0.9))
                    .lineLimit(1)
                Text(entry.artwork.title)
                    .font(Gallery.serif(12))
                    .foregroundStyle(Gallery.ivory.opacity(0.92))
                    .lineLimit(1)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
        .scaleEffect(hovering ? 1.03 : 1)
        .animation(.easeOut(duration: 0.15), value: hovering)
        .onHover { hovering = $0 }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .help("\(entry.artwork.title) — \(entry.artwork.artistDisplay)")
    }
}

/// Settings room — wraps the form on the gallery wall.
private struct StudioView: View {
    var body: some View {
        SettingsFormView()
            .scrollContentBackground(.hidden)
    }
}

/// Shown when the pool is empty: loading / offline / empty, with a retry.
private struct GalleryStatusView: View {
    let state: AppController.LibraryState
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            switch state {
            case .loading:
                ProgressView().controlSize(.large)
                Text(t("status.loadingTitle"))
                    .font(Gallery.serif(16)).foregroundStyle(Gallery.ivory)
                Text(t("status.loadingBody"))
                    .font(.system(size: 12)).foregroundStyle(Gallery.muted)
            case .offline:
                Image(systemName: "wifi.slash").font(.system(size: 34)).foregroundStyle(Gallery.brass)
                Text(t("status.offlineTitle"))
                    .font(Gallery.serif(16)).foregroundStyle(Gallery.ivory)
                Text(t("status.offlineBody"))
                    .font(.system(size: 12)).foregroundStyle(Gallery.muted)
                Button(t("status.retry"), action: onRetry).buttonStyle(.borderedProminent)
            case .empty:
                Image(systemName: "photo.artframe").font(.system(size: 34)).foregroundStyle(Gallery.brass)
                Text(t("status.emptyTitle"))
                    .font(Gallery.serif(16)).foregroundStyle(Gallery.ivory)
                Text(t("status.emptyBody"))
                    .font(.system(size: 12)).foregroundStyle(Gallery.muted)
                    .multilineTextAlignment(.center).frame(maxWidth: 360)
                Button(t("status.retry"), action: onRetry).buttonStyle(.borderedProminent)
            case .ready:
                EmptyView()
            }
        }
        .padding(30)
    }
}

// MARK: - Thumbnail (efficient ImageIO downsample, cached per path+size)

struct ArtThumbnail: View {
    let path: String
    var maxPixel: Int = 420
    var contentMode: ContentMode = .fill
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: contentMode)
            } else {
                Rectangle().fill(.black.opacity(0.25))
                    .overlay(ProgressView().controlSize(.small))
            }
        }
        .clipped()
        .task(id: path) {
            image = await Thumbnailer.shared.thumbnail(path: path, maxPixel: maxPixel)
        }
    }
}

actor Thumbnailer {
    static let shared = Thumbnailer()
    private let cache: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()
        c.countLimit = 40          // max 40 images retained at once
        c.totalCostLimit = 80 * 1024 * 1024  // 80 MB pixel budget
        return c
    }()

    func thumbnail(path: String, maxPixel: Int) -> NSImage? {
        let key = "\(path)#\(maxPixel)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        let cost = cg.width * cg.height * 4  // bytes in pixel buffer
        cache.setObject(img, forKey: key, cost: cost)
        return img
    }
}
