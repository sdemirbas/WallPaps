import Foundation

/// Art Institute of Chicago — open-access API (no key required).
/// Docs: https://api.artic.edu/docs/  ·  Images via IIIF Image API 2.0.
struct ArticProvider: ArtworkSource {
    let name = "Art Institute of Chicago"

    private static let fallbackIIIF = "https://www.artic.edu/iiif/2"

    /// Requested IIIF width in pixels (height auto). 4K-class for crisp masters.
    private static let targetWidth = 3840

    private struct SearchResponse: Decodable {
        let data: [Item]
        let config: Config

        struct Config: Decodable { let iiif_url: String? }
        struct Item: Decodable {
            let id: Int
            let title: String?
            let image_id: String?
            let artist_display: String?
            let date_display: String?
            let is_public_domain: Bool?
            let thumbnail: Thumbnail?
            let medium_display: String?
            let dimensions: String?
            let department_title: String?
            let description: String?
            struct Thumbnail: Decodable { let width: Int?; let height: Int? }
        }
    }

    private func clean(_ s: String?) -> String? {
        // AIC `description` is HTML; strip tags crudely for a plain placard.
        guard let s, !s.isEmpty else { return nil }
        let stripped = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? nil : stripped
    }

    func fetchArtworks(artist: String, limit: Int) async throws -> [Artwork] {
        try await fetchArtworks(artist: artist, limit: limit, page: 1)
    }

    /// Paginated fetch — `page` (1-based) lets the library pull fresh results
    /// across rounds to build a large pool.
    func fetchArtworks(artist: String, limit: Int, page: Int) async throws -> [Artwork] {
        var comps = URLComponents(string: "https://api.artic.edu/api/v1/artworks/search")!
        comps.queryItems = [
            .init(name: "q", value: artist),
            .init(name: "query[term][is_public_domain]", value: "true"),
            .init(name: "fields", value: "id,title,image_id,artist_display,date_display,is_public_domain,thumbnail,medium_display,dimensions,department_title,description"),
            .init(name: "limit", value: String(max(limit, 10))),
            .init(name: "page", value: String(max(page, 1)))
        ]

        let (data, response) = try await artNetwork.data(from: comps.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ArtSourceError.badResponse }

        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        let base = decoded.config.iiif_url ?? Self.fallbackIIIF

        return decoded.data.compactMap { item -> Artwork? in
            // Require an image and (defensively) public-domain status.
            guard item.is_public_domain != false,
                  let imageID = item.image_id, !imageID.isEmpty,
                  let url = URL(string: "\(base)/\(imageID)/full/\(Self.targetWidth),/0/default.jpg")
            else { return nil }

            let artistName = item.artist_display.map(cleanArtistName) ?? artist
            return Artwork(
                id: "AIC:\(item.id)",
                title: item.title ?? "Untitled",
                artist: artistName.isEmpty ? artist : artistName,
                date: item.date_display ?? "",
                imageURL: url,
                source: name,
                creditLine: "CC0 Public Domain — Art Institute of Chicago",
                pixelWidth: item.thumbnail?.width,
                pixelHeight: item.thumbnail?.height,
                medium: item.medium_display,
                dimensions: item.dimensions,
                department: item.department_title,
                museumDescription: clean(item.description)
            )
        }
    }
}
