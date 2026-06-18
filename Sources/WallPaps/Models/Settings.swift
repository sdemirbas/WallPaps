import Foundation
import SwiftUI

/// How often the wallpaper rotates to the next artwork.
enum RefreshInterval: String, CaseIterable, Identifiable, Codable, Sendable {
    case fifteenMinutes, thirtyMinutes, hourly, threeHours, daily

    var id: String { rawValue }

    var seconds: TimeInterval {
        switch self {
        case .fifteenMinutes: return 15 * 60
        case .thirtyMinutes:  return 30 * 60
        case .hourly:         return 60 * 60
        case .threeHours:     return 3 * 60 * 60
        case .daily:          return 24 * 60 * 60
        }
    }

    var label: String {
        switch self {
        case .fifteenMinutes: return t("interval.15m")
        case .thirtyMinutes:  return t("interval.30m")
        case .hourly:         return t("interval.1h")
        case .threeHours:     return t("interval.3h")
        case .daily:          return t("interval.daily")
        }
    }
}

/// Where artworks come from.
enum SourceMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case museums   // Art Institute of Chicago + The Met
    case local     // user-supplied local folder only
    case both      // museums + local mixed

    var id: String { rawValue }
    var label: String {
        switch self {
        case .museums: return t("source.museums")
        case .local:   return t("source.local")
        case .both:    return t("source.both")
        }
    }
    var usesMuseums: Bool { self == .museums || self == .both }
    var usesLocal: Bool { self == .local || self == .both }
}

/// Preset matte (paspartu) widths, relative to the artwork's longer side.
enum MatPreset: String, CaseIterable, Identifiable {
    case thin, medium, wide
    var id: String { rawValue }
    var value: Double {
        switch self {
        case .thin:   return 0.045
        case .medium: return 0.08
        case .wide:   return 0.13
        }
    }
    var label: String {
        switch self {
        case .thin:   return t("mat.thin")
        case .medium: return t("mat.medium")
        case .wide:   return t("mat.wide")
        }
    }
}

