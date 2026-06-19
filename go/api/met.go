package api

import (
	"encoding/json"
	"fmt"
	"io"
	"net/url"
)

// MetProvider fetches CC0 artworks from The Metropolitan Museum of Art.
type MetProvider struct{}

func (p MetProvider) Name() string { return "The Met" }

const metSearch = "https://collectionapi.metmuseum.org/public/collection/v1/search"
const metObject = "https://collectionapi.metmuseum.org/public/collection/v1/objects/%d"

func (p MetProvider) Fetch(artist string, limit int) ([]Artwork, error) {
	params := url.Values{
		"q":         {artist},
		"hasImages": {"true"},
	}
	resp, err := HTTPClient.Get(metSearch + "?" + params.Encode())
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return nil, ErrBadResponse
	}

	body, _ := io.ReadAll(resp.Body)
	var search struct {
		Total     int   `json:"total"`
		ObjectIDs []int `json:"objectIDs"`
	}
	if err := json.Unmarshal(body, &search); err != nil {
		return nil, err
	}

	// Over-fetch: many objects lack public-domain images.
	ids := search.ObjectIDs
	if len(ids) > limit*4 {
		ids = ids[:limit*4]
	}

	var artworks []Artwork
	for _, id := range ids {
		if len(artworks) >= limit {
			break
		}
		art, err := p.fetchObject(id, artist)
		if err != nil {
			continue
		}
		artworks = append(artworks, art)
	}
	return artworks, nil
}

func (p MetProvider) fetchObject(id int, fallbackArtist string) (Artwork, error) {
	resp, err := HTTPClient.Get(fmt.Sprintf(metObject, id))
	if err != nil {
		return Artwork{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return Artwork{}, ErrBadResponse
	}

	body, _ := io.ReadAll(resp.Body)
	var obj struct {
		Title             string `json:"title"`
		ArtistDisplayName string `json:"artistDisplayName"`
		ObjectDate        string `json:"objectDate"`
		PrimaryImage      string `json:"primaryImage"`
		IsPublicDomain    bool   `json:"isPublicDomain"`
		Medium            string `json:"medium"`
		Department        string `json:"department"`
	}
	if err := json.Unmarshal(body, &obj); err != nil {
		return Artwork{}, err
	}
	if !obj.IsPublicDomain || obj.PrimaryImage == "" {
		return Artwork{}, fmt.Errorf("skip: not public domain or no image")
	}

	artist := cleanArtistName(obj.ArtistDisplayName)
	if artist == "" {
		artist = fallbackArtist
	}
	title := obj.Title
	if title == "" {
		title = "Untitled"
	}
	return Artwork{
		ID:       fmt.Sprintf("Met:%d", id),
		Title:    title,
		Artist:   artist,
		Date:     obj.ObjectDate,
		ImageURL: obj.PrimaryImage,
		Source:   p.Name(),
		Medium:   obj.Medium,
	}, nil
}
