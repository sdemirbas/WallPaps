import CoreGraphics

/// Visual frame/matte themes for the wallpaper composition.
enum FrameTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case classic   // warm off-white mat, thin dark frame (default)
    case gold      // gilded gold frame, cream mat, deep dark wall
    case modern    // minimal: white mat, hairline frame, light wall
    case vintage   // aged sepia mat, dark wood frame, warm wall

    var id: String { rawValue }

    var label: String {
        switch self {
        case .classic: return t("theme.classic")
        case .gold:    return t("theme.gold")
        case .modern:  return t("theme.modern")
        case .vintage: return t("theme.vintage")
        }
    }

    /// Short code used in cache filenames (style signature).
    var sig: String {
        switch self {
        case .classic: return "cl"
        case .gold:    return "gd"
        case .modern:  return "md"
        case .vintage: return "vn"
        }
    }

    var style: ThemeStyle {
        switch self {
        case .classic:
            return ThemeStyle(bgTarget: (0.10, 0.10, 0.11), bgFraction: 0.70, bgSolid: nil,
                              matColor: (0.96, 0.95, 0.93), frameColor: (0.10, 0.09, 0.08),
                              frameFactor: 0.20, minFrame: 3, gilded: false, bevel: false)
        case .gold:
            return ThemeStyle(bgTarget: (0.06, 0.05, 0.04), bgFraction: 0.80, bgSolid: nil,
                              matColor: (0.94, 0.90, 0.80), frameColor: (0.55, 0.40, 0.12),
                              frameFactor: 0.85, minFrame: 8, gilded: true, bevel: true)
        case .modern:
            return ThemeStyle(bgTarget: (0, 0, 0), bgFraction: 0, bgSolid: (0.93, 0.93, 0.94),
                              matColor: (1.0, 1.0, 1.0), frameColor: (0.82, 0.82, 0.84),
                              frameFactor: 0.06, minFrame: 2, gilded: false, bevel: false)
        case .vintage:
            return ThemeStyle(bgTarget: (0.14, 0.10, 0.07), bgFraction: 0.74, bgSolid: nil,
                              matColor: (0.85, 0.78, 0.64), frameColor: (0.30, 0.19, 0.10),
                              frameFactor: 0.70, minFrame: 6, gilded: false, bevel: true)
        }
    }
}

/// Concrete rendering parameters resolved from a `FrameTheme`.
struct ThemeStyle: Sendable {
    /// Background = artwork average blended toward `bgTarget` by `bgFraction`…
    let bgTarget: (CGFloat, CGFloat, CGFloat)
    let bgFraction: CGFloat
    /// …unless `bgSolid` is set (then the background is this flat color).
    let bgSolid: (CGFloat, CGFloat, CGFloat)?
    let matColor: (CGFloat, CGFloat, CGFloat)
    let frameColor: (CGFloat, CGFloat, CGFloat)
    /// Frame band width as a fraction of the matte width.
    let frameFactor: CGFloat
    let minFrame: CGFloat
    /// Draw a gold gradient over the frame band.
    let gilded: Bool
    /// Draw highlight/shadow bevel lines for depth.
    let bevel: Bool
}
