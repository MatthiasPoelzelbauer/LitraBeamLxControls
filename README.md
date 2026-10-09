# Litra Beam LX

A native macOS menu bar app for controlling the **Logitech Litra Beam LX** over Bluetooth or USB.

## Features

- **Backlight (RGB):** on/off, brightness in %, and color from a spectrum that opens next to the menu
- **Front light:** on/off, brightness in %, color temperature from 2700 to 6500 K (the slider runs from cool to warm), and Cool / Neutral / Warm presets
- Shows the light's current state when it connects. The backlight color is the exception, because the light doesn't report it.
- The sun icon appears in the menu bar only while the light is connected.
- Turns both lights off when the Mac goes to sleep (for example when you close the lid) and turns them back on when it wakes
- Launches automatically at login
- Liquid Glass design, no Dock icon

## Requirements

- macOS 26 or later
- Swift 6.2 or later. The Xcode Command Line Tools are enough (`xcode-select --install`); you don't need Xcode.

## Build and run

```sh
./scripts/bundle.sh               # builds "build/Litra Beam LX.app"
open "build/Litra Beam LX.app"    # launches the app
```

To install it permanently, copy the app to `/Applications` and launch it once from there. Launch at login then points to that copy.

```sh
cp -R "build/Litra Beam LX.app" /Applications/
open "/Applications/Litra Beam LX.app"
```

While the light is disconnected, the app keeps running invisibly in the background. To quit it, run `pkill LitraApp`.

## Tests

```sh
swift test
```

## Project structure

| File | Purpose |
|---|---|
| `Sources/LitraCore/LitraProtocol.swift` | HID++ commands (bytes) and response parsing |
| `Sources/LitraApp/LitraDevice.swift` | Finds the light (USB `0xC903`, Bluetooth `0xB903`) and sends commands in the background |
| `Sources/LitraApp/LightState.swift` | Holds the light state, persists it, and keeps it in sync with the light |
| `Sources/LitraApp/MenuView.swift` | UI, including the color spectrum |
| `scripts/bundle.sh` | Builds the `.app` from the Swift package |
| `scripts/make-icon.swift` | Draws the app icon (the output is in `Resources/AppIcon.icns`) |

The protocol is taken from [litra-rs](https://github.com/timrogers/litra-rs).
