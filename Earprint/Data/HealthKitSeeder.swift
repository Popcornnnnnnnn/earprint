#if DEBUG
import Foundation
import HealthKit

/// Debug-only simulator helper that writes realistic multi-device headphone audio exposure samples
/// into Apple Health so the full real-data pipeline (`HKAnchoredObjectQueryDescriptor` →
/// `HealthIngestor` → `ListeningAggregate` → `LibrarySnapshot` → `AggregateCache`) can be exercised
/// without a physical iPhone.
///
/// Release builds compile this file out completely and keep `Info.plist` read-only.
enum HealthKitSeeder {
    static let seedMetadataKey = "com.popcornnn.earprint.seeded"

    struct SeedReport: Sendable {
        var samplesWritten: Int
        var deviceCount: Int
    }

    private struct SeedDevice {
        var name: String
        var earlierName: String?
        var manufacturer: String
        var model: String
        var hardwareVersion: String?
        var localIdentifier: String
    }

    private static let devices: [SeedDevice] = [
        SeedDevice(
            name: "🧸's AirPods Pro",
            earlierName: "AirPods Pro",
            manufacturer: "Apple Inc.",
            model: "0x2024",
            hardwareVersion: "1.0",
            localIdentifier: "E1:A0:00:00:00:01-tacl"
        ),
        SeedDevice(
            name: "Studio Max",
            earlierName: nil,
            manufacturer: "Apple Inc.",
            model: "0x201F",
            hardwareVersion: "1.0",
            localIdentifier: "E1:A0:00:00:00:02-tacl"
        ),
        SeedDevice(
            name: "Gym buds",
            earlierName: nil,
            manufacturer: "Apple Inc.",
            model: "0x2012",
            hardwareVersion: "1.0",
            localIdentifier: "E1:A0:00:00:00:03-tacl"
        ),
    ]

    enum SeedError: LocalizedError {
        case writePermissionDenied

        var errorDescription: String? {
            switch self {
            case .writePermissionDenied:
                return "Write access to Headphone Audio Levels was not enabled. Turn it on in Settings › Health › Data Access › Earprint."
            }
        }
    }

    /// Requests read+write authorization for `headphoneAudioExposure` (Debug only) and writes
    /// deterministic multi-device listening history across the past 28 days.
    static func seed(store: HKHealthStore = HKHealthStore(), now: Date = Date(), calendar: Calendar = .current) async throws -> SeedReport {
        let type = HKQuantityType(.headphoneAudioExposure)
        try await store.requestAuthorization(toShare: [type], read: [type])
        guard store.authorizationStatus(for: type) == .sharingAuthorized else {
            throw SeedError.writePermissionDenied
        }

        // Replace any earlier seeded samples so repeated runs do not duplicate totals.
        try? await clearSeeded(store: store)

        let raw = buildRawSamples(now: now, calendar: calendar)
        let hkSamples = makeHKSamples(from: raw)

        // Write in chunks to keep each HealthKit IPC call fast.
        let batchSize = 400
        var offset = 0
        while offset < hkSamples.count {
            let slice = Array(hkSamples[offset..<min(offset + batchSize, hkSamples.count)])
            try await store.save(slice)
            offset += batchSize
        }

        return SeedReport(samplesWritten: hkSamples.count, deviceCount: devices.count)
    }

