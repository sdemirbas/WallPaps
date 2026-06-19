// Package render composites a public-domain painting onto a canvas with a
// matte/frame border and optional caption text. Pure Go — safe on all platforms.
package render

import (
	"bytes"
	"image"
	"image/color"
	"image/jpeg" // also registers the JPEG decoder
	"image/png"
	"math"
	"math/rand"

	"golang.org/x/image/draw"
	"golang.org/x/image/font"
	"golang.org/x/image/font/gofont/goregular"
	"golang.org/x/image/font/opentype"
	"golang.org/x/image/math/fixed"
)

// Theme describes matte and frame colours.
type Theme int

const (
	ThemeClassic Theme = iota // dark wood frame, cream matte
	ThemeGilt                 // gold frame, off-white matte
	ThemeModern               // thin dark frame, white matte
	ThemeVintage              // antique frame, aged matte
)

type Options struct {
	CanvasW, CanvasH int
	ShowCaption      bool
	MatWidth         float64 // fraction of longer artwork side
	Theme            Theme
}

// Render composites srcData (JPEG/PNG artwork) and writes a PNG to a buffer.
// Returns nil on error.
func Render(srcData []byte, caption string, opts Options) []byte {
	src, _, err := image.Decode(bytes.NewReader(srcData))
	if err != nil {
		return nil
	}
	W, H := opts.CanvasW, opts.CanvasH
	if W <= 0 || H <= 0 {
		return nil
	}

	canvas := image.NewNRGBA(image.Rect(0, 0, W, H))

	// ── 1. Background ────────────────────────────────────────────────────────
	avg := averageColor(src)
	bg := blendColor(avg, themeBackground(opts.Theme), 0.55)
	fillRect(canvas, image.Rect(0, 0, W, H), bg)

	// Subtle noise grain (mimics gallery wall texture).
	addGrain(canvas, 0.03)

	// ── 2. Layout geometry ───────────────────────────────────────────────────
	sW, sH := float64(src.Bounds().Dx()), float64(src.Bounds().Dy())
	maxFrac := 0.66
	labelRoom := 0.0
	if opts.ShowCaption && caption != "" {
		labelRoom = float64(H) * 0.07
	}

	maxW := float64(W) * maxFrac
	maxH := (float64(H) - labelRoom) * maxFrac
	scale := math.Min(maxW/sW, maxH/sH)
	if scale > 1 {
		scale = 1
	}
	aW, aH := sW*scale, sH*scale

	mat := math.Max(aW, aH) * opts.MatWidth
	if mat < 4 {
		mat = 4
	}
	frameW := mat * 0.45
	if frameW < 3 {
		frameW = 3
	}

	// Shrink if assembly overflows canvas (96% safe zone).
	avW := float64(W) * 0.96
	avH := (float64(H) - labelRoom) * 0.96
	total := aW + 2*(mat+frameW)
	shrink := math.Min(avW/total, avH/(aH+2*(mat+frameW)))
	if shrink < 1 {
		aW *= shrink
		aH *= shrink
		mat *= shrink
		frameW *= shrink
	}

	aX := (float64(W) - aW) / 2
	aY := (float64(H)-aH)/2 + labelRoom/2
	artRect := image.Rect(int(aX), int(aY), int(aX+aW), int(aY+aH))
	matRect := expand(artRect, int(mat))
	outerRect := expand(matRect, int(frameW))

	// Clamp to canvas.
	outerRect = outerRect.Intersect(image.Rect(0, 0, W, H))
	matRect = matRect.Intersect(outerRect)
	artRect = artRect.Intersect(matRect)

	// ── 3. Frame band ────────────────────────────────────────────────────────
	fillRect(canvas, outerRect, themeFrame(opts.Theme))

	// ── 4. Matte ─────────────────────────────────────────────────────────────
	fillRect(canvas, matRect, themeMatte(opts.Theme))

	// Thin inner stroke around artwork.
	strokeRect(canvas, artRect, color.NRGBA{0, 0, 0, 30}, 1)

	// ── 5. Artwork (high-quality Catmull-Rom scaling) ─────────────────────────
	scaled := image.NewNRGBA(artRect)
	draw.CatmullRom.Scale(scaled, scaled.Bounds(), src, src.Bounds(), draw.Over, nil)
	drawImage(canvas, scaled, artRect.Min)

	// ── 6. Radial vignette on the canvas edges ────────────────────────────────
	addVignette(canvas, 0.35)

	// ── 7. Caption ────────────────────────────────────────────────────────────
	if opts.ShowCaption && caption != "" {
		drawCaption(canvas, caption, W, H, outerRect.Min.Y)
	}

	var buf bytes.Buffer
	if err := png.Encode(&buf, canvas); err != nil {
		return nil
	}
	return buf.Bytes()
}

