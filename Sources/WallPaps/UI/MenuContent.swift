import SwiftUI
import AppKit

/// The dropdown shown from the menu-bar icon.
struct MenuContent: View {
    @ObservedObject private var controller = AppController.shared
    @ObservedObject private var settings = AppController.shared.settings
    @ObservedObject private var library = AppController.shared.library
    @ObservedObject private var favorites = AppController.shared.favorites
    @ObservedObject private var catalog = AppController.shared.catalog

    var body: some View {
        if let entry = library.current {
            Text(entry.artwork.title)
            if !entry.artwork.caption.isEmpty { Text(entry.artwork.caption).font(.caption) }
        } else {
            Text(controller.statusText)
        }

        if controller.state == .offline || controller.state == .empty {
            Button(t("menu.retry")) { controller.retryNow() }
        }

        Divider()

        Button(t("menu.gallerysettings")) { GalleryWindowController.shared.show() }
            .keyboardShortcut(",")

        Divider()

        Button(t("menu.next")) { controller.userNext() }.keyboardShortcut("n")
        Button(controller.isCurrentFavorite ? t("menu.favRemove") : t("menu.favAdd")) {
            controller.toggleFavoriteCurrent()
        }
        .keyboardShortcut("f")
        .disabled(library.current == nil)
        Button(t("menu.skip")) { controller.skipCurrent() }

        Menu(t("menu.share")) {
            Button(t("share.save")) { controller.saveCurrentShare() }
            Button(t("share.copy")) { controller.copyCurrentShare() }
        }
        .disabled(library.current == nil)

        if !favorites.favorites.isEmpty {
            Menu("\(t("menu.favorites")) (\(favorites.favorites.count))") {
                ForEach(favorites.favorites) { art in
                    Button(favoriteLabel(art)) { controller.applyFavorite(art) }
                }
            }
            Toggle(t("menu.favoritesOnly"), isOn: favoritesOnlyBinding)
        }

        Divider()

        Menu(t("col.section")) {
            Button {
                controller.setCollection(nil)
            } label: {
                Label(t("col.none"), systemImage: settings.activeCollection == nil ? "checkmark" : "")
            }
            Divider()
            ForEach(catalog.collections) { collection in
                Button {
                    controller.setCollection(collection.id)
                } label: {
                    Label(collection.localizedName,
                          systemImage: settings.activeCollection == collection.id ? "checkmark" : "")
                }
            }
        }

        Menu(t("menu.artists")) {
            ForEach(catalog.artists) { artist in
                Toggle(artist.displayName, isOn: artistBinding(artist.name))
            }
        }

        Menu(t("menu.interval")) {
            ForEach(RefreshInterval.allCases) { interval in
                Button {
                    settings.refreshInterval = interval
                    controller.applyInterval()
                } label: {
                    Label(interval.label, systemImage: settings.refreshInterval == interval ? "checkmark" : "")
                }
            }
        }

        Menu(t("menu.librarySize")) {
            ForEach(Settings.librarySizeOptions, id: \.self) { size in
                Button {
                    controller.setLibrarySize(size)
                } label: {
                    Label("\(size) \(t("unit.artworks"))",
                          systemImage: settings.librarySize == size ? "checkmark" : "")
                }
            }
        }

        Menu(t("menu.frame")) {
            Menu(t("menu.theme")) {
                ForEach(FrameTheme.allCases) { theme in
                    Button {
                        controller.setTheme(theme)
                    } label: {
                        Label(theme.label, systemImage: settings.frameTheme == theme ? "checkmark" : "")
                    }
                }
            }
            Divider()
            Toggle(t("menu.showCaption"), isOn: captionBinding)
            Toggle(t("set.ambiance"), isOn: Binding(
                get: { settings.galleryAmbiance }, set: { controller.setGalleryAmbiance($0) }))
            Toggle(t("set.autoFrame"), isOn: Binding(
                get: { settings.autoFrameByPeriod }, set: { controller.setAutoFrame($0) }))
            Divider()
            ForEach(MatPreset.allCases) { preset in
                Button {
                    settings.matWidthPercent = preset.value
                    controller.reapplyCurrent()
                } label: {
                    Label(preset.label, systemImage: isSelectedMat(preset) ? "checkmark" : "")
                }
            }
        }

        Menu(t("menu.source")) {
            ForEach(SourceMode.allCases) { mode in
                Button {
                    controller.setSourceMode(mode)
                } label: {
                    Label(mode.label, systemImage: settings.sourceMode == mode ? "checkmark" : "")
                }
            }
            Divider()
            Button(t("menu.chooseFolder")) { controller.chooseLocalFolder() }
            if let path = settings.localFolderPath {
                Text(URL(fileURLWithPath: path).lastPathComponent).font(.caption)
            }
        }

        Menu(t("menu.orientation")) {
            ForEach(Orientation.allCases) { o in
                Button {
                    controller.setOrientation(o)
                } label: {
                    Label(o.label, systemImage: settings.orientation == o ? "checkmark" : "")
                }
            }
        }

        Menu(t("lang.title")) {
            ForEach(AppLanguage.allCases) { lang in
                Button {
                    controller.setLanguage(lang)
                } label: {
                    Label(lang.label, systemImage: settings.language == lang ? "checkmark" : "")
                }
            }
        }

        Toggle(t("menu.perScreen"), isOn: $settings.distinctPerScreen)
        Toggle(t("menu.notify"), isOn: notifyBinding)

        Divider()

        Toggle(t("menu.launchLogin"), isOn: Binding(
            get: { LaunchAtLogin.isEnabled },
            set: { LaunchAtLogin.set($0) }
        ))
        Button(t("menu.refresh")) { controller.refreshLibrary() }
        Button(t("menu.openMasters")) { controller.openMastersFolder() }

        if library.isWorking {
            Divider()
            Text(t("menu.working")).foregroundStyle(.secondary)
        }

        Divider()
        Button(t("menu.quit")) { NSApp.terminate(nil) }.keyboardShortcut("q")
    }

    // MARK: - Bindings & helpers

    private func artistBinding(_ name: String) -> Binding<Bool> {
        Binding(
            get: { settings.selectedArtists.contains(name) },
            set: { isOn in
                if isOn { settings.selectedArtists.insert(name) }
                else { settings.selectedArtists.remove(name) }
            }
        )
    }

    private var captionBinding: Binding<Bool> {
        Binding(get: { settings.showCaption },
                set: { settings.showCaption = $0; controller.reapplyCurrent() })
    }

    private var favoritesOnlyBinding: Binding<Bool> {
        Binding(get: { settings.favoritesOnly },
                set: { controller.setFavoritesOnly($0) })
    }

    private var notifyBinding: Binding<Bool> {
        Binding(get: { settings.notifyOnChange }, set: { controller.setNotifications($0) })
    }

    private func isSelectedMat(_ preset: MatPreset) -> Bool {
        abs(settings.matWidthPercent - preset.value) < 0.001
    }

    private func favoriteLabel(_ art: Artwork) -> String {
        art.caption.isEmpty ? art.title : "\(art.title) — \(art.caption)"
    }
}
