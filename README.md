# Earprint (codename)

An iPhone app that turns your AirPods / headphone listening history from Apple Health into beautiful, shareable stats. The main hook is the **Earprint**: a picture made from your own listening. Each ring is one day, and each segment is one hour of the day. Color shows how loud you listened.

**UI and UX come first.** Every feature must look good enough to post on Xiaohongshu / TikTok.

## Goal

- Read `HKQuantityType(.headphoneAudioExposure)` samples, which iOS logs automatically while audio plays. Nothing leaves the phone.
- Show listening time, sessions, loudness and a weekly hearing budget for each headphone, using our own design.
- Make "Wrapped"-style weekly, monthly and yearly cards that people want to share.
- Chinese and English from day one. TestFlight first. The China App Store needs an ICP filing (备案) first.

## Stage 1 completion criteria

1. A data probe runs on a real iPhone and confirms the fields we get: device name, manufacturer, model / hardware ID, dB(A), sample count and load time.
2. A home screen and share card built with the agreed visual direction (sample: `docs/samples/`).
3. The home screen uses real HealthKit data instead of sample data.
4. A TestFlight build is installed and used for one week.

## Status (2026-11-19)

- Done: XcodeGen project, data probe tab, first UI sample (home + 9:16 share card) running in the simulator with sample data.
- Blocked: device builds fail with "No Accounts". **Xcode needs an Apple ID signed in** (Xcode › Settings › Accounts) so automatic signing can add the HealthKit capability for team `R26X7B8XDT`.

## Next steps

1. Sign in to Xcode, run the probe on the iPhone and copy the report.
2. Review the visual direction, then refine the Earprint glyph and share cards.
3. Connect the home screen to real data. Add localization (String Catalog) and widgets.

## Build

```sh
xcodegen generate
# Simulator (sample data)
xcodebuild -project Earprint.xcodeproj -scheme Earprint -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build build
# Device (needs an Apple ID in Xcode)
xcodebuild -project Earprint.xcodeproj -scheme Earprint -destination 'id=<device-udid>' -derivedDataPath build -allowProvisioningUpdates build
```

Launch with `-showShare` to open the share sheet directly (useful for screenshots).

## Landscape (checked 2026-11-19)

- **PodsStats** (Xiaohongshu dev "momo"): same data source. TestFlight only, not on the App Store, and its build is currently expired.
- App Store: no app with the same features. Nearby apps are EarRest (break reminders based on Bluetooth connection), EarTimer, and decibel meters.
- Open source: no matching app. An empty repo `MIN202299/airpodsStats` was created on 2026-11-19, so someone else is starting too.
