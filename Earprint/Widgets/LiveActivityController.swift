import ActivityKit
import Foundation

/// Manages the "Listening now" Live Activity for audio routes, Shortcuts, and debug controls.
@MainActor
@Observable
final class LiveActivityController {
    static let shared = LiveActivityController()
    private static let restIntervalKey = "earprint.liveActivity.restIntervalMinutes"
    private static let manualActivityIDKey = "earprint.liveActivity.manualActivityID"
    private static let restIntervalRange = 15...180

    /// Rest reminder after this much continuous listening.
    var restIntervalMinutes: Int {
        get { storedRestIntervalMinutes }
        set {
            let minutes = Self.clampRestInterval(newValue)
            storedRestIntervalMinutes = minutes
            defaults.set(minutes, forKey: Self.restIntervalKey)
        }
    }

    var restInterval: TimeInterval {
        get { TimeInterval(restIntervalMinutes * 60) }
        set {
            guard newValue.isFinite else { return }
            let minutes = min(max(newValue / 60, Double(Self.restIntervalRange.lowerBound)),
                              Double(Self.restIntervalRange.upperBound))
            restIntervalMinutes = Int(minutes.rounded())
        }
    }

    private(set) var isRunning = false
    private(set) var lastError: String?

    private let defaults: UserDefaults
    private var storedRestIntervalMinutes: Int
    private var activity: Activity<ListeningActivityAttributes>?
    private var manuallyStoppedCardID: String?
    private var startedManually = false
    @ObservationIgnored private var endingActivity: Task<Void, Never>?
    @ObservationIgnored private var pendingRouteStart: Task<Void, Never>?

    var areActivitiesEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    convenience init() {
        self.init(defaults: .standard)
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        storedRestIntervalMinutes = Self.clampRestInterval(defaults.object(forKey: Self.restIntervalKey) as? Int ?? 60)
        // Re-attach to an activity that survived an app relaunch.
        activity = Activity<ListeningActivityAttributes>.activities.first
        isRunning = activity != nil
        startedManually = Self.restoreManualState(activeActivityID: activity?.id, defaults: defaults)
    }

    static func persistManualState(_ value: Bool, activeActivityID: String?, defaults: UserDefaults) {
        if value, let activeActivityID {
            defaults.set(activeActivityID, forKey: manualActivityIDKey)
        } else if defaults.object(forKey: manualActivityIDKey) != nil {
            defaults.removeObject(forKey: manualActivityIDKey)
        }
    }

    static func restoreManualState(activeActivityID: String?, defaults: UserDefaults) -> Bool {
        guard let activeActivityID else {
            if defaults.object(forKey: manualActivityIDKey) != nil {
                defaults.removeObject(forKey: manualActivityIDKey)
            }
            return false
        }
        if defaults.string(forKey: manualActivityIDKey) == activeActivityID {
            return true
        }
        if defaults.object(forKey: manualActivityIDKey) != nil {
            defaults.removeObject(forKey: manualActivityIDKey)
        }
        return false
    }

    private func setStartedManually(_ value: Bool, activityID: String?) {
        startedManually = value
        Self.persistManualState(value, activeActivityID: activityID, defaults: defaults)
    }

    private static func clampRestInterval(_ minutes: Int) -> Int {
        min(max(minutes, restIntervalRange.lowerBound), restIntervalRange.upperBound)
    }

    @discardableResult
    func start(card: HeadphoneCard, startedAt: Date = Date(), decibels: Double = 0, manual: Bool = false) -> Bool {
        start(deviceName: card.nickname, symbol: card.symbol, cardID: card.id, startedAt: startedAt, decibels: decibels, manual: manual)
    }

