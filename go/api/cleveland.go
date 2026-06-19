package api

import (
	"encoding/json"
	"fmt"
	"io"
	"net/url"
)

// ClevelandProvider fetches CC0 artworks from the Cleveland Museum of Art.
// Images are often >10 000 px — excellent for 4K rendering.
type ClevelandProvider struct{}

func (p ClevelandProvider) Name() string { return "Cleveland Museum of Art" }

const clevelandAPI = "https://openaccess-api.clevelandart.org/api/artworks/"

func (p ClevelandProvider) Fetch(artist string, limit int) ([]Artwork, error) {
	params := url.Values{
		"q":         {artist},
		"cc0":       {"1"},
		"has_image": {"1"},
		"limit":     {fmt.Sprintf("%d", limit)},
		"fields":    {"id,title,creators,creation_date,images,technique"},
	}
	resp, err := HTTPClient.Get(clevelandAPI + "?" + params.Encode())
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
			ID           int     `json:"id"`
			Title        *string `json:"title"`
			CreationDate *string `json:"creation_date"`
			Technique    *string `json:"technique"`
			Creators     []struct {
				Description *string `json:"description"`
			} `json:"creators"`
			Images *struct {
				Full *struct {
					URL string `json:"url"`
				} `json:"full"`
			} `json:"images"`
		} `json:"data"`
	}
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, err
	}

	var artworks []Artwork
	for _, item := range result.Data {
		if item.Images == nil || item.Images.Full == nil || item.Images.Full.URL == "" {
			continue
		}
		artistName := artist
		if len(item.Creators) > 0 && item.Creators[0].Description != nil {
			if n := cleanArtistName(*item.Creators[0].Description); n != "" {
				artistName = n
			}
		}
		title := "Untitled"
		if item.Title != nil && *item.Title != "" {
			title = *item.Title
		}
		artworks = append(artworks, Artwork{
			ID:       fmt.Sprintf("CMA:%d", item.ID),
			Title:    title,
			Artist:   artistName,
			Date:     strVal(item.CreationDate, ""),
			ImageURL: item.Images.Full.URL,
			Source:   p.Name(),
			Medium:   strVal(item.Technique, ""),
		})
		if len(artworks) >= limit {
			break
		}
	}
	return artworks, nil
}
