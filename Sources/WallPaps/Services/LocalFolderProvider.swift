import Foundation

/// Turns the images in a user-chosen local folder into `Artwork` values so they
/// can be matted and rotated alongside (or instead of) museum images.
/// Resolves a security-scoped bookmark when present (sandbox-ready), falling
/// back to a plain path otherwise.
enum LocalFolderProvider {
    private static let imageExtensions: Set<String> =
        ["jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "gif", "bmp", "webp"]

    static func artworks(bookmark: Data?, fallbackPath: String?) -> [Artwork] {
        if let bookmark {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: bookmark,
                                  options: [.withSecurityScope],
                                  relativeTo: nil, bookmarkDataIsStale: &stale) {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                return artworks(inFolder: url)
            }
        }
        if let fallbackPath { return artworks(inFolder: URL(fileURLWithPath: fallbackPath)) }
        return []
    }

    static func artworks(inFolderPath path: String) -> [Artwork] {
        artworks(inFolder: URL(fileURLWithPath: path))
    }

    private static func artworks(inFolder folder: URL) -> [Artwork] {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]) else { return [] }

        return items.compactMap { url -> Artwork? in
            guard imageExtensions.contains(url.pathExtension.lowercased()) else { return nil }
            let name = url.deletingPathExtension().lastPathComponent
            let encoded = Data(url.path.utf8).base64EncodedString()
            return Artwork(
                id: "Local:\(encoded)",
                title: name,
                artist: "",
                date: "",
                imageURL: url,
                source: "Yerel klasör",
                creditLine: nil
            )
        }
    }
}
