import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// "Listening now" Live Activity. Shared by the app (starts/updates/ends it) and the widget extension (draws it).
struct ListeningActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// When the current headphone session began. Elapsed time is drawn by the system from this date,
        /// so the timer keeps ticking without updates.
        var startedAt: Date
        /// Latest Leq in dB(A). Update every few minutes at most (each update costs budget).
        var decibels: Double
        /// When to suggest a break. Drawn as a system countdown.
        var restAt: Date
    }

    /// Display name of the headphones, e.g. "🧸's AirPods Pro".
    var deviceName: String
    /// SF Symbol, e.g. "airpodspro".
    var deviceSymbol: String
    /// Matches `WidgetSnapshot.Card.id`, so tapping the activity can open that card.
    var cardID: String
}

extension ListeningActivityAttributes {
    static let preview = ListeningActivityAttributes(deviceName: "🧸's AirPods Pro", deviceSymbol: "airpodspro", cardID: "pro2")
}

extension ListeningActivityAttributes.ContentState {
    static func preview(now: Date = Date()) -> Self {
        Self(startedAt: now.addingTimeInterval(-72 * 60), decibels: 63, restAt: now.addingTimeInterval(40 * 60))
    }
}
#endif
