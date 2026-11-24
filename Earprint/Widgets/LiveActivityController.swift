import ActivityKit
import Foundation

/// Manages the "Listening now" Live Activity for audio routes, Shortcuts, and debug controls.
@MainActor
@Observable
final class LiveActivityController {
    static let shared = LiveActivityController()
    private static let restIntervalKey = "earprint.liveActivity.restIntervalMinutes"
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
    }

    private static func clampRestInterval(_ minutes: Int) -> Int {
        min(max(minutes, restIntervalRange.lowerBound), restIntervalRange.upperBound)
    }

    func start(card: HeadphoneCard, startedAt: Date = Date(), decibels: Double = 63) {
        start(deviceName: card.nickname, symbol: card.symbol, cardID: card.id, startedAt: startedAt, decibels: decibels)
    }

    func syncWithActiveRoute(cards: [HeadphoneCard], routeMonitor: ActiveAudioRouteMonitor,
                             decibels: Double = 63, proUnlocked: Bool) {
        guard let card = routeMonitor.activeMatchedCard(in: cards) else {
            if isRunning || pendingRouteStart != nil { stop() }
            return
        }
        pendingRouteStart?.cancel()
        pendingRouteStart = nil
        guard proUnlocked, activity?.attributes.cardID != card.id else { return }

        if isRunning { stop() }
        if let endingActivity {
            // ActivityKit ends asynchronously. Wait before requesting a replacement.
            pendingRouteStart = Task {
                await endingActivity.value
                guard !Task.isCancelled else { return }
                start(card: card, decibels: decibels)
            }
        } else {
            start(card: card, decibels: decibels)
        }
    }

    func start(deviceName: String, symbol: String, cardID: String, startedAt: Date = Date(), decibels: Double = 63) {
        pendingRouteStart?.cancel()
        pendingRouteStart = nil
        guard activity == nil else { return }
        guard areActivitiesEnabled else {
            lastError = "Live Activities are turned off for Earprint in Settings."
            return
        }
        let attributes = ListeningActivityAttributes(deviceName: deviceName, deviceSymbol: symbol, cardID: cardID)
        let state = ListeningActivityAttributes.ContentState(startedAt: startedAt, decibels: decibels,
                                                             restAt: startedAt.addingTimeInterval(restInterval))
        do {
            activity = try Activity.request(attributes: attributes,
                                            content: ActivityContent(state: state, staleDate: state.restAt.addingTimeInterval(30 * 60)),
                                            pushType: nil)
            isRunning = true
            lastError = nil
        } catch {
            lastError = error.localizedDescription
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

    func stop() {
        pendingRouteStart?.cancel()
        pendingRouteStart = nil
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

    func stopAndWait() async {
        stop()
        await endingActivity?.value
    }
}
