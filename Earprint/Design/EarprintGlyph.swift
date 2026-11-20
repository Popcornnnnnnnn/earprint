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
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = side / 2 * (showHourLabels ? 0.82 : 0.94)
            let inner = outer * 0.46
            let step = (outer - inner) / CGFloat(max(grid.days, 1))
            let maxMinutes = max(grid.maxMinutes, 1)
            let bezelGap = max(1.4, step * 0.45)
            let innerRingRadius = max(2, inner - bezelGap * 0.55)
            let outerRingRadius = outer + bezelGap * 0.55
            let hairlineWidth = max(0.75, min(1.0, side * 0.0045))

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
                    context.stroke(arc(day: day, hour: hour), with: .color(.white.opacity(0.055)),
                                   style: StrokeStyle(lineWidth: step * 0.55, lineCap: .round))
                }
            }

            // Concentric inner & outer precision chronometer hairline rings.
            let innerRingRect = CGRect(
                x: center.x - innerRingRadius,
                y: center.y - innerRingRadius,
                width: innerRingRadius * 2,
                height: innerRingRadius * 2
            )
            let outerRingRect = CGRect(
                x: center.x - outerRingRadius,
                y: center.y - outerRingRadius,
                width: outerRingRadius * 2,
                height: outerRingRadius * 2
            )
            context.stroke(Path(ellipseIn: innerRingRect), with: .color(.white.opacity(0.08)), lineWidth: hairlineWidth)
            context.stroke(Path(ellipseIn: outerRingRect), with: .color(.white.opacity(0.08)), lineWidth: hairlineWidth)

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

            // Crisp cardinal tick dots at 0 / 6 / 12 / 18h on the outer bezel ring.
            let dotDiameter = max(2.2, min(3.4, side * 0.015))
            let cardinalHours: [(Int, String)] = [(0, "0"), (6, "6"), (12, "12"), (18, "18")]
            for (hour, label) in cardinalHours {
                let angle = (Double(hour) * 15 - 90) * .pi / 180
                let tickPoint = CGPoint(
                    x: center.x + outerRingRadius * cos(angle),
                    y: center.y + outerRingRadius * sin(angle)
                )
                let dotRect = CGRect(
                    x: tickPoint.x - dotDiameter / 2,
                    y: tickPoint.y - dotDiameter / 2,
                    width: dotDiameter,
                    height: dotDiameter
                )
                context.fill(
                    Path(ellipseIn: dotRect),
                    with: .color(.white.opacity(hour == 0 ? 0.78 : 0.48))
                )

                if showHourLabels {
                    let labelRadius = outerRingRadius + max(10, side * 0.052)
                    let labelPoint = CGPoint(
                        x: center.x + labelRadius * cos(angle),
                        y: center.y + labelRadius * sin(angle)
                    )
                    context.draw(
                        Text(label)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.secondaryText),
                        at: labelPoint
                    )
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
