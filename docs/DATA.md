# Earprint HealthKit Data Pipeline

Earprint reads `HKQuantityType(.headphoneAudioExposure)` from Apple Health entirely on device. Nothing leaves the iPhone.

## Architecture

```
Apple Health (HKHealthStore)
  │  HKAnchoredObjectQueryDescriptor (25,000 samples / page)
  │  HKObserverQuery (live updates while running)
  ▼
HealthIngestor (Swift actor — off main thread)
  ├── ListeningAggregate (compact per-device running totals + 15-min slots)
  └── AggregateCache (Application Support/listening-aggregate.json + HKQueryAnchor)
  ▼
LibrarySnapshot (computed for `now` + `Calendar.current`)
  ├── DeviceSummary (lifetime, Leq, sessions, 28×24 grid, WHO weekly budget)
  ├── cards()       → [HeadphoneCard]    → CollectionView
  └── homeSummary() → ListeningSummary   → HomeView / ShareCardView
  ▲
HeadphoneLibrary (@MainActor ObservableObject)
  └── Hydrates from disk cache on init; falls back to SampleData with badge when empty/denied/simulator
```

The library combines known AirPods records that share a model and current Bluetooth nickname. It combines recorded listening time and merges overlapping or nearby sessions using the existing five-minute gap. The original accessory IDs remain in the on-device cache, and older card links resolve to the combined card.

### Source Files (`Earprint/Data/`)

| File | Responsibility |
| --- | --- |
| `DeviceDescriptor.swift` | Plain `Sendable` copy of `HKDevice`, stable `identityKey` across renames, host-device filter (`iPhone`, `Apple Watch`, `iPad`, `Mac`). |
| `HeadphoneModelCatalog.swift` | 34 Apple / Beats Bluetooth product IDs (`0x2002`–`0x2036`, cross-checked against 5 open-source tables) mapping to marketing names, SF Symbols, `HeadphoneModelKey`, and 3D `HeadphoneKind`. |
| `ListeningAggregate.swift` | Pure-Swift aggregation engine: `HearingBudget` (`Leq` + WHO dose), out-of-order `SessionSet` merging, local day counters, and 15-minute slot bucketing. |
| `LibrarySnapshot.swift` | Projects `ListeningAggregate` at a given `now` and `Calendar` into `DeviceSummary`, 28×24 `ListeningGrid`, `HeadphoneCard`, and `ListeningSummary`. |
| `HealthIngestor.swift` | Dedicated `actor` owning `HKHealthStore`, paged anchored sync, `HKObserverQuery`, and `AggregateCache`. |
| `HeadphoneLibrary.swift` | `@MainActor ObservableObject` bridging `HealthIngestor` into SwiftUI with instant cache hydration and a "Sample data" fallback. |
| `HealthKitSeeder.swift` | `#if DEBUG` simulator helper writing realistic multi-device samples into HealthKit so the full real-data pipeline can be verified locally. |

## Incremental Anchor & Why Sample Queries

We query raw `HKQuantitySample` objects via `HKAnchoredObjectQueryDescriptor` instead of `HKStatisticsCollectionQuery` because:

1. Statistics queries can group by *source* (app bundle ID), not by *device* (`HKDevice`), so they cannot separate AirPods Pro from AirPods Max or Beats.
2. Statistics queries cannot reconstruct listening sessions (count, average length, longest session).

To keep years of history fast and off the main thread:

- **First run**: pages through history in batches of `25,000` samples on the `HealthIngestor` actor, folding each batch directly into `ListeningAggregate` so raw samples are never retained in memory.
- **Subsequent runs**: passes the saved `HKQueryAnchor` and ingests only newly added samples.
- **Live updates**: an `HKObserverQuery` triggers silent incremental syncs while the app is open.
- **Deletions**: because running totals cannot accurately subtract a deleted sample (especially from merged sessions), receiving any `deletedObjects` on an incremental sync discards the working aggregate and rebuilds from `anchor = nil`. Deletions of system-logged audio exposure samples are rare.

## On-Disk Cache & Privacy

- Stored at `<Application Support>/listening-aggregate.json` with `.atomic` and `.completeFileProtectionUntilFirstUserAuthentication` (encrypted at rest when locked before first unlock).
- Persists `ListeningAggregate` alongside the `NSKeyedArchiver`-encoded `HKQueryAnchor` in a single atomic file.
- **Integrity guards**:
  - `schemaVersion` mismatch invalidates the cache and triggers a clean rebuild.
  - If an encoded anchor exists in the file but fails to unarchive, both aggregate and anchor are dropped to prevent double-counting on the next sync.
