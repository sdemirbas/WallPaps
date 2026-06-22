import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

/// Rendering knobs for the matte/border ("paspartu") composition.
struct RenderOptions: Sendable {
    var showCaption: Bool = true
    /// Matte width as a fraction of the artwork's longer side.
    var matWidthPercent: Double = 0.08
    /// The artwork (excluding matte/frame) occupies at most this fraction of the canvas.
    var artworkMaxFraction: CGFloat = 0.66
    var frameTheme: FrameTheme = .classic
    /// When true, a subtle "made with WallPaps" credit is drawn (for share images).
    var shareCredit: Bool = false
    /// Gallery atmosphere: spotlight, vignette, fine grain, engraved brass placard.
    var galleryAmbiance: Bool = true
    /// Hour of day (0–23) — warms/cools the gallery ("opens and closes").
    var hour: Int = 12
    /// Resolve the frame from the artwork's period (handled by the library before render).
    var autoFrameByPeriod: Bool = false

    /// Coarse time-of-day bucket (4 buckets → at most 4 cached variants/day).
    var periodChar: String {
        switch hour {
        case 0...6:   return "n" // night
        case 7...11:  return "m" // morning
        case 12...17: return "d" // day
        default:      return "e" // evening
        }
    }

    /// Compact signature of the style-affecting options, used in cache filenames
    /// so a style change naturally produces fresh variants.
    var styleSignature: String {
        "c\(showCaption ? 1 : 0)m\(Int((matWidthPercent * 1000).rounded()))t\(frameTheme.sig)a\(galleryAmbiance ? 1 : 0)\(galleryAmbiance ? periodChar : "")"
    }
}

/// Composites a public-domain painting onto a 4K-class canvas in a matte + frame
/// style (themeable), with an optional caption. Pure Core Graphics / Core Text /
/// ImageIO so it is safe to run off the main thread.
enum WallpaperRenderer {

