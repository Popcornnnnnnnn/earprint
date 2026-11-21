import SwiftUI

// Building blocks shared by every Earprint widget. Pure SwiftUI (no WidgetKit types) so the
// render tests can draw them with ImageRenderer.

enum WidgetPalette {
    static let base = Color(red: 0.05, green: 0.05, blue: 0.08)
    static let baseDeep = Color(red: 0.02, green: 0.02, blue: 0.04)
    static let secondary = Color.white.opacity(0.58)
    static let tertiary = Color.white.opacity(0.36)
    static let track = Color.white.opacity(0.08)
}

/// Dark glass with a soft colored glow in one corner (the "lit from inside" look of the app).
struct WidgetBackdrop: View {
    var glow: Color = Theme.quiet.color
    var secondGlow: Color? = nil
    var glowCenter: UnitPoint = .topTrailing

    var body: some View {
        ZStack {
            LinearGradient(colors: [WidgetPalette.base, WidgetPalette.baseDeep], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [glow.opacity(0.42), glow.opacity(0.0)], center: glowCenter, startRadius: 0, endRadius: 190)
            if let secondGlow {
                RadialGradient(colors: [secondGlow.opacity(0.22), .clear], center: .bottomLeading, startRadius: 0, endRadius: 200)
            }
        }
    }
}

/// Static foil for mini cards: per-material natural gradients (no center pinwheel) + micro finish.
struct MiniFoil: View {
    let rarity: Rarity

    var body: some View {
        let colors = rarity.baseColors
        let mid = colors.indices.contains(0) ? colors[0] : rarity.glow
        let hi = colors.indices.contains(1) ? colors[1] : mid
        let sh = colors.indices.contains(2) ? colors[2] : mid
        let deep = colors.indices.contains(3) ? colors[3] : sh

        ZStack {
            switch rarity.material {
            case .matteGrain:
                LinearGradient(colors: [hi, mid, sh, deep], startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [hi.opacity(0.40), .clear], center: UnitPoint(x: 0.20, y: 0.15), startRadius: 2, endRadius: 90)
            case .brushed:
                LinearGradient(colors: [mid, hi, mid, sh], startPoint: UnitPoint(x: 0.12, y: 0), endPoint: UnitPoint(x: 0.88, y: 1))
                LinearGradient(colors: [.clear, .white.opacity(0.24), .clear], startPoint: .top, endPoint: UnitPoint(x: 0.8, y: 0.75))
                    .blendMode(.softLight)
            case .satin:
                LinearGradient(colors: [hi, mid, sh, deep], startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [hi.opacity(0.45), .clear], center: UnitPoint(x: 0.82, y: 0.18), startRadius: 2, endRadius: 85)
            case .carbon:
                LinearGradient(colors: [mid, deep, sh], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [hi.opacity(0.55), rarity.glow.opacity(0.22), .clear], center: UnitPoint(x: 0.85, y: 0.12), startRadius: 2, endRadius: 75)
            case .holo:
                LinearGradient(colors: [colors[0], colors[1], colors[2], colors[3]], startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [colors[0].opacity(0.52), .clear], center: UnitPoint(x: 0.2, y: 0.2), startRadius: 2, endRadius: 75)
                RadialGradient(colors: [colors[2].opacity(0.42), .clear], center: UnitPoint(x: 0.82, y: 0.45), startRadius: 2, endRadius: 75)
            }

            Canvas { context, size in
                var path = Path()
                switch rarity.material {
                case .brushed:
                    stride(from: CGFloat(0), to: size.height, by: 2.5).forEach { y in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(path, with: .color(.white.opacity(0.05)), lineWidth: 0.5)
                case .carbon:
                    stride(from: -size.height, to: size.width + size.height, by: 4).forEach { x in
                        path.move(to: CGPoint(x: x, y: size.height))
                        path.addLine(to: CGPoint(x: x + size.height, y: 0))
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                    }
                    context.stroke(path, with: .color(.white.opacity(0.06)), lineWidth: 0.6)
                case .matteGrain, .satin, .holo:
                    stride(from: -size.height, to: size.width, by: 3.5).forEach { x in
                        path.move(to: CGPoint(x: x, y: size.height))
                        path.addLine(to: CGPoint(x: x + size.height, y: 0))
                    }
                    context.stroke(path, with: .color(.white.opacity(rarity == .holo ? 0.06 : 0.035)), lineWidth: 0.55)
                }
            }

            if rarity == .holo {
                LinearGradient(colors: [.clear, .pink.opacity(0.24), .yellow.opacity(0.20), .cyan.opacity(0.26), .clear],
                               startPoint: UnitPoint(x: -0.1, y: 0), endPoint: UnitPoint(x: 1.1, y: 1))
                    .blendMode(.colorDodge)
                    .opacity(0.55)
            }
        }
    }
}

/// A headphone card shrunk to widget size. Same proportions as the app card (300 x 440).
struct MiniCard: View {
    let card: WidgetSnapshot.Card
    var width: CGFloat = 80
    var showsName = true

