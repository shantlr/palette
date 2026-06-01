# Palette

Palette is a macOS menu bar launcher for user-defined shell commands.

Features:
- Global hotkey opens Raycast-style command palette
- Commands stored locally and editable in app
- Menu bar utility mode
- Screen brush / capture tooling

## Requirements

- macOS 14+
- Xcode Command Line Tools or Xcode with Swift 6 support

## Run Locally

Start app from source:

```bash
swift run Palette
```

Notes:
- On first run, macOS may prompt for Accessibility access because global hotkeys require it.
- App runs as menu bar app (`LSUIElement`), so it does not show a Dock icon.

## Build

Debug build:

```bash
swift build
```

Release build:

```bash
swift build --configuration release
```

## Test

```bash
swift test
```

## Package macOS App

Create unsigned `.app` and `.dmg` installer:

```bash
./scripts/package-macos.sh
```

Artifacts:
- `dist/Palette.app`
- `dist/Palette.dmg`

Install flow:
1. Open `dist/Palette.dmg`
2. Drag `Palette.app` into `Applications`
3. If Gatekeeper blocks first launch, right-click app and choose `Open`
