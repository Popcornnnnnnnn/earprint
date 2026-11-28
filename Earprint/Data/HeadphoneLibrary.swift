import Foundation
import HealthKit
import SwiftUI

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
    @Published private(set) var snapshot: LibrarySnapshot? {
        didSet { rebuildDerivedCache() }
    }
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var lastNewSamples: Int = 0
    @Published var needsHealthOnboarding = false

    static let onboardingSeenKey = "onboarding.healthIntroSeen"
    static let onboardingSkippedKey = "onboarding.healthIntroSkipped"

    #if DEBUG || EARPRINT_REPEAT_CARD_HINT
    nonisolated static var isFirstLaunchSimulation: Bool {
        ProcessInfo.processInfo.arguments.contains("-firstLaunch")
    }
    #endif

    /// Precomputed display models so SwiftUI reads stay O(1) with zero per-frame allocations or DateFormatter work.
    private(set) var cards: [HeadphoneCard] = []
    private(set) var homeSummary: ListeningSummary = SampleData.summary
    private var cachedCombinedSummary: ListeningSummary = SampleData.summary
    private var cachedSummariesByID: [String: ListeningSummary] = [:]
    private var cacheDayStart: Date = Calendar.current.startOfDay(for: Date())
    private var cacheLanguage: AppLanguage = AppLanguage.current

    #if DEBUG
    @Published private(set) var isSeeding = false
    @Published private(set) var seedStatus: String?
    #endif

    private let ingestor: HealthIngestor
    private var started = false
    private var observing = false
    private var retirementScopeVersion: UInt64 = 0

    init(store: HKHealthStore = HKHealthStore(), cache: AggregateCache = AggregateCache()) {
        // Instant launch: decode the on-disk aggregate cache ONCE and share it with HealthIngestor.
        #if DEBUG || EARPRINT_REPEAT_CARD_HINT
        let simulateFirstLaunch = Self.isFirstLaunchSimulation
        let saved = simulateFirstLaunch ? nil : cache.load()
        self.ingestor = HealthIngestor(store: store, cache: cache, initialSaved: saved, ignoreCache: simulateFirstLaunch)
        #else
        let saved = cache.load()
        self.ingestor = HealthIngestor(store: store, cache: cache, initialSaved: saved)
        #endif
        if let saved, !saved.aggregate.isEmpty {
            let cached = LibrarySnapshot(
                aggregate: saved.aggregate,
                cutoffScopes: DeviceLifecycleStore.persistedCutoffScopes()
            )
            self.snapshot = cached
            self.state = .ready
        } else if !HealthIngestor.isAvailable {
            self.state = .unavailable
        }
        rebuildDerivedCache()
    }

    /// True when HealthKit data is not available and Debug views are previewing deterministic sample data.
    var isShowingSampleData: Bool {
        #if DEBUG
        return snapshot == nil || snapshot?.isEmpty == true
        #else
        return false
        #endif
    }

    /// True in Release builds when Apple Health has not yet provided any headphone listening samples.
    var isShowingEmptyState: Bool {
        #if DEBUG
        return false
        #else
        return snapshot == nil || snapshot?.isEmpty == true
        #endif
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    /// Rebuilds cached `cards` and `ListeningSummary` instances when language or local calendar day changes.
    func refreshDerivedCacheIfNeeded(force: Bool = false) {
        let today = Calendar.current.startOfDay(for: Date())
        let lang = AppLanguage.current
        guard force || today != cacheDayStart || lang != cacheLanguage else { return }
        objectWillChange.send()
        rebuildDerivedCache(now: Date())
    }

    private func rebuildDerivedCache(now: Date = Date(), calendar: Calendar = .current) {
        cacheDayStart = calendar.startOfDay(for: now)
        cacheLanguage = AppLanguage.current

        if let snapshot, !snapshot.isEmpty {
            let builtCards = snapshot.cards(now: now, calendar: calendar)
            let primarySummary = snapshot.homeSummary(now: now, calendar: calendar) ?? SampleData.summary
            let combined = snapshot.combinedHomeSummary(now: now, calendar: calendar) ?? primarySummary
            var byID: [String: ListeningSummary] = [:]
            byID.reserveCapacity(snapshot.devices.count * 2)
            for device in snapshot.devices {
                if let summary = snapshot.summary(for: device.id, now: now, calendar: calendar) {
                    byID[device.id] = summary
                    for alias in device.aliasIDs {
                        byID[alias] = summary
                    }
                }
            }
            self.cards = builtCards
            self.homeSummary = primarySummary
            self.cachedCombinedSummary = combined
            self.cachedSummariesByID = byID
        } else {
            #if DEBUG
            let sampleCards = SampleCards.all
            self.cards = sampleCards
            let localizedSamplePrimary = Self.localizedSamplePrimary(now: now, calendar: calendar)
            self.homeSummary = localizedSamplePrimary
            self.cachedCombinedSummary = sampleCards.count > 1
                ? Self.combinedSampleSummary(from: sampleCards, now: now, calendar: calendar)
                : localizedSamplePrimary
            var byID: [String: ListeningSummary] = [:]
            byID.reserveCapacity(sampleCards.count)
            for card in sampleCards {
                let summary = Self.sampleSummary(for: card, now: now, calendar: calendar)
                byID[card.id] = summary
                for alias in card.aliasIDs {
                    byID[alias] = summary
                }
            }
            self.cachedSummariesByID = byID
            #else
            self.cards = []
            let empty = ListeningSummary.empty(now: now, calendar: calendar)
            self.homeSummary = empty
            self.cachedCombinedSummary = empty
            self.cachedSummariesByID = [:]
            #endif
        }
    }

    /// Returns a real `DeviceDossier` hydrated from Apple Health sessions, or `nil` in sample mode.
    func dossier(
        for card: HeadphoneCard,
        retirement: DeviceRetirement? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DeviceDossier? {
        snapshot?.dossier(forCardID: card.id, retirement: retirement, now: now, calendar: calendar)
    }

    /// O(1) cached summary for either all connected headphones (`cardID == nil`) or a specific card (`cardID != nil`).
    func summary(forCardID cardID: String?) -> ListeningSummary {
        if let cardID, let cached = cachedSummariesByID[cardID] {
            return cached
        }
        return cachedCombinedSummary
    }

    private static func localizedSamplePrimary(now: Date, calendar: Calendar) -> ListeningSummary {
        var summary = SampleData.summary
        summary.periodLabel = DateText.weekRange(endingAt: now, calendar: calendar)
        if let parsed = DateText.parse("2026.10.30", dateFormat: "yyyy.MM.dd", calendar: calendar) {
            summary.firstUse = DateText.dotted(parsed, calendar: calendar)
        }
        return summary
    }

    private static func localizedSampleFirstUse(_ dottedDate: String, calendar: Calendar) -> String {
        guard let parsed = DateText.parse(dottedDate, dateFormat: "yyyy.MM.dd", calendar: calendar) else {
            return dottedDate
        }
        return DateText.dotted(parsed, calendar: calendar)
    }

    private static func sampleSummary(for card: HeadphoneCard, now: Date, calendar: Calendar) -> ListeningSummary {
        ListeningSummary(
            deviceName: card.nickname,
            deviceModel: card.model,
            deviceSymbol: card.symbol,
            periodLabel: DateText.weekRange(endingAt: now, calendar: calendar),
            grid: card.grid,
            lifetimeMinutes: card.lifetimeMinutes,
            sessions: card.sessions,
            averageSessionMinutes: card.sessions > 0 ? card.lifetimeMinutes / Double(card.sessions) : 0,
            longestSessionMinutes: card.longestMinutes,
            firstUse: localizedSampleFirstUse(card.firstMet, calendar: calendar)
        )
    }

    private static func combinedSampleSummary(from cards: [HeadphoneCard], now: Date, calendar: Calendar) -> ListeningSummary {
        let dayCount = cards.map(\.grid.days).max() ?? 28
        var combinedMinutes = Array(repeating: Array(repeating: 0.0, count: 24), count: dayCount)
        var combinedEnergy = combinedMinutes

        for c in cards {
            let dayOffset = max(0, dayCount - c.grid.days)
            for day in 0..<c.grid.days {
                let targetDay = dayOffset + day
                for hour in 0..<24 {
                    let mins = c.grid.minutes[day][hour]
                    guard mins > 0 else { continue }
                    let db = c.grid.decibels[day][hour]
                    combinedMinutes[targetDay][hour] += mins
                    combinedEnergy[targetDay][hour] += pow(10, db / 10) * mins
                }
            }
        }

        var combinedDecibels = Array(repeating: Array(repeating: 0.0, count: 24), count: dayCount)
        for day in 0..<dayCount {
            for hour in 0..<24 where combinedMinutes[day][hour] > 0 {
                combinedDecibels[day][hour] = 10 * log10(combinedEnergy[day][hour] / combinedMinutes[day][hour])
            }
        }

        let totalMinutes = cards.reduce(0) { $0 + $1.lifetimeMinutes }
        let totalSessions = cards.reduce(0) { $0 + $1.sessions }
        let longest = cards.map(\.longestMinutes).max() ?? 0
        let avgSession = totalSessions > 0 ? totalMinutes / Double(totalSessions) : 0
        let earliestFirst = cards
            .compactMap { DateText.parse($0.firstMet, dateFormat: "yyyy.MM.dd", calendar: calendar) }
            .min()
            .map { DateText.dotted($0, calendar: calendar) } ?? "—"

        return ListeningSummary(
            deviceName: AppLanguage.current.text("All Headphones"),
            deviceModel: AppLanguage.current.text("%lld pairs", cards.count),
            deviceSymbol: "headphones",
            periodLabel: DateText.weekRange(endingAt: now, calendar: calendar),
            grid: ListeningGrid(minutes: combinedMinutes, decibels: combinedDecibels),
            lifetimeMinutes: totalMinutes,
            sessions: totalSessions,
            averageSessionMinutes: avgSession,
            longestSessionMinutes: longest,
            firstUse: earliestFirst
        )
    }

    /// Short badge label shown when HealthKit data is not yet available.
    var sampleBadgeText: LocalizedStringKey {
        #if targetEnvironment(simulator)
        if state == .empty || state == .idle { return "Sample data · Simulator" }
        #endif
        #if DEBUG
        switch state {
        case .idle: return "Sample data"
        case .loading(let n): return n > 0 ? "Syncing \(n)…" : "Syncing Health…"
        case .empty: return "Sample data · No Health records"
        case .unavailable: return "Sample data · Health unavailable"
        case .failed: return "Sample data"
        case .ready: return ""
        }
        #else
        switch state {
        case .idle: return "Apple Health"
        case .loading(let n): return n > 0 ? "Syncing \(n)…" : "Syncing Health…"
        case .empty: return "No Health records"
        case .unavailable: return "Health unavailable"
        case .failed: return "Sync needed"
        case .ready: return ""
        }
        #endif
    }

    /// Detailed hint for empty / denied / error states.
    var statusMessage: LocalizedStringKey? {
        #if DEBUG
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
        #else
        switch state {
        case .idle:
            return "Connect Apple Health to see your headphones. iOS records audio levels while playing audio (not silent ANC)."
        case .loading(let count):
            return count > 0 ? "Reading Apple Health… \(count) samples" : "Reading Apple Health…"
        case .empty:
            return "No headphone samples found in Apple Health. Play audio through headphones or enable access in Settings › Health › Data Access › Earprint."
        case .unavailable:
            return "Apple Health is not available on this device."
        case .failed(let message):
            return "Couldn't read Apple Health: \(message)"
        case .ready:
            return nil
        }
        #endif
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

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-onboarding") {
            needsHealthOnboarding = true
            return
        }
        #endif

        #if DEBUG || EARPRINT_REPEAT_CARD_HINT
        if Self.isFirstLaunchSimulation {
            needsHealthOnboarding = true
            return
        }
        #endif

        let authStatus = await ingestor.authorizationRequestStatus()
        if authStatus == .unnecessary || snapshot != nil {
            UserDefaults.standard.set(true, forKey: Self.onboardingSeenKey)
            UserDefaults.standard.set(false, forKey: Self.onboardingSkippedKey)
            await sync()
            await ensureObserving()
        } else {
            #if !targetEnvironment(simulator)
            if !UserDefaults.standard.bool(forKey: Self.onboardingSeenKey) {
                needsHealthOnboarding = true
            } else if !UserDefaults.standard.bool(forKey: Self.onboardingSkippedKey) {
                await connectAndSync()
            }
            #endif
        }
    }

    #if DEBUG || EARPRINT_REPEAT_CARD_HINT
    /// Replays a cold-start first launch without deleting the user's cached Health history on disk.
    func previewFirstLaunch(afterDelayMilliseconds delayMs: UInt64 = 350) async {
        await ingestor.resetInMemoryState()
        snapshot = nil
        state = .idle
        if delayMs > 0 {
            try? await Task.sleep(for: .milliseconds(delayMs))
        }
        needsHealthOnboarding = true
    }
    #endif

    func completeOnboarding(connect: Bool) async {
        UserDefaults.standard.set(true, forKey: Self.onboardingSeenKey)
        UserDefaults.standard.set(!connect, forKey: Self.onboardingSkippedKey)
        needsHealthOnboarding = false
        if connect {
            await connectAndSync()
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
        let canReuseSnapshot = snapshot.map {
            Calendar.current.isDate($0.generatedAt, inSameDayAs: Date())
        } ?? false
        let scopeVersionBefore = retirementScopeVersion

        do {
            let result = try await ingestor.sync(skipSnapshotIfUnchanged: canReuseSnapshot) { [weak self] fetched in
                Task { @MainActor [weak self] in
                    guard let self, self.snapshot == nil else { return }
                    self.state = .loading(samplesFetched: fetched)
                }
            }
            if !silent || result.newSamples > 0 || result.rebuilt || lastSyncDate == nil {
                lastSyncDate = Date()
            }
            if lastNewSamples != result.newSamples {
                lastNewSamples = result.newSamples
            }
            if result.isEmpty {
                if snapshot != nil { snapshot = nil }
                if state != .empty { state = .empty }
            } else if retirementScopeVersion != scopeVersionBefore {
                let recoveryVersion = retirementScopeVersion
                let latestScopes = DeviceLifecycleStore.persistedCutoffScopes()
                if await ingestor.needsRebuild(for: latestScopes) {
                    if recoveryVersion == retirementScopeVersion {
                        await sync(silent: true)
                    }
                    return
                }
                if let refreshed = await ingestor.cachedSnapshot(cutoffScopes: latestScopes),
                   recoveryVersion == retirementScopeVersion {
                    snapshot = refreshed
                    if state != .ready { state = .ready }
                }
            } else if let fresh = result.snapshot {
                snapshot = fresh
                if state != .ready { state = .ready }
            } else if state != .ready {
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

    func handleRetirementScopesChanged(_ scopes: [RetirementCutoffScope]) async {
        retirementScopeVersion &+= 1
        let version = retirementScopeVersion
        guard snapshot != nil else { return }
        if let refreshed = await ingestor.cachedSnapshot(cutoffScopes: scopes),
           version == retirementScopeVersion {
            snapshot = refreshed
        }
        if HealthIngestor.isAvailable,
           await ingestor.needsRebuild(for: scopes),
           version == retirementScopeVersion {
            await sync(silent: true)
        }
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
