package api

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"unicode"
)

// ArticProvider fetches public-domain artworks from the Art Institute of Chicago.
// No API key required. Images served via IIIF Image API 2.0.
type ArticProvider struct{}

func (p ArticProvider) Name() string { return "Art Institute of Chicago" }

const articBase = "https://api.artic.edu/api/v1/artworks/search"
const articFallbackIIIF = "https://www.artic.edu/iiif/2"
const articTargetWidth = 3840

func (p ArticProvider) Fetch(artist string, limit int) ([]Artwork, error) {
	params := url.Values{
		"q":                             {artist},
		"query[term][is_public_domain]": {"true"},
		"fields":                        {"id,title,image_id,artist_display,date_display,is_public_domain,medium_display"},
		"limit":                         {fmt.Sprintf("%d", max(limit, 10))},
	}
	req, _ := http.NewRequest("GET", articBase+"?"+params.Encode(), nil)
	req.Header.Set("AIC-User-Agent", "WallPaps/1.0 (wallpaper app; contact@example.com)")

	resp, err := HTTPClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return nil, ErrBadResponse
	}

	body, _ := io.ReadAll(resp.Body)

	var result struct {
		Data []struct {
			ID             int     `json:"id"`
			Title          string  `json:"title"`
			ImageID        *string `json:"image_id"`
			ArtistDisplay  *string `json:"artist_display"`
			DateDisplay    *string `json:"date_display"`
			IsPublicDomain *bool   `json:"is_public_domain"`
			MediumDisplay  *string `json:"medium_display"`
		} `json:"data"`
		Config struct {
			IIIFUrl *string `json:"iiif_url"`
		} `json:"config"`
	}
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, err
	}

	iiifBase := articFallbackIIIF
	if result.Config.IIIFUrl != nil && *result.Config.IIIFUrl != "" {
		iiifBase = *result.Config.IIIFUrl
	}

	var artworks []Artwork
	for _, item := range result.Data {
		if item.IsPublicDomain != nil && !*item.IsPublicDomain {
			continue
		}
		if item.ImageID == nil || *item.ImageID == "" {
			continue
		}
		imageURL := fmt.Sprintf("%s/%s/full/%d,/0/default.jpg", iiifBase, *item.ImageID, articTargetWidth)
		artistName := cleanArtistName(strVal(item.ArtistDisplay, artist))
		artworks = append(artworks, Artwork{
			ID:       fmt.Sprintf("AIC:%d", item.ID),
			Title:    strVal(&item.Title, "Untitled"),
			Artist:   artistName,
			Date:     strVal(item.DateDisplay, ""),
			ImageURL: imageURL,
			Source:   p.Name(),
			Medium:   strVal(item.MediumDisplay, ""),
		})
		if len(artworks) >= limit {
			break
		}
	}
	return artworks, nil
}

var htmlTagRe = regexp.MustCompile(`<[^>]+>`)

func cleanArtistName(s string) string {
	s = htmlTagRe.ReplaceAllString(s, "")
	// AIC artist_display often has "Artist Name\nNationality, born–died"
	if idx := strings.IndexByte(s, '\n'); idx != -1 {
		s = s[:idx]
	}
	// Drop trailing punctuation or parenthetical fragments.
	s = strings.TrimRightFunc(strings.TrimSpace(s), func(r rune) bool {
		return unicode.IsPunct(r) && r != '.'
	})
	return strings.TrimSpace(s)
}

func strVal(s *string, fallback string) string {
	if s == nil || *s == "" {
		return fallback
	}
	return *s
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
