import SwiftUI

// Views for the "Listening now" Live Activity. Timers are drawn by the system from dates in
// `ContentState`, so elapsed time and the rest countdown tick without any app updates.

struct LiveActivityLockScreenView: View {
    let attributes: ListeningActivityAttributes
    let state: ListeningActivityAttributes.ContentState
    var staticProgress: Double? = nil

    var body: some View {
        let hasReading = state.decibels > 0
        let color = hasReading ? Theme.levelColor(db: state.decibels) : Theme.quietColor
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ListeningBadge(symbol: attributes.deviceSymbol, color: color, size: 46)
                VStack(alignment: .leading, spacing: 1) {
                    Text("LISTENING NOW")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.3)
                        .foregroundStyle(color)
                    Text(state.startedAt, style: .timer)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                    Text(attributes.deviceName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(WidgetPalette.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                DecibelReadout(decibels: state.decibels, big: true)
            }
            RestCountdown(state: state, staticProgress: staticProgress)
        }
        .foregroundStyle(.white)
    }
}

/// Glowing circle with the headphone symbol.
struct ListeningBadge: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.18))
            Circle().strokeBorder(color.opacity(0.7), lineWidth: 1.5)
            Image(systemName: symbol)
                .font(.system(size: size * 0.46, weight: .medium))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
        .shadow(color: color.opacity(0.6), radius: 8)
    }
}

struct DecibelReadout: View {
    let decibels: Double
    var big = false

    var body: some View {
        let hasReading = decibels > 0
        let color = hasReading ? Theme.levelColor(db: decibels) : WidgetPalette.secondary
        VStack(alignment: .trailing, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if hasReading {
                    Text("\(Int(decibels.rounded()))")
                        .font(.system(size: big ? 28 : 22, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: decibels))
                    Text("dB").font(.system(size: big ? 12 : 10, weight: .bold))
                } else {
                    Text("—")
                        .font(.system(size: big ? 28 : 22, weight: .heavy, design: .rounded))
                    Text("dB").font(.system(size: big ? 12 : 10, weight: .bold))
                }
            }
            .foregroundStyle(color)
            Text(hasReading ? LevelBand(decibels: decibels).title : String(localized: "Recent Health"))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(WidgetPalette.secondary)
        }
    }
}

/// "Rest in 39:12" + a bar that fills from session start to the rest time.
struct RestCountdown: View {
    let state: ListeningActivityAttributes.ContentState
    /// Render tests only: ImageRenderer cannot draw timer-driven progress, so they pass a fixed value.
    var staticProgress: Double? = nil

    var body: some View {
        let color = state.decibels > 0 ? Theme.levelColor(db: state.decibels) : Theme.quietColor
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: "cup.and.saucer.fill")
                Text("Ear break in")
                Text(timerInterval: Date()...max(Date(), state.restAt), countsDown: true)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(maxWidth: 60, alignment: .leading)
                Spacer(minLength: 0)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(WidgetPalette.secondary)
            if let staticProgress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(WidgetPalette.track)
                        Capsule().fill(color).frame(width: geo.size.width * staticProgress)
                    }
                }
                .frame(height: 4)
            } else {
                ProgressView(timerInterval: state.startedAt...max(state.startedAt.addingTimeInterval(1), state.restAt), countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.linear)
                .tint(color)
            }
        }
    }
}

// MARK: - Dynamic Island pieces

struct IslandCompactLeading: View {
    let attributes: ListeningActivityAttributes
    let state: ListeningActivityAttributes.ContentState

    var body: some View {
        Image(systemName: attributes.deviceSymbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.levelColor(db: state.decibels))
    }
}

struct IslandCompactTrailing: View {
    let state: ListeningActivityAttributes.ContentState

    var body: some View {
        Text(state.startedAt, style: .timer)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .multilineTextAlignment(.trailing)
            .foregroundStyle(Theme.levelColor(db: state.decibels))
            .frame(width: 56, alignment: .trailing)
    }
}

struct IslandExpandedCenter: View {
    let attributes: ListeningActivityAttributes
    let state: ListeningActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 0) {
            Text(attributes.deviceName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WidgetPalette.secondary)
                .lineLimit(1)
            Text(state.startedAt, style: .timer)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
        }
    }
}
