# Litra Beam LX

Native macOS-Menüleisten-App zur Steuerung der **Logitech Litra Beam LX**, per Bluetooth oder USB.

## Was die App kann

- **Backlight (RGB):** an/aus, Helligkeit in %, Farbe über ein Farbspektrum, das sich neben dem Menü öffnet
- **Frontlicht:** an/aus, Helligkeit in %, Farbtemperatur 2700–6500 K (Slider von kalt nach warm) und Presets Cool / Neutral / Warm
- Zeigt beim Verbinden den aktuellen Zustand der Lampe an. Ausnahme ist die Backlight-Farbe, weil die Lampe sie nicht meldet.
- Das Sonnen-Icon in der Menüleiste erscheint nur, wenn die Lampe verbunden ist.
- Schaltet beide Lichter aus, wenn der Mac in den Ruhezustand geht (z. B. beim Zuklappen), und nach dem Aufwachen wieder ein
- Startet automatisch beim Login
- Liquid-Glass-Design, kein Dock-Icon

## Voraussetzungen

- macOS 26 oder neuer
- Swift 6.2 oder neuer. Die Xcode Command Line Tools reichen (`xcode-select --install`), Xcode ist nicht nötig.

## Bauen und starten

```sh
./scripts/bundle.sh               # baut "build/Litra Beam LX.app"
open "build/Litra Beam LX.app"    # startet die App
```

Zum dauerhaften Installieren kopierst du die App nach `/Applications` und startest sie einmal von dort. Der Autostart beim Login zeigt dann auf diese Kopie.

```sh
cp -R "build/Litra Beam LX.app" /Applications/
open "/Applications/Litra Beam LX.app"
```

Ist die Lampe nicht verbunden, läuft die App unsichtbar im Hintergrund. Beenden kannst du sie dann mit `pkill LitraApp`.

## Tests

```sh
swift test
```

## Aufbau

| Datei | Aufgabe |
|---|---|
| `Sources/LitraCore/LitraProtocol.swift` | HID++-Befehle (Bytes) und Auswertung der Antworten |
| `Sources/LitraApp/LitraDevice.swift` | Findet die Lampe (USB `0xC903`, Bluetooth `0xB903`) und sendet im Hintergrund |
| `Sources/LitraApp/LightState.swift` | Zustand der Lichter, speichert ihn und synchronisiert ihn mit der Lampe |
| `Sources/LitraApp/MenuView.swift` | Oberfläche inkl. Farbspektrum |
| `scripts/bundle.sh` | Baut aus dem Swift Package die `.app` |
| `scripts/make-icon.swift` | Zeichnet das App-Icon (Ergebnis liegt in `Resources/AppIcon.icns`) |

Das Protokoll stammt aus [litra-rs](https://github.com/timrogers/litra-rs).
