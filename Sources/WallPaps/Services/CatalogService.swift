import Foundation

/// Holds the effective artist/collection catalog: remote manifest → cached →
/// bundled defaults. Refreshing the remote manifest expands the catalog WITHOUT
/// an app update. Never fails the app: any error keeps the previous (bundled or
/// cached) catalog.
@MainActor
final class CatalogService: ObservableObject {
    static let shared = CatalogService()

    @Published private(set) var artists: [Artist] = Artist.defaults
    @Published private(set) var collections: [ArtCollection] = ArtCollection.all
    @Published private(set) var featured: Featured?

    struct Featured: Equatable {
        let collectionId: String
        let titleTR: String
        let titleEN: String
        var localizedTitle: String { Localization.resolved() == .tr ? titleTR : titleEN }
    }

    /// Live catalog hosted on GitHub — edit catalog/catalog.json + push to expand.
    static let manifestURL = URL(string:
        "https://raw.githubusercontent.com/sdemirbas/WallPaps/main/catalog/catalog.json")!

    private init() { loadCached() }

    /// Load the last-fetched manifest from disk (if any).
    func loadCached() {
        guard let data = try? Data(contentsOf: LibraryPaths.catalogFile),
              let manifest = try? JSONDecoder().decode(CatalogManifest.self, from: data) else { return }
        apply(manifest)
    }

    /// Fetch the remote manifest; on success update + cache, otherwise keep current.
    func refresh() async {
        guard let (data, response) = try? await artNetwork.data(from: Self.manifestURL),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let manifest = try? JSONDecoder().decode(CatalogManifest.self, from: data)
        else { return }
        LibraryPaths.ensureDirs()
        try? data.write(to: LibraryPaths.catalogFile, options: .atomic)
        apply(manifest)
    }

    private func apply(_ manifest: CatalogManifest) {
        let newArtists = manifest.artists.map { Artist($0.name, displayName: $0.displayName) }
        if !newArtists.isEmpty { artists = newArtists }

        let newCollections = manifest.collections.map {
            ArtCollection(id: $0.id, nameTR: $0.nameTR, nameEN: $0.nameEN,
                          artists: $0.artists,
                          orientation: $0.orientation.flatMap(Orientation.init(rawValue:)))
        }
        if !newCollections.isEmpty { collections = newCollections }

        if let f = manifest.featured {
            featured = Featured(collectionId: f.collectionId, titleTR: f.titleTR, titleEN: f.titleEN)
        }
    }
}
