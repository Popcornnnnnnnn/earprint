import SwiftUI
import WidgetKit

// Lock Screen accessory widgets. They render in "vibrant" mode (monochrome, tinted by the system),
// so they rely on shape and type weight instead of color.

/// Circular: weekly hearing budget gauge.
struct BudgetGaugeView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        Gauge(value: min(snapshot.week.budgetUsed, 1)) {
            Image(systemName: "ear")
        } currentValueLabel: {
            Text("\(Int((snapshot.week.budgetUsed * 100).rounded()))")
                .contentTransition(.numericText(value: snapshot.week.budgetUsed))
        }
        .gaugeStyle(.accessoryCircular)
    }
}

/// Rectangular: today's time, headphone, and a 7-day sparkline.
struct TodayRectangularView: View {
    let snapshot: WidgetSnapshot
    let date: Date

    var body: some View {
        let today = snapshot.today(at: date)
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Label("Today", systemImage: "headphones")
                    .font(.system(size: 12, weight: .semibold))
                    .widgetAccentable()
                Text(WidgetFormat.duration(today.minutes))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: today.minutes))
                Text(today.deviceName ?? "No listening yet")
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .opacity(0.75)
            }
            Spacer(minLength: 0)
            WeekSparkline(daily: snapshot.heatmap.dailyMinutes, barWidth: 4, height: 34)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Inline: one line above the clock.
struct TodayInlineView: View {
    let snapshot: WidgetSnapshot
    let date: Date

    var body: some View {
        let today = snapshot.today(at: date)
        ViewThatFits {
            Label("\(WidgetFormat.duration(today.minutes)) today · \(WidgetFormat.percent(snapshot.week.budgetUsed)) budget", systemImage: "headphones")
            Label("\(WidgetFormat.duration(today.minutes)) today", systemImage: "headphones")
        }
    }
}
