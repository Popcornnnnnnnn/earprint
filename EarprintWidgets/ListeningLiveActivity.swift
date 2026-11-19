import ActivityKit
import SwiftUI
import WidgetKit

/// "Listening now" Live Activity on the Lock Screen and in the Dynamic Island.
struct ListeningLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ListeningActivityAttributes.self) { context in
            LiveActivityLockScreenView(attributes: context.attributes, state: context.state)
                .padding(16)
                .activityBackgroundTint(Color(red: 0.04, green: 0.04, blue: 0.07).opacity(0.82))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(EarprintLink.card(context.attributes.cardID))
        } dynamicIsland: { context in
            let color = Theme.levelColor(db: context.state.decibels)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ListeningBadge(symbol: context.attributes.deviceSymbol, color: color, size: 44)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    DecibelReadout(decibels: context.state.decibels)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    IslandExpandedCenter(attributes: context.attributes, state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    RestCountdown(state: context.state)
                        .padding(.horizontal, 6)
                        .padding(.top, 4)
                }
            } compactLeading: {
                IslandCompactLeading(attributes: context.attributes, state: context.state)
            } compactTrailing: {
                IslandCompactTrailing(state: context.state)
            } minimal: {
                IslandCompactLeading(attributes: context.attributes, state: context.state)
            }
            .widgetURL(EarprintLink.card(context.attributes.cardID))
            .keylineTint(color)
        }
    }
}

#Preview("Live Activity", as: .content, using: ListeningActivityAttributes.preview) {
    ListeningLiveActivity()
} contentStates: {
    ListeningActivityAttributes.ContentState.preview()
}

#Preview("Island expanded", as: .dynamicIsland(.expanded), using: ListeningActivityAttributes.preview) {
    ListeningLiveActivity()
} contentStates: {
    ListeningActivityAttributes.ContentState.preview()
}