- **Slot retention**: 15-minute slots older than 35 days are pruned on ingest (the Earprint glyph needs 28 local days). Lifetime totals, active day counts, and session stats remain complete across the entire history.
- **Read-only Release builds**: Release builds compile out `HealthKitSeeder.swift`, link zero HealthKit write/save/delete APIs, and only ever call `requestAuthorization(toShare: [], read:)` with an empty share set. `NSHealthUpdateUsageDescription` is included in `Info.plist` solely because App Store Connect's static validation (`ITMS-90683`) requires it whenever `requestAuthorization(toShare:read:)` is linked.

## Device Identity & Model Mapping

- `HKDevice.localIdentifier` (often suffixed with `-tacl`) stays stable when a user renames their headphones. Stripping `-tacl` and keying on `localIdentifier` merges history under the latest nickname while preserving previous nicknames in `otherNames`.
- `HKDevice.model` holds Apple's Bluetooth product ID as hex text (e.g. `0x2024` → *AirPods Pro 2 · USB-C*). Unknown Apple PIDs keep the hex ID visible; third-party devices fall back to over-ear vs. in-ear heuristics.
- Samples whose device is the host iPhone, iPad, Mac, or Apple Watch (e.g. third-party apps writing with `HKDevice.local()`) are counted in `hostSamples` and excluded from headphone cards.

## Math & Time-Zone Bucketing

- **Energy-averaged dB (`Leq`)**: levels are never arithmetically averaged. Each sample contributes sound energy $E = 10^{L/10} \cdot t$, and any range's average level is $L_{\text{eq}} = 10 \log_{10}(\sum E / \sum t)$.
- **WHO weekly hearing budget**: based on WHO/ITU H.870 (80 dB(A) for 40 hours/week = 100%). Using the exact equal-energy exchange rate ($10\log_{10}2 \approx 3.01\text{ dB}$ halves allowed time), weekly dose is $\sum E_{\text{last 7 local days}} / (10^{80/10} \cdot 40 \cdot 3600)$.
- **28-day × 24-hour grid**: recent samples are split into wall-clock-independent 15-minute UTC slots (`epoch / 900`). Because every real-world UTC offset (including `+05:30`, `+05:45`) is a multiple of 15 minutes, slots project cleanly onto local days and hours in `Calendar.current`:
  - **Midnight crossings** split cleanly across consecutive days and increment `activeDays` for both days.
  - **Spring-forward DST**: the skipped local hour stays empty (`0`), and subsequent day indices stay aligned.
  - **Fall-back DST**: both occurrences of the repeated local hour accumulate into that hour cell with a single energy-averaged `Leq`.

## Accuracy Limits & Known Caveats

1. **iOS only logs while audio plays.** Apple Health records `headphoneAudioExposure` only during active audio playback (music, podcasts, calls, video). Wearing AirPods in silence with ANC or Transparency enabled generates no HealthKit samples and cannot be measured by any third-party iOS app.
2. **Session merging is an estimate.** iOS writes irregular exposure clips (from a few seconds to ~30 minutes) rather than explicit "put headphones on / took off" events. Earprint merges clips separated by `≤ 5 minutes` into one wearing session. Short pauses between tracks merge; a 6-minute silent break splits into two sessions. Active listening duration sums only sample durations, while session span includes the short in-session gaps.
3. **Read-denial looks identical to empty data.** By design, Apple Health never tells apps whether the user denied read permission; denied access simply returns 0 samples. Earprint falls back to sample data with a clear badge and instructs the user where to enable access (`Settings › Health › Data Access › Earprint`).
4. **Loudness accuracy varies by headphone.** Apple/Beats headphones are calibrated by iOS; third-party Bluetooth headphones may be uncalibrated or estimated unless classified accurately in iOS Bluetooth settings.
5. **Defensive clipping.** Individual samples longer than 6 hours are clipped to 6 hours (and counted in `clippedSamples`) so a malformed third-party writer cannot corrupt daily or weekly totals. Negative durations, `NaN`, or dB values outside `0...160` are discarded (`invalidSamples`).

## Testing & Simulator Seeding

- **Unit tests (`EarprintTests`)**: fast, HealthKit-daemon-free tests covering session merging, `Leq`, WHO budget, 28×24 grid bucketing (midnight, spring-forward/fall-back DST, `Asia/Kolkata` +05:30), device-ID catalog, rename merging, host filtering, cache persistence, and `HKQuantitySample` seeder round-trip:
  ```sh
  xcodegen generate
  xcodebuild test -project Earprint.xcodeproj -scheme Earprint \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build-data
  ```
- **Simulator HealthKit Seeder (Debug only)**:
  - Open the **Data probe** tab and tap **Seed simulator Health data** (or launch with `-seedHealth`).
  - Tap **Turn On All** → **Allow** on the iOS Health Access sheet to write ~3 months of realistic multi-device samples (AirPods Pro 2 USB-C with an earlier nickname merged via `localIdentifier`, AirPods Max USB-C, Beats Fit Pro, plus host-device noise samples) directly into the simulator's Health store.
  - Tap **Clear seeded Health data** to remove only samples tagged with `com.popcornnn.earprint.seeded`.
