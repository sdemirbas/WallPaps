//go:build darwin

package wallpaper

import (
	"fmt"
	"os/exec"
)

// Set applies path as the desktop wallpaper on macOS via osascript.
// The Go binary on macOS is a fallback — the native Swift app is preferred.
func Set(path string) error {
	script := fmt.Sprintf(`
tell application "System Events"
  tell every desktop
    set picture to %q
  end tell
end tell`, path)
	return exec.Command("osascript", "-e", script).Run()
}
