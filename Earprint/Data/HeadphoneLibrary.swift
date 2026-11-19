import Foundation
import HealthKit

/// Main-actor view model that bridges `HealthIngestor` (off-main-actor HealthKit sync + disk cache)
/// into SwiftUI views (`CollectionView`, `HomeView`, `ProbeView`).
///
/// Design:
/// - **Instant launch**: reads the disk-cached `ListeningAggregate` synchronously on init so the
///   very first frame shows real stats if the user has synced before.
/// - **Incremental updates**: syncs only samples added since the saved `HKQueryAnchor`, and runs
///   an `HKObserverQuery` while the app is open so new listening appears automatically.
/// - **Graceful fallback**: whenever Health is unavailable, not yet connected, read-denied, or has
///   0 headphone samples (such as a fresh simulator), views receive deterministic sample data along
///   with `isShowingSampleData == true` so the UI shows a clear "Sample data" badge.
@MainActor
final class HeadphoneLibrary: ObservableObject {
    enum State: Equatable {
        case idle
        case loading(samplesFetched: Int)
        case ready
        case empty
        case unavailable
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var snapshot: LibrarySnapshot?
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var lastNewSamples: Int = 0

    #if DEBUG
    @Published private(set) var isSeeding = false
    @Published private(set) var seedStatus: String?
    #endif

    private let ingestor: HealthIngestor
    private var started = false
    private var observing = false

    init(store: HKHealthStore = HKHealthStore(), cache: AggregateCache = AggregateCache()) {
        self.ingestor = HealthIngestor(store: store, cache: cache)
        // Instant launch: hydrate from the on-disk aggregate cache before the first frame renders.
        if let saved = cache.load(), !saved.aggregate.isEmpty {
            let cached = LibrarySnapshot(aggregate: saved.aggregate)
            self.snapshot = cached
            self.state = .ready
        } else if !HealthIngestor.isAvailable {
            self.state = .unavailable
        }
    }

    /// True when real HealthKit data is not available and views are displaying sample data.
    var isShowingSampleData: Bool {
        snapshot == nil || snapshot?.isEmpty == true
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var cards: [HeadphoneCard] {
        if let snapshot, !snapshot.isEmpty {
            return snapshot.cards()
        }
        return SampleCards.all
    }

    var homeSummary: ListeningSummary {
        if let snapshot, let summary = snapshot.homeSummary() {
            return summary
        }
        return SampleData.summary
    }

    /// Short badge label shown when falling back to sample data.
    var sampleBadgeText: String {
        #if targetEnvironment(simulator)
        if state == .empty || state == .idle { return "Sample data · Simulator" }
        #endif
        switch state {
        case .idle: return "Sample data"
        case .loading(let n): return n > 0 ? "Syncing \(n)…" : "Syncing Health…"
        case .empty: return "Sample data · No Health records"
        case .unavailable: return "Sample data · Health unavailable"
        case .failed: return "Sample data"
        case .ready: return ""
        }
    }

    /// Detailed hint for empty / denied / error states.
    var statusMessage: String? {
        switch state {
        case .idle:
            return "Previewing sample data. Connect Apple Health to see your real headphones."
        case .loading(let count):
            return count > 0 ? "Reading Apple Health… \(count) samples" : "Reading Apple Health…"
        case .empty:
            // HealthKit intentionally hides read-denial from apps (0 samples looks identical to denied).
            return "No headphone samples found in Apple Health. If you denied access, enable it in Settings › Health › Data Access › Earprint."
        case .unavailable:
            return "Apple Health is not available on this device. Showing sample data."
        case .failed(let message):
            return "Couldn't read Apple Health: \(message)"
        case .ready:
            return nil
        }
    }

    /// Called once when the app launches.
    /// - If `-seedHealth` is passed (Debug only), seeds simulator HealthKit and syncs immediately.
    /// - If read authorization was already prompted (or we already have a disk cache), syncs silently
    ///   and starts `HKObserverQuery` without interrupting launch with a system sheet.
    func start() async {
        guard !started else { return }
        started = true

        guard HealthIngestor.isAvailable else {
            state = .unavailable
            return
        }

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-seedHealth") {
            // Wait for the window scene to become active so HealthKit can present its permission sheet.
            try? await Task.sleep(for: .milliseconds(800))
            await seedSimulatorHealth()
            return
        }
        #endif

        let authStatus = await ingestor.authorizationRequestStatus()
        if authStatus == .unnecessary || snapshot != nil {
            await sync()
            await ensureObserving()
        }
    }

    /// Explicitly prompts for HealthKit read permission (if needed), syncs all new samples,
    /// and starts live observation.
    func connectAndSync() async {
        guard HealthIngestor.isAvailable else {
            state = .unavailable
            return
        }
        if snapshot == nil {
            state = .loading(samplesFetched: 0)
        }
        do {
            try await ingestor.requestAuthorization()
            await sync()
            await ensureObserving()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Incremental anchored sync off the main actor.
    func sync(silent: Bool = false) async {
        guard HealthIngestor.isAvailable else {
            state = .unavailable
            return
        }
        if !silent && snapshot == nil {
            state = .loading(samplesFetched: 0)
        }
        do {
            let result = try await ingestor.sync { [weak self] fetched in
                Task { @MainActor [weak self] in
                    guard let self, self.snapshot == nil else { return }
                    self.state = .loading(samplesFetched: fetched)
                }
            }
            lastSyncDate = Date()
            lastNewSamples = result.newSamples
            if result.snapshot.isEmpty {
                snapshot = nil
                state = .empty
            } else {
                snapshot = result.snapshot
                state = .ready
            }
        } catch {
            if snapshot == nil {
                state = .failed(error.localizedDescription)
            }
        }
    }

    /// Drops the disk cache and rebuilds the aggregate from scratch from HealthKit.
    func resetCacheAndResync() async {
        await ingestor.resetCache()
        snapshot = nil
        await sync()
    }

    private func ensureObserving() async {
        guard !observing else { return }
        observing = true
        await ingestor.startObserving { [weak self] in
            Task { @MainActor [weak self] in
                await self?.sync(silent: true)
            }
        }
    }

    #if DEBUG
    /// Debug-only: seeds realistic multi-device samples into HealthKit and runs a full sync.
    func seedSimulatorHealth() async {
        guard HealthIngestor.isAvailable else {
            seedStatus = "HealthKit is unavailable on this device."
            return
        }
        isSeeding = true
        seedStatus = "Writing realistic samples to Apple Health…"
        defer { isSeeding = false }
        do {
            let report = try await HealthKitSeeder.seed()
            await ingestor.resetCache()
            await sync()
            await ensureObserving()
            let count = snapshot?.devices.count ?? 0
            seedStatus = "Seeded \(report.samplesWritten) samples across \(report.deviceCount) devices (loaded \(count) real cards)."
        } catch {
            seedStatus = "Seed failed: \(error.localizedDescription)"
        }
    }

    /// Debug-only: removes seeded samples from HealthKit and rebuilds the cache.
    func clearSeededHealth() async {
        isSeeding = true
        seedStatus = "Removing seeded samples…"
        defer { isSeeding = false }
        do {
            let deleted = try await HealthKitSeeder.clearSeeded()
            await ingestor.resetCache()
            snapshot = nil
            await sync()
            seedStatus = "Deleted \(deleted) seeded samples."
        } catch {
            seedStatus = "Clear failed: \(error.localizedDescription)"
        }
    }
    #endif
}
