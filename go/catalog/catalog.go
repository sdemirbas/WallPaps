package catalog

import (
	"encoding/json"
	"io"
	"net/http"
	"os"
	"time"
	"wallpaps/paths"
)

const manifestURL = "https://raw.githubusercontent.com/sdemirbas/WallPaps/main/catalog/catalog.json"

type Artist struct {
	Name        string `json:"name"`
	DisplayName string `json:"displayName"`
}

// DefaultArtists mirrors the Swift Artist.defaults list.
var DefaultArtists = []Artist{
	{"Vincent van Gogh", "Van Gogh"},
	{"Claude Monet", "Monet"},
	{"Pierre-Auguste Renoir", "Renoir"},
	{"Paul Cézanne", "Cézanne"},
	{"Edgar Degas", "Degas"},
	{"Johannes Vermeer", "Vermeer"},
	{"Rembrandt van Rijn", "Rembrandt"},
	{"Katsushika Hokusai", "Hokusai"},
	{"Gustav Klimt", "Klimt"},
	{"Georges Seurat", "Seurat"},
	{"Henri de Toulouse-Lautrec", "Toulouse-Lautrec"},
	{"Eugène Delacroix", "Delacroix"},
	{"Camille Pissarro", "Pissarro"},
	{"Paul Gauguin", "Gauguin"},
	{"Édouard Manet", "Manet"},
	{"John Singer Sargent", "Sargent"},
	{"J. M. W. Turner", "Turner"},
	{"Utagawa Hiroshige", "Hiroshige"},
	{"Mary Cassatt", "Cassatt"},
	{"Francisco Goya", "Goya"},
	{"Caravaggio", "Caravaggio"},
	{"Diego Velázquez", "Velázquez"},
	{"Peter Paul Rubens", "Rubens"},
	{"Titian", "Titian"},
	{"Albrecht Dürer", "Dürer"},
	{"Sandro Botticelli", "Botticelli"},
	{"Winslow Homer", "Homer"},
	{"James McNeill Whistler", "Whistler"},
	{"Camille Corot", "Corot"},
	{"Jean-François Millet", "Millet"},
	{"Gustave Courbet", "Courbet"},
	{"Berthe Morisot", "Morisot"},
	{"Caspar David Friedrich", "Friedrich"},
	{"Raphael", "Raphael"},
	{"Tintoretto", "Tintoretto"},
	{"El Greco", "El Greco"},
	{"Hieronymus Bosch", "Bosch"},
	{"Pieter Bruegel the Elder", "Bruegel"},
	{"Jan van Eyck", "van Eyck"},
	{"Hans Holbein the Younger", "Holbein"},
	{"Anthony van Dyck", "van Dyck"},
	{"Bartolomé Esteban Murillo", "Murillo"},
	{"Frans Hals", "Hals"},
	{"Nicolas Poussin", "Poussin"},
	{"Jacques-Louis David", "J.-L. David"},
	{"Théodore Géricault", "Géricault"},
	{"John Constable", "Constable"},
	{"Thomas Gainsborough", "Gainsborough"},
	{"Alfred Sisley", "Sisley"},
	{"Henri Rousseau", "Rousseau"},
	{"Kitagawa Utamaro", "Utamaro"},
	{"Pierre Bonnard", "Bonnard"},
	{"Édouard Vuillard", "Vuillard"},
}

type manifest struct {
	Artists []Artist `json:"artists"`
}

// Load returns the artist catalog: tries the cached remote manifest first,
// then falls back to DefaultArtists. Never fails.
func Load() []Artist {
	// Try cached manifest.
	if data, err := os.ReadFile(paths.CatalogFile()); err == nil {
		var m manifest
		if json.Unmarshal(data, &m) == nil && len(m.Artists) > 0 {
			return m.Artists
		}
	}
	return DefaultArtists
}

// Refresh fetches the remote manifest and caches it. Called at startup in a
// background goroutine — any error is silently ignored.
func Refresh() {
	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Get(manifestURL)
	if err != nil || resp.StatusCode != 200 {
		return
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return
	}
	var m manifest
	if json.Unmarshal(data, &m) != nil || len(m.Artists) == 0 {
		return
	}
	os.WriteFile(paths.CatalogFile(), data, 0o644)
}