// ── Colour helpers ───────────────────────────────────────────────────────────

func averageColor(src image.Image) color.NRGBA {
	b := src.Bounds()
	// Sample corners + centre for speed.
	points := [][2]int{
		{b.Min.X + b.Dx()/4, b.Min.Y + b.Dy()/4},
		{b.Max.X - b.Dx()/4, b.Min.Y + b.Dy()/4},
		{b.Min.X + b.Dx()/4, b.Max.Y - b.Dy()/4},
		{b.Max.X - b.Dx()/4, b.Max.Y - b.Dy()/4},
		{b.Min.X + b.Dx()/2, b.Min.Y + b.Dy()/2},
	}
	var r, g, bl float64
	for _, p := range points {
		c := color.NRGBAModel.Convert(src.At(p[0], p[1])).(color.NRGBA)
		r += float64(c.R)
		g += float64(c.G)
		bl += float64(c.B)
	}
	n := float64(len(points))
	return color.NRGBA{uint8(r / n), uint8(g / n), uint8(bl / n), 255}
}

func blendColor(a, b color.NRGBA, t float64) color.NRGBA {
	lerp := func(x, y uint8) uint8 {
		return uint8(float64(x)*(1-t) + float64(y)*t)
	}
	return color.NRGBA{lerp(a.R, b.R), lerp(a.G, b.G), lerp(a.B, b.B), 255}
}

// ── Theme colours ────────────────────────────────────────────────────────────

func themeBackground(t Theme) color.NRGBA {
	switch t {
	case ThemeGilt:
		return color.NRGBA{30, 28, 24, 255}
	case ThemeModern:
		return color.NRGBA{248, 248, 248, 255}
	case ThemeVintage:
		return color.NRGBA{55, 45, 32, 255}
	default:
		return color.NRGBA{42, 38, 32, 255} // classic
	}
}

func themeFrame(t Theme) color.NRGBA {
	switch t {
	case ThemeGilt:
		return color.NRGBA{190, 152, 62, 255}
	case ThemeModern:
		return color.NRGBA{30, 30, 30, 255}
	case ThemeVintage:
		return color.NRGBA{110, 85, 52, 255}
	default:
		return color.NRGBA{68, 52, 30, 255}
	}
}

func themeMatte(t Theme) color.NRGBA {
	switch t {
	case ThemeGilt:
		return color.NRGBA{250, 248, 242, 255}
	case ThemeModern:
		return color.NRGBA{255, 255, 255, 255}
	case ThemeVintage:
		return color.NRGBA{234, 225, 205, 255}
	default:
		return color.NRGBA{242, 236, 220, 255}
	}
}

// ── Drawing helpers ──────────────────────────────────────────────────────────

func fillRect(img *image.NRGBA, r image.Rectangle, c color.NRGBA) {
	for y := r.Min.Y; y < r.Max.Y; y++ {
		for x := r.Min.X; x < r.Max.X; x++ {
			img.SetNRGBA(x, y, c)
		}
	}
}

