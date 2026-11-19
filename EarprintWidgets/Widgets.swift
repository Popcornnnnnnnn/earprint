import SwiftUI
import WidgetKit

// MARK: - Today (small + Lock Screen rectangular + inline)

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.today, provider: SnapshotProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("Today's listening, your top headphone card and a safe-level dot. Tap the card to flip to the next one.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline])
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            TodayRectangularView(snapshot: entry.snapshot, date: entry.date)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(EarprintLink.rings)
        case .accessoryInline:
            TodayInlineView(snapshot: entry.snapshot, date: entry.date)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(EarprintLink.rings)
        default:
            SmallTodayView(snapshot: entry.snapshot, featured: entry.featured, date: entry.date)
                .containerBackground(for: .widget) {
                    WidgetBackdrop(glow: entry.featured?.rarity.glow ?? Theme.quiet.color)
                }
                .widgetURL(entry.featured?.deepLink ?? EarprintLink.collection)
        }
    }
}

// MARK: - Card shelf (medium)

struct CardShelfWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.shelf, provider: SnapshotProvider()) { entry in
            CardShelfView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) {
                    WidgetBackdrop(glow: entry.snapshot.topCard?.rarity.glow ?? Theme.quiet.color,
                                   secondGlow: Theme.quiet.color, glowCenter: .trailing)
                }
                .widgetURL(EarprintLink.collection)
        }
        .configurationDisplayName("Card shelf")
        .description("Your headphone cards with lifetime hours. Tap a card to open it.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Earprint ring (large)

struct EarprintRingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.ring, provider: SnapshotProvider()) { entry in
            EarprintRingView(snapshot: entry.snapshot, date: entry.date)
                .containerBackground(for: .widget) {
                    WidgetBackdrop(glow: Theme.quiet.color, secondGlow: Theme.moderate.color, glowCenter: .topLeading)
                }
                .widgetURL(EarprintLink.rings)
        }
        .configurationDisplayName("Earprint")
        .description("Four weeks of listening as your Earprint ring, plus your weekly hearing budget.")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Hearing budget (Lock Screen circular)

struct BudgetWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.budget, provider: SnapshotProvider()) { entry in
            BudgetGaugeView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(EarprintLink.rings)
        }
        .configurationDisplayName("Hearing budget")
        .description("How much of this week's safe-listening budget you have used.")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    TodayWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .preview, featured: WidgetSnapshot.preview.cards[0], isFallback: true)
    SnapshotEntry(date: .now, snapshot: .preview, featured: WidgetSnapshot.preview.cards[1], isFallback: true)
}

#Preview("Shelf", as: .systemMedium) {
    CardShelfWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .preview, featured: nil, isFallback: true)
}

#Preview("Ring", as: .systemLarge) {
    EarprintRingWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .preview, featured: nil, isFallback: true)
}

#Preview("Budget", as: .accessoryCircular) {
    BudgetWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .preview, featured: nil, isFallback: true)
}

#Preview("Rectangular", as: .accessoryRectangular) {
    TodayWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .preview, featured: nil, isFallback: true)
}
