import Foundation
import CoreGraphics

/// Renders a few real wallpaper compositions (different artists / themes / times
/// of day) for the landing page. These are exactly what the app sets as the
/// desktop wallpaper. Run via: `WallPaps --shots <outdir>`
enum ShotsGenerator {
    static func run(outDir: String) -> Never {
        let semaphore = DispatchSemaphore(value: 0)
        var code: Int32 = 1
        Task {
            defer { semaphore.signal() }
            try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

            // (artist, theme, hour, filename)
            let picks: [(String, FrameTheme, Int, String)] = [
                ("Claude Monet", .classic, 9, "monet"),
                ("Rembrandt van Rijn", .gold, 13, "rembrandt"),
                ("Katsushika Hokusai", .modern, 16, "hokusai"),
                ("Vincent van Gogh", .vintage, 20, "vangogh"),
            ]
            let aic = ArticProvider()
            let size = CGSize(width: 2560, height: 1600) // 16:10, Mac-like

            for (artist, theme, hour, name) in picks {
                guard let arts = try? await aic.fetchArtworks(artist: artist, limit: 12) else {
                    print("✗ \(artist): alınamadı"); continue
                }
                // Prefer a landscape-ish piece so it fills a desktop nicely.
                let art = arts.first { ($0.pixelWidth ?? 0) >= ($0.pixelHeight ?? 1) } ?? arts.first
                guard let art else { print("✗ \(artist): eser yok"); continue }
                guard let (data, resp) = try? await artNetwork.data(from: art.imageURL),
                      (resp as? HTTPURLResponse)?.statusCode == 200 else {
                    print("✗ \(artist): indirilemedi"); continue
                }
                var opts = RenderOptions(frameTheme: theme, hour: hour)
                opts.autoFrameByPeriod = false
                guard let png = WallpaperRenderer.render(
                    sourceData: data, caption: art.caption, title: art.title,
                    detail: art.medium ?? "", canvasPixelSize: size, options: opts) else {
                    print("✗ \(artist): render edilemedi"); continue
                }
                let url = URL(fileURLWithPath: outDir).appendingPathComponent("\(name).png")
                try? png.write(to: url, options: .atomic)
                print("✓ \(name): \(art.title) — \(art.artist) [\(theme.rawValue), saat \(hour)]")
                code = 0
            }
        }
        semaphore.wait()
        exit(code)
    }
}
