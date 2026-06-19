//go:build linux

package main

// screenResolution returns a sensible default canvas size on Linux.
// Without CGO/X11 binding, we default to 1920×1080 and let the user
// configure a higher resolution via settings if needed.
func screenResolution() (int, int) {
	return 1920, 1080
}
