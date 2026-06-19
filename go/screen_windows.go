//go:build windows

package main

import "syscall"

var (
	user32wnd         = syscall.NewLazyDLL("user32.dll")
	getSystemMetrics  = user32wnd.NewProc("GetSystemMetrics")
)

const (
	smCxScreen = 0
	smCyScreen = 1
)

func screenResolution() (int, int) {
	w, _, _ := getSystemMetrics.Call(smCxScreen)
	h, _, _ := getSystemMetrics.Call(smCyScreen)
	if w == 0 || h == 0 {
		return 1920, 1080
	}
	return int(w), int(h)
}
