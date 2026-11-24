# App Store Release Checklist for Earprint v1.1.0 (build 10)

App `com.popcornnn.earprint` · widget extension `com.popcornnn.earprint.widgets` · App Group `group.com.popcornnn.earprint`.

Earprint v1.1.0 ships **100% free with zero In-App Purchases** so early collectors can unlock every feature immediately without friction.

## v1.1.0 (build 10) release gates

### App Store Connect

- [ ] Confirm Earprint v1.1.0 pricing is set to **Free** with **zero attached In-App Purchases**.
- [ ] Add the four localized listings and screenshots (`en-US`, `zh-Hans`, `ja`, and `ko`). Keep App Name and Subtitle free of third-party headphone brands. Use the Earprint Rings Emblem as the primary icon. [Listing copy and screenshot storyboard](APP_STORE_METADATA.md)
- [ ] Set the canonical marketing, support, and privacy URLs. Verify HTTPS and public access to all three pages from an iPhone. Use the documented GitHub Pages URLs if the canonical host is unavailable. Reconfirm the **Data Not Collected** label and the published privacy policy. [URLs](APP_STORE_METADATA.md#app-store-connect-urls--contact) · [Privacy policy](PRIVACY_POLICY.md)
- [ ] Paste the v1.1.0 App Review Notes and attach a real-device demo if needed to show HealthKit ingestion, cards, and the device features on a phone with listening history. [App Review Notes](APP_STORE_METADATA.md#app-review-notes-v110)

### Clean-device & feature smoke tests

- [ ] On a clean install with no readable HealthKit data, confirm Collection, Rings, and widgets show zero-data states. Confirm the **Sync Apple Health** path works and Settings remains accessible. With a real logged headphone pair that has no dedicated model, verify that the generic 3D card renders and flips to the pair's own stats.
- [ ] Confirm **Wrapped 3D Video / GIF export**, **4 Custom Foils**, **Slab Engraving**, **Watermark-Free 2100×2800 Posters**, **Multi-Year Archive Export**, and **Live Listening Session** are all immediately unlocked with no paywall or StoreKit prompt.

### Physical iPhone feature smoke tests

- [ ] On a Dynamic Island iPhone with Live Activities enabled, start **Settings → Session & Archive → Live Listening Session**. Check the Lock Screen and Dynamic Island presentation, including the rest countdown. Stop the session from Settings.
- [ ] Add the Earprint actions in Shortcuts. Run **Start Listening Session**, **Reset Listening Rest Timer**, and **Stop Listening Session** in order. Verify one activity starts, reset restarts the countdown on that activity, and stop ends it.
- [ ] With 2026 listening data, open **2026 Earprint Wrapped** in Rings. Go offline and export the card reel as 1080p MP4 (`1080 × 1920 px`) and 540p GIF (`540 × 960 px`). Open both saved files and confirm they animate.
- [ ] In a Device Dossier, try the four custom foil finishes and customize the slab engraving. In the share sheet, enable High-Res and hide the watermark. Open the exported PNG and verify `2100 × 2800 px` and no footer watermark.
- [ ] From **Settings → Session & Archive → Export Archive**, export both CSV and JSON with listening data spanning at least two years. Open the saved files and confirm devices, dates, and listening totals agree with the source history.
- [ ] Confirm the 3D cards, Device Dossier, Rings, widgets, and Wrapped recap are all accessible.

### Final Release archive

- [ ] Confirm `project.yml` and the generated Release settings use `MARKETING_VERSION = 1.1.0` and `CURRENT_PROJECT_VERSION = 10`. Run `EarprintTests` and archive the exact release commit with the Release configuration.
- [ ] Check the archived `Earprint.app` and embedded widget extension for bundle version `1.1.0` and build `10`. Confirm the read-only HealthKit purpose strings and `ITSAppUsesNonExemptEncryption = NO`.
- [ ] Confirm the Release code requests only Headphone Audio Levels with `toShare: []` and excludes the DEBUG-only HealthKit seeder. Inspect the binary with `nm -u` and verify zero HealthKit write, save, or delete symbols. Check the Objective-C selector table for direct HealthKit save/delete calls.
- [ ] Confirm the Release `Earprint.app`, including the embedded extension, contains zero `.storekit` or `l10n-*.json` files.
- [ ] Upload the verified archive, confirm TestFlight export compliance, and complete the smoke tests above on the uploaded build before submitting to App Review.

Run the checks against the app in the archive selected for upload.

```sh
earprint_app='/path/to/Earprint.xcarchive/Products/Applications/Earprint.app'
earprint_plist="$earprint_app/Info.plist"
plutil -extract CFBundleShortVersionString raw -o - "$earprint_plist"
plutil -extract CFBundleVersion raw -o - "$earprint_plist"
plutil -p "$earprint_plist" | grep -E 'NSHealth|ITSAppUsesNonExemptEncryption'

# Run both tools successfully and confirm the searches show zero HealthKit write matches.
xcrun nm -u "$earprint_app/Earprint" | xcrun swift-demangle \
  | grep -iE '(HKHealthStore|HealthKit).*(save|delete|write)'
xcrun otool -v -s __TEXT __objc_methname "$earprint_app/Earprint" \
  | grep -E '(^|[[:space:]])(saveObjects?|deleteObjects?(OfType)?):'

# Expect no paths.
find "$earprint_app" \( -iname '*.storekit' -o -iname 'l10n-*.json' \) -print
```

## Compliance and device verification

### Trademark and asset review

- Use the original Earprint Rings Emblem on the storefront. Keep brand references to supported hardware and the data source in the Full Description, with the non-affiliation and non-medical notice at the bottom. Verify the same notices in **Settings → Credits & Attributions** and on the support and privacy pages.
- The CC-BY 4.0 license covers the creators' models and textures. Review third-party hardware marks and silhouettes separately for App Review. If a model must be removed, verify its procedural 3D fallback and review the corresponding 2D artwork and credits. [Asset inventory and provenance](../ASSETS.md)

### In-app CC-BY 4.0 credits

Verify that **Settings → Credits & Attributions** identifies each distributed CC-BY 4.0 model, its creator and source, the license, and any modifications. Keep credits aligned with the assets in the archive.

| Asset | Source Title | Author | Source URL | License & Notes |
| --- | --- | --- | --- | --- |
| `AirPods4.usdz` (+ front render) | *AirPods 4* | **Falah3D (`3dFalah`)** (`https://sketchfab.com/3dFalah`) | `https://sketchfab.com/3d-models/airpods-4-e44730974131402eb496352cab19c82e` | [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/). Modified: cropped front render; decimated open-pose FBX (99,248 → 44,967 tris), joined meshes, normalized, compressed textures, converted to USDZ. Provenance also noted in `AirPods4Credits.txt` via Andrea Balbo (`clawd-airpods4-anc-case`). |
| `AirPodsMax.usdz` | *Airpods max sky blue* | **polyman Studio (`Polyman_3D`)** (`https://sketchfab.com/Polyman_3D`) | `https://sketchfab.com/3d-models/airpods-max-sky-blue-3d0643db08fc4ef89bda55a74077ece4` | [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/). Modified: decimated (87,701 → 41,968 tris), joined meshes (137 → 20), normalized, baked PBR factors, dropped emissive maps, compressed textures, added headband canopy `opacityThreshold`, converted to USDZ. |
| `AirPodsPro.usdz` | *Airpods Pro With Magsafe Charging Case Ios15* | **polyman Studio (`Polyman_3D`)** (`https://sketchfab.com/Polyman_3D`) | `https://sketchfab.com/3d-models/airpods-pro-with-magsafe-charging-case-ios15-52e5f28b37f94f05b6c0768773137689` | [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/). Modified: removed internal occlusion shell, decimated (96,992 → 47,975 tris), joined meshes (48 → 14), normalized, baked `metallicFactor = 0`, dropped emissive maps, JPEG-compressed textures, converted to USDZ. |
| `HeadphoneGeneric.usdz` | *Studio Headphones* | **crow (`crow.bite`)** (`https://sketchfab.com/crow.bite`) | `https://sketchfab.com/3d-models/studio-headphones-2f04830fbf884632a89445db0d170ba8` | [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/). Modified: decimated (64,544 → 51,995 tris), joined 6 parts into 1 mesh, normalized, baked roughness map, downscaled to 2048 px JPEG, converted to USDZ. |

### HealthKit and clean-device regression

- Verify that the permission sheet lists read access to **Headphone Audio Levels** only. The app has no write permission toggle. Release purpose strings in `Info.plist` describe read-only access, including the update purpose string used for App Store Connect validation.
- Check both no-sample and denied-permission paths. Use a physical iPhone with real headphone playback to verify the first HealthKit sync, per-device history, and widget snapshot. Review the app's HealthKit handling and disclosure against the published privacy policy before submission. [Privacy policy](PRIVACY_POLICY.md)

### Seven-day TestFlight device checklist

For external testing, complete **TestFlight → Beta App Information** with the beta description, feedback email, privacy URL, and clean-device review notes. Submit for Beta App Review when App Store Connect requests it. [Device acceptance tracking](https://github.com/Popcornnnnnnnn/earprint/issues/2)

Run these checks on an iPhone with iOS 18 or later and real headphone hardware.

- [ ] **Day 1 — Cold Install & HealthKit Ingestion**
  - Fresh install from TestFlight (no prior cache). Confirm HealthKit permission sheet lists **read-only** `Headphone Audio Levels` (zero write toggles).
  - Verify initial multi-year `HKAnchoredObjectQueryDescriptor` paged sync completes without UI freeze or excessive memory spike; check `<Application Support>/listening-aggregate.json` persists across force-quit and cold relaunches.
- [ ] **Day 2 — Device Identity & PID Accuracy**
  - Pair at least 2 headphones (e.g., AirPods Pro + AirPods Max or Beats/third-party). Confirm `HeadphoneModelCatalog` resolves exact marketing names and no unexpected `0x20XX` unknown hex IDs appear for current Apple/Beats hardware.
  - Test Bluetooth rename in iOS Settings → Bluetooth: confirm `localIdentifier` merges old + new nicknames cleanly without splitting cards (`otherNames` preserved).
- [ ] **Day 3 — Accuracy Cross-Check vs Apple Health**
  - Compare Earprint's daily/weekly listening minutes and `Leq` dB(A) against **Apple Health → Hearing → Headphone Audio Levels** across 3 consecutive days (including a midnight-crossing session if possible).
  - Confirm `HKObserverQuery` updates listening totals automatically after taking headphones off and reopening the app.
- [ ] **Day 4 — Real Dossier & Export Stress Test**
  - Open `DeviceDossierView` for your top card: verify `Week / Month / Year / All` switching, 30-day scrub chart haptics, 24h `DayClock`, `HabitsBento`, `EarGrade` penalties, and `CertificateLabel` metadata match real `HKDevice` / `HKSource` values.
  - Export **Simple (1-page)** and **Long (4-page)** PNG posters via `DossierShareSheet` and share a 9:16 `ShareCardView` image; verify crisp rendering in Photos / Rednote / WeChat.
- [ ] **Day 5 — 3D Thermal, Gesture & Accessibility Check**
  - Spin, pinch-zoom, long-press twirl, flip, and switch colors (AirPods Max / Beats) on `CardDetail` for 2–3 minutes; confirm smooth frame rate, no thermal throttling, and tilt motion pauses cleanly when Reduce Motion is enabled or sheets are open.
- [ ] **Day 6 — Widgets, Deep Links & Custom Icons**
  - Place **Small Today** (tap interactive `NextCardIntent`), **Medium Card Shelf** (tap a card to test `earprint://card/<id>` cold-start deep link), **Large Earprint Ring**, and Lock Screen **Budget Gauge** + **Today Summary**.
  - Test switching App Icons in `Settings → App Icon` (`Auto / Light / Dark / Holo` × AirPods Max finishes) and verify no icon-change failures.
- [ ] **Day 7 — Bilingual Localization & Clean-Device Regression**
  - Switch `Settings → Language` between **English** and **Simplified Chinese**; inspect every tab, `CardTiersView`, `ModelGalleryView`, `SettingsView`, `Credits`, `Dossier`, and `ShareSheet` for clipped labels or untranslated keys.
  - Test on a **clean secondary device** (or after denying HealthKit permission) to confirm zero crashes, zero misleading sample data, and clear recovery instructions before pressing **Submit for Review**.
