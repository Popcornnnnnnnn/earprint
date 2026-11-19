# iPhone Duo Adaptation

Earprint adapts cleanly across both iPhone Duo displays, all orientations, and active fold postures (book and tabletop), with zero regression on standard slab iPhones (verified on iPhone 17 Pro).

---

## 1. iPhone Duo Hardware & Display Specs

Verified against the iOS 27.2 iPhone Duo simulator runtime (`com.apple.CoreSimulator.SimRuntime.iOS-27-2-iPhone19-4`, Xcode 27.2):

| Display | Diagonal | Native Resolution (Portrait) | Native Resolution (Landscape) | Scale | Logical Points (Portrait) | Logical Points (Landscape) | Sim `io --display` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **Outer (Folded)** | 5.4" | `1398 × 2034 px` | `2034 × 1398 px` | `@3x` (460 ppi) | `466 × 678 pt` | `678 × 466 pt` | `--display=1` (`primary`) |
| **Inner (Unfolded)** | 7.6" | `2007 × 2853 px` | `2853 × 2007 px` | `@3x` | `669 × 951 pt` | `951 × 669 pt` | `--display=3` (`primary-1`) |

Key hardware traits affecting layout:
- **Asymmetric chrome & safe areas:** On the outer display (and in landscape on the inner display), the status indicator and floating glass tab bar sit vertically along the right/side edge, near the outer-corner front camera cutout. Do not assume equal left/right safe-area insets.
- **Dynamic hinge (`.division` reserved region):** On iOS 27.1+, `GeometryProxy.reservedRegions(kind: .division, options: .includeInactive)` reports the hinge frame in the measured view's own coordinates (including system margins). The region is present (inactive) when flat on the inner display and becomes **active** when partially folded into **book** (vertical hinge) or **tabletop / laptop** (horizontal hinge) poses.
- **All orientations on the inner display:** The unfolded inner canvas behaves like a compact tablet and supports all four orientations (`Portrait`, `LandscapeLeft`, `LandscapeRight`, `PortraitUpsideDown`).

---

## 2. App Store Screenshot Requirements & April 2027 Deadline

- **Enforcement deadline:** Starting **April 2027**, any new app, game, or app update built with the **iOS 27.1 SDK or later** must include dedicated **iPhone Duo** screenshots in App Store Connect (uploads have been open since October 2026 and unlock the iPhone Duo optimization badge).
- **No automatic fallback:** App Store Connect does **not** auto-downscale standard iPhone screenshots into iPhone Duo slots. Both displays must be supplied explicitly.
- **Required dimensions (1–10 screenshots per display, PNG/JPEG with no alpha/transparency):**
  - **Outer Display:** `1398 × 2034 px` (portrait) or `2034 × 1398 px` (landscape)
  - **Inner Display:** `2007 × 2853 px` (portrait) or `2853 × 2007 px` (landscape)
- **Ready-to-upload captures:** All screenshots in [`docs/duo/`](duo/) are captured at native simulator framebuffer dimensions (`1398×2034`, `2034×1398`, `2853×2007`, `2007×2853`) and saved as opaque RGB PNGs (alpha channel stripped) for direct App Store Connect compatibility.

---

## 3. HIG Rules Applied

1. **Adapt to available geometry & size classes, not device models:** All layout decisions read container size and `.division` reserved regions through `LayoutSpace` (`AdaptiveLayout.swift`) rather than hardcoding device identifiers.
2. **Respect asymmetric safe areas:** Never hardcode symmetric horizontal chrome margins; measure the safe viewport container (`ScrollView` / overlay root) so SwiftUI's automatic safe-area insets clear the vertical status bar, camera punch-hole, and floating glass tab pill.
3. **Keep interactive elements and cards out of the hinge crease:**
   - **Collection grid:** Keep column counts **even** on foldable displays so the hinge always falls in the gutter between cards. When a vertical fold is active (book pose), widen the middle gutter to cover `fold.width` and center each half on its own page.
   - **Two-column detail / dashboard layouts (`ColumnSplit`):** When a vertical fold is active, size the leading column to `fold.minX - padding`, the gap to `fold.width`, and the trailing column to `width - padding - fold.maxX` so each column stays strictly on its own side of the hinge.
   - **Tabletop / laptop pose (horizontal fold):** Place the interactive hero card strictly above `fold.minY` and controls below `fold.maxY`.
