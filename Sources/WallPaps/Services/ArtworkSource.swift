import Foundation

/// A provider of public-domain artworks from a museum open-access API.
protocol ArtworkSource: Sendable {
    var name: String { get }
    /// Fetch up to `limit` public-domain artworks matching the given artist.
    func fetchArtworks(artist: String, limit: Int) async throws -> [Artwork]
}

enum ArtSourceError: Error {
    case badResponse
}

/// Shared, polite URLSession used by all providers and the image downloader.
let artNetwork: URLSession = {
    let config = URLSessionConfiguration.default
    config.httpAdditionalHeaders = [
        // The Art Institute of Chicago asks API clients to identify themselves.
        "AIC-User-Agent": "WallPaps/1.0 (personal use)",
        "User-Agent": "WallPaps/1.0 (personal macOS wallpaper app)"
    ]
    config.requestCachePolicy = .returnCacheDataElseLoad
    config.timeoutIntervalForRequest = 30
    config.waitsForConnectivity = false
    return URLSession(configuration: config)
}()

/// Normalize the artist string the museums return to just the name, e.g.
/// "Vincent van Gogh\nDutch, 1853–1890"  -> "Vincent van Gogh"
/// "Vincent van Gogh (Dutch, 1853–1890)" -> "Vincent van Gogh".
func cleanArtistName(_ raw: String) -> String {
    var name = raw.split(separator: "\n").first.map(String.init) ?? raw
    if let paren = name.range(of: " (") {
        name = String(name[..<paren.lowerBound])
    }
    return name.trimmingCharacters(in: .whitespacesAndNewlines)
}
