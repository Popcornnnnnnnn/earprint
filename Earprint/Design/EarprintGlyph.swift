import SwiftUI

/// Listening minutes and loudness per day and hour. Day 0 is the oldest day.
struct ListeningGrid {
    var minutes: [[Double]]
    var decibels: [[Double]]

    var days: Int { minutes.count }
    var maxMinutes: Double { minutes.flatMap { $0 }.max() ?? 0 }

    func totalMinutes(lastDays: Int) -> Double {
        minutes.suffix(lastDays).flatMap { $0 }.reduce(0, +)
    }

    /// Share of listening inside the given hours (wraps past midnight).
    func share(hours: [Int], lastDays: Int) -> Double {
        let total = totalMinutes(lastDays: lastDays)
        guard total > 0 else { return 0 }
        let part = minutes.suffix(lastDays).reduce(0) { sum, day in sum + hours.reduce(0) { $0 + day[$1] } }
        return part / total
    }

    /// Time-weighted energy average level over the last days.
    func averageDecibels(lastDays: Int) -> Double {
        var energy = 0.0, weight = 0.0
        for (m, db) in zip(minutes.suffix(lastDays), decibels.suffix(lastDays)) {
            for h in 0..<24 where m[h] > 0 {
                energy += pow(10, db[h] / 10) * m[h]
                weight += m[h]
            }
        }
        return weight > 0 ? 10 * log10(energy / weight) : 0
    }
}

/// The signature visual: each ring is a day (oldest inside), each segment an hour of the day.
/// Brighter and thicker means more listening; color shows loudness.
struct EarprintGlyph: View {
    let grid: ListeningGrid
    var showHourLabels = true

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = min(size.width, size.height) / 2 * (showHourLabels ? 0.86 : 0.98)
            let inner = outer * 0.42
            let step = (outer - inner) / CGFloat(max(grid.days, 1))
            let maxMinutes = max(grid.maxMinutes, 1)

            func arc(day: Int, hour: Int) -> Path {
                let r = inner + step * (CGFloat(day) + 0.5)
                let gap = 1.2
                var path = Path()
                path.addArc(
                    center: center,
                    radius: r,
                    startAngle: .degrees(Double(hour) * 15 - 90 + gap),
                    endAngle: .degrees(Double(hour + 1) * 15 - 90 - gap),
                    clockwise: false
                )
                return path
            }

            // Faint tracks so empty hours still read as a clock.
            for day in 0..<grid.days {
                for hour in 0..<24 {
                    context.stroke(arc(day: day, hour: hour), with: .color(.white.opacity(0.045)),
                                   style: StrokeStyle(lineWidth: step * 0.55, lineCap: .round))
                }
            }

            func drawActive(_ ctx: inout GraphicsContext) {
                for day in 0..<grid.days {
                    for hour in 0..<24 {
                        let minutes = grid.minutes[day][hour]
                        guard minutes > 0 else { continue }
                        let t = min(1, minutes / maxMinutes)
                        let color = Theme.levelColor(db: grid.decibels[day][hour])
                        ctx.stroke(arc(day: day, hour: hour), with: .color(color.opacity(0.3 + 0.7 * t)),
                                   style: StrokeStyle(lineWidth: step * (0.3 + 0.55 * t), lineCap: .round))
                    }
                }
            }

            context.drawLayer { glow in
                glow.addFilter(.blur(radius: step * 1.2))
                drawActive(&glow)
            }
            drawActive(&context)

            if showHourLabels {
                for (hour, label) in [(0, "0"), (6, "6"), (12, "12"), (18, "18")] {
                    let angle = Double(hour) * 15 - 90
                    let r = outer + 14
                    let point = CGPoint(x: center.x + r * cos(angle * .pi / 180), y: center.y + r * sin(angle * .pi / 180))
                    context.draw(Text(label).font(.caption2.weight(.medium)).foregroundStyle(Theme.secondaryText), at: point)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
