# WallPaps — Go cross-platform build

LDFLAGS_WIN = -s -w -H windowsgui
LDFLAGS_UNIX = -s -w

# ── Tidy & fetch deps (run once after cloning) ────────────────────────────────
deps:
	go mod tidy

# ── Native build for the current platform ────────────────────────────────────
build:
	go build -ldflags="$(LDFLAGS_UNIX)" -o wallpaps .

# ── Cross-compile ─────────────────────────────────────────────────────────────
# Windows — no CGO needed (pure syscall/winapi).
# Can be cross-compiled from macOS or Linux after `go mod tidy`.
windows:
	GOOS=windows GOARCH=amd64 CGO_ENABLED=0 \
	  go build -ldflags="$(LDFLAGS_WIN)" -o wallpaps.exe .

# Linux — requires CGO + GTK3/AppIndicator for the systray backend.
#   sudo apt install libgtk-3-dev libayatana-appindicator3-dev
linux:
	GOOS=linux GOARCH=amd64 CGO_ENABLED=1 \
	  go build -ldflags="$(LDFLAGS_UNIX)" -o wallpaps-linux .

# macOS (arm64) — requires CGO + Cocoa (standard on any Mac with Xcode).
macos:
	GOOS=darwin GOARCH=arm64 CGO_ENABLED=1 \
	  go build -ldflags="$(LDFLAGS_UNIX)" -o wallpaps-macos .

# ── Run in place (dev) ───────────────────────────────────────────────────────
run:
	go run .

.PHONY: deps build windows linux macos run
