import Foundation

/// Persisted set of favorite artworks (metadata only — files can be re-rendered
/// from the stored image URL, so favorites survive pool churn and resets).
@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var favorites: [Artwork] = []

    init() { load() }

    func contains(_ id: String) -> Bool {
        favorites.contains { $0.id == id }
    }

    /// Add the artwork if absent, remove it if present. Returns the new state.
    @discardableResult
    func toggle(_ artwork: Artwork) -> Bool {
        if let idx = favorites.firstIndex(where: { $0.id == artwork.id }) {
            favorites.remove(at: idx)
            save()
            return false
        } else {
            favorites.insert(artwork, at: 0)
            save()
            return true
        }
    }

    func remove(_ id: String) {
        favorites.removeAll { $0.id == id }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: LibraryPaths.favoritesFile),
              let list = try? JSONDecoder().decode([Artwork].self, from: data) else { return }
        favorites = list
    }

    private func save() {
        LibraryPaths.ensureDirs()
        if let data = try? JSONEncoder().encode(favorites) {
            try? data.write(to: LibraryPaths.favoritesFile, options: .atomic)
        }
    }
}
