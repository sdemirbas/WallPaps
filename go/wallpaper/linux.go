//go:build linux

package wallpaper

import (
	"fmt"
	"os"
	"os/exec"
)

// Set attempts to apply path as the desktop wallpaper, trying common Linux
// desktop environments in order: GNOME → KDE Plasma → XFCE → feh → nitrogen.
func Set(path string) error {
	fileURI := "file://" + path

	// GNOME / GNOME-based (Ubuntu, Pop!_OS, Fedora …)
	if which("gsettings") {
		err := exec.Command("gsettings", "set",
			"org.gnome.desktop.background", "picture-uri", fileURI).Run()
		if err == nil {
			// Also set the dark-mode key (GNOME 42+)
			exec.Command("gsettings", "set",
				"org.gnome.desktop.background", "picture-uri-dark", fileURI).Run()
			exec.Command("gsettings", "set",
				"org.gnome.desktop.background", "picture-options", "zoom").Run()
			return nil
		}
	}

	// KDE Plasma 5.6+
	if which("plasma-apply-wallpaperimage") {
		if err := exec.Command("plasma-apply-wallpaperimage", path).Run(); err == nil {
			return nil
		}
	}

	// XFCE
	if which("xfconf-query") {
		display := os.Getenv("DISPLAY")
		if display == "" {
			display = ":0"
		}
		// Try the default monitor/workspace path.
		err := exec.Command("xfconf-query",
			"-c", "xfce4-desktop",
			"-p", "/backdrop/screen0/monitor0/workspace0/last-image",
			"-s", path).Run()
		if err == nil {
			return nil
		}
	}

	// feh (widely used on minimal setups and tiling WMs)
	if which("feh") {
		if err := exec.Command("feh", "--bg-fill", path).Run(); err == nil {
			return nil
		}
	}

	// nitrogen
	if which("nitrogen") {
		if err := exec.Command("nitrogen", "--set-zoom-fill", path).Run(); err == nil {
			return nil
		}
	}

	// swaybg (Wayland/sway)
	if which("swaybg") {
		// swaybg runs as a daemon; kill any existing instance first.
		exec.Command("pkill", "-f", "swaybg").Run()
		cmd := exec.Command("swaybg", "-i", path, "-m", "fill")
		if err := cmd.Start(); err == nil {
			return nil
		}
	}

	return fmt.Errorf("wallpaper: no compatible setter found (tried gsettings, plasma, xfconf-query, feh, nitrogen, swaybg)")
}

func which(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}
