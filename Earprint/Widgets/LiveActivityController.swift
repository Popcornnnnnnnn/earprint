import ActivityKit
import Foundation

/// Starts, updates and ends the "Listening now" Live Activity.
///
/// Today it is driven by debug buttons on the Data probe tab. Real triggering (planned):
/// observe `AVAudioSession.routeChangeNotification`; when the output route becomes Bluetooth
/// headphones (`.bluetoothA2DP` / `.bluetoothLE`) and audio is playing, call `start(...)`;
/// when the route leaves headphones, call `stop()`. Note iOS only lets the app start an activity
/// while it is in the foreground (or via an ActivityKit push), so background starts need push tokens
/// from a server, or an App Intent the user runs (e.g. from a Focus or Shortcuts automation).
@MainActor
@Observable
final class LiveActivityController {
    static let shared = LiveActivityController()

    /// Rest reminder after this much continuous listening.
    var restInterval: TimeInterval = 60 * 60
    private(set) var isRunning = false
    private(set) var lastError: String?

    private var activity: Activity<ListeningActivityAttributes>?

    var areActivitiesEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    init() {
        // Re-attach to an activity that survived an app relaunch.
        activity = Activity<ListeningActivityAttributes>.activities.first
        isRunning = activity != nil
    }

    func start(deviceName: String, symbol: String, cardID: String, startedAt: Date = Date(), decibels: Double = 63) {
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
        guard let activity else { return }
        var state = activity.content.state
        state.restAt = Date().addingTimeInterval(restInterval)
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    func stop() {
        let ending = activity
        activity = nil
        isRunning = false
        Task {
            for item in Activity<ListeningActivityAttributes>.activities where item.id == ending?.id || ending == nil {
                await item.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
