// Package assets generates the system-tray icon PNG at runtime.
package assets

import (
	"bytes"
	"image"
	"image/color"
	"image/png"
)

// TrayIcon returns a 32×32 PNG depicting a picture frame — used as the
// system-tray icon on all platforms.
func TrayIcon() []byte {
	img := image.NewNRGBA(image.Rect(0, 0, 32, 32))

	fill := func(x0, y0, x1, y1 int, c color.NRGBA) {
		for y := y0; y < y1; y++ {
			for x := x0; x < x1; x++ {
				img.SetNRGBA(x, y, c)
			}
		}
	}

	outer := color.NRGBA{38, 28, 14, 255}   // dark wood outer border
	frame := color.NRGBA{160, 122, 52, 255}  // warm gold frame band
	matte := color.NRGBA{240, 234, 218, 255} // cream matte
	art := color.NRGBA{110, 130, 155, 255}   // painting placeholder (soft blue-grey)

	// 1) Whole canvas: outer dark border
	fill(0, 0, 32, 32, outer)
	// 2) Gold frame band
	fill(2, 2, 30, 30, frame)
	// 3) Cream matte
	fill(5, 5, 27, 27, matte)
	// 4) Artwork area
	fill(8, 8, 24, 24, art)

	// Horizon line in the art area for visual interest
	horizon := color.NRGBA{80, 105, 130, 255}
	fill(8, 16, 24, 17, horizon)

	// Sun / highlight
	img.SetNRGBA(18, 11, color.NRGBA{255, 220, 130, 255})
	img.SetNRGBA(19, 11, color.NRGBA{255, 220, 130, 255})
	img.SetNRGBA(18, 12, color.NRGBA{255, 220, 130, 255})
	img.SetNRGBA(19, 12, color.NRGBA{255, 220, 130, 255})

	var buf bytes.Buffer
	png.Encode(&buf, img)
	return buf.Bytes()
}
