# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

WallPaps — macOS 14+ menu-bar app (Swift 6, SwiftPM, AppKit + SwiftUI hybrid) that rotates public-domain paintings as 4K wallpapers with a matte/frame renderer. No Dock icon (`LSUIElement`); runs as a background agent with a `MenuBarExtra`.

## Commands

```bash
# Quick dev run (menu-bar app launches; no .app bundle, launch-at-login won't work)
swift run

# Build release binary + wrap into WallPaps.app + ad-hoc sign
./Scripts/build-app.sh

# Run the headless smoke-test (downloads a Van Gogh, renders 4K — does NOT change wallpaper)
swift build -c release && .build/release/WallPaps --selftest

# Open the built app
open WallPaps.app

# Notarized DMG for distribution (needs Developer ID + notary secrets in env)
SIGN_ID="Developer ID Application: Name (TEAMID)" ./Scripts/notarize.sh

# Unsigned DMG for sharing/testing
./Scripts/make-dmg.sh

# App Store build
./Scripts/build-appstore.sh
```

CI (`ci.yml`) runs `swift build -c release` on every push to `main`; the `--selftest` step is network-dependent and set to `continue-on-error`. Release (`release.yml`) fires on `v*` tags and produces a notarized DMG uploaded to GitHub Releases.

## Architecture

### Entry point

`WallPapsApp.swift` — `@main enum Entry` dispatches headless modes before delegating to `WallPapsApp` (SwiftUI `App`). Headless modes:
- `--selftest` → `SelfTest.run()`
- `--makeicon <path>` → `IconGenerator.run()`
- `--previewwelcome <path>` → `WelcomePreview.render()`
- `--shots <dir>` → `ShotsGenerator.run()`

### Central coordinator

`AppController` (singleton, `@MainActor`) owns and wires everything:
- `Settings` — `UserDefaults`-backed config
- `ArtLibrary` — rotation pool + variant cache
- `FavoritesStore` — starred artworks
- `RefreshScheduler` — `NSBackgroundActivityScheduler` wrapper
- `NetworkMonitor` — online/offline transitions
- `CatalogService` — remote-updatable artist/collection list

### Data flow

1. `ArtLibrary.replenish()` pulls `Artwork` structs from one or more `ArtworkSource` providers (`ArticProvider`, `MetProvider`, `ClevelandProvider`, `LocalFolderProvider`).
2. `ArtLibrary.variantURL()` checks the disk cache; on miss it calls `WallpaperRenderer.render()` (pure CoreGraphics/CoreText, off-main-thread safe) to produce a screen-sized PNG.
3. `WallpaperManager.setWallpaper()` sets the URL via `NSWorkspace`.

### Museum providers

Each provider conforms to `ArtworkSource` (`Services/ArtworkSource.swift`). Three live museum APIs (no key required, CC0):
- `ArticProvider` — Art Institute of Chicago (IIIF)
- `MetProvider` — Metropolitan Museum of Art Open Access
- `ClevelandProvider` — Cleveland Museum of Art

### Remote catalog

`CatalogService` fetches `catalog/catalog.json` from `raw.githubusercontent.com` on startup. Editing that JSON file and pushing to `main` adds artists/collections without an app update. Falls back to embedded defaults on any network failure.

### UI layers

- `MenuContent.swift` — SwiftUI menu attached to the `MenuBarExtra`
- `GalleryWindowController.swift` / `MainWindowView.swift` — the museum-style gallery window (`NSPanel`)
- `SettingsFormView.swift`, `OnboardingAndAbout.swift` — settings & welcome screens

### Rendering

`WallpaperRenderer` composes artwork onto a canvas with:
- Matte/border ("paspartu") controlled by `RenderOptions`
- Four `FrameTheme`s: classic, gilt, modern, vintage
- Gallery ambiance layer (spotlight, vignette, grain, brass placard)
- Time-of-day colour shift (4 buckets: night/morning/day/evening)
- Caption drawn with CoreText

Cache key is built from `(artworkId, pixelWidth, pixelHeight, styleSignature)` — style changes naturally invalidate cached variants.

### Concurrency model

Swift 5 language mode (`swiftLanguageMode(.v5)` in `Package.swift`) — chosen to keep AppKit/CoreGraphics interop friction-free. `AppController` and `ArtLibrary` are `@MainActor`; heavy work (download, render) runs in `Task {}` off the main thread and returns results to `@MainActor` via `await`.

