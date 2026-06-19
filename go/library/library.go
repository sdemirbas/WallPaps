// Package library manages the artwork rotation pool and on-disk cache.
package library

import (
	"encoding/json"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"os"
	"path/filepath"
	"sync"
	"time"
	"wallpaps/api"
	"wallpaps/catalog"
	"wallpaps/config"
	"wallpaps/paths"
	"wallpaps/render"
)

// Entry is one artwork in the rotation pool.
type Entry struct {
	Artwork    api.Artwork `json:"artwork"`
	SourcePath string      `json:"sourcePath"` // downloaded original
	MasterPath string      `json:"masterPath"` // 4K PNG
}

// Library manages a pool of entries and rotates through them.
type Library struct {
	mu      sync.Mutex
	entries []Entry
	index   int
	current *Entry
}

const lowWaterMark = 8

var httpClient = &http.Client{
	Timeout: 30 * time.Second,
}

// New creates an empty library and loads any persisted state.
func New() *Library {
	l := &Library{index: -1}
	l.loadPersisted()
	return l
}

func (l *Library) Len() int {
	l.mu.Lock()
	defer l.mu.Unlock()
	return len(l.entries)
}

func (l *Library) NeedsMore() bool {
	return l.Len() < lowWaterMark
}

func (l *Library) Current() *Entry {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.current
}

// Next advances the rotation and returns the next entry.
func (l *Library) Next() *Entry {
	l.mu.Lock()
	defer l.mu.Unlock()
	if len(l.entries) == 0 {
		return nil
	}
	l.index = (l.index + 1) % len(l.entries)
	l.current = &l.entries[l.index]
	return l.current
}

// Replenish downloads and renders artworks until the pool reaches librarySize.
// It fetches from enabled artists across all three museum sources.
func (l *Library) Replenish(s *config.Settings, artists []catalog.Artist) {
	target := s.LibrarySize
	if target <= 0 {
		target = 100
	}

	enabled := s.GetEnabledArtists()
	if len(enabled) == 0 {
		for _, a := range artists {
			enabled = append(enabled, a.Name)
		}
	}

	sources := []api.Source{
		api.ArticProvider{},
		api.MetProvider{},
		api.ClevelandProvider{},
	}

	attempts := 0
	for l.Len() < target && attempts < 20 {
		attempts++
		artist := enabled[rand.Intn(len(enabled))]
		src := sources[rand.Intn(len(sources))]

		artworks, err := src.Fetch(artist, 5)
		if err != nil || len(artworks) == 0 {
			continue
		}

		for _, art := range artworks {
			if l.Len() >= target {
				break
			}
			if l.has(art.ID) {
				continue
			}
			entry, err := l.downloadAndRender(art)
			if err != nil {
				continue
			}
			l.mu.Lock()
			l.entries = append(l.entries, entry)
			l.mu.Unlock()
			l.persist()
		}
	}
}

func (l *Library) has(id string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	for _, e := range l.entries {
		if e.Artwork.ID == id {
			return true
		}
	}
	return false
}

// WallpaperPath returns the cached variant path for the given pixel size, or
// renders and caches it if missing.
func (l *Library) WallpaperPath(e *Entry, w, h int, opts render.Options) (string, error) {
	opts.CanvasW = w
	opts.CanvasH = h
	variantName := fmt.Sprintf("%s_%dx%d_c%d_m%d_t%d.png",
		sanitize(e.Artwork.ID), w, h,
		boolInt(opts.ShowCaption), int(opts.MatWidth*1000), int(opts.Theme))
	variantPath := filepath.Join(paths.WallsDir(), variantName)

	if _, err := os.Stat(variantPath); err == nil {
		return variantPath, nil
	}

	srcData, err := os.ReadFile(e.SourcePath)
	if err != nil {
		return "", fmt.Errorf("read source: %w", err)
	}

	caption := e.Artwork.Artist
	if e.Artwork.Date != "" {
		caption += " · " + e.Artwork.Date
	}
	png := render.Render(srcData, caption, opts)
	if png == nil {
		return "", fmt.Errorf("render failed")
	}
	if err := os.WriteFile(variantPath, png, 0o644); err != nil {
		return "", err
	}
	return variantPath, nil
}

// ── Persistence ──────────────────────────────────────────────────────────────

type persistState struct {
	Entries []Entry `json:"entries"`
	Index   int     `json:"index"`
}

func (l *Library) persist() {
	l.mu.Lock()
	state := persistState{Entries: l.entries, Index: l.index}
	l.mu.Unlock()
	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return
	}
	os.WriteFile(paths.LibraryFile(), data, 0o644)
}

func (l *Library) loadPersisted() {
	data, err := os.ReadFile(paths.LibraryFile())
	if err != nil {
		return
	}
	var state persistState
	if json.Unmarshal(data, &state) != nil {
		return
	}
	// Drop entries whose source files are missing.
	valid := state.Entries[:0]
	for _, e := range state.Entries {
		if _, err := os.Stat(e.SourcePath); err == nil {
			valid = append(valid, e)
		}
	}
	l.mu.Lock()
	l.entries = valid
	if state.Index >= 0 && state.Index < len(l.entries) {
		l.index = state.Index
		l.current = &l.entries[l.index]
	}
	l.mu.Unlock()
}

// ── Download + render ────────────────────────────────────────────────────────

func (l *Library) downloadAndRender(art api.Artwork) (Entry, error) {
	srcName := sanitize(art.ID) + ".jpg"
	srcPath := filepath.Join(paths.SourcesDir(), srcName)

	// Skip download if the file already exists (resume after crash).
	if _, err := os.Stat(srcPath); os.IsNotExist(err) {
		if err := downloadFile(art.ImageURL, srcPath); err != nil {
			return Entry{}, fmt.Errorf("download %s: %w", art.ID, err)
		}
	}

	// Render 4K master.
	masterName := sanitize(art.ID) + "_4k.png"
	masterPath := filepath.Join(paths.MastersDir(), masterName)
	if _, err := os.Stat(masterPath); os.IsNotExist(err) {
		srcData, err := os.ReadFile(srcPath)
		if err != nil {
			return Entry{}, err
		}
		caption := art.Artist
		if art.Date != "" {
			caption += " · " + art.Date
		}
		opts := render.Options{
			CanvasW:     3840,
			CanvasH:     2160,
			ShowCaption: true,
			MatWidth:    0.08,
			Theme:       render.ThemeClassic,
		}
		data := render.Render(srcData, caption, opts)
		if data == nil {
			return Entry{}, fmt.Errorf("4K render failed for %s", art.ID)
		}
		os.WriteFile(masterPath, data, 0o644)
	}

	return Entry{Artwork: art, SourcePath: srcPath, MasterPath: masterPath}, nil
}

func downloadFile(url, dst string) error {
	resp, err := httpClient.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	f, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = io.Copy(f, resp.Body)
	return err
}

// ── Utilities ────────────────────────────────────────────────────────────────

func sanitize(id string) string {
	out := make([]byte, 0, len(id))
	for _, c := range []byte(id) {
		if c == ':' || c == '/' || c == '\\' {
			out = append(out, '_')
		} else {
			out = append(out, c)
		}
	}
	return string(out)
}

func boolInt(b bool) int {
	if b {
		return 1
	}
	return 0
}