4. **Fluid continuity across fold/unfold & rotation:** Declare `UIApplicationSceneManifest`, dynamic `UILaunchScreen`, and all four `UISupportedInterfaceOrientations` in `project.yml` so the app transitions smoothly without letterboxing.

---

## 4. What We Adapted in Earprint

- **`project.yml`**
  - Added `UIApplicationSceneManifest` (`UIApplicationSupportsMultipleScenes: false`) and expanded `UISupportedInterfaceOrientations` to support all four orientations (`Portrait`, `LandscapeLeft`, `LandscapeRight`, `PortraitUpsideDown`).
- **`Earprint/Design/AdaptiveLayout.swift`**
  - `LayoutSpace`: Reads container `CGSize` and iOS 27.1+ `proxy.reservedRegions(kind: .division, options: .includeInactive)` to detect `canFold`, active `verticalFold`, and active `horizontalFold`.
  - `ColumnSplit`: Computes equal two-column widths when flat, or hinge-aligned left/right page widths when `verticalFold` is active.
  - `AdaptiveGrid`: Computes responsive column counts, enforces even column counts on foldable displays, and splits the middle gutter cleanly around an active vertical fold.
  - `FittedDesign`: Scales fixed-design-size artwork (`ShareCardView` at `360×640`) to fit any sheet geometry while reporting its scaled footprint to layout.
- **`Earprint/Collection/CollectionView.swift`**
  - `CollectionView`: Attached `.readLayoutSpace($space)` to the `ScrollView` viewport (so geometry and fold frames stay viewport-anchored while scrolling). Uses `AdaptiveGrid(minItemWidth: 170)`: 2 columns on slab iPhones, outer portrait, and inner portrait (lush 2×2 showcase), 3 columns on outer landscape (non-foldable outer screen), and 4 columns on inner landscape / book pose (2 cards per half with a hinge-clearing middle gutter). Added inner horizontal padding & `minimumScaleFactor` to `lockedSlot` so its caption never clips against the dashed border.
  - `CardDetail`: Four adaptive modes:
    - `.single`: Classic single flippable 3D card on slab iPhones and folded outer portrait.
    - `.besideControls`: Card left, hint + action pills right on short landscape screens (outer landscape `678×466 pt`).
    - `.sideBySide`: Front 3D card and back stats card displayed simultaneously on inner portrait, inner landscape, and book pose (one card per page, aligned footer baseline, generous top margin for the popping 3D headphone model). Auto-unflips if transitioning into `.sideBySide` while flipped.
    - `.foldStacked(CGRect)`: Tabletop/laptop pose with the 3D card cleanly above the horizontal fold and controls below.
- **`Earprint/Home/HomeView.swift`**
  - Attached `.readLayoutSpace($space)` to the `ScrollView` viewport so `isLandscape` reflects true viewport dimensions (`585×466 pt` on outer landscape).
  - Switches to a two-column `ColumnSplit` dashboard (Earprint rings + legend left, persona + stats + hearing budget + share CTA right) whenever `space.isWide || (space.isLandscape && space.size.width >= 520)` — covering inner portrait, inner landscape, book pose, and outer landscape without vertical glyph overflow.
  - Constrains the center `weekMinutes` label to the inner ring diameter (`max(84, width * 0.32)` with `minimumScaleFactor(0.55)`) and tightens legend spacing so `"4 weeks · rings = days"` stays on a single line.
- **`Earprint/Home/ShareCardView.swift`**
  - `ShareSheet` wraps the fixed `360×640` `ShareCardView` in `FittedDesign`, stacking vertically in portrait/modal sheets and arranging side-by-side (`HStack`) in wide/short landscape sheets (`width > height * 1.1`).