    static func render(sourceData: Data,
                       caption: String,
                       title: String = "",
                       detail: String = "",
                       canvasPixelSize: CGSize,
                       options: RenderOptions,
                       useJPEG: Bool = false) -> Data? {
        guard let src = loadImage(sourceData) else { return nil }
        let w = Int(canvasPixelSize.width.rounded())
        let h = Int(canvasPixelSize.height.rounded())
        guard w > 0, h > 0 else { return nil }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        let W = CGFloat(w), H = CGFloat(h)
        let style = options.frameTheme.style
        let ambiance = options.galleryAmbiance
        let tint = periodTint(options.hour)
        ctx.interpolationQuality = .high

        // 1) Background (period-tinted for time-of-day ambiance).
        let avg = averageColor(src)
        var bg = style.bgSolid ?? blend(avg, toward: style.bgTarget, fraction: style.bgFraction)
        if ambiance { bg = blend(bg, toward: tint.wall, fraction: tint.wallAmount) }
        setFill(ctx, bg)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

        // 2) Geometry (artwork + matte + frame), clamped to fit the canvas.
        let sW = CGFloat(src.width), sH = CGFloat(src.height)
        let hasLabel = options.showCaption && (!caption.isEmpty || !title.isEmpty)
        let labelRoom = hasLabel ? H * (ambiance ? 0.10 : 0.06) : 0

        let maxW = W * options.artworkMaxFraction
        let maxH = (H - labelRoom) * options.artworkMaxFraction
        let scale0 = min(maxW / sW, maxH / sH, 1.0)
        var aW = sW * scale0, aH = sH * scale0
        var mat = max(aW, aH) * CGFloat(options.matWidthPercent)
        var frameW = max(style.minFrame, mat * style.frameFactor)

        let availW = W * 0.96, availH = (H - labelRoom) * 0.96
        let shrink = min(availW / (aW + 2 * (mat + frameW)),
                         availH / (aH + 2 * (mat + frameW)), 1.0)
        aW = (aW * shrink).rounded(); aH = (aH * shrink).rounded()
        mat = (mat * shrink).rounded(); frameW = (frameW * shrink).rounded()

        let aX = ((W - aW) / 2).rounded()
        let aY = ((H - aH) / 2 + labelRoom / 2).rounded()
        let artRect = CGRect(x: aX, y: aY, width: aW, height: aH)
        let matRect = artRect.insetBy(dx: -mat, dy: -mat)
        let outerRect = matRect.insetBy(dx: -frameW, dy: -frameW)

        // 2.5) Gallery atmosphere on the WALL (grain, track-light spotlight, vignette).
        if ambiance {
            drawGrain(ctx, canvas: CGSize(width: W, height: H))
            drawSpotlight(ctx, canvas: CGSize(width: W, height: H),
                          center: CGPoint(x: outerRect.midX, y: outerRect.midY + H * 0.05),
                          color: tint.spot, alpha: tint.spotAlpha)
            drawVignette(ctx, canvas: CGSize(width: W, height: H), strength: tint.vignette)
        }

        // 3) Frame band (with drop shadow for depth).
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -(frameW + mat) * 0.35),
                      blur: max(10, (frameW + mat) * 0.55),
                      color: CGColor(gray: 0, alpha: 0.5))
        setFill(ctx, style.frameColor)
        ctx.fill(outerRect)
        ctx.restoreGState()

        if style.gilded { drawGold(ctx, outer: outerRect, inner: matRect) }
        if style.bevel  { drawBevel(ctx, outer: outerRect, inner: matRect, frameW: frameW) }

        // 4) Matte.
        setFill(ctx, style.matColor)
        ctx.fill(matRect)

        ctx.setStrokeColor(CGColor(gray: 0, alpha: 0.15))
        ctx.setLineWidth(max(1, mat * 0.03))
        ctx.stroke(artRect)

        // 5) The painting itself.
        ctx.draw(src, in: artRect)

        // 6) Label — engraved brass placard (ambiance) or plain caption.
        if hasLabel {
            if ambiance {
                drawPlacard(ctx, canvas: CGSize(width: W, height: H), belowY: outerRect.minY,
                            title: title, caption: caption, detail: detail)
            } else if !caption.isEmpty {
                drawCaption(caption, in: ctx, canvas: CGSize(width: W, height: H),
                            belowY: outerRect.minY, bgIsDark: luminance(bg) < 0.5)
            }
        }

        // 7) Optional share credit, bottom-right.
        if options.shareCredit {
            drawShareCredit(in: ctx, canvas: CGSize(width: W, height: H),
                            bgIsDark: luminance(bg) < 0.5)
        }

        guard let out = ctx.makeImage() else { return nil }
        return useJPEG ? encodeJPEG(out) : encodePNG(out)
    }

    // MARK: - Gallery atmosphere

    private struct PeriodTint {
        let wall: (CGFloat, CGFloat, CGFloat); let wallAmount: CGFloat
        let spot: (CGFloat, CGFloat, CGFloat); let spotAlpha: CGFloat
        let vignette: CGFloat
    }

    private static func periodTint(_ hour: Int) -> PeriodTint {
        switch hour {
        case 0...6:   return PeriodTint(wall: (0.05, 0.06, 0.10), wallAmount: 0.30,
                                        spot: (1.0, 0.86, 0.62), spotAlpha: 0.16, vignette: 0.50)
        case 7...11:  return PeriodTint(wall: (0.60, 0.64, 0.70), wallAmount: 0.10,
                                        spot: (1.0, 0.98, 0.92), spotAlpha: 0.12, vignette: 0.34)
        case 12...17: return PeriodTint(wall: (0.50, 0.50, 0.50), wallAmount: 0.05,
                                        spot: (1.0, 1.0, 0.97), spotAlpha: 0.13, vignette: 0.32)
        default:      return PeriodTint(wall: (0.30, 0.19, 0.11), wallAmount: 0.20,
                                        spot: (1.0, 0.82, 0.55), spotAlpha: 0.17, vignette: 0.44)
        }
    }

    private static func drawSpotlight(_ ctx: CGContext, canvas: CGSize,
                                      center: CGPoint, color: (CGFloat, CGFloat, CGFloat), alpha: CGFloat) {
        ctx.saveGState()
        ctx.setBlendMode(.plusLighter)
        let cs = CGColorSpaceCreateDeviceRGB()
        let colors = [CGColor(red: color.0, green: color.1, blue: color.2, alpha: alpha),
                      CGColor(red: color.0, green: color.1, blue: color.2, alpha: 0)] as CFArray
        if let g = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1]) {
            let r = max(canvas.width, canvas.height) * 0.72
            ctx.drawRadialGradient(g, startCenter: center, startRadius: 0,
                                   endCenter: center, endRadius: r, options: [])
        }
        ctx.restoreGState()
    }

    private static func drawVignette(_ ctx: CGContext, canvas: CGSize, strength: CGFloat) {
        ctx.saveGState()
        let cs = CGColorSpaceCreateDeviceRGB()
        let colors = [CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: strength)] as CFArray
        if let g = CGGradient(colorsSpace: cs, colors: colors, locations: [0.55, 1]) {
            let c = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
            let r = hypot(canvas.width, canvas.height) / 2
            ctx.drawRadialGradient(g, startCenter: c, startRadius: r * 0.35,
                                   endCenter: c, endRadius: r, options: [.drawsAfterEndLocation])
        }
        ctx.restoreGState()
    }

    private static func drawGrain(_ ctx: CGContext, canvas: CGSize) {
        guard let noise = noiseImage(size: 220) else { return }
        ctx.saveGState()
        ctx.setAlpha(0.035)
        ctx.setBlendMode(.overlay)
        ctx.draw(noise, in: CGRect(x: 0, y: 0, width: canvas.width, height: canvas.height))
        ctx.restoreGState()
    }

    private static func noiseImage(size: Int) -> CGImage? {
        var px = [UInt8](repeating: 0, count: size * size * 4)
        var i = 0
        while i < px.count {
            let v = UInt8.random(in: 90...165)
            px[i] = v; px[i + 1] = v; px[i + 2] = v; px[i + 3] = 255
            i += 4
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        return px.withUnsafeMutableBytes { ptr -> CGImage? in
            guard let c = CGContext(data: ptr.baseAddress, width: size, height: size,
                                    bitsPerComponent: 8, bytesPerRow: size * 4, space: cs,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            return c.makeImage()
        }
    }

    /// Engraved brass museum placard: title (serif), "Artist · Year", and medium.
    private static func drawPlacard(_ ctx: CGContext, canvas: CGSize, belowY: CGFloat,
                                    title: String, caption: String, detail: String) {
        let H = canvas.height
        var lines: [(CTLine, CGFloat, CGFloat)] = [] // line, width, height
        func add(_ text: String, size: CGFloat, serif: Bool, kern: CGFloat) {
            guard !text.isEmpty else { return }
            let fontName = serif ? "Times New Roman" : "Helvetica Neue"
            let font = CTFontCreateWithName(fontName as CFString, size, nil)
            let attrs: [CFString: Any] = [kCTFontAttributeName: font,
                                          kCTForegroundColorAttributeName: CGColor(gray: 0.16, alpha: 1),
                                          kCTKernAttributeName: kern]
            guard let a = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary) else { return }
            let line = CTLineCreateWithAttributedString(a)
            let b = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
            lines.append((line, b.width, b.height))
        }
        add(title, size: H * 0.018, serif: true, kern: 0)
        add(caption, size: H * 0.014, serif: false, kern: H * 0.0006)
        add(detail, size: H * 0.011, serif: false, kern: 0)
        guard !lines.isEmpty else { return }

        let padX = H * 0.022, padY = H * 0.016, lineGap = H * 0.008
        let textW = lines.map(\.1).max() ?? 0
        let textH = lines.map(\.2).reduce(0, +) + lineGap * CGFloat(lines.count - 1)
        let plateW = textW + 2 * padX
        let plateH = textH + 2 * padY
        let plateX = (canvas.width - plateW) / 2
        let plateY = max(belowY - H * 0.012 - plateH, H * 0.02)
        let plate = CGRect(x: plateX, y: plateY, width: plateW, height: plateH)

        // Brass plate with a soft shadow.
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -H * 0.004), blur: H * 0.01,
                      color: CGColor(gray: 0, alpha: 0.5))
        let path = CGPath(roundedRect: plate, cornerWidth: H * 0.006, cornerHeight: H * 0.006, transform: nil)
        ctx.addPath(path); ctx.clip()
        let cs = CGColorSpaceCreateDeviceRGB()
        let brass = [CGColor(red: 0.80, green: 0.66, blue: 0.36, alpha: 1),
                     CGColor(red: 0.62, green: 0.49, blue: 0.22, alpha: 1)] as CFArray
        if let g = CGGradient(colorsSpace: cs, colors: brass, locations: [0, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: plate.minX, y: plate.maxY),
                                   end: CGPoint(x: plate.minX, y: plate.minY), options: [])
        }
        ctx.restoreGState()
        ctx.addPath(CGPath(roundedRect: plate.insetBy(dx: 0.5, dy: 0.5),
                           cornerWidth: H * 0.006, cornerHeight: H * 0.006, transform: nil))
        ctx.setStrokeColor(CGColor(red: 0.36, green: 0.27, blue: 0.10, alpha: 0.9))
        ctx.setLineWidth(max(1, H * 0.0012)); ctx.strokePath()

        // Engraved (debossed) text: a light highlight under a dark line.
        var y = plate.maxY - padY
        for (line, width, height) in lines {
            y -= height
            let x = (canvas.width - width) / 2
            ctx.textPosition = CGPoint(x: x, y: y + height * 0.18)
            ctx.saveGState()
            ctx.setTextDrawingMode(.fill)
            // highlight copy (brass-light), 1px below
            ctx.textMatrix = .identity
            drawLineTinted(ctx, line: line, at: CGPoint(x: x, y: y + height * 0.18 - max(1, H * 0.0012)),
                           color: CGColor(red: 0.96, green: 0.86, blue: 0.55, alpha: 0.7))
            // dark engraved copy on top
            drawLineTinted(ctx, line: line, at: CGPoint(x: x, y: y + height * 0.18),
                           color: CGColor(red: 0.20, green: 0.14, blue: 0.04, alpha: 1))
            ctx.restoreGState()
            y -= lineGap
        }
    }

    private static func drawLineTinted(_ ctx: CGContext, line: CTLine, at p: CGPoint, color: CGColor) {
        ctx.saveGState()
        ctx.setFillColor(color)
        // Re-color glyphs: draw each run with our fill (CTLineDraw uses attribute colors,
        // so override via text drawing mode + a context fill is unreliable; use runs).
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let count = CTRunGetGlyphCount(run)
            if count == 0 { continue }
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRangeMake(0, count), &glyphs)
            CTRunGetPositions(run, CFRangeMake(0, count), &positions)
            let attrs = CTRunGetAttributes(run) as NSDictionary
            let font = attrs[kCTFontAttributeName as String] as! CTFont
            for i in 0..<count { positions[i] = CGPoint(x: positions[i].x + p.x, y: positions[i].y + p.y) }
            CTFontDrawGlyphs(font, glyphs, positions, count, ctx)
        }
        ctx.restoreGState()
    }

    // MARK: - Frame detailing

    /// Fill the frame band (outer minus inner) with a diagonal gold gradient.
    private static func drawGold(_ ctx: CGContext, outer: CGRect, inner: CGRect) {
        ctx.saveGState()
        let band = CGMutablePath()
        band.addRect(outer); band.addRect(inner)
        ctx.addPath(band); ctx.clip(using: .evenOdd)

        let cs = CGColorSpaceCreateDeviceRGB()
        let colors = [
            CGColor(colorSpace: cs, components: [0.98, 0.88, 0.55, 1])!,
            CGColor(colorSpace: cs, components: [0.78, 0.60, 0.22, 1])!,
            CGColor(colorSpace: cs, components: [0.95, 0.82, 0.45, 1])!,
            CGColor(colorSpace: cs, components: [0.50, 0.36, 0.12, 1])!,
        ] as CFArray
        if let g = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 0.4, 0.65, 1]) {
            ctx.drawLinearGradient(g,
                                   start: CGPoint(x: outer.minX, y: outer.maxY),
                                   end: CGPoint(x: outer.maxX, y: outer.minY),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
        ctx.restoreGState()
    }

    /// Highlight on the outer edge, shadow on the inner edge — gives the frame depth.
    private static func drawBevel(_ ctx: CGContext, outer: CGRect, inner: CGRect, frameW: CGFloat) {
        let lw = max(1, frameW * 0.10)
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.16))
        ctx.setLineWidth(lw)
        ctx.stroke(outer.insetBy(dx: lw / 2, dy: lw / 2))

        ctx.setStrokeColor(CGColor(gray: 0, alpha: 0.35))
        ctx.setLineWidth(lw)
        ctx.stroke(inner.insetBy(dx: -lw / 2, dy: -lw / 2))
    }

    // MARK: - Helpers

    private static func setFill(_ ctx: CGContext, _ c: (CGFloat, CGFloat, CGFloat)) {
        ctx.setFillColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
    }

    private static func loadImage(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func drawCaption(_ text: String,
                                    in ctx: CGContext,
                                    canvas: CGSize,
                                    belowY: CGFloat,
                                    bgIsDark: Bool) {
        let fontSize = canvas.height * 0.016
        let font = CTFontCreateWithName("Helvetica Neue" as CFString, fontSize, nil)
        let gray: CGFloat = bgIsDark ? 0.92 : 0.12
        let color = CGColor(red: gray, green: gray, blue: gray, alpha: 0.9)

        let attrs: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: color,
            kCTKernAttributeName: fontSize * 0.04
        ]
        guard let attr = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary)
        else { return }
        let line = CTLineCreateWithAttributedString(attr)
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

        let tx = (canvas.width - bounds.width) / 2
        let ty = max(belowY - canvas.height * 0.045, canvas.height * 0.03)
        ctx.textPosition = CGPoint(x: tx, y: ty)
        CTLineDraw(line, ctx)
    }

    /// Small "made with WallPaps" credit in the bottom-right corner (share images).
    private static func drawShareCredit(in ctx: CGContext, canvas: CGSize, bgIsDark: Bool) {
        let text = "✦ " + t("share.credit")
        let fontSize = canvas.height * 0.013
        let font = CTFontCreateWithName("Helvetica Neue" as CFString, fontSize, nil)
        let gray: CGFloat = bgIsDark ? 0.78 : 0.30
        let color = CGColor(red: gray, green: gray, blue: gray, alpha: 0.8)
        let attrs: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: color,
            kCTKernAttributeName: fontSize * 0.05
        ]
        guard let attr = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary) else { return }
        let line = CTLineCreateWithAttributedString(attr)
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        let margin = canvas.height * 0.03
        ctx.textPosition = CGPoint(x: canvas.width - bounds.width - margin, y: margin)
        CTLineDraw(line, ctx)
    }

    private static func averageColor(_ image: CGImage) -> (CGFloat, CGFloat, CGFloat) {
        var px = [UInt8](repeating: 0, count: 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let c = CGContext(data: &px, width: 1, height: 1,
                                bitsPerComponent: 8, bytesPerRow: 4, space: cs,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return (0.1, 0.1, 0.11) }
        c.interpolationQuality = .medium
        c.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (CGFloat(px[0]) / 255, CGFloat(px[1]) / 255, CGFloat(px[2]) / 255)
    }

    private static func blend(_ c: (CGFloat, CGFloat, CGFloat),
                              toward t: (CGFloat, CGFloat, CGFloat),
                              fraction f: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
        (c.0 * (1 - f) + t.0 * f, c.1 * (1 - f) + t.1 * f, c.2 * (1 - f) + t.2 * f)
    }

    private static func luminance(_ c: (CGFloat, CGFloat, CGFloat)) -> CGFloat {
        0.2126 * c.0 + 0.7152 * c.1 + 0.0722 * c.2
    }

    private static func encodePNG(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    static func encodeJPEG(_ image: CGImage, quality: CGFloat = 0.92) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }
}
