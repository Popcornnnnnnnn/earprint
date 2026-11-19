# Earprint (codename)

An iPhone app that turns your AirPods and headphone listening history from Apple Health into collectible 3D holo trading cards, a collector-grade Device Dossier, native widgets, and Live Activities.

**UI and UX come first.** Direction: **C (Headphone Collection with interactive 3D cards) + G (Native Widgets & Live Activity)**, plus a PSA-style **Device Dossier** for deep metadata and **iPhone Duo** foldable adaptation.

## What Is Built

- **3D Collectible Cards (`Earprint/Collection/`, `Earprint/ThreeD/`):**
  - Rarity tiers by lifetime listening hours: `BRONZE` → `SILVER` → `GOLD` → `HOLO · LEGENDARY`.
  - Real-time RealityKit 3D models (`AirPods4.usdz`, `AirPodsMax.usdz`, `AirPodsPro.usdz`, `HeadphoneGeneric.usdz`, plus procedural fallback) floating above the card surface: drag to spin with momentum, pinch to zoom, long-press to twirl with haptics, tilt the phone for foil shine and parallax, and tap the card or swipe across its surface outside the 3D model to flip to its stats. Swipe below to browse the deck.
  - Each card shows its exact model name. The Collection shows equipment without charging cases. The collection number and its meaning are in the Dossier certificate.
  - See [docs/ASSETS.md](docs/ASSETS.md) for CC-BY 4.0 attributions and trademark notes.
- **Device Dossier (`Earprint/Dossier/`):**
  - Flip a card and tap **Dossier** on the reverse to open its PSA-style acrylic grading slab (`EAR GRADE` from hearing safety), period switcher (`Week` / `Month` / `Year` / `All`), interactive 30-day scrub bar chart, 24-hour peak clock, 6-tile habits & hearing bento, lifetime ledger, milestone timeline, and guilloché hardware certificate (`Apple Inc. · 0x2024`, firmware, sample count, history range).
  - See [docs/DOSSIER.md](docs/DOSSIER.md).
- **HealthKit Data Pipeline (`Earprint/Data/`, `EarprintTests/`):**
  - Incremental anchored sync of `HKQuantityType(.headphoneAudioExposure)` off the main actor, disk cache for instant startup, `HKObserverQuery` live updates, 34-device Apple Bluetooth product ID catalog, rename merging via `localIdentifier`, WHO weekly hearing budget, and 28×24 local-time/DST grid bucketing.
  - Debug-only simulator seeder (`-seedHealth`); Release builds stay strictly read-only.
  - See [docs/DATA.md](docs/DATA.md).
- **Widgets & Live Activity (`EarprintWidgets/`, `Shared/`, `Earprint/Widgets/`):**
  - Home Screen widgets (Small Today, Medium Card Shelf with `earprint://card/<id>` deep links, Large Earprint Ring + heatmap + WHO budget), Lock Screen accessories, Dynamic Island, and "Listening now" Live Activity.
  - See [docs/WIDGETS.md](docs/WIDGETS.md).
- **iPhone Duo Foldable Adaptation (`Earprint/Design/AdaptiveLayout.swift`):**
  - Adaptive grids (even column counts clear of the hinge), 4-mode `CardDetail` (single, beside controls, side-by-side front + back on inner/book display, tabletop fold-stacked), two-column Rings screen, and native App Store screenshot verification across outer/inner/book/tabletop postures.
  - See [docs/IPHONE_DUO.md](docs/IPHONE_DUO.md).

## Stage 1 Completion Criteria

1. Verify the HealthKit pipeline and listening experience on a real iPhone. Follow [physical device acceptance](https://github.com/Popcornnnnnnnn/earprint/issues/2) for progress.
2. Collectible 3D cards, Device Dossier, Widgets & Live Activity, and iPhone Duo layouts built and visually verified in simulators.
3. Connect full per-session HealthKit history into `DeviceDossier` (currently hydrates card totals and uses deterministic sample sessions when in sample mode) and add bilingual Chinese + English localization (String Catalog).
4. Ship TestFlight build and daily-drive for one week.

## Current Status (2026-11-19)

- **Done:** All 5 core tracks integrated, 21/21 unit tests passing, Debug + Release simulator builds passing, verified on iPhone 17 Pro and iPhone Duo simulators.
- **Device testing:** Signed Release builds install and launch on iPhone 17. See [physical device acceptance](https://github.com/Popcornnnnnnnn/earprint/issues/2) for the remaining checks.

## Build & Test

```sh
xcodegen generate

# Unit tests (21 tests, < 1s)
xcodebuild test -project Earprint.xcodeproj -scheme Earprint \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build

# Release build check (verifies read-only HealthKit Info.plist)
xcodebuild build -project Earprint.xcodeproj -scheme Earprint \
  -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build
```

Useful launch arguments: `-demo`, `-demoIndex <n>`, `-cardDetail`, `-dossier`, `-dossierDemo`, `-rings`, `-showShare`, `-tab <collection|rings|probe>`, `-seedHealth` (Debug), `-startLiveActivity`.

Use the gear in Collection to choose the app icon and switch between English and Simplified Chinese. The controls below the detail card handle previous and next navigation. See [supported headphone artwork](docs/ASSETS.md#collectible-support).

In Debug builds, press and hold the Collection gear, then choose **Developer Tools** and **Data Probe**. `-tab probe` opens the same screen directly.
