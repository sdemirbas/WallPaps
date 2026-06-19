//go:build windows

package wallpaper

import (
	"syscall"
	"unsafe"
)

const (
	spiSetDeskWallpaper = 0x0014
	spifUpdateIniFile   = 0x0001
	spifSendChange      = 0x0002
)

var (
	user32               = syscall.NewLazyDLL("user32.dll")
	systemParametersInfo = user32.NewProc("SystemParametersInfoW")
)

// Set applies path as the desktop wallpaper via SystemParametersInfoW.
func Set(path string) error {
	ptr, err := syscall.UTF16PtrFromString(path)
	if err != nil {
		return err
	}
	r1, _, lastErr := systemParametersInfo.Call(
		spiSetDeskWallpaper,
		0,
		uintptr(unsafe.Pointer(ptr)),
		spifUpdateIniFile|spifSendChange,
	)
	if r1 == 0 {
		return lastErr
	}
	return nil
}
