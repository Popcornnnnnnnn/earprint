# Earprint Widgets & Live Activity (Direction G)

Native WidgetKit extension (`EarprintWidgets`) + ActivityKit Live Activity and Dynamic Island for Earprint.

## What Is Included

### Home Screen Widgets
- **Today (`EarprintToday`, `.systemSmall`)**: Today's listening time, top/featured headphone mini holo card (tappable interactive card cycling via `NextCardIntent`), and safe-level dot with `dB(A)`.
- **Card Shelf (`EarprintCardShelf`, `.systemMedium`)**: Up to 3 collectible foil cards (`HOLO`, `GOLD`, `SILVER`, `BRONZE`) showing lifetime hours, plus this week's total and safe-level status. Each card deep-links directly to `earprint://card/<id>`.
- **Earprint Ring (`EarprintRing`, `.systemLarge`)**: 4-week radial Earprint glyph, 28-day loudness heatmap, per-headphone weekly bars, and the WHO weekly hearing budget bar.

### Lock Screen Widgets
- **Budget Gauge (`EarprintBudget`, `.accessoryCircular`)**: Weekly WHO hearing budget percentage gauge.
- **Today Summary (`EarprintToday`, `.accessoryRectangular`)**: Today's listening time and primary device.
- **Inline (`EarprintToday`, `.accessoryInline`)**: One-line summary (`1h 12m today · 38% budget`).

### Live Activity & Dynamic Island (`ListeningLiveActivity`)
- **Lock Screen banner**: Live elapsed timer, headphone name, `dB(A)` loudness band, and ear-break countdown bar.
- **Dynamic Island**: Compact icon + live timer, minimal badge, and expanded view with current level and break countdown.
- **Triggering**: Controlled today via debug buttons on the **Data probe** tab (`WidgetDebugSection` → `LiveActivityController`). Real-world automatic starts require foreground audio-route detection (`AVAudioSession.routeChangeNotification`), a Shortcuts/App Intent trigger, or ActivityKit push tokens.

## Data Flow

1. Shared App Group: `group.com.popcornnn.earprint` (`WidgetSnapshotStore`).
2. Shared Codable contract: `Shared/WidgetSnapshot.swift` (versioned JSON `widget-snapshot.json`).
   - Built today from sample data via `Earprint/Widgets/WidgetSnapshot+App.swift`.
   - Ready for the HealthKit pipeline (`HeadphoneLibrary`) to publish real snapshots via `WidgetSnapshotStore.save(_:)`. Identical snapshots (ignoring `generatedAt`) skip disk writes and timeline reloads.
3. Deep links (`EarprintLink`):
   - `earprint://card/<id>` → opens **Collection** tab and opens that card.
   - `earprint://collection` and `earprint://rings` switch tabs. `earprint://probe` opens Data Probe in Debug builds.
   - Handled in-app by `DeepLinkRouter`.

## Visual Previews

Generated renders live in `docs/widgets/`:
- `board-home-screen.png` (Small, Medium, Large)
- `board-lock-screen.png` (Dynamic Island, Lock Screen accessories, Live Activity)
- Individual widget & island states (`small-today.png`, `medium-card-shelf.png`, `large-earprint.png`, `island-compact.png`, `island-expanded.png`, `live-activity-lock-screen.png`, etc.)

## How to Test

```sh
xcodegen generate
xcodebuild -project Earprint.xcodeproj -scheme Earprint \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build-widgets build
```

1. Launch in simulator → open the **Data probe** tab → tap **Start Live Activity** (or change loudness) to verify Lock Screen & Dynamic Island.
2. Add Earprint widgets from the simulator Home Screen / Lock Screen widget gallery.
3. Test deep linking:
   ```sh
   xcrun simctl openurl booted "earprint://card/pro2"
   ```
