import Foundation

/// Remote-updatable catalog: lets the artist/collection list (and a featured
/// pick) be expanded AFTER deployment, without shipping a new app version.
/// Hosted as JSON (e.g. on GitHub raw); the app falls back to the bundled
/// defaults when it can't be fetched.
struct CatalogManifest: Codable, Sendable {
    var version: Int
    var minAppVersion: String?
    var artists: [ArtistEntry]
    var collections: [CollectionEntry]
    var featured: FeaturedEntry?

    struct ArtistEntry: Codable, Sendable {
        let name: String
        let displayName: String?
    }
    struct CollectionEntry: Codable, Sendable {
        let id: String
        let nameTR: String
        let nameEN: String
        let artists: [String]
        let orientation: String?
    }
    struct FeaturedEntry: Codable, Sendable {
        let collectionId: String
        let titleTR: String
        let titleEN: String
    }
}