    static let aspect: CGFloat = 300.0 / 440.0
    private var s: CGFloat { width / 80 }

    var body: some View {
        let rarity = card.rarity
        let ink = rarity.ink
        VStack(alignment: .leading, spacing: 0) {
            Text(rarity.shortName.uppercased())
                .font(.system(size: 5.5 * s, weight: .heavy))
                .tracking(0.6 * s)
                .padding(.horizontal, 3.5 * s).padding(.vertical, 1.5 * s)
                .background(.black.opacity(0.28), in: Capsule())
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            Image(systemName: card.symbol)
                .font(.system(size: 30 * s, weight: .thin))
                .foregroundStyle(ink.opacity(0.85))
                .shadow(color: .white.opacity(0.6), radius: 0.5, y: 0.5)
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            Text(WidgetFormat.hours(card.lifetimeMinutes))
                .font(.system(size: 19 * s, weight: .black, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText(value: card.lifetimeMinutes))
            if showsName {
                Text(card.nickname)
                    .font(.system(size: 6.5 * s, weight: .bold))
                    .lineLimit(1)
                    .opacity(0.75)
            }
        }
        .foregroundStyle(ink)
        .padding(6 * s)
        .frame(width: width, height: width / Self.aspect)
        .background(MiniFoil(rarity: rarity))
        .clipShape(RoundedRectangle(cornerRadius: 7 * s, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 7 * s, style: .continuous).strokeBorder(.white.opacity(0.5), lineWidth: max(0.5, 0.8 * s)))
        .shadow(color: rarity.glow.opacity(0.55), radius: 8 * s, y: 3 * s)
    }
}

/// Dashed "next pair" slot, same size as a mini card.
struct LockedCardSlot: View {
    var width: CGFloat = 80

    var body: some View {
        RoundedRectangle(cornerRadius: 7 * width / 80, style: .continuous)
            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .foregroundStyle(.white.opacity(0.22))
            .frame(width: width, height: width / MiniCard.aspect)
            .overlay {
                VStack(spacing: 3) {
                    Image(systemName: "lock.fill").font(.system(size: 12))
                    Text("Next pair").font(.system(size: 8, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.35))
            }
    }
}

/// Glowing dot + label for a dB value.
struct LevelDot: View {
    let decibels: Double?
    var showsValue = true

