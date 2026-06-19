package paths

import (
	"os"
	"path/filepath"
	"runtime"
)

var base string

func init() {
	switch runtime.GOOS {
	case "windows":
		if d, err := os.UserConfigDir(); err == nil {
			base = filepath.Join(d, "WallPaps")
		} else {
			base = filepath.Join(os.Getenv("APPDATA"), "WallPaps")
		}
	case "darwin":
		if d, err := os.UserHomeDir(); err == nil {
			base = filepath.Join(d, "Library", "Application Support", "WallPaps")
		}
	default: // linux, etc.
		if d, err := os.UserConfigDir(); err == nil {
			base = filepath.Join(d, "wallpaps")
		} else {
			base = filepath.Join(os.Getenv("HOME"), ".config", "wallpaps")
		}
	}
}

func DataDir() string    { return base }
func SourcesDir() string { return filepath.Join(base, "sources") }
func MastersDir() string { return filepath.Join(base, "masters") }
func WallsDir() string   { return filepath.Join(base, "wallpapers") }
func LibraryFile() string { return filepath.Join(base, "library.json") }
func FavoritesFile() string { return filepath.Join(base, "favorites.json") }
func SettingsFile() string { return filepath.Join(base, "settings.json") }
func CatalogFile() string  { return filepath.Join(base, "catalog.json") }

func EnsureDirs() {
	for _, d := range []string{base, SourcesDir(), MastersDir(), WallsDir()} {
		os.MkdirAll(d, 0o755)
	}
}
