import Foundation
import CoreGraphics

/// Headless verification: fetch a public-domain artwork from the live APIs,
/// render a 4K master, and write it to disk. Does NOT change the wallpaper.
/// Run via: `WallPaps --selftest`
enum SelfTest {
    static func run() -> Never {
        print("WallPaps self-test — API + 4K render (duvar kâğıdı DEĞİŞMEZ)")
        let semaphore = DispatchSemaphore(value: 0)
        var code: Int32 = 1

        Task {
            defer { semaphore.signal() }
            let providers: [ArtworkSource] = [ArticProvider(), MetProvider()]
            var picked: Artwork?

            for provider in providers {
                do {
                    let arts = try await provider.fetchArtworks(artist: "Vincent van Gogh", limit: 3)
                    print("  • \(provider.name): \(arts.count) eser")
                    if picked == nil { picked = arts.first }
                } catch {
                    print("  • \(provider.name): hata — \(error)")
                }
            }

            guard let art = picked else { print("✗ Hiçbir kaynaktan eser alınamadı"); return }
            print("  • Seçilen: \(art.title) — \(art.caption)")
            print("  • Görsel : \(art.imageURL.absoluteString)")

            guard let (data, response) = try? await artNetwork.data(from: art.imageURL),
                  (response as? HTTPURLResponse)?.statusCode == 200, !data.isEmpty else {
                print("✗ Kaynak görsel indirilemedi"); return
            }
            print("  • İndirilen kaynak: \(data.count / 1024) KB")

            guard let png = WallpaperRenderer.render(
                sourceData: data,
                caption: art.caption,
                canvasPixelSize: CGSize(width: 3840, height: 2160),
                options: RenderOptions()
            ) else {
                print("✗ Render başarısız"); return
            }

            LibraryPaths.ensureDirs()
            let out = LibraryPaths.mastersDir.appendingPathComponent("selftest.png")
            do {
                try png.write(to: out, options: .atomic)
                print("✓ 4K master yazıldı: \(out.path) (\(png.count / 1024) KB)")
            } catch {
                print("✗ Diske yazılamadı: \(error)")
                return
            }

            // Per-screen variant render (ultra-wide 2560×1080) — no caption style.
            let screenSize = CGSize(width: 2560, height: 1080)
            if let variant = WallpaperRenderer.render(
                sourceData: data, caption: art.caption,
                canvasPixelSize: screenSize, options: RenderOptions(showCaption: false)) {
                let vURL = LibraryPaths.wallpapersDir.appendingPathComponent("selftest-2560x1080.png")
                try? variant.write(to: vURL, options: .atomic)
                print("✓ Ekran varyantı (2560×1080) yazıldı: \(variant.count / 1024) KB")
            } else {
                print("✗ Ekran varyantı render edilemedi"); return
            }

            // Local-folder provider: list the images we just produced.
            let locals = LocalFolderProvider.artworks(inFolderPath: LibraryPaths.mastersDir.path)
            print("✓ Yerel klasör tarama: \(locals.count) görsel bulundu (masters/)")

            // Orientation metadata (AIC provides pixel dimensions up front).
            if let monet = try? await ArticProvider().fetchArtworks(artist: "Claude Monet", limit: 12) {
                let withDims = monet.filter { $0.knownPixelSize != nil }
                let landscape = monet.filter { $0.matchesPreFilter(.landscape) && $0.knownPixelSize != nil && !$0.matchesPreFilter(.portrait) }
                let portrait = monet.filter { $0.matchesPreFilter(.portrait) && $0.knownPixelSize != nil && !$0.matchesPreFilter(.landscape) }
                print("✓ Yön metadata: \(withDims.count)/\(monet.count) eserde boyut var — yatay≈\(landscape.count), dikey≈\(portrait.count)")
            }

            // Cleveland source (CC0, dimensions, museum context).
            if let cma = try? await ClevelandProvider().fetchArtworks(artist: "Vincent van Gogh", limit: 5) {
                let dims = cma.filter { $0.knownPixelSize != nil }.count
                let desc = cma.filter { $0.museumDescription?.isEmpty == false }.count
                print("✓ Cleveland: \(cma.count) eser — \(dims) boyutlu, \(desc) açıklamalı")
            } else {
                print("✗ Cleveland alınamadı")
            }

            // Metadata enrichment on the picked artwork.
            print("  • Metadata: teknik=\(art.medium ?? "—") | bölüm=\(art.department ?? "—")")

            // Localization round-trip.
            Localization.current = .en; let enStr = t("share.button")
            Localization.current = .tr; let trStr = t("share.button")
            Localization.current = .system
            print("✓ Lokalizasyon: EN='\(enStr)'  TR='\(trStr)'")

            // Remote catalog manifest: parse a sample + confirm bundled fallback.
            let sample = #"{"version":1,"artists":[{"name":"Hilma af Klint","displayName":"af Klint"}],"collections":[{"id":"abstract","nameTR":"Soyut","nameEN":"Abstract","artists":["Hilma af Klint"],"orientation":"portrait"}],"featured":{"collectionId":"abstract","titleTR":"Vitrin","titleEN":"Featured"}}"#
            if let m = try? JSONDecoder().decode(CatalogManifest.self, from: Data(sample.utf8)) {
                print("✓ Manifest parse: \(m.artists.count) sanatçı (\(m.artists.first?.name ?? "?")), \(m.collections.count) koleksiyon, featured=\(m.featured?.collectionId ?? "—")")
            } else {
                print("✗ Manifest parse başarısız"); return
            }
            print("✓ Bundled fallback: \(Artist.defaults.count) sanatçı, \(ArtCollection.all.count) koleksiyon")

            // Share image (4K + credit).
            if let share = WallpaperRenderer.render(
                sourceData: data, caption: art.caption,
                canvasPixelSize: CGSize(width: 3840, height: 2160),
                options: RenderOptions(shareCredit: true)) {
                let url = URL(fileURLWithPath: "/tmp/wallpaps-share.png")
                try? share.write(to: url, options: .atomic)
                print("✓ Paylaşım görseli (4K + kredi): \(share.count / 1024) KB → \(url.path)")
            } else {
                print("✗ Paylaşım görseli render edilemedi"); return
            }

            // Gallery ambiance samples (day vs evening) for visual review.
            for (label, hr) in [("day", 13), ("evening", 20)] {
                var opts = RenderOptions(); opts.hour = hr
                if let img = WallpaperRenderer.render(
                    sourceData: data, caption: art.caption, title: art.title,
                    detail: art.medium ?? "Oil on canvas",
                    canvasPixelSize: CGSize(width: 1920, height: 1080), options: opts) {
                    try? img.write(to: URL(fileURLWithPath: "/tmp/wallpaps-gallery-\(label).png"), options: .atomic)
                    print("✓ Galeri atmosferi (\(label), saat \(hr)): \(img.count / 1024) KB")
                }
            }
            // Period framing sanity.
            print("  • Dönem çerçevesi: van Gogh→\(PeriodFraming.theme(for: "Vincent van Gogh")?.rawValue ?? "—"), Rembrandt→\(PeriodFraming.theme(for: "Rembrandt van Rijn")?.rawValue ?? "—"), Hokusai→\(PeriodFraming.theme(for: "Katsushika Hokusai")?.rawValue ?? "—")")

            // Render every frame theme (for visual review) at 1920×1080.
            for theme in FrameTheme.allCases {
                let opts = RenderOptions(frameTheme: theme)
                guard let themed = WallpaperRenderer.render(
                    sourceData: data, caption: art.caption,
                    canvasPixelSize: CGSize(width: 1920, height: 1080), options: opts) else {
                    print("✗ Tema render edilemedi: \(theme.label)"); return
                }
                let url = URL(fileURLWithPath: "/tmp/wallpaps-theme-\(theme.rawValue).png")
                try? themed.write(to: url, options: .atomic)
                print("✓ Tema '\(theme.label)' → \(url.path) (\(themed.count / 1024) KB)")
            }

            code = 0
        }

        semaphore.wait()
        exit(code)
    }
}