func strokeRect(img *image.NRGBA, r image.Rectangle, c color.NRGBA, w int) {
	for i := 0; i < w; i++ {
		fillRect(img, image.Rect(r.Min.X-i, r.Min.Y-i, r.Max.X+i, r.Min.Y-i+1), c)
		fillRect(img, image.Rect(r.Min.X-i, r.Max.Y+i-1, r.Max.X+i, r.Max.Y+i), c)
		fillRect(img, image.Rect(r.Min.X-i, r.Min.Y-i, r.Min.X-i+1, r.Max.Y+i), c)
		fillRect(img, image.Rect(r.Max.X+i-1, r.Min.Y-i, r.Max.X+i, r.Max.Y+i), c)
	}
}

func drawImage(dst *image.NRGBA, src *image.NRGBA, at image.Point) {
	draw.Draw(dst, src.Bounds().Add(at), src, image.Point{}, draw.Over)
}

func expand(r image.Rectangle, by int) image.Rectangle {
	return image.Rect(r.Min.X-by, r.Min.Y-by, r.Max.X+by, r.Max.Y+by)
}

func addGrain(img *image.NRGBA, alpha float64) {
	b := img.Bounds()
	a := uint8(alpha * 255)
	for y := b.Min.Y; y < b.Max.Y; y += 3 {
		for x := b.Min.X; x < b.Max.X; x += 3 {
			v := uint8(rand.Intn(60) + 97)
			// Blend noise over the existing pixel.
			c := img.NRGBAAt(x, y)
			blend := func(base, noise uint8) uint8 {
				return uint8((int(base)*int(255-a) + int(noise)*int(a)) / 255)
			}
			img.SetNRGBA(x, y, color.NRGBA{blend(c.R, v), blend(c.G, v), blend(c.B, v), 255})
		}
	}
}

func addVignette(img *image.NRGBA, strength float64) {
	b := img.Bounds()
	cx, cy := float64(b.Dx())/2, float64(b.Dy())/2
	maxR := math.Hypot(cx, cy)
	innerFrac := 0.55

	for y := b.Min.Y; y < b.Max.Y; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			dx, dy := float64(x)-cx, float64(y)-cy
			r := math.Hypot(dx, dy) / maxR
			if r <= innerFrac {
				continue
			}
			t := (r - innerFrac) / (1 - innerFrac)
			if t > 1 {
				t = 1
			}
			dark := uint8(t * t * strength * 255)
			c := img.NRGBAAt(x, y)
			sub := func(v, d uint8) uint8 {
				if int(v)-int(d) < 0 {
					return 0
				}
				return v - d
			}
			img.SetNRGBA(x, y, color.NRGBA{sub(c.R, dark), sub(c.G, dark), sub(c.B, dark), 255})
		}
	}
}

func drawCaption(img *image.NRGBA, caption string, W, H, outerTop int) {
	f, err := opentype.Parse(goregular.TTF)
	if err != nil {
		return
	}
	size := float64(H) * 0.016
	if size < 12 {
		size = 12
	}
	face, err := opentype.NewFace(f, &opentype.FaceOptions{Size: size, DPI: 96})
	if err != nil {
		return
	}
	defer face.Close()

	d := &font.Drawer{
		Dst:  img,
		Src:  image.NewUniform(color.NRGBA{24, 20, 14, 220}),
		Face: face,
	}
	textW := d.MeasureString(caption).Ceil()
	tx := (W - textW) / 2
	ty := outerTop - int(float64(H)*0.03)
	if ty < int(float64(H)*0.02)+int(size) {
		ty = int(float64(H)*0.02) + int(size)
	}
	d.Dot = fixed.P(tx, ty)
	d.DrawString(caption)
}

// RenderJPEGPreview renders a lower-quality JPEG for the 4K master thumbnail.
func RenderJPEGPreview(data []byte) ([]byte, error) {
	img, _, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		return nil, err
	}
	var buf bytes.Buffer
	err = jpeg.Encode(&buf, img, &jpeg.Options{Quality: 85})
	return buf.Bytes(), err
}