    var body: some View {
        let color = decibels.map { Theme.levelColor(db: $0) } ?? WidgetPalette.tertiary
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .shadow(color: color, radius: 3)
            if let decibels {
                Text(showsValue ? "\(LevelBand(decibels: decibels).title) · \(Int(decibels.rounded())) dB" : LevelBand(decibels: decibels).title)
            } else {
                Text("Nothing played yet")
            }
        }
        .foregroundStyle(color)
    }
}

/// Weekly hearing budget: teal → amber → coral track, glowing fill, 100 % tick.
struct BudgetBar: View {
    let used: Double
    var height: CGFloat = 9

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            // The bar spans 0 ... 120 % so going over budget is still visible.
            let fill = min(max(used, 0), 1.2) / 1.2
            ZStack(alignment: .leading) {
                Capsule().fill(WidgetPalette.track)
                Capsule()
                    .fill(LinearGradient(colors: [Theme.quiet.color, Theme.moderate.color, Theme.loud.color],
                                         startPoint: .leading, endPoint: .trailing))
                    .mask(alignment: .leading) { Capsule().frame(width: max(height, w * fill)) }
                    .shadow(color: Theme.levelColor(db: 60 + 20 * min(used, 1)).opacity(0.8), radius: 5)
                Rectangle()
                    .fill(.white.opacity(0.55))
                    .frame(width: 1.5, height: height + 6)
                    .offset(x: w / 1.2 - 0.75)
            }
        }
        .frame(height: height)
    }
}

/// 4 rows (weeks, oldest on top) x 7 columns (days). Brightness = minutes, color = loudness.
struct DayHeatmap: View {
    let heatmap: WidgetSnapshot.Heatmap
    let lastDay: Date
    var cell: CGFloat = 17
    var gap: CGFloat = 3

    var body: some View {
        let daily = heatmap.dailyMinutes.suffix(28)
        let days = Array(daily)
        let maxMinutes = max(days.max() ?? 1, 1)
        let grid = heatmap.grid
        let offset = grid.days - days.count
        VStack(alignment: .leading, spacing: gap) {
            ForEach(0..<(days.count + 6) / 7, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<7, id: \.self) { col in
                        let i = row * 7 + col
                        if i < days.count {
                            let t = (days[i] / maxMinutes).squareRoot()
                            let db = averageDecibels(grid, day: offset + i)
                            RoundedRectangle(cornerRadius: cell * 0.28, style: .continuous)
                                .fill(days[i] > 0 ? Theme.levelColor(db: db).opacity(0.18 + 0.82 * t) : WidgetPalette.track)
                                .overlay {
                                    if i == days.count - 1 {
                                        RoundedRectangle(cornerRadius: cell * 0.28, style: .continuous)
                                            .strokeBorder(.white.opacity(0.9), lineWidth: 1.2)
                                    }
                                }
                                .shadow(color: days[i] > 0 ? Theme.levelColor(db: db).opacity(0.5 * t) : .clear, radius: 3)
                                .frame(width: cell, height: cell)
                        }
                    }
                }
            }
            HStack(spacing: gap) {
                ForEach(0..<7, id: \.self) { col in
                    Text(weekdayLetter(dayIndex: col, count: days.count))
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(WidgetPalette.tertiary)
                        .frame(width: cell)
                }
            }
        }
    }

    private func averageDecibels(_ grid: ListeningGrid, day: Int) -> Double {
        guard grid.minutes.indices.contains(day) else { return 0 }
        var energy = 0.0, weight = 0.0
        for h in 0..<24 where grid.minutes[day][h] > 0 {
            energy += pow(10, grid.decibels[day][h] / 10) * grid.minutes[day][h]
            weight += grid.minutes[day][h]
        }
        return weight > 0 ? 10 * log10(energy / weight) : 0
    }

    private func weekdayLetter(dayIndex: Int, count: Int) -> String {
        let back = count - 1 - dayIndex
        let date = Calendar.current.date(byAdding: .day, value: -back, to: lastDay) ?? lastDay
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return symbols[Calendar.current.component(.weekday, from: date) - 1]
    }
}

/// Seven thin bars for the last 7 days (used on the Lock Screen).
struct WeekSparkline: View {
    let daily: [Double]
    var barWidth: CGFloat = 4
    var height: CGFloat = 30

    var body: some View {
        let last = Array(daily.suffix(7))
        let maxValue = max(last.max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(last.enumerated()), id: \.offset) { index, value in
                Capsule()
                    .fill(.primary.opacity(index == last.count - 1 ? 1 : 0.45))
                    .frame(width: barWidth, height: max(barWidth, height * value / maxValue))
            }
        }
        .frame(height: height, alignment: .bottom)
    }
}
