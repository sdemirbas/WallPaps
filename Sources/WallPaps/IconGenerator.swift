import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Draws a 1024×1024 app icon (a framed painting on a wall) and writes it as PNG.
/// Run via: `WallPaps --makeicon <path.png>`  (used by Scripts/build-app.sh).
enum IconGenerator {
    static func run(outputPath: String) -> Never {
        let size = 1024
        guard let data = render(size: size) else {
            FileHandle.standardError.write(Data("icon render failed\n".utf8))
            exit(1)
        }
        do {
            try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
            print("icon yazıldı: \(outputPath)")
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("icon write failed: \(error)\n".utf8))
            exit(1)
        }
    }

    private static func render(size: Int) -> Data? {
        let cs = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: size, height: size,
                                  bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        let S = CGFloat(size)
        ctx.interpolationQuality = .high

        // Rounded-rect background with a soft vertical gradient (macOS icon shape).
        let inset = S * 0.06
        let rect = CGRect(x: inset, y: inset, width: S - 2 * inset, height: S - 2 * inset)
        let path = CGPath(roundedRect: rect, cornerWidth: S * 0.22, cornerHeight: S * 0.22, transform: nil)
        ctx.saveGState()
        ctx.addPath(path); ctx.clip()
        if let grad = CGGradient(colorsSpace: cs,
                                 colors: [CGColor(red: 0.16, green: 0.17, blue: 0.22, alpha: 1),
                                          CGColor(red: 0.07, green: 0.08, blue: 0.11, alpha: 1)] as CFArray,
                                 locations: [0, 1]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: S),
                                   end: CGPoint(x: 0, y: 0), options: [])
        }

        // Framed painting in the center.
        let frame = CGRect(x: S * 0.27, y: S * 0.30, width: S * 0.46, height: S * 0.40)

        // Drop shadow under the frame.
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -S * 0.012), blur: S * 0.05,
                      color: CGColor(gray: 0, alpha: 0.55))
        ctx.setFillColor(CGColor(red: 0.10, green: 0.09, blue: 0.08, alpha: 1))
        ctx.fill(frame)
        ctx.restoreGState()

        // Matte (off-white).
        let mat = frame.insetBy(dx: frame.width * 0.07, dy: frame.height * 0.07)
        ctx.setFillColor(CGColor(red: 0.96, green: 0.95, blue: 0.93, alpha: 1))
        ctx.fill(mat)

        // "Painting": a warm gradient with a sun + hill motif (evokes a landscape).
        let art = mat.insetBy(dx: mat.width * 0.06, dy: mat.height * 0.06)
        ctx.saveGState()
        ctx.clip(to: art)
        if let sky = CGGradient(colorsSpace: cs,
                                colors: [CGColor(red: 0.99, green: 0.80, blue: 0.36, alpha: 1),
                                         CGColor(red: 0.93, green: 0.45, blue: 0.30, alpha: 1)] as CFArray,
                                locations: [0, 1]) {
            ctx.drawLinearGradient(sky, start: CGPoint(x: art.minX, y: art.maxY),
                                   end: CGPoint(x: art.minX, y: art.minY), options: [])
        }
        // Sun.
        ctx.setFillColor(CGColor(red: 1.0, green: 0.97, blue: 0.86, alpha: 0.95))
        let sun = CGRect(x: art.minX + art.width * 0.58, y: art.minY + art.height * 0.55,
                         width: art.width * 0.22, height: art.width * 0.22)
        ctx.fillEllipse(in: sun)
        // Hill.
        ctx.setFillColor(CGColor(red: 0.30, green: 0.45, blue: 0.55, alpha: 1))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: art.minX, y: art.minY))
        ctx.addQuadCurve(to: CGPoint(x: art.maxX, y: art.minY),
                         control: CGPoint(x: art.midX, y: art.minY + art.height * 0.45))
        ctx.addLine(to: CGPoint(x: art.maxX, y: art.minY))
        ctx.closePath()
        ctx.fillPath()
        ctx.restoreGState()

        ctx.restoreGState() // background clip

        guard let image = ctx.makeImage() else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            out, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
