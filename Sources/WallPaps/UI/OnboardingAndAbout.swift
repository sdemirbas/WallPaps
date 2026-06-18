import SwiftUI
import AppKit

/// Animated first-run welcome: a framed painting "unveils" (the brass frame
/// draws itself, the canvas fades in, a gilt shimmer sweeps across), then the
/// title and feature rows arrive with a staggered fade. Respects Reduce Motion.
struct WelcomeView: View {
    @ObservedObject private var controller = AppController.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var enableNotifications = true

    // Animation drivers.
    @State private var drawFrame: CGFloat = 0
    @State private var canvasIn = false
    @State private var shine = false
    @State private var textIn = false

    init(previewFinal: Bool = false) {
        if previewFinal {
            _drawFrame = State(initialValue: 1)
            _canvasIn = State(initialValue: true)
            _textIn = State(initialValue: true)
        }
    }

    private var features: [(String, String)] {
        [("paintpalette", t("welcome.f1")),
         ("checkmark.seal", t("welcome.f2")),
         ("bolt.badge.a", t("welcome.f3"))]
    }

    var body: some View {
        VStack(spacing: 20) {
            FramedHero(drawProgress: drawFrame, canvasIn: canvasIn, shine: shine)
                .frame(width: 168, height: 124)
                .padding(.top, 6)

            VStack(spacing: 6) {
                Text(t("welcome.title"))
                    .font(Gallery.serif(24, .semibold))
                    .opacity(textIn ? 1 : 0)
                    .offset(y: textIn ? 0 : 10)
                Text(t("welcome.subtitle"))
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 380)
                    .opacity(textIn ? 1 : 0)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    HStack(spacing: 10) {
                        Image(systemName: feature.0).foregroundStyle(Gallery.brass).frame(width: 22)
                        Text(feature.1).font(.system(size: 12))
                        Spacer()
                    }
                    .opacity(textIn ? 1 : 0)
                    .offset(x: textIn ? 0 : -10)
                    .animation(reduceMotion ? nil :
                        .easeOut(duration: 0.5).delay(0.65 + Double(index) * 0.12), value: textIn)
                }
            }
            .padding(.vertical, 4)

            Toggle(t("welcome.notify"), isOn: $enableNotifications)
                .toggleStyle(.checkbox)
                .opacity(textIn ? 1 : 0)

            Button {
                controller.completeOnboarding(enableNotifications: enableNotifications)
            } label: {
                Text(t("welcome.cta")).frame(maxWidth: 200)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .opacity(textIn ? 1 : 0)
            .scaleEffect(textIn ? 1 : 0.96)

            Text(t("welcome.credit"))
                .font(.system(size: 10)).foregroundStyle(.tertiary)
                .opacity(textIn ? 1 : 0)
        }
        .padding(34)
        .frame(width: 460)
        .onAppear(perform: runIntro)
    }

    private func runIntro() {
        guard !reduceMotion else {
            drawFrame = 1; canvasIn = true; textIn = true
            return
        }
        withAnimation(.easeInOut(duration: 0.9)) { drawFrame = 1 }
        withAnimation(.easeOut(duration: 0.45).delay(0.35)) { textIn = true }
        withAnimation(.easeOut(duration: 0.7).delay(0.7)) { canvasIn = true }
        withAnimation(.easeInOut(duration: 1.2).delay(1.15)) { shine = true }
    }
}

/// The animated framed-painting motif used on the welcome screen.
private struct FramedHero: View {
    var drawProgress: CGFloat
    var canvasIn: Bool
    var shine: Bool

    var body: some View {
        ZStack {
            // Matte + canvas, fading/scaling in once the frame is drawn.
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(red: 0.96, green: 0.95, blue: 0.93))
                .overlay(painting.padding(7).clipShape(RoundedRectangle(cornerRadius: 2)))
                .padding(9)
                .opacity(canvasIn ? 1 : 0)
                .scaleEffect(canvasIn ? 1 : 0.92)
                .shadow(color: .black.opacity(0.4), radius: 10, y: 5)

            // Brass frame that draws itself.
            RoundedRectangle(cornerRadius: 8)
                .trim(from: 0, to: drawProgress)
                .stroke(Gallery.brass, style: StrokeStyle(lineWidth: 4, lineCap: .round))

            // Gilt shimmer sweeping across once.
            Rectangle()
                .fill(LinearGradient(colors: [.clear, .white.opacity(0.4), .clear],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 44)
                .rotationEffect(.degrees(20))
                .offset(x: shine ? 150 : -150)
                .blendMode(.plusLighter)
                .mask(RoundedRectangle(cornerRadius: 8))
                .allowsHitTesting(false)
        }
    }

    /// A small sunset/landscape, echoing the app icon.
    private var painting: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.99, green: 0.80, blue: 0.36),
                                    Color(red: 0.93, green: 0.45, blue: 0.30)],
                           startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(Color(red: 1.0, green: 0.97, blue: 0.86).opacity(0.95))
                .frame(width: 26, height: 26)
                .offset(x: 20, y: -8)
            Ellipse()
                .fill(Color(red: 0.30, green: 0.45, blue: 0.55))
                .frame(width: 150, height: 64)
                .offset(y: 44)
        }
    }
}

/// Headless render of the welcome screen's final frame (for visual review).
/// Run via: `WallPaps --previewwelcome <path.png>`
@MainActor
enum WelcomePreview {
    static func render(to path: String) -> Never {
        _ = NSApplication.shared // ImageRenderer needs AppKit initialized
        let content = WelcomeView(previewFinal: true)
            .environment(\.colorScheme, .dark)
            .background(Color(red: 0.12, green: 0.115, blue: 0.12))

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("welcome preview render failed\n".utf8))
            exit(1)
        }
        try? png.write(to: URL(fileURLWithPath: path))
        print("welcome preview yazıldı: \(path)")
        exit(0)
    }
}

/// About / credits — shown as a section inside the settings form.
struct AboutSection: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "photo.artframe").foregroundStyle(Gallery.brass)
                Text("WallPaps").font(.headline)
                Text("v\(version)").foregroundStyle(.secondary)
            }
            Text(t("about.cc0"))
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 14) {
                Link("Art Institute of Chicago",
                     destination: URL(string: "https://www.artic.edu/open-access")!)
                Link("The Met Open Access",
                     destination: URL(string: "https://www.metmuseum.org/about-the-met/policies-and-documents/open-access")!)
            }
            .font(.caption)
        }
        .padding(.vertical, 2)
    }
}
