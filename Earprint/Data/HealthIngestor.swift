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
        var snapshot: LibrarySnapshot?
        var isEmpty: Bool
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
    private var lastSnapshotScopes: [RetirementCutoffScope] = []

    init(
        store: HKHealthStore = HKHealthStore(),
        cache: AggregateCache = AggregateCache(),
        initialSaved: AggregateCache.Saved? = nil,
        ignoreCache: Bool = false
    ) {
        self.store = store
        self.cache = cache
        if !ignoreCache, let saved = initialSaved ?? cache.load() {
            aggregate = saved.aggregate
            anchor = saved.anchor
        } else {
            aggregate = ListeningAggregate()
            anchor = nil
        }
    }

    #if DEBUG || EARPRINT_REPEAT_CARD_HINT
    /// Clears in-memory aggregate and anchor without erasing the on-disk cache so test builds can replay first-launch sync cleanly.
    func resetInMemoryState() {
        aggregate = ListeningAggregate()
        anchor = nil
    }
    #endif

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Snapshot from the disk cache, available instantly at launch.
    func cachedSnapshot(now: Date = Date(), cutoffScopes: [RetirementCutoffScope]? = nil) -> LibrarySnapshot? {
        guard !aggregate.isEmpty else { return nil }
        let scopes = cutoffScopes ?? DeviceLifecycleStore.persistedCutoffScopes()
        lastSnapshotScopes = scopes
        return LibrarySnapshot(
            aggregate: aggregate,
            now: now,
            calendar: .current,
            cutoffScopes: scopes
        )
    }

    func snapshot(now: Date = Date(), cutoffScopes: [RetirementCutoffScope]? = nil) -> LibrarySnapshot {
        let scopes = cutoffScopes ?? DeviceLifecycleStore.persistedCutoffScopes()
        lastSnapshotScopes = scopes
        return LibrarySnapshot(
            aggregate: aggregate,
            now: now,
            calendar: .current,
            cutoffScopes: scopes
        )
    }

    func needsRebuild(for scopes: [RetirementCutoffScope]) -> Bool {
        aggregate.needsRebuild(for: scopes)
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
    /// When `skipSnapshotIfUnchanged` is true and no samples changed, returns `snapshot = nil` so callers
    /// avoid redundant `LibrarySnapshot` re-bucketing and main-actor UI invalidations.
    func sync(skipSnapshotIfUnchanged: Bool = false, progress: (@Sendable (Int) -> Void)? = nil) async throws -> SyncResult {
        // Coalesce overlapping calls (observer firing during the initial load).
        while syncing { try await Task.sleep(for: .milliseconds(100)) }
        syncing = true
        defer { syncing = false }

        var scopes = DeviceLifecycleStore.persistedCutoffScopes()
        var scopesChanged = lastSnapshotScopes != scopes
        var rebuilt = anchor == nil
        var fetched = 0
        var working = aggregate
        var workingAnchor = anchor
        if !rebuilt && working.needsRebuild(for: scopes) {
            working = ListeningAggregate()
            workingAnchor = nil
            rebuilt = true
        }

        while true {
            let descriptor = HKAnchoredObjectQueryDescriptor(
                predicates: [.quantitySample(type: type)],
                anchor: workingAnchor,
                limit: Self.pageSize
            )
            let result = try await descriptor.result(for: store)

            let latestScopes = DeviceLifecycleStore.persistedCutoffScopes()
            if latestScopes != scopes {
                scopes = latestScopes
                scopesChanged = true
                if (!rebuilt && working.needsRebuild(for: scopes)) || (fetched > 0 && working.needsRebuild(for: scopes)) {
                    working = ListeningAggregate()
                    workingAnchor = nil
                    rebuilt = true
                    fetched = 0
                    continue
                }
            }

            if !result.deletedObjects.isEmpty && workingAnchor != nil && !rebuilt {
                // Totals cannot subtract a deleted sample, so start over. Deletions are rare.
                working = ListeningAggregate()
                workingAnchor = nil
                rebuilt = true
                fetched = 0
                continue
            }

            let samples = result.addedSamples.map(Self.plain)
            working.ingest(samples, now: Date(), calendar: .current, cutoffScopes: scopes)
            fetched += samples.count
            workingAnchor = result.newAnchor
            progress?(fetched)

            if result.addedSamples.count + result.deletedObjects.count < Self.pageSize {
                let finalScopes = DeviceLifecycleStore.persistedCutoffScopes()
                if finalScopes != scopes {
                    scopes = finalScopes
                    scopesChanged = true
                    if working.needsRebuild(for: scopes) {
                        working = ListeningAggregate()
                        workingAnchor = nil
                        rebuilt = true
                        fetched = 0
                        continue
                    }
                }
                break
            }
        }

        let commitScopes = DeviceLifecycleStore.persistedCutoffScopes()
        if commitScopes != scopes {
            scopes = commitScopes
            scopesChanged = true
        }

        aggregate = working
        anchor = workingAnchor
        if fetched > 0 || rebuilt {
            cache.save(aggregate: aggregate, anchor: anchor)
        }
        let unchanged = skipSnapshotIfUnchanged && fetched == 0 && !rebuilt && !aggregate.isEmpty && !scopesChanged
        return SyncResult(
            snapshot: unchanged ? nil : snapshot(cutoffScopes: scopes),
            isEmpty: aggregate.isEmpty,
            newSamples: fetched,
            rebuilt: rebuilt
        )
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
