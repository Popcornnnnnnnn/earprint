import SwiftUI
import AppIntents

// MARK: - Small: today

/// Small Home Screen widget: today's time, the featured headphone card, safe-level dot.
/// Tapping the card runs `NextCardIntent` (shows the next card); tapping anywhere else opens the card in the app.
struct SmallTodayView: View {
    let snapshot: WidgetSnapshot
    let featured: WidgetSnapshot.Card?
    let date: Date

    var body: some View {
        let today = snapshot.today(at: date)
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                Text("TODAY")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(WidgetPalette.secondary)
                Spacer(minLength: 0)
                Text(WidgetFormat.duration(today.minutes))
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .contentTransition(.numericText(value: today.minutes))
                    .shadow(color: .white.opacity(0.25), radius: 6)
                Text(today.deviceName ?? featured?.nickname ?? "No headphones yet")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WidgetPalette.secondary)
                    .lineLimit(1)
                    .padding(.top, 1)
                LevelDot(decibels: today.decibels)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            if let featured {
                Button(intent: NextCardIntent()) {
                    MiniCard(card: featured, width: 48, showsName: false)
                        .rotationEffect(.degrees(9))
                }
                .buttonStyle(.plain)
                .offset(x: 2, y: -2)
            }
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Medium: card shelf

/// Medium Home Screen widget: this week's total + up to 3 mini holo cards. Each card is a deep link.
struct CardShelfView: View {
    let snapshot: WidgetSnapshot

    private let cardWidth: CGFloat = 79

    var body: some View {
        let cards = Array(snapshot.cards.prefix(3))
        let lifetime = snapshot.cards.reduce(0) { $0 + $1.lifetimeMinutes }
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text("CARD SHELF")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.9)
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(WidgetPalette.secondary)
                Spacer(minLength: 0)
                Text("This week")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(WidgetPalette.secondary)
                Text(WidgetFormat.duration(snapshot.week.minutes))
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText(value: snapshot.week.minutes))
                LevelDot(decibels: snapshot.week.decibels, showsValue: false)
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(1)
                    .padding(.top, 3)
                Spacer(minLength: 0)
                Text("\(snapshot.cards.count) cards")
                    .font(.system(size: 10, weight: .bold))
                Text("\(WidgetFormat.hours(lifetime)) together")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(WidgetPalette.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            ForEach(cards) { card in
                Link(destination: card.deepLink) {
                    MiniCard(card: card, width: cardWidth)
                }
            }
            ForEach(0..<max(0, 3 - cards.count), id: \.self) { _ in
                Link(destination: EarprintLink.collection) { LockedCardSlot(width: cardWidth) }
            }
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Large: Earprint ring + heatmap + budget

/// Large Home Screen widget: the Earprint ring for 4 weeks, a day heatmap and the weekly hearing budget.
struct EarprintRingView: View {
    let snapshot: WidgetSnapshot
    let date: Date

    var body: some View {
        let today = snapshot.today(at: date)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "circle.hexagongrid.fill")
                    .foregroundStyle(Theme.quiet.color)
                Text("EARPRINT")
                    .tracking(1.6)
                Spacer()
                Text("LAST 4 WEEKS")
                    .tracking(1.2)
                    .foregroundStyle(WidgetPalette.tertiary)
            }
            .font(.system(size: 10, weight: .heavy))

            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    EarprintGlyph(grid: snapshot.heatmap.grid, showHourLabels: false)
                    VStack(spacing: 0) {
                        Text(WidgetFormat.hours(snapshot.week.minutes))
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .contentTransition(.numericText(value: snapshot.week.minutes))
                        Text("this week")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(WidgetPalette.secondary)
                    }
                    .frame(width: 62)
                }
                .frame(width: 172, height: 172)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Today")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(WidgetPalette.secondary)
                    Text(WidgetFormat.duration(today.minutes))
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: today.minutes))
                    LevelDot(decibels: today.decibels)
                        .font(.system(size: 9, weight: .semibold))
                        .lineLimit(1)
                        .padding(.bottom, 10)
                    DayHeatmap(heatmap: snapshot.heatmap, lastDay: snapshot.day, cell: 17, gap: 3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)

            WeekByHeadphone(cards: Array(snapshot.cards.prefix(3)))

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Weekly hearing budget")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                    Text(WidgetFormat.percent(snapshot.week.budgetUsed))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.levelColor(db: 60 + 20 * min(snapshot.week.budgetUsed, 1)))
                        .contentTransition(.numericText(value: snapshot.week.budgetUsed))
                }
                BudgetBar(used: snapshot.week.budgetUsed)
                Text("WHO safe listening: 80 dB(A) for 40 h a week\(snapshot.week.decibels.map { " · you avg \(Int($0.rounded())) dB" } ?? "")")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(WidgetPalette.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .foregroundStyle(.white)
    }
}

/// "This week by headphone": one thin foil bar per card.
struct WeekByHeadphone: View {
    let cards: [WidgetSnapshot.Card]

    var body: some View {
        let maxMinutes = max(cards.map(\.weekMinutes).max() ?? 1, 1)
        VStack(alignment: .leading, spacing: 5) {
            ForEach(cards) { card in
                Link(destination: card.deepLink) {
                    HStack(spacing: 8) {
                        Image(systemName: card.symbol)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(card.rarity.glow)
                            .frame(width: 16)
                        Text(card.nickname)
                            .font(.system(size: 10, weight: .semibold))
                            .lineLimit(1)
                            .frame(width: 96, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(WidgetPalette.track)
                                Capsule()
                                    .fill(LinearGradient(colors: card.rarity.baseColors, startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(5, geo.size.width * card.weekMinutes / maxMinutes))
                                    .shadow(color: card.rarity.glow.opacity(0.6), radius: 3)
                            }
                        }
                        .frame(height: 5)
                        Text(WidgetFormat.duration(card.weekMinutes))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
        }
    }
}