    func syncWithActiveRoute(
        cards: [HeadphoneCard],
        routeMonitor: ActiveAudioRouteMonitor,
        decibels: Double = 0,
        decibelsForCard: ((HeadphoneCard) -> Double)? = nil,
        proUnlocked: Bool,
        proResolved: Bool = true
    ) {
        if proResolved && !proUnlocked {
            pendingRouteStart?.cancel()
            pendingRouteStart = nil
            if isRunning { stop(manual: false) }
            return
        }

        guard let card = routeMonitor.activeMatchedCard(in: cards) else {
            manuallyStoppedCardID = nil
            if !startedManually && (isRunning || pendingRouteStart != nil) {
                stop(manual: false)
            }
            return
        }
        if let stoppedID = manuallyStoppedCardID, stoppedID != card.id {
            manuallyStoppedCardID = nil
        }

        if startedManually && isRunning && activity?.attributes.cardID != card.id {
            return
        }

        let resolvedDB = max(0, decibelsForCard?(card) ?? decibels)
        if activity?.attributes.cardID == card.id {
            if let currentDB = activity?.content.state.decibels, abs(currentDB - resolvedDB) >= 1.0 {
                update(decibels: resolvedDB)
            }
            return
        }

        pendingRouteStart?.cancel()
        pendingRouteStart = nil
        guard proUnlocked, manuallyStoppedCardID != card.id else { return }

        if isRunning { stop(manual: false) }
        if let endingActivity {
            // ActivityKit ends asynchronously. Wait before requesting a replacement.
            pendingRouteStart = Task {
                await endingActivity.value
                guard !Task.isCancelled else { return }
                start(card: card, decibels: resolvedDB)
            }
        } else {
            start(card: card, decibels: resolvedDB)
        }
    }

    @discardableResult
    func start(deviceName: String, symbol: String, cardID: String, startedAt: Date = Date(), decibels: Double = 0, manual: Bool = false) -> Bool {
        manuallyStoppedCardID = nil
        pendingRouteStart?.cancel()
        pendingRouteStart = nil
        if let current = activity {
            if manual { setStartedManually(true, activityID: current.id) }
            return true
        }
        guard areActivitiesEnabled else {
            lastError = "Live Activities are turned off for Earprint in Settings."
            return false
        }
        let attributes = ListeningActivityAttributes(deviceName: deviceName, deviceSymbol: symbol, cardID: cardID)
        let state = ListeningActivityAttributes.ContentState(startedAt: startedAt, decibels: max(0, decibels),
                                                             restAt: startedAt.addingTimeInterval(restInterval))
        do {
            let requested = try Activity.request(attributes: attributes,
                                                 content: ActivityContent(state: state, staleDate: state.restAt.addingTimeInterval(30 * 60)),
                                                 pushType: nil)
            activity = requested
            setStartedManually(manual, activityID: requested.id)
            isRunning = true
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Push a new loudness reading (keep updates to every few minutes in real use).
    func update(decibels: Double) {
        guard let activity else { return }
        var state = activity.content.state
        state.decibels = decibels
        Task { await activity.update(ActivityContent(state: state, staleDate: state.restAt.addingTimeInterval(30 * 60))) }
    }

    /// Restart the rest countdown (user took a break).
    func resetRest() {
        Task { await resetRestAndWait() }
    }

    func resetRestAndWait() async {
        guard let activity else { return }
        var state = activity.content.state
        state.restAt = Date().addingTimeInterval(restInterval)
        await activity.update(ActivityContent(state: state, staleDate: nil))
    }

    func stop(manual: Bool = false) {
        pendingRouteStart?.cancel()
        pendingRouteStart = nil
        setStartedManually(false, activityID: nil)
        if manual {
            manuallyStoppedCardID = activity?.attributes.cardID ?? Activity<ListeningActivityAttributes>.activities.first?.attributes.cardID
        }
        let activities = activity.map { [$0] } ?? Activity<ListeningActivityAttributes>.activities
        activity = nil
        isRunning = false
        guard !activities.isEmpty else { return }
        let previousEnd = endingActivity
        endingActivity = Task {
            await previousEnd?.value
            for item in activities {
                await item.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    func stopAndWait(manual: Bool = false) async {
        stop(manual: manual)
        await endingActivity?.value
    }
}
