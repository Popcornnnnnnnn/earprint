import Foundation
import HealthKit

/// Reads headphone audio exposure samples from HealthKit and folds them into a `ListeningAggregate`.
/// Runs on its own actor so years of samples never touch the main thread.
///
/// Why sample queries and not `HKStatisticsCollectionQuery`: statistics can split by *source* (the app
/// that wrote the sample) but not by *device*, and they cannot give sessions. So we page through raw
/// samples once with an anchored query, keep only small running totals, and afterwards fetch only the
/// new samples since the saved anchor.
actor HealthIngestor {
    struct SyncResult: Sendable {
        var snapshot: LibrarySnapshot
        var newSamples: Int
        var rebuilt: Bool
    }

    static let pageSize = 25_000

    private let store: HKHealthStore
    private let type = HKQuantityType(.headphoneAudioExposure)
    private let cache: AggregateCache
    private var aggregate: ListeningAggregate
    private var anchor: HKQueryAnchor?
    private var observer: HKObserverQuery?
    private var syncing = false

    init(store: HKHealthStore = HKHealthStore(), cache: AggregateCache = AggregateCache()) {
        self.store = store
        self.cache = cache
        if let saved = cache.load() {
            aggregate = saved.aggregate
            anchor = saved.anchor
        } else {
            aggregate = ListeningAggregate()
            anchor = nil
        }
    }

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Snapshot from the disk cache, available instantly at launch.
    func cachedSnapshot(now: Date = Date()) -> LibrarySnapshot? {
        aggregate.isEmpty ? nil : LibrarySnapshot(aggregate: aggregate, now: now, calendar: .current)
    }

    func snapshot(now: Date = Date()) -> LibrarySnapshot {
        LibrarySnapshot(aggregate: aggregate, now: now, calendar: .current)
    }

    /// Whether iOS still needs to present the HealthKit permission sheet for read access.
    func authorizationRequestStatus() async -> HKAuthorizationRequestStatus {
        do {
            return try await store.statusForAuthorizationRequest(toShare: [], read: [type])
        } catch {
            return .unknown
        }
    }

    /// Asks for read access. HealthKit never tells us whether reading was denied; a denied user just
    /// looks like a user with zero samples. The caller handles that as the "no data" state.
    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [], read: [type])
    }

    /// Fetches everything new since the saved anchor (or everything on first run) in pages.
    func sync(progress: (@Sendable (Int) -> Void)? = nil) async throws -> SyncResult {
        // Coalesce overlapping calls (observer firing during the initial load).
        while syncing { try await Task.sleep(for: .milliseconds(100)) }
        syncing = true
        defer { syncing = false }

        var rebuilt = anchor == nil
        var fetched = 0
        var working = aggregate
        var workingAnchor = anchor

        while true {
            let descriptor = HKAnchoredObjectQueryDescriptor(
                predicates: [.quantitySample(type: type)],
                anchor: workingAnchor,
                limit: Self.pageSize
            )
            let result = try await descriptor.result(for: store)

            if !result.deletedObjects.isEmpty && workingAnchor != nil && !rebuilt {
                // Totals cannot subtract a deleted sample, so start over. Deletions are rare.
                working = ListeningAggregate()
                workingAnchor = nil
                rebuilt = true
                fetched = 0
                continue
            }

            let samples = result.addedSamples.map(Self.plain)
            working.ingest(samples, now: Date(), calendar: .current)
            fetched += samples.count
            workingAnchor = result.newAnchor
            progress?(fetched)

            if result.addedSamples.count + result.deletedObjects.count < Self.pageSize { break }
        }

        aggregate = working
        anchor = workingAnchor
        if fetched > 0 || rebuilt {
            cache.save(aggregate: aggregate, anchor: anchor)
        }
        return SyncResult(snapshot: snapshot(), newSamples: fetched, rebuilt: rebuilt)
    }

    /// Calls `onChange` whenever Health gets new headphone samples (while the app runs).
    func startObserving(onChange: @escaping @Sendable () -> Void) {
        guard observer == nil else { return }
        let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
            if error == nil { onChange() }
            completion()
        }
        observer = query
        store.execute(query)
    }

    func stopObserving() {
        if let observer { store.stop(observer) }
        observer = nil
    }

    /// Forgets the cache and reloads all samples from Health.
    func resetCache() {
        aggregate = ListeningAggregate()
        anchor = nil
        cache.clear()
    }

    static func plain(_ sample: HKQuantitySample) -> RawListeningSample {
        RawListeningSample(
            start: sample.startDate,
            end: sample.endDate,
            decibels: sample.quantity.doubleValue(for: .decibelAWeightedSoundPressureLevel()),
            device: sample.device.map(DeviceDescriptor.init(_:)),
            source: sample.sourceRevision.source.bundleIdentifier
        )
    }
}

extension DeviceDescriptor {
    init(_ device: HKDevice) {
        self.init(name: device.name, manufacturer: device.manufacturer, model: device.model,
                  hardwareVersion: device.hardwareVersion, firmwareVersion: device.firmwareVersion,
                  softwareVersion: device.softwareVersion, localIdentifier: device.localIdentifier,
                  udiDeviceIdentifier: device.udiDeviceIdentifier)
    }
}

/// Saves the aggregate + query anchor to Application Support so the app opens instantly.
struct AggregateCache: Sendable {
    struct Saved {
        var aggregate: ListeningAggregate
        var anchor: HKQueryAnchor?
    }

    private struct File: Codable {
        var aggregate: ListeningAggregate
        var anchor: Data?
    }

    let url: URL

    init(url: URL? = nil) {
        if let url {
            self.url = url
        } else {
            let dir = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                    appropriateFor: nil, create: true)) ?? FileManager.default.temporaryDirectory
            self.url = dir.appendingPathComponent("listening-aggregate.json")
        }
    }

    func load() -> Saved? {
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data),
              file.aggregate.version == ListeningAggregate.schemaVersion else { return nil }
        let anchor = file.anchor.flatMap {
            try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0)
        }
        // An aggregate without its anchor would double-count on the next sync, so drop both.
        if file.anchor != nil && anchor == nil { return nil }
        return Saved(aggregate: file.aggregate, anchor: anchor)
    }

    func save(aggregate: ListeningAggregate, anchor: HKQueryAnchor?) {
        let anchorData = anchor.flatMap { try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true) }
        guard let data = try? JSONEncoder().encode(File(aggregate: aggregate, anchor: anchorData)) else { return }
        // Health-derived data: keep it encrypted while the phone is locked after first unlock.
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
