import Foundation

/// A single public-domain artwork fetched from a museum open-access source.
struct Artwork: Codable, Identifiable, Hashable, Sendable {
    /// Stable id in the form "<source>:<sourceID>", e.g. "AIC:28560".
    let id: String
    let title: String
    /// Display name of the artist.
    let artist: String
    /// Free-form date string, e.g. "1889".
    let date: String
    /// High-resolution source image URL (requested at >= 4K width where possible).
    let imageURL: URL
    /// Human-readable source / institution.
    let source: String
    /// Attribution / license note (always CC0 / public domain here).
    let creditLine: String?
    /// Original image pixel size when the source provides it (AIC does); used to
    /// filter by orientation before downloading. Optional → decodes old JSON fine.
    var pixelWidth: Int? = nil
    var pixelHeight: Int? = nil
    // Optional museum-provided context (shown as a factual placard — never fabricated).
    var medium: String? = nil
    var dimensions: String? = nil
    var department: String? = nil
    var museumDescription: String? = nil

    /// True if there is any real museum context to show.
    var hasDetails: Bool {
        [medium, dimensions, department, museumDescription]
            .contains { ($0?.isEmpty == false) }
    }

    /// Caption shown under the artwork: "Artist · Year" (or just the artist if no date).
    var caption: String {
        date.trimmingCharacters(in: .whitespaces).isEmpty ? artist : "\(artist) · \(date)"
    }

    /// Artist name for display, with a fallback for local/unknown images.
    var artistDisplay: String {
        artist.trimmingCharacters(in: .whitespaces).isEmpty ? "Bilinmeyen sanatçı" : artist
    }

    /// Known pixel size, if the source provided it.
    var knownPixelSize: (width: Int, height: Int)? {
        if let w = pixelWidth, let h = pixelHeight, w > 0, h > 0 { return (w, h) }
        return nil
    }

    /// Pre-download orientation check: pass if size unknown, else must match.
    func matchesPreFilter(_ orientation: Orientation) -> Bool {
        guard let s = knownPixelSize else { return true }
        return orientation.accepts(width: s.width, height: s.height)
    }

    /// Filesystem-safe identifier derived from `id` (handles ":" from source
    /// prefixes and "/", "+", "=" from base64 local ids).
    var fileStem: String {
        let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        let mapped = id.map { allowed.contains($0) ? $0 : "_" }
        return String(String(mapped).prefix(96))
    }
}
