package api

import (
	"fmt"
	"net/http"
	"time"
)

// Artwork holds the metadata and image URL for a single public-domain painting.
type Artwork struct {
	ID       string
	Title    string
	Artist   string
	Date     string
	ImageURL string
	Source   string
	Medium   string
}

// Source is implemented by each museum API provider.
type Source interface {
	Name() string
	Fetch(artist string, limit int) ([]Artwork, error)
}

// ErrBadResponse is returned when the API returns a non-200 status.
var ErrBadResponse = fmt.Errorf("bad API response")

// HTTPClient shared by all providers — 20 s timeout, follows redirects.
var HTTPClient = &http.Client{
	Timeout: 20 * time.Second,
	Transport: &http.Transport{
		MaxIdleConns:       10,
		IdleConnTimeout:    30 * time.Second,
		DisableCompression: false,
	},
}