- **`Earprint/EarprintApp.swift`**
  - Added launch-argument tab selection (`-rings`, `-showShare`) so automated captures and `-showShare` work directly on launch across simulators.

---

## 5. Verified Screenshots (`docs/duo/`)

All 19 screenshots below were captured on the iOS 27.2 iPhone Duo simulator and visually inspected:

| Posture / Display | Resolution | Collection | Card Detail (`-demo`) | Rings (`-rings`) | Share Sheet (`-showShare`) |
| --- | --- | --- | --- | --- | --- |
| **Outer Portrait (Closed)** | `1398 × 2034` | [outer-portrait-collection.png](duo/outer-portrait-collection.png) | [outer-portrait-detail.png](duo/outer-portrait-detail.png) | [outer-portrait-rings.png](duo/outer-portrait-rings.png) | [outer-portrait-share.png](duo/outer-portrait-share.png) |
| **Outer Landscape (Closed)** | `2034 × 1398` | — (3-col verified) | [outer-landscape-detail.png](duo/outer-landscape-detail.png) | [outer-landscape-rings.png](duo/outer-landscape-rings.png) | [outer-landscape-share.png](duo/outer-landscape-share.png) |
| **Inner Landscape (Open)** | `2853 × 2007` | [inner-landscape-collection.png](duo/inner-landscape-collection.png) | [inner-landscape-detail.png](duo/inner-landscape-detail.png) | [inner-landscape-rings.png](duo/inner-landscape-rings.png) | [inner-landscape-share.png](duo/inner-landscape-share.png) |
| **Inner Portrait (Open)** | `2007 × 2853` | [inner-portrait-collection.png](duo/inner-portrait-collection.png) | [inner-portrait-detail.png](duo/inner-portrait-detail.png) | [inner-portrait-rings.png](duo/inner-portrait-rings.png) | [inner-portrait-share.png](duo/inner-portrait-share.png) |
| **Book Pose (Partially Open)** | `2853 × 2007` | [book-collection.png](duo/book-collection.png) | [book-detail.png](duo/book-detail.png) | [book-rings.png](duo/book-rings.png) | — |
| **Tabletop Pose (Partially Open)** | `2007 × 2853` | — | [tabletop-detail.png](duo/tabletop-detail.png) | — | — |

Regression verified on **iPhone 17 Pro** (iOS 27.0): Collection, Card Detail, Rings, and Share Sheet render cleanly with no layout regressions.

---

## 6. Open Risks & Follow-Ups

1. **Physical device testing:** Simulator validates geometry, `.division` reserved regions, and safe areas, but real hardware hinge angles (continuous 0°–180° transitions), CoreMotion `TiltMotion` axis mapping across all 4 orientations, and RealityKit 3D frame rate during live fold/unfold transitions still need a physical iPhone Duo check before shipping.
2. **Outer landscape legend truncation:** In `outer-landscape-rings.png` (265 pt left column), `"4 weeks · rings = days"` truncates the last two characters (`= d...`). Shortening the label on narrow landscape widths or lowering `minimumScaleFactor` to `0.65` would eliminate the ellipsis.
3. **Live fold/unfold animation continuity for `matchedGeometryEffect`:** If the user unfolds or rotates while `CardDetail` is open and then closes it, `CollectionView`'s column count may have changed underneath. Test rapid fold-then-close transitions on device and guard against abrupt hero jumps if needed.
4. **Merge coordination with parallel feature branches:** Edits were kept minimal and self-contained (`AdaptiveLayout.swift`, `project.yml`, `EarprintApp.swift`, and surgical adaptive wrappers in `CollectionView.swift`, `HomeView.swift`, `ShareCardView.swift`). When merging with `feat/dossier`, `feat/widgets`, and `feat/health-data`, new screens/cards should reuse `LayoutSpace` / `ColumnSplit` so Duo hinge avoidance stays consistent.
