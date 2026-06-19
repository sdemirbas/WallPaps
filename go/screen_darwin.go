//go:build darwin

package main

import (
	"os/exec"
	"strconv"
	"strings"
)

// screenResolution queries the main display size on macOS via system_profiler.
func screenResolution() (int, int) {
	out, err := exec.Command("system_profiler", "SPDisplaysDataType").Output()
	if err != nil {
		return 1920, 1080
	}
	for _, line := range strings.Split(string(out), "\n") {
		line = strings.TrimSpace(line)
		if !strings.HasPrefix(line, "Resolution:") {
			continue
		}
		// e.g. "Resolution: 2560 x 1600 Retina"
		parts := strings.Fields(line)
		if len(parts) >= 4 {
			w, _ := strconv.Atoi(parts[1])
			h, _ := strconv.Atoi(parts[3])
			if w > 0 && h > 0 {
				return w, h
			}
		}
	}
	return 1920, 1080
}