## Key files

| Path | Role |
|------|------|
| `Sources/WallPaps/AppController.swift` | Central coordinator — all settings mutations + scheduling |
| `Sources/WallPaps/Services/ArtLibrary.swift` | Pool management, variant caching, replenishment |
| `Sources/WallPaps/Services/WallpaperRenderer.swift` | CoreGraphics renderer + `RenderOptions` |
| `Sources/WallPaps/Services/CatalogService.swift` | Remote catalog refresh + fallback |
| `Sources/WallPaps/Models/Settings.swift` | All `UserDefaults`-backed user preferences |
| `catalog/catalog.json` | Remotely-updatable artist + collection manifest |
| `Scripts/build-app.sh` | Local build script (bundle + ad-hoc sign) |

## Data on disk

All data lives under `~/Library/Application Support/WallPaps/`:
- `sources/` — downloaded originals
- `masters/` — 4K archival renders (3840×2160)
- `wallpapers/` — screen-sized variants (cache)
- `library.json` — pool + rotation state
- `favorites.json` — starred artworks
- `catalog.json` — last-fetched remote catalog

---

## Go port — `go/` (Windows + Linux + macOS)

A full cross-platform re-implementation in Go targeting Windows, Linux, and macOS.  
Entry point: `go/main.go`. Requires Go 1.22+.

### Quick start

```bash
cd go

# Fetch dependencies (first time)
go mod tidy

# Run in place (dev)
go run .

# Build for current platform
go build -o wallpaps .

# Cross-compile
make windows   # → wallpaps.exe (CGO_ENABLED=0)
make linux     # → wallpaps-linux (needs CGO + GTK3/AppIndicator)
make macos     # → wallpaps-macos (needs CGO + Cocoa)
```

### Dependencies

| Package | Purpose |
|---------|---------|
| `github.com/getlantern/systray` | Cross-platform system-tray icon + menu (CGO) |
| `golang.org/x/image` | Catmull-Rom scaling, opentype font rendering |
| `golang.org/x/image/font/gofont/goregular` | Embedded caption font (no font files needed) |

**Linux build requirements**: `libgtk-3-dev`, `libappindicator3-dev` (Debian/Ubuntu: `sudo apt install libgtk-3-dev libayatana-appindicator3-dev`).

### Architecture (Go port)

```
main.go             App lifecycle, tray menu, scheduler
screen_*.go         Platform-specific screen resolution (build tags)
api/                Museum HTTP providers
  source.go         Artwork struct + Source interface
  artic.go          Art Institute of Chicago (IIIF)
  met.go            Metropolitan Museum
  cleveland.go      Cleveland Museum of Art
render/renderer.go  Pure-Go compositor (matte + frame + caption)
wallpaper/          Platform-specific wallpaper setter (build tags)
  linux.go          gsettings → KDE → XFCE → feh → swaybg
  windows.go        SystemParametersInfoW
  darwin.go         osascript fallback
library/library.go  Pool management, download, variant cache
catalog/catalog.go  Remote catalog + bundled 53-artist defaults
config/settings.go  JSON-persisted settings
paths/paths.go      Platform-specific data dirs
assets/icon.go      Programmatic 32×32 tray icon (no binary assets)
```

### Data directory

| Platform | Path |
|----------|------|
| Windows | `%APPDATA%\WallPaps\` |
| Linux | `~/.config/wallpaps/` |
| macOS | `~/Library/Application Support/WallPaps/` |

### Wallpaper setting — Linux DE support

Tried in order: **GNOME** (`gsettings`) → **KDE Plasma 5.6+** (`plasma-apply-wallpaperimage`) → **XFCE** (`xfconf-query`) → **feh** → **nitrogen** → **swaybg** (Wayland).

### Renderer

`render.Render()` composites artwork with a matte/frame using `golang.org/x/image/draw.CatmullRom` for scaling and `golang.org/x/image/font/opentype` for caption text. Four `Theme` values mirror the Swift version: `ThemeClassic`, `ThemeGilt`, `ThemeModern`, `ThemeVintage`. Output is always PNG.

---

## Localization

UI strings use a custom `t()` helper (`Models/Localization.swift`). Language is either system-detected or overridden via `Settings.language` (`AppLanguage`). Currently Turkish and English.