    static func makeHKSamples(from raw: [RawListeningSample]) -> [HKQuantitySample] {
        let type = HKQuantityType(.headphoneAudioExposure)
        let unit = HKUnit.decibelAWeightedSoundPressureLevel()
        return raw.map { sample in
            let hkDevice = sample.device.map { d in
                HKDevice(
                    name: d.name,
                    manufacturer: d.manufacturer,
                    model: d.model,
                    hardwareVersion: d.hardwareVersion,
                    firmwareVersion: d.firmwareVersion,
                    softwareVersion: d.softwareVersion,
                    localIdentifier: d.localIdentifier,
                    udiDeviceIdentifier: d.udiDeviceIdentifier
                )
            }
            return HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: sample.decibels),
                start: sample.start,
                end: sample.end,
                device: hkDevice,
                metadata: [seedMetadataKey: true]
            )
        }
    }

    /// Removes only samples tagged with `seedMetadataKey`.
    @discardableResult
    static func clearSeeded(store: HKHealthStore = HKHealthStore()) async throws -> Int {
        let type = HKQuantityType(.headphoneAudioExposure)
        let predicate = HKQuery.predicateForObjects(withMetadataKey: seedMetadataKey)
        return try await withCheckedThrowingContinuation { continuation in
            store.deleteObjects(of: type, predicate: predicate) { _, deletedCount, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: deletedCount)
                }
            }
        }
    }

    /// Deterministic multi-device listening history across the past 28 days (plus a few older days
    /// for realistic "first met" dates and a couple of host-device samples to test host filtering).
    static func buildRawSamples(now: Date = Date(), calendar: Calendar = .current) -> [RawListeningSample] {
        var rng = SplitMix64(seed: 2026_1119)
        let today = calendar.startOfDay(for: now)
        var out: [RawListeningSample] = []

        func descriptor(for device: SeedDevice, useEarlierName: Bool = false) -> DeviceDescriptor {
            DeviceDescriptor(
                name: useEarlierName ? (device.earlierName ?? device.name) : device.name,
                manufacturer: device.manufacturer,
                model: device.model,
                hardwareVersion: device.hardwareVersion,
                localIdentifier: device.localIdentifier
            )
        }

        /// Appends a listening session broken into realistic 2–8 minute HealthKit clips
        /// separated by short pauses (< 5 min so they merge into one session).
        func addSession(dayOffset: Int, startHour: Int, startMinute: Int, totalMinutes: Double,
                        dbRange: ClosedRange<Double>, device: DeviceDescriptor) {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today),
                  var cursor = calendar.date(byAdding: .minute, value: startHour * 60 + startMinute, to: day)
            else { return }
            let targetEnd = min(cursor.addingTimeInterval(totalMinutes * 60), now.addingTimeInterval(-60))
            while cursor < targetEnd {
                let clipMin = min(rng.in(2.5...7.5), targetEnd.timeIntervalSince(cursor) / 60)
                guard clipMin >= 0.5 else { break }
                let clipEnd = cursor.addingTimeInterval(clipMin * 60)
                out.append(RawListeningSample(
                    start: cursor,
                    end: clipEnd,
                    decibels: rng.in(dbRange),
                    device: device,
                    source: "com.apple.health"
                ))
                // Small inter-clip gap (10–90 s), well under the 5-minute session gap.
                cursor = clipEnd.addingTimeInterval(rng.in(10...90))
            }
        }

        let airPods = devices[0]
        let max = devices[1]
        let beats = devices[2]

        // Older history (day -90 ... -32) so lifetime stats and "first met" dates look rich and
        // the AirPods Pro show a rename merged via localIdentifier.
        for dayOffset in stride(from: 90, through: 32, by: -2) {
            let renamed = dayOffset > 70
            let ap = descriptor(for: airPods, useEarlierName: renamed)
            addSession(dayOffset: dayOffset, startHour: 8, startMinute: 20, totalMinutes: rng.in(35...55), dbRange: 61...69, device: ap)
            addSession(dayOffset: dayOffset, startHour: 22, startMinute: 10, totalMinutes: rng.in(45...85), dbRange: 56...66, device: ap)
            if dayOffset % 4 == 0 {
                addSession(dayOffset: dayOffset, startHour: 15, startMinute: 0, totalMinutes: rng.in(45...90), dbRange: 60...68,
                           device: descriptor(for: max))
            }
            if dayOffset % 6 == 0 {
                addSession(dayOffset: dayOffset, startHour: 7, startMinute: 0, totalMinutes: rng.in(30...45), dbRange: 70...78,
                           device: descriptor(for: beats))
            }
        }

        // Last 28 days (populates the 28×24 Earprint grid and 7-day hearing budget).
        let apCurrent = descriptor(for: airPods)
        let maxCurrent = descriptor(for: max)
        let beatsCurrent = descriptor(for: beats)

        for dayOffset in (0..<28).reversed() {
            let weekday = dayOffset % 7 < 5
            if weekday {
                // Morning commute (AirPods Pro)
                addSession(dayOffset: dayOffset, startHour: 8, startMinute: Int(rng.in(5...25)),
                           totalMinutes: rng.in(28...48), dbRange: 62...70, device: apCurrent)
                // Evening commute (AirPods Pro)
                addSession(dayOffset: dayOffset, startHour: 18, startMinute: Int(rng.in(0...20)),
                           totalMinutes: rng.in(30...52), dbRange: 63...72, device: apCurrent)
                // Occasional desk session (Studio Max)
                if rng.unit() < 0.55 {
                    addSession(dayOffset: dayOffset, startHour: 14, startMinute: Int(rng.in(0...30)),
                               totalMinutes: rng.in(40...80), dbRange: 58...66, device: maxCurrent)
                }
            } else {
                // Weekend afternoon (Studio Max)
                addSession(dayOffset: dayOffset, startHour: 15, startMinute: Int(rng.in(0...30)),
                           totalMinutes: rng.in(50...105), dbRange: 60...69, device: maxCurrent)
            }

            // Late-night listening (AirPods Pro) — gives a clear night-owl ring signature
            if rng.unit() < 0.8 {
                addSession(dayOffset: dayOffset, startHour: 22, startMinute: Int(rng.in(0...35)),
                           totalMinutes: rng.in(40...95), dbRange: 57...68, device: apCurrent)
            }
            if rng.unit() < 0.45 {
                addSession(dayOffset: dayOffset, startHour: 0, startMinute: Int(rng.in(5...20)),
                           totalMinutes: rng.in(20...45), dbRange: 65...76, device: apCurrent)
            }

            // Morning workout 3x/week (Beats Fit Pro)
            if dayOffset % 2 == 1 && rng.unit() < 0.7 {
                addSession(dayOffset: dayOffset, startHour: 7, startMinute: Int(rng.in(0...15)),
                           totalMinutes: rng.in(28...45), dbRange: 71...79, device: beatsCurrent)
            }
        }

        // Add two host-device samples to verify `isHostDevice` filtering ignores non-headphone writers.
        let host = DeviceDescriptor(name: "iPhone", manufacturer: "Apple Inc.", model: "iPhone17,1", localIdentifier: "host-iphone")
        addSession(dayOffset: 1, startHour: 12, startMinute: 0, totalMinutes: 5, dbRange: 65...65, device: host)

        return out.sorted { $0.start < $1.start }
    }
}
#endif