/// User-facing settings, persisted to `UserDefaults`.
@MainActor
final class Settings: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var selectedArtists: Set<String> {
        didSet { defaults.set(Array(selectedArtists), forKey: Keys.artists) }
    }
    @Published var refreshInterval: RefreshInterval {
        didSet { defaults.set(refreshInterval.rawValue, forKey: Keys.interval) }
    }
    @Published var showCaption: Bool {
        didSet { defaults.set(showCaption, forKey: Keys.caption) }
    }
    @Published var matWidthPercent: Double {
        didSet { defaults.set(matWidthPercent, forKey: Keys.mat) }
    }
    @Published var pauseOnLowPower: Bool {
        didSet { defaults.set(pauseOnLowPower, forKey: Keys.lowPower) }
    }
    /// Show a different artwork on each connected display.
    @Published var distinctPerScreen: Bool {
        didSet { defaults.set(distinctPerScreen, forKey: Keys.perScreen) }
    }
    @Published var sourceMode: SourceMode {
        didSet { defaults.set(sourceMode.rawValue, forKey: Keys.sourceMode) }
    }
    /// Path to the user's own image folder (used when sourceMode includes local).
    @Published var localFolderPath: String? {
        didSet { defaults.set(localFolderPath, forKey: Keys.localFolder) }
    }
    @Published var frameTheme: FrameTheme {
        didSet { defaults.set(frameTheme.rawValue, forKey: Keys.theme) }
    }
    /// Rotate only through favorited artworks.
    @Published var favoritesOnly: Bool {
        didSet { defaults.set(favoritesOnly, forKey: Keys.favOnly) }
    }
    /// Post a notification each time the wallpaper changes.
    @Published var notifyOnChange: Bool {
        didSet { defaults.set(notifyOnChange, forKey: Keys.notify) }
    }
    /// Preferred artwork orientation.
    @Published var orientation: Orientation {
        didSet { defaults.set(orientation.rawValue, forKey: Keys.orientation) }
    }
    /// Target number of artworks kept in the rotation pool.
    @Published var librarySize: Int {
        didSet { defaults.set(librarySize, forKey: Keys.librarySize) }
    }
    /// Whether the first-run welcome has been completed.
    @Published var hasOnboarded: Bool {
        didSet { defaults.set(hasOnboarded, forKey: Keys.onboarded) }
    }
    /// UI language.
    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Keys.language); Localization.current = language }
    }
    /// Active curated collection id (nil = manual artist selection).
    @Published var activeCollection: String? {
        didSet { defaults.set(activeCollection, forKey: Keys.collection) }
    }
    /// Security-scoped bookmark for the local folder (sandbox-ready).
    @Published var localFolderBookmark: Data? {
        didSet { defaults.set(localFolderBookmark, forKey: Keys.bookmark) }
    }
    /// Gallery atmosphere on the wallpaper (spotlight, vignette, grain, engraved placard, time-of-day).
    @Published var galleryAmbiance: Bool {
        didSet { defaults.set(galleryAmbiance, forKey: Keys.ambiance) }
    }
    /// Auto-match the frame to the artwork's period.
    @Published var autoFrameByPeriod: Bool {
        didSet { defaults.set(autoFrameByPeriod, forKey: Keys.autoFrame) }
    }

    /// Selectable pool sizes (disk ≈ 10–12 MB per artwork).
    static let librarySizeOptions = [40, 100, 200, 400]

    init() {
        let saved = defaults.array(forKey: Keys.artists) as? [String]
        selectedArtists = Set(saved ?? Artist.defaults.map(\.name))
        refreshInterval = RefreshInterval(rawValue: defaults.string(forKey: Keys.interval) ?? "") ?? .hourly
        showCaption = defaults.object(forKey: Keys.caption) as? Bool ?? true
        matWidthPercent = defaults.object(forKey: Keys.mat) as? Double ?? MatPreset.medium.value
        pauseOnLowPower = defaults.object(forKey: Keys.lowPower) as? Bool ?? true
        distinctPerScreen = defaults.object(forKey: Keys.perScreen) as? Bool ?? false
        sourceMode = SourceMode(rawValue: defaults.string(forKey: Keys.sourceMode) ?? "") ?? .museums
        localFolderPath = defaults.string(forKey: Keys.localFolder)
        frameTheme = FrameTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .classic
        favoritesOnly = defaults.object(forKey: Keys.favOnly) as? Bool ?? false
        notifyOnChange = defaults.object(forKey: Keys.notify) as? Bool ?? false
        orientation = Orientation(rawValue: defaults.string(forKey: Keys.orientation) ?? "") ?? .any
        librarySize = defaults.object(forKey: Keys.librarySize) as? Int ?? 100
        hasOnboarded = defaults.object(forKey: Keys.onboarded) as? Bool ?? false
        language = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .system
        activeCollection = defaults.string(forKey: Keys.collection)
        localFolderBookmark = defaults.data(forKey: Keys.bookmark)
        galleryAmbiance = defaults.object(forKey: Keys.ambiance) as? Bool ?? true
        autoFrameByPeriod = defaults.object(forKey: Keys.autoFrame) as? Bool ?? true
        Localization.current = language
    }

    /// Snapshot of the rendering-relevant options for the renderer.
    var renderOptions: RenderOptions {
        RenderOptions(showCaption: showCaption,
                      matWidthPercent: matWidthPercent,
                      frameTheme: frameTheme,
                      galleryAmbiance: galleryAmbiance,
                      hour: Calendar.current.component(.hour, from: Date()),
                      autoFrameByPeriod: autoFrameByPeriod)
    }

    private enum Keys {
        static let artists = "selectedArtists"
        static let interval = "refreshInterval"
        static let caption = "showCaption"
        static let mat = "matWidthPercent"
        static let lowPower = "pauseOnLowPower"
        static let perScreen = "distinctPerScreen"
        static let sourceMode = "sourceMode"
        static let localFolder = "localFolderPath"
        static let theme = "frameTheme"
        static let favOnly = "favoritesOnly"
        static let notify = "notifyOnChange"
        static let orientation = "orientation"
        static let librarySize = "librarySize"
        static let onboarded = "hasOnboarded"
        static let language = "language"
        static let collection = "activeCollection"
        static let bookmark = "localFolderBookmark"
        static let ambiance = "galleryAmbiance"
        static let autoFrame = "autoFrameByPeriod"
    }
}
