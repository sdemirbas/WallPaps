import Foundation

/// Cleveland Museum of Art — Open Access API (no key required).
/// Docs: https://openaccess-api.clevelandart.org/  ·  CC0 images, full-res (often >10000px).
struct ClevelandProvider: ArtworkSource {
    let name = "Cleveland Museum of Art"

    func fetchArtworks(artist: String, limit: Int) async throws -> [Artwork] {
        try await fetchArtworks(artist: artist, limit: limit, skip: 0)
    }

    /// Paginated fetch via `skip` (offset).
    func fetchArtworks(artist: String, limit: Int, skip: Int) async throws -> [Artwork] {
        var comps = URLComponents(string: "https://openaccess-api.clevelandart.org/api/artworks/")!
        comps.queryItems = [
            .init(name: "q", value: artist),
            .init(name: "cc0", value: "1"),
            .init(name: "has_image", value: "1"),
            .init(name: "limit", value: String(limit)),
            .init(name: "skip", value: String(max(skip, 0))),
            .init(name: "fields", value: "id,title,creators,creation_date,images,department,technique,description")
        ]

        let (data, response) = try await artNetwork.data(from: comps.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ArtSourceError.badResponse }
        let decoded = try JSONDecoder().decode(Response.self, from: data)

        return decoded.data.compactMap { item -> Artwork? in
            guard let full = item.images?.full,
                  let urlString = full.url, let url = URL(string: urlString) else { return nil }
            let rawArtist = item.creators?.first?.description
            let artistName = rawArtist.map(cleanArtistName) ?? artist
            return Artwork(
                id: "CMA:\(item.id)",
                title: item.title ?? "Untitled",
                artist: artistName.isEmpty ? artist : artistName,
                date: item.creation_date ?? "",
                imageURL: url,
                source: name,
                creditLine: "CC0 Public Domain — Cleveland Museum of Art",
                pixelWidth: full.width.value,
                pixelHeight: full.height.value,
                medium: item.technique,
                dimensions: nil,
                department: item.department,
                museumDescription: nonEmpty(item.description)
            )
        }
    }

    private func nonEmpty(_ s: String?) -> String? {
        (s?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
    }

    // MARK: - Decodable

    private struct Response: Decodable { let data: [Item] }

    private struct Item: Decodable {
        let id: Int
        let title: String?
        let creation_date: String?
        let department: String?
        let technique: String?
        let description: String?
        let creators: [Creator]?
        let images: Images?

        struct Creator: Decodable { let description: String? }
        struct Images: Decodable { let full: ImageRef?; let web: ImageRef? }
        struct ImageRef: Decodable {
            let url: String?
            let width: FlexibleInt
            let height: FlexibleInt
        }
    }
}

/// Decodes an integer that may arrive as a number or a string ("900").
struct FlexibleInt: Decodable {
    let value: Int?
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) { value = i }
        else if let s = try? c.decode(String.self) { value = Int(s) }
        else if let d = try? c.decode(Double.self) { value = Int(d) }
        else { value = nil }
    }
}
