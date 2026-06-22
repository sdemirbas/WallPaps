import SwiftUI

/// All settings in one tidy grouped form (mirrors the menu-bar options).
struct SettingsFormView: View {
    @ObservedObject private var controller = AppController.shared
    @ObservedObject private var settings = AppController.shared.settings
    @ObservedObject private var catalog = AppController.shared.catalog
    @ObservedObject private var updater = UpdaterService.shared

    var body: some View {
        Form {
            Section(t("col.section")) {
                Picker(t("set.collection"), selection: Binding(
                    get: { settings.activeCollection },
                    set: { controller.setCollection($0) })) {
                    Text(t("col.none")).tag(String?.none)
                    ForEach(catalog.collections) { Text($0.localizedName).tag(Optional($0.id)) }
                }
            }

            Section(t("set.source")) {
                Picker(t("set.sourceLabel"), selection: Binding(
                    get: { settings.sourceMode },
                    set: { controller.setSourceMode($0) })) {
                    ForEach(SourceMode.allCases) { Text($0.label).tag($0) }
                }
                if let path = settings.localFolderPath {
                    LabeledContent(t("set.localFolder"),
                                   value: URL(fileURLWithPath: path).lastPathComponent)
                }
                Button(t("menu.chooseFolder")) { controller.chooseLocalFolder() }

                Picker(t("set.orientation"), selection: Binding(
                    get: { settings.orientation },
                    set: { controller.setOrientation($0) })) {
                    ForEach(Orientation.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section(t("set.frame")) {
                Picker(t("menu.theme"), selection: Binding(
                    get: { settings.frameTheme },
                    set: { controller.setTheme($0) })) {
                    ForEach(FrameTheme.allCases) { Text($0.label).tag($0) }
                }
                Toggle(t("menu.showCaption"), isOn: Binding(
                    get: { settings.showCaption },
                    set: { controller.setCaption($0) }))
                Toggle(t("set.ambiance"), isOn: Binding(
                    get: { settings.galleryAmbiance },
                    set: { controller.setGalleryAmbiance($0) }))
                Toggle(t("set.autoFrame"), isOn: Binding(
                    get: { settings.autoFrameByPeriod },
                    set: { controller.setAutoFrame($0) }))
                VStack(alignment: .leading) {
                    Text(t("set.matWidth")).font(.caption).foregroundStyle(.secondary)
                    Slider(value: Binding(
                        get: { settings.matWidthPercent },
                        set: { controller.setMatWidth($0) }),
                        in: 0.03...0.16,
                        onEditingChanged: { editing in if !editing { controller.applyMatWidth() } })
                }
            }

            Section(t("set.displayRefresh")) {
                Toggle(t("menu.perScreen"), isOn: $settings.distinctPerScreen)
                Picker(t("set.interval"), selection: Binding(
                    get: { settings.refreshInterval },
                    set: { controller.setInterval($0) })) {
                    ForEach(RefreshInterval.allCases) { Text($0.label).tag($0) }
                }
                Picker(t("menu.librarySize"), selection: Binding(
                    get: { settings.librarySize },
                    set: { controller.setLibrarySize($0) })) {
                    ForEach(Settings.librarySizeOptions, id: \.self) { Text("\($0) \(t("unit.artworks"))").tag($0) }
                }
                Text(t("set.libSizeDisk")).font(.caption).foregroundStyle(.secondary)
            }

            Section(t("set.notifFav")) {
                Toggle(t("menu.notify"), isOn: Binding(
                    get: { settings.notifyOnChange },
                    set: { controller.setNotifications($0) }))
                Toggle(t("menu.favoritesOnly"), isOn: Binding(
                    get: { settings.favoritesOnly },
                    set: { controller.setFavoritesOnly($0) }))
            }

            Section(t("menu.artists")) {
                ForEach(catalog.artists) { artist in
                    Toggle(artist.displayName, isOn: Binding(
                        get: { settings.selectedArtists.contains(artist.name) },
                        set: { controller.setArtist(artist.name, enabled: $0) }))
                }
            }

            Section(t("set.general")) {
                Picker(t("lang.title"), selection: Binding(
                    get: { settings.language },
                    set: { controller.setLanguage($0) })) {
                    ForEach(AppLanguage.allCases) { Text($0.label).tag($0) }
                }
                Toggle(t("menu.launchLogin"), isOn: Binding(
                    get: { LaunchAtLogin.isEnabled },
                    set: { LaunchAtLogin.set($0) }))
                Button(t("set.rebuild")) { controller.rebuildLibrary() }
                Button(t("menu.openMasters")) { controller.openMastersFolder() }
            }

            Section(t("update.section")) {
                Toggle(t("update.autoCheck"), isOn: Binding(
                    get: { updater.automaticallyChecksForUpdates },
                    set: { updater.automaticallyChecksForUpdates = $0 }))
                if updater.automaticallyChecksForUpdates {
                    Toggle(t("update.autoDownload"), isOn: Binding(
                        get: { updater.automaticallyDownloadsUpdates },
                        set: { updater.automaticallyDownloadsUpdates = $0 }))
                    if updater.automaticallyDownloadsUpdates {
                        Text(t("update.autoDownloadNote"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Button(t("update.checkNow")) { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
            }

            Section(t("set.about")) {
                AboutSection()
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
