import Foundation

/// The Metropolitan Museum of Art — open-access API (no key required).
/// Docs: https://metmuseum.github.io/  ·  CC0 images via `primaryImage`.
struct MetProvider: ArtworkSource {
    let name = "The Met"

    private struct SearchResponse: Decodable {
        let total: Int
        let objectIDs: [Int]?
    }

    private struct ObjectResponse: Decodable {
        let title: String?
        let artistDisplayName: String?
        let objectDate: String?
        let primaryImage: String?
        let isPublicDomain: Bool?
        let creditLine: String?
        let medium: String?
        let dimensions: String?
        let department: String?
    }

    func fetchArtworks(artist: String, limit: Int) async throws -> [Artwork] {
        var comps = URLComponents(string: "https://collectionapi.metmuseum.org/public/collection/v1/search")!
        // Note: `artistOrCulture=true` is too strict here (returns 0 for many
        // painters); we rely on the text query plus our PD + image filter, and
        // the artist name is verified per-object below.
        comps.queryItems = [
            .init(name: "q", value: artist),
            .init(name: "hasImages", value: "true")
        ]

        let (data, response) = try await artNetwork.data(from: comps.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ArtSourceError.badResponse }

        let search = try JSONDecoder().decode(SearchResponse.self, from: data)
        // Overfetch ids: many objects are non-PD or lack a full-res image.
        let ids = Array((search.objectIDs ?? []).prefix(max(limit * 4, 12)))

        var artworks: [Artwork] = []
        for id in ids {
            if artworks.count >= limit { break }
            guard let obj = try? await fetchObject(id),
                  obj.isPublicDomain == true,
                  let img = obj.primaryImage, !img.isEmpty,
                  let url = URL(string: img)
            else { continue }

            let artistName = obj.artistDisplayName.map(cleanArtistName) ?? artist
            artworks.append(Artwork(
                id: "Met:\(id)",
                title: obj.title ?? "Untitled",
                artist: artistName.isEmpty ? artist : artistName,
                date: obj.objectDate ?? "",
                imageURL: url,
                source: name,
                creditLine: obj.creditLine ?? "CC0 Public Domain — The Met",
                medium: obj.medium,
                dimensions: obj.dimensions,
                department: obj.department,
                museumDescription: nil
            ))
        }
        return artworks
    }

    private func fetchObject(_ id: Int) async throws -> ObjectResponse {
        let url = URL(string: "https://collectionapi.metmuseum.org/public/collection/v1/objects/\(id)")!
        let (data, response) = try await artNetwork.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ArtSourceError.badResponse }
        return try JSONDecoder().decode(ObjectResponse.self, from: data)
    }
}
