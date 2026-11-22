# App Store Launch & Compliance Checklist — Earprint (`v1.0.0`)

Master launch checklist for **Earprint** (`com.popcornnn.earprint` / `EarprintWidgets` `com.popcornnn.earprint.widgets` / App Group `group.com.popcornnn.earprint`).

Tracked alongside Stage 1 Completion Criteria in [README.md](../../README.md) and physical device verification in [GitHub Issue #2](https://github.com/Popcornnnnnnnn/earprint/issues/2).

---

## 1. Do Now (In Parallel with UI Polish)

Work that does not depend on final Rings layout pixels and should start immediately:

- [x] **Add In-App CC-BY 4.0 Credits / Attributions Screen in Settings** *(see §4b below)*
  - Shipped in `v1.0.0-rc1`: `CreditsView` (`Settings → Credits & Attributions`) in `Earprint/Design/AppIconPickerView.swift` crediting all 4 Sketchfab models plus the Apple non-affiliation & non-medical disclaimers.
- [x] **Wire Real HealthKit Per-Session History into `DeviceDossierView`** *(README Stage 1 #3)*
  - Shipped in `v1.0.0-rc1`: `ListeningAggregate.schemaVersion = 2` persists per-span `listeningSeconds` / `energy` / `peakDecibels` and `LibrarySnapshot.dossier(forCardID:)` hydrates `DeviceDossierView` directly.
- [x] **Fix Release Empty / Denied HealthKit UX Consistency** *(see §4c below)*
  - Shipped in `v1.0.0-rc1`: `HeadphoneLibrary.isShowingEmptyState` drives consistent zero-data empty states on both Collection and Rings (`HomeView.emptyRingsState`, `CollectionView.emptyCollectionState`, and zero-data `EarprintWidgets` snapshots).
- [x] **Decide Release Trigger for `ListeningLiveActivity`**
  - Decided for `v1.0.0`: removed `NSSupportsLiveActivities` and `ListeningLiveActivity()` from `EarprintWidgetsBundle.swift` and aligned metadata to widgets-only (`Earprint` Home & Lock Screen widgets).
- [x] **Prepare Trademark Fallback Plan & Primary Icon Audit** *(see §4a below)*
  - Shipped in `v1.0.0-rc1`: switched primary `AppIcon.appiconset` (`Light`, `Dark`, `Tinted`) to a custom trademark-safe concentric **Earprint Rings Emblem**, moved old AirPods Max icon to optional `AppIconMidnightAuto`, and kept `ProceduralHeadphones` verified as a fallback.
- [x] **Stand Up Privacy Policy & Support URL Hosting** *(see §4d below)*
  - Live `HTTP 200` static bilingual HTML pages served from `docs/site/` via `.github/workflows/pages.yml` at `https://popcornnnnnnnn.github.io/earprint/`, `/privacy.html`, and `/support.html`.
- [x] **Add `ITSAppUsesNonExemptEncryption = NO` to `project.yml` / `Info.plist`**
  - Shipped in `v1.0.0-rc1` (`project.yml` & `Earprint/Info.plist`) plus `PrivacyInfo.xcprivacy` for both app and widget targets.
- [x] **Reserve App Record in App Store Connect**
  - Created `Earprint - Headphone Archive` (`Apple ID: 6837883616`, bundle ID `com.popcornnn.earprint`) under team `R26X7B8XDT` with App Group `group.com.popcornnn.earprint` + HealthKit capability.

---

## 2. After Rings UI Locks (Screenshots & Preview Video)

Capture marketing assets only after `@rings-ui` finalizes `Theme.swift`, `EarprintGlyph.swift`, `HomeView.swift`, and `ShareCardView.swift`:

- [x] **Generate Clean Release-Styled Screenshots (6.1"/6.3" & 6.9" iPhone)**
  - Captured and uploaded 40 screenshots (`10 en-US` + `10 zh-Hans` across both required `1206 × 2622` and optional `1320 × 2868` Dynamic Island slots).
  - **Hygiene check:** Stripped `"Sample data · Simulator"` debug banners and forced `9:41` / 100% battery status bar via `xcrun simctl status_bar`.
- [ ] **Record App Preview Video (15–30s, Portrait 6.9")** *(recommended for 3D motion)*
  - Physical iPhone or clean capture showing: real-time phone tilt shimmering holographic foil → dragging & pinching 3D RealityKit AirPods → tapping to flip card → scrolling PSA Device Dossier slab & scrubbing 30-day bars → Rings tab 28-day chronometer.
  - Keep within Apple App Preview specs (H.264/ProRes, 15–30s, no device mockups/hands outside screen bounds, clear non-sample UI).
- [ ] **Record Unedited App Review Demo Video**
  - Capture a 30–60s unedited physical iPhone video showing Apple Health permission flow, real `headphoneAudioExposure` sync, 3D card interaction, Dossier, and widgets to attach inside App Store Connect Review Notes if the reviewer tests on an iPhone with 0 Health samples.

---

## 3. Pre-Submit Blockers (Hard Gates Before Submitting `v1.0.0`)

Do **not** submit to App Store Review until every blocker below is green:

1. [x] **CC-BY 4.0 In-App Credits screen live in Release** (`Settings → Credits & Attributions` for all 4 Sketchfab models + `AirPods4Credits.txt`).
2. [x] **Real `DeviceDossier` data wired** (no synthetic sample sessions inside real cards' Dossiers).
3. [x] **Clean Release empty/denied HealthKit UX** across `Collection`, `Rings`, and `EarprintWidgets`.
4. [x] **Release `Info.plist` & binary verified read-only** (`HealthKitSeeder.swift` compiled out, zero HealthKit save/write symbols linked via `nm -u`, strictly `toShare: []`, and truthful read-only `NSHealthShareUsageDescription` + `NSHealthUpdateUsageDescription` included for `ITMS-90683`).
5. [x] **`project.yml` bumped to `MARKETING_VERSION: "1.0.0"`**, `CURRENT_PROJECT_VERSION: "1"`, `xcodegen generate` re-run, and Release candidate tagged on clean SHA `v1.0.0-rc1` (re-tag final App Store release SHA if updated before archive).
6. [ ] **1-week real-device daily-drive & TestFlight external beta pass completed** ([Issue #2](https://github.com/Popcornnnnnnnn/earprint/issues/2) closed/verified).
7. [x] **App Store Connect Privacy Nutrition Label (`Data Not Collected`)**, **Support URL**, and **Privacy Policy URL** live (`HTTP 200`, HTTPS, no auth wall) and matching [APP_STORE_METADATA.md](APP_STORE_METADATA.md) + [PRIVACY_POLICY.md](PRIVACY_POLICY.md).
8. [ ] **Unit tests (`EarprintTests`, 21+ tests) + Release build + physical iPhone smoke test** passing on the exact release commit.

---

## 4. Deep Dive: Blockers & Compliance Reference

### (a) Apple Trademark & Trade-Dress Risk Assessment (`docs/ASSETS.md`)

#### Assets at Risk
1. **3D USDZ Models (`Earprint/Resources/Models/`):** `AirPods4.usdz`, `AirPodsMax.usdz`, `AirPodsPro.usdz`, `HeadphoneGeneric.usdz`.
2. **2D Card Renders & Icon Cutouts (`Earprint/Assets.xcassets/`):** `CardRenderAirPods4` (cropped/masked from Falah3D's render), `CardRenderAirPodsMax`, `CardRenderAirPodsOpen`, `CardRenderAirPodsPro`, `CardRenderAirPodsProCase`, `CardRenderBeatsFit*`, and the 10 `IconCutout*` silhouettes used in `AppIcon` + 39 alternate `AppIcon*` sets (`project.yml`).
3. **Strings & Identifiers (`HeadphoneModelCatalog.swift`, `AppIconPickerView.swift`):** `AirPods`, `AirPods Pro`, `AirPods Max`, `Beats`, `Powerbeats`, `Apple Health`.

#### Legal / App Review Nuance (from `docs/ASSETS.md`)
- Sketchfab's **CC-BY 4.0** license grants copyright permission for the 3D creators' geometry and textures, **not** trademark or industrial design / trade-dress rights owned by **Apple Inc.**
- **App Review Guidelines involved:**
  - **Guideline 5.2.1 (Generally / Intellectual Property):** Apps may not use protected third-party trademarks, product silhouettes, or hardware imagery in ways that imply Apple endorsement or misappropriate Apple trade dress—**especially in the primary App Icon and App Title**.
  - **Guideline 4.1 (Copycats):** Apps must not mimic Apple system apps or official Apple hardware branding.
  - **Guideline 2.3.8 (Metadata):** App name, subtitle, and icon must accurately reflect an independent utility rather than posing as an official Apple accessory app.

#### Concrete Mitigation Paths
- **Mitigation 1 — Non-Affiliation Notice & Naming Hygiene (Required):**
  - Keep `"AirPods"` / `"Apple"` out of the primary App Name (`Earprint`) and Subtitle (`3D Audio Cards & WHO Rings`).
  - Include explicit non-affiliation text in `Settings → Credits`, the bottom of the App Store Description, and the Support/Privacy pages: *"Earprint is an independent app and is not affiliated with, sponsored by, or endorsed by Apple Inc."*
- **Mitigation 2 — Primary App Icon Review (Low-Effort Preventive):**
  - The primary `AppIcon` (`IconCutoutMidnight` over auto dark/light background) depicts a recognizable AirPods Max silhouette. If Risk Tolerance is conservative, swap the primary `AppIcon` to an abstract **Earprint concentric ring / holo card emblem** before initial submission, keeping stylized generic headphone shapes or alternate icons optional inside Settings.
- **Mitigation 3 — Turnkey Fallback if Rejected under Guideline 4.1 / 5.2.1:**
  - `Earprint/ThreeD/HeadphoneModel.swift` already implements `ProceduralHeadphones` (`overEar`, `earbuds` with/without case), documented in source as: *"Original, trademark-safe headphone models built from code. Used until (or instead of) USDZ assets."*
  - If Apple Review rejects specific bundled `.usdz` files or `CardRender*` PNGs:
    1. **Immediate 3D switch:** Remove the flagged `.usdz` file(s) from `Earprint/Resources/Models/`. `HeadphoneModel.load(...)` automatically detects `Bundle.main.url(forResource:withExtension: "usdz") == nil` and falls back to `ProceduralHeadphones.make(...)` with zero code breakage.
    2. **Immediate 2D switch:** Replace `CardRender*` / `IconCutout*` assets in `HeadphoneModelKey.collectibleArtwork` / `collectionArtwork` (`Earprint/Data/HeadphoneModelCatalog.swift`) with abstract procedural silhouettes or SF Symbols (`airpodspro` / `headphones` / stylized vector cards) and swap `AppIcon*` to abstract Earprint ring icons.
    3. **Longer-term upgrade:** Commission bespoke stylized low-poly / wireframe / geometric 3D headphone sculptures with distinct visual language while retaining the real Apple Bluetooth PID lookup (`0x2002`–`0x2036`) for accurate device naming.

---

### (b) Required CC-BY 4.0 In-App Credits / Attributions Screen

Under [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/) Section 3(a), distributed applications must provide reasonable attribution (creator name, title, URI/URL, license link, and indication of modifications). Currently, `Earprint/Resources/AirPods4Credits.txt` covers only `AirPods4.usdz`, and `SettingsView` (`Earprint/Design/AppIconPickerView.swift`) has no Credits destination.

Add **`Credits & Attributions`** (`版权声明与致谢`) to `SettingsView` displaying all four bundled models verified against `docs/ASSETS.md`:

| Asset | Source Title | Author | Source URL | License & Notes |
| --- | --- | --- | --- | --- |
| `AirPods4.usdz` (+ front render) | *AirPods 4* | **Falah3D (`3dFalah`)** (`https://sketchfab.com/3dFalah`) | `https://sketchfab.com/3d-models/airpods-4-e44730974131402eb496352cab19c82e` | [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/). Modified: cropped front render; decimated open-pose FBX (99,248 → 44,967 tris), joined meshes, normalized, compressed textures, converted to USDZ. Provenance also noted in `AirPods4Credits.txt` via Andrea Balbo (`clawd-airpods4-anc-case`). |
| `AirPodsMax.usdz` | *Airpods max sky blue* | **polyman Studio (`Polyman_3D`)** (`https://sketchfab.com/Polyman_3D`) | `https://sketchfab.com/3d-models/airpods-max-sky-blue-3d0643db08fc4ef89bda55a74077ece4` | [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/). Modified: decimated (87,701 → 41,968 tris), joined meshes (137 → 20), normalized, baked PBR factors, dropped emissive maps, compressed textures, added headband canopy `opacityThreshold`, converted to USDZ. |
| `AirPodsPro.usdz` | *Airpods Pro With Magsafe Charging Case Ios15* | **polyman Studio (`Polyman_3D`)** (`https://sketchfab.com/Polyman_3D`) | `https://sketchfab.com/3d-models/airpods-pro-with-magsafe-charging-case-ios15-52e5f28b37f94f05b6c0768773137689` | [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/). Modified: removed internal occlusion shell, decimated (96,992 → 47,975 tris), joined meshes (48 → 14), normalized, baked `metallicFactor = 0`, dropped emissive maps, JPEG-compressed textures, converted to USDZ. |
| `HeadphoneGeneric.usdz` | *Studio Headphones* | **crow (`crow.bite`)** (`https://sketchfab.com/crow.bite`) | `https://sketchfab.com/3d-models/studio-headphones-2f04830fbf884632a89445db0d170ba8` | [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/). Modified: decimated (64,544 → 51,995 tris), joined 6 parts into 1 mesh, normalized, baked roughness map, downscaled to 2048 px JPEG, converted to USDZ. |

> **Tip:** If any `.usdz` is later removed under §4a Mitigation 3, remove its corresponding attribution row from Credits as well (keeping credits accurate to what actually ships).

---

### (c) HealthKit Guideline 5.1.3 Compliance & Empty/Denied UX

1. **Read-Only `Info.plist` & Entitlements Verification:**
   - `Earprint/Info.plist`, `project.yml`, and `InfoPlist.xcstrings` define `NSHealthShareUsageDescription`:
     > `"Earprint reads your headphone audio levels from Apple Health to show how long and how loudly you listen. Data stays on your iPhone."`
   - Because Apple's App Store Connect static analyzer (`ITMS-90683`) rejects binaries linking `HKHealthStore.requestAuthorization(toShare:read:)` without `NSHealthUpdateUsageDescription` (even with `toShare: []`), `project.yml` & `InfoPlist.xcstrings` also include a truthful read-only `NSHealthUpdateUsageDescription` explaining that Earprint never writes data to Apple Health, while `Earprint/Data/HealthKitSeeder.swift` remains wrapped in `#if DEBUG`.
   - **Required pre-submit shell check** on the built Release `.app` inside the `.xcarchive`:
     ```sh
     plutil -p Earprint.app/Info.plist | grep -E "NSHealth|ITSAppUsesNonExemptEncryption"
     nm -u Earprint.app/Earprint | grep -iE "Health|HK.*save|HK.*delete|HK.*write"
     ```
     Confirm both `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` + `ITSAppUsesNonExemptEncryption => 0` are present, and `nm -u` links zero HealthKit write/save/delete APIs.
2. **Guideline 5.1.3 HealthKit Policy Checks:**
   - Never share HealthKit data with third parties, advertisers, or data brokers (verified: zero network calls, zero analytics SDKs).
   - Never store HealthKit data in iCloud or unencrypted backups without user consent (verified: `<Application Support>/listening-aggregate.json` uses `.completeFileProtectionUntilFirstUserAuthentication`).
   - Clearly frame Earprint as informational/wellness visualization (WHO/ITU H.870 80 dB(A) 40h/week reference), **not** a medical device.
3. **Empty / Denied HealthKit UX Audit (Current Code Findings):**
   - **Issue 1 (`HeadphoneLibrary.swift` lines 63–79):** In `#else` (Release), `cards` returns `[]` when `snapshot == nil`, while `homeSummary` still falls back to `SampleData.summary` (`188h 22m`, `"🧸's AirPods Pro"`). A clean device or denied permission therefore sees an empty Collection tab alongside a populated Rings tab showing `SampleDataBanner`.
     - **Fix:** In Release builds, show a cohesive empty/onboarding state on **both** Collection and Rings when `snapshot == nil || snapshot.isEmpty`—with a clear `"Sync Apple Health"` CTA, recovery instructions (`Settings › Health › Data Access › Earprint`), and (optionally) an explicit `"Load Demo Preview"` button so fake data never appears unexpectedly.
   - **Issue 2 (`CollectionView.swift` line 106 & `DeviceDossierView.swift` line 31):** Ensure `CollectionView` constructs and passes a real `DeviceDossier` hydrated from HealthKit `WearSession` history instead of defaulting to `DeviceDossier.sample(for: card)`.
   - **Issue 3 (`EarprintWidgets`):** Verify `WidgetSnapshot` writes an authentic zero-data state when `snapshot == nil` in Release rather than calling `WidgetPublisher.publishSample()`.

---

### (d) Version Bump, App Store Connect Nutrition Label & URL Hosting

1. **Version Bump in `project.yml`:**
   - Update `MARKETING_VERSION: "0.1.0"` → `"1.0.0"` (line 12 of `project.yml`).
   - Increment `CURRENT_PROJECT_VERSION` (`"1"` → `"2"` or current TestFlight build number, line 13 of `project.yml`).
   - Add under `targets.Earprint.info.properties` (or `settings.base`):
     `ITSAppUsesNonExemptEncryption: false`
   - Run `xcodegen generate`, run `EarprintTests` + Release build, commit with empty `git status --porcelain`, and tag the release candidate commit.
2. **App Store Connect Privacy Nutrition Label:**
   - Under **App Store Connect → App Privacy**, answer **"No, we do not collect data from this app"** → displays **Data Not Collected**.
   - Re-verify before every future release: if crash reporting, telemetry, or server-backed ActivityKit push tokens are ever added, the Nutrition Label and `PRIVACY_POLICY.md` must be updated first.
3. **Support URL & Privacy Policy URL Hosting:**
   - Both URLs are mandatory in App Store Connect (Privacy Policy URL is also required for HealthKit TestFlight External Beta Review).
   - **Zero-cost hosting option:** Enable GitHub Pages on `Popcornnnnnnnn/earprint` serving clean static HTML pages generated from [PRIVACY_POLICY.md](PRIVACY_POLICY.md) and a bilingual Support page (`support.html` covering Health permission instructions, why silent ANC wear without audio playback isn't logged by iOS, supported headphones, and contact email).
   - Verify both URLs return `HTTP 200`, work cleanly in Safari on iOS without login walls, and match the App Store Connect listing languages (`en-US` and `zh-Hans`).

---

### (e) TestFlight External Beta Review & 1-Week Real-Device Daily-Drive Checklist

Follows `README.md` Stage 1 #4 and [GitHub Issue #2](https://github.com/Popcornnnnnnnn/earprint/issues/2).

#### TestFlight External Beta Setup
- [ ] Upload Release archive (`scheme: Earprint`, configuration `Release`) via Xcode Organizer / `xcodebuild -exportArchive`.
- [ ] Verify build clears Export Compliance automatically (`ITSAppUsesNonExemptEncryption = NO`).
- [ ] Fill out **TestFlight → Beta App Information**: Beta App Description (EN + ZH-Hans), Feedback Email, Privacy Policy URL, and Beta Review Notes (same clean-device explanation as [APP_STORE_METADATA.md](APP_STORE_METADATA.md#4-app-review-notes-copy-into-app-store-connect--app-review-information)).
- [ ] Pass Apple's initial TestFlight Beta App Review (typically required once per `1.0.0` minor train before external testers can install).

#### 1-Week Physical Device Daily-Drive Matrix (7 Consecutive Days)
Run on primary iPhone (`iOS 18+`) + real AirPods / Beats / third-party Bluetooth headphones:

- [ ] **Day 1 — Cold Install & HealthKit Ingestion:**
  - Fresh install from TestFlight (no prior cache). Confirm HealthKit permission sheet lists **read-only** `Headphone Audio Levels` (zero write toggles).
  - Verify initial multi-year `HKAnchoredObjectQueryDescriptor` paged sync completes without UI freeze or excessive memory spike; check `<Application Support>/listening-aggregate.json` persists across force-quit and cold relaunches.
- [ ] **Day 2 — Device Identity & PID Accuracy:**
  - Pair at least 2 headphones (e.g., AirPods Pro + AirPods Max or Beats/third-party). Confirm `HeadphoneModelCatalog` resolves exact marketing names and no unexpected `0x20XX` unknown hex IDs appear for current Apple/Beats hardware.
  - Test Bluetooth rename in iOS Settings → Bluetooth: confirm `localIdentifier` merges old + new nicknames cleanly without splitting cards (`otherNames` preserved).
- [ ] **Day 3 — Accuracy Cross-Check vs Apple Health:**
  - Compare Earprint's daily/weekly listening minutes and `Leq` dB(A) against **Apple Health → Hearing → Headphone Audio Levels** across 3 consecutive days (including a midnight-crossing session if possible).
  - Confirm `HKObserverQuery` updates listening totals automatically after taking headphones off and reopening the app.
- [ ] **Day 4 — Real Dossier & Export Stress Test:**
  - Open `DeviceDossierView` for your top card: verify `Week / Month / Year / All` switching, 30-day scrub chart haptics, 24h `DayClock`, `HabitsBento`, `EarGrade` penalties, and `CertificateLabel` metadata match real `HKDevice` / `HKSource` values.
  - Export **Simple (1-page)** and **Long (4-page)** PNG posters via `DossierShareSheet` (`1200 × 1680 px` each) and share a 9:16 `ShareCardView` image; verify crisp rendering in Photos / Rednote / WeChat.
- [ ] **Day 5 — 3D Thermal, Gesture & Accessibility Check:**
  - Spin, pinch-zoom, long-press twirl, flip, and switch colors (AirPods Max / Beats) on `CardDetail` for 2–3 minutes; confirm smooth frame rate, no thermal throttling, and tilt motion pauses cleanly when Reduce Motion is enabled or sheets are open.
- [ ] **Day 6 — Widgets, Deep Links & Custom Icons:**
  - Place **Small Today** (tap interactive `NextCardIntent`), **Medium Card Shelf** (tap a card to test `earprint://card/<id>` cold-start deep link), **Large Earprint Ring**, and Lock Screen **Budget Gauge** + **Today Summary**.
  - Test switching App Icons in `Settings → App Icon` (`Auto / Light / Dark / Holo` × AirPods Max finishes) and verify no icon-change failures.
- [ ] **Day 7 — Bilingual Localization & Clean-Device Regression:**
  - Switch `Settings → Language` between **English** and **简体中文**; inspect every tab, `CardTiersView`, `ModelGalleryView`, `SettingsView`, `Credits`, `Dossier`, and `ShareSheet` for clipped labels or untranslated keys.
  - Test on a **clean secondary device** (or after denying HealthKit permission) to confirm zero crashes, zero misleading sample data, and clear recovery instructions before pressing **Submit for Review**.
