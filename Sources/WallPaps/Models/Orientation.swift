import Foundation

/// Preferred artwork orientation (by aspect ratio).
enum Orientation: String, CaseIterable, Identifiable, Codable, Sendable {
    case any        // Tümü
    case landscape  // Yatay
    case portrait   // Dikey

    var id: String { rawValue }

    var label: String {
        switch self {
        case .any:       return t("orient.any")
        case .landscape: return t("orient.landscape")
        case .portrait:  return t("orient.portrait")
        }
    }

    /// Whether an image of the given pixel size satisfies this orientation.
    func accepts(width: Int, height: Int) -> Bool {
        switch self {
        case .any:       return true
        case .landscape: return width >= height
        case .portrait:  return height >= width
        }
    }
}
