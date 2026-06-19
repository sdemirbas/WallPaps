package main

import (
	"fmt"
	"log"
	"os/exec"
	"runtime"
	"sync"
	"time"
	"wallpaps/assets"
	"wallpaps/catalog"
	"wallpaps/config"
	"wallpaps/library"
	"wallpaps/paths"
	"wallpaps/render"
	"wallpaps/wallpaper"

	"github.com/getlantern/systray"
)

func main() {
	paths.EnsureDirs()
	systray.Run(onReady, onExit)
}

// ── App state ────────────────────────────────────────────────────────────────

type App struct {
	mu       sync.Mutex
	settings *config.Settings
	artists  []catalog.Artist
	lib      *library.Library
	ticker   *time.Ticker
	stopCh   chan struct{}

	miStatus  *systray.MenuItem
	miNext    *systray.MenuItem
	miMi15m   *systray.MenuItem
	miMi30m   *systray.MenuItem
	miMi1h    *systray.MenuItem
	miMi3h    *systray.MenuItem
	miMiDaily *systray.MenuItem
	miFolder  *systray.MenuItem
	miQuit    *systray.MenuItem
}

var app App

func onReady() {
	systray.SetIcon(assets.TrayIcon())
	systray.SetTitle("")
	systray.SetTooltip("WallPaps — rotating museum masterpieces")

	app.settings = config.Load()
	app.artists = catalog.Load()
	app.lib = library.New()

	buildMenu()

	go catalog.Refresh()

	go func() {
		if app.lib.NeedsMore() {
			setStatus("Downloading artworks…")
			app.lib.Replenish(app.settings, app.artists)
		}
		advance()
		startScheduler()
	}()
}

func buildMenu() {
	app.miStatus = systray.AddMenuItem("WallPaps", "")
	app.miStatus.Disable()
	systray.AddSeparator()

	app.miNext = systray.AddMenuItem("Next Artwork", "Rotate to the next painting")
	systray.AddSeparator()

	miInterval := systray.AddMenuItem("Refresh Interval", "")
	app.miMi15m = miInterval.AddSubMenuItem("15 minutes", "")
	app.miMi30m = miInterval.AddSubMenuItem("30 minutes", "")
	app.miMi1h = miInterval.AddSubMenuItem("1 hour", "")
	app.miMi3h = miInterval.AddSubMenuItem("3 hours", "")
	app.miMiDaily = miInterval.AddSubMenuItem("Daily", "")
	checkInterval()
	systray.AddSeparator()

	app.miFolder = systray.AddMenuItem("Open Data Folder", "Browse downloaded artworks")
	systray.AddSeparator()
	app.miQuit = systray.AddMenuItem("Quit WallPaps", "")

	go handleMenuEvents()
}

func handleMenuEvents() {
	for {
		select {
		case <-app.miNext.ClickedCh:
			go advance()
		case <-app.miMi15m.ClickedCh:
			setInterval(config.Interval15m)
		case <-app.miMi30m.ClickedCh:
			setInterval(config.Interval30m)
		case <-app.miMi1h.ClickedCh:
			setInterval(config.Interval1h)
		case <-app.miMi3h.ClickedCh:
			setInterval(config.Interval3h)
		case <-app.miMiDaily.ClickedCh:
			setInterval(config.IntervalDaily)
		case <-app.miFolder.ClickedCh:
			go openFolder(paths.DataDir())
		case <-app.miQuit.ClickedCh:
			systray.Quit()
		}
	}
}

// ── Scheduling ───────────────────────────────────────────────────────────────

func startScheduler() {
	app.mu.Lock()
	if app.stopCh != nil {
		close(app.stopCh)
	}
	interval := time.Duration(app.settings.RefreshInterval.Seconds()) * time.Second
	app.ticker = time.NewTicker(interval)
	ch := make(chan struct{})
	app.stopCh = ch
	tick := app.ticker.C
	app.mu.Unlock()

	go func() {
		for {
			select {
			case <-tick:
				go advance()
			case <-ch:
				return
			}
		}
	}()
}

func setInterval(r config.RefreshInterval) {
	app.settings.SetInterval(r)
	checkInterval()
	startScheduler()
}

func checkInterval() {
	r := app.settings.RefreshInterval
	items := map[config.RefreshInterval]*systray.MenuItem{
		config.Interval15m:   app.miMi15m,
		config.Interval30m:   app.miMi30m,
		config.Interval1h:    app.miMi1h,
		config.Interval3h:    app.miMi3h,
		config.IntervalDaily: app.miMiDaily,
	}
	for k, mi := range items {
		if k == r {
			mi.Check()
		} else {
			mi.Uncheck()
		}
	}
}

// ── Wallpaper rotation ────────────────────────────────────────────────────────

func advance() {
	if app.lib.NeedsMore() {
		go app.lib.Replenish(app.settings, app.artists)
	}
	entry := app.lib.Next()
	if entry == nil {
		setStatus("No artworks yet — downloading…")
		return
	}
	applyEntry(entry)
}

func applyEntry(entry *library.Entry) {
	w, h := screenResolution()
	opts := render.Options{
		CanvasW:     w,
		CanvasH:     h,
		ShowCaption: app.settings.ShowCaption,
		MatWidth:    app.settings.MatWidth,
		Theme:       render.ThemeClassic,
	}
	path, err := app.lib.WallpaperPath(entry, w, h, opts)
	if err != nil {
		log.Printf("render error: %v", err)
		setStatus("Render error — retrying next cycle")
		return
	}
	if err := wallpaper.Set(path); err != nil {
		log.Printf("wallpaper set error: %v", err)
	}
	caption := entry.Artwork.Title
	detail := entry.Artwork.Artist
	if entry.Artwork.Date != "" {
		detail += " · " + entry.Artwork.Date
	}
	setStatus(fmt.Sprintf("%s — %s", caption, detail))
}

// ── Utilities ────────────────────────────────────────────────────────────────

func setStatus(s string) {
	if len([]rune(s)) > 70 {
		runes := []rune(s)
		s = string(runes[:67]) + "…"
	}
	app.miStatus.SetTitle(s)
}

func openFolder(dir string) {
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "darwin":
		cmd = exec.Command("open", dir)
	case "windows":
		cmd = exec.Command("explorer", dir)
	default:
		cmd = exec.Command("xdg-open", dir)
	}
	_ = cmd.Start()
}

func onExit() {}
