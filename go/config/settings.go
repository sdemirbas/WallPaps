package config

import (
	"encoding/json"
	"os"
	"sync"
	"wallpaps/paths"
)

type RefreshInterval string

const (
	Interval15m   RefreshInterval = "15m"
	Interval30m   RefreshInterval = "30m"
	Interval1h    RefreshInterval = "1h"
	Interval3h    RefreshInterval = "3h"
	IntervalDaily RefreshInterval = "daily"
)

func (r RefreshInterval) Seconds() float64 {
	switch r {
	case Interval15m:
		return 15 * 60
	case Interval30m:
		return 30 * 60
	case Interval3h:
		return 3 * 60 * 60
	case IntervalDaily:
		return 24 * 60 * 60
	default:
		return 60 * 60 // 1h
	}
}

type Settings struct {
	mu sync.Mutex

	RefreshInterval RefreshInterval `json:"refreshInterval"`
	EnabledArtists  []string        `json:"enabledArtists"`
	ShowCaption     bool            `json:"showCaption"`
	MatWidth        float64         `json:"matWidth"`
	LibrarySize     int             `json:"librarySize"`
	LocalFolderPath string          `json:"localFolderPath"`
}

func DefaultSettings() *Settings {
	return &Settings{
		RefreshInterval: Interval1h,
		ShowCaption:     true,
		MatWidth:        0.08,
		LibrarySize:     100,
	}
}

func Load() *Settings {
	s := DefaultSettings()
	data, err := os.ReadFile(paths.SettingsFile())
	if err == nil {
		json.Unmarshal(data, s)
	}
	return s
}

func (s *Settings) Save() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	data, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(paths.SettingsFile(), data, 0o644)
}

func (s *Settings) SetInterval(r RefreshInterval) {
	s.mu.Lock()
	s.RefreshInterval = r
	s.mu.Unlock()
	s.Save()
}

func (s *Settings) GetEnabledArtists() []string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return append([]string(nil), s.EnabledArtists...)
}

func (s *Settings) SetEnabledArtists(artists []string) {
	s.mu.Lock()
	s.EnabledArtists = artists
	s.mu.Unlock()
	s.Save()
}
