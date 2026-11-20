import SwiftUI

/// Listening minutes and loudness per day and hour. Day 0 is the oldest day.
struct ListeningGrid: Equatable {
    var minutes: [[Double]]
    var decibels: [[Double]]

    var days: Int { minutes.count }

    var maxMinutes: Double {
        var best = 0.0
        for day in minutes {
            for value in day where value > best {
                best = value
            }
        }
        return best
    }

    func totalMinutes(lastDays: Int) -> Double {
        var total = 0.0
        for day in minutes.suffix(lastDays) {
            for value in day {
                total += value
            }
        }
        return total
    }

    /// Share of listening inside the given hours (wraps past midnight).
    func share(hours: [Int], lastDays: Int) -> Double {
        var total = 0.0
        var part = 0.0
        for day in minutes.suffix(lastDays) {
            for value in day { total += value }
            for hour in hours where hour >= 0 && hour < day.count {
                part += day[hour]
            }
        }
        return total > 0 ? part / total : 0
    }

    /// Time-weighted energy average level over the last days.
    func averageDecibels(lastDays: Int) -> Double {
        var energy = 0.0, weight = 0.0
        for (m, db) in zip(minutes.suffix(lastDays), decibels.suffix(lastDays)) {
            let count = min(m.count, db.count)
            for h in 0..<count where m[h] > 0 {
                energy += pow(10, db[h] / 10) * m[h]
                weight += m[h]
            }
        }
        return weight > 0 ? 10 * log10(energy / weight) : 0
    }

    /// Time-weighted energy average level for a single day index.
    func dayAverageDecibels(dayIndex: Int) -> Double? {
        guard minutes.indices.contains(dayIndex), decibels.indices.contains(dayIndex) else { return nil }
        let dayMinutes = minutes[dayIndex]
        let dayDB = decibels[dayIndex]
        let count = min(dayMinutes.count, dayDB.count)
        var energy = 0.0
        var weight = 0.0
        for h in 0..<count where dayMinutes[h] > 0 {
            energy += pow(10, dayDB[h] / 10) * dayMinutes[h]
            weight += dayMinutes[h]
        }
        return weight > 0 ? 10 * log10(energy / weight) : nil
    }
}

/// The signature visual: each ring is a day (oldest inside), each segment an hour of the day.
/// Brighter and thicker means more listening; color shows loudness.
/// Batches empty tracks into 1 path, blurred glow arcs into ≤6 loudness buckets, and crisp arcs into
/// quantized `(loudness × intensity)` buckets so both live rendering and `ImageRenderer` export stay fast.
struct EarprintGlyph: View, Equatable {
    let grid: ListeningGrid
    var showHourLabels = true

    private struct HourGeometry {
        let startAngle: Angle
        let endAngle: Angle
        let cosStart: CGFloat
        let sinStart: CGFloat
    }

    private static let arcGap: Double = 1.2
    private static let hourGeometries: [HourGeometry] = (0..<24).map { hour in
        let start = Angle.degrees(Double(hour) * 15 - 90 + arcGap)
        let end = Angle.degrees(Double(hour + 1) * 15 - 90 - arcGap)
        let rad = start.radians
        return HourGeometry(startAngle: start, endAngle: end, cosStart: CGFloat(cos(rad)), sinStart: CGFloat(sin(rad)))
    }

    private static let crispPalette: [Color] = [
        Theme.levelColor(db: 56),
        Theme.levelColor(db: 61),
        Theme.levelColor(db: 63),
        Theme.levelColor(db: 65),
        Theme.levelColor(db: 67),
        Theme.levelColor(db: 69),
        Theme.levelColor(db: 71),
        Theme.levelColor(db: 73.25),
        Theme.levelColor(db: 75.75),
        Theme.levelColor(db: 78.25),
        Theme.levelColor(db: 80.75),
        Theme.levelColor(db: 84),
    ]

    private static let glowPalette: [Color] = [
        Theme.levelColor(db: 56),
        Theme.levelColor(db: 63),
        Theme.levelColor(db: 68),
        Theme.levelColor(db: 73),
        Theme.levelColor(db: 78),
        Theme.levelColor(db: 84),
    ]

    private static let intensityLevels: [Double] = [0.16, 0.44, 0.72, 0.96]

    private static func crispColorIndex(for db: Double) -> Int {
        if db < 60 { return 0 }
        if db < 72 { return 1 + min(5, Int((db - 60) / 2)) }
        if db < 82 { return 7 + min(3, Int((db - 72) / 2.5)) }
        return 11
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.showHourLabels == rhs.showHourLabels && lhs.grid == rhs.grid
    }

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = side / 2 * (showHourLabels ? 0.80 : 0.94)
            let inner = outer * 0.46
            let dayCount = grid.days
            let step = (outer - inner) / CGFloat(max(dayCount, 1))
            let maxMinutes = max(grid.maxMinutes, 1)
            let bezelGap = max(1.6, step * 0.55)
            let innerRingRadius = max(2, inner - bezelGap * 0.55)
            let outerRingRadius = outer + bezelGap * 0.65
            let hairlineWidth = max(0.75, min(1.0, side * 0.0045))
            let geoms = Self.hourGeometries

            // 1. Batch all empty clock tracks into a single Path (1 draw call instead of 672).
            var trackPath = Path()
            for day in 0..<dayCount {
                let r = inner + step * (CGFloat(day) + 0.5)
                for hour in 0..<24 {
                    let g = geoms[hour]
                    trackPath.move(to: CGPoint(x: center.x + r * g.cosStart, y: center.y + r * g.sinStart))
                    trackPath.addArc(center: center, radius: r, startAngle: g.startAngle, endAngle: g.endAngle, clockwise: false)
                }
            }
            context.stroke(trackPath, with: .color(.white.opacity(0.055)),
                           style: StrokeStyle(lineWidth: step * 0.55, lineCap: .round))

            // 2. Concentric inner & outer precision chronometer hairline rings.
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
            context.stroke(Path(ellipseIn: innerRingRect), with: .color(.white.opacity(0.11)), lineWidth: hairlineWidth)
            context.stroke(Path(ellipseIn: outerRingRect), with: .color(.white.opacity(0.10)), lineWidth: hairlineWidth)

            // 3. Precision 24-hour chronometer bezel micro-ticks (batched into 1 Path).
            if showHourLabels {
                var minorTicks = Path()
                let tickLen = max(2.2, side * 0.014)
                for hour in 0..<24 where hour % 6 != 0 {
                    let angle = (Double(hour) * 15 - 90) * .pi / 180
                    let c = CGFloat(cos(angle)), s = CGFloat(sin(angle))
                    let r0 = outerRingRadius - tickLen * 0.35
                    let r1 = outerRingRadius + tickLen * 0.65
                    minorTicks.move(to: CGPoint(x: center.x + r0 * c, y: center.y + r0 * s))
                    minorTicks.addLine(to: CGPoint(x: center.x + r1 * c, y: center.y + r1 * s))
                }
                context.stroke(minorTicks, with: .color(.white.opacity(0.18)), lineWidth: max(0.65, hairlineWidth * 0.85))
            }

            // 4. Bucket active arcs into batched paths (≤6 glow paths, ≤48 crisp paths vs up to 1,344 strokes).
            var glowBuckets = Array(repeating: Path(), count: Self.glowPalette.count)
            var glowHasArcs = Array(repeating: false, count: Self.glowPalette.count)
            let crispCount = Self.crispPalette.count * Self.intensityLevels.count
            var crispBuckets = Array(repeating: Path(), count: crispCount)
            var crispHasArcs = Array(repeating: false, count: crispCount)

            for day in 0..<dayCount {
                let r = inner + step * (CGFloat(day) + 0.5)
                let dayMinutes = grid.minutes[day]
                let dayDB = grid.decibels.indices.contains(day) ? grid.decibels[day] : []
                let hours = min(24, min(dayMinutes.count, dayDB.count))
                for hour in 0..<hours {
                    let minutes = dayMinutes[hour]
                    guard minutes > 0 else { continue }
                    let g = geoms[hour]
                    let startPoint = CGPoint(x: center.x + r * g.cosStart, y: center.y + r * g.sinStart)

                    let cIdx = Self.crispColorIndex(for: dayDB[hour])
                    let gIdx = cIdx / 2
                    glowBuckets[gIdx].move(to: startPoint)
                    glowBuckets[gIdx].addArc(center: center, radius: r, startAngle: g.startAngle, endAngle: g.endAngle, clockwise: false)
                    glowHasArcs[gIdx] = true

                    let t = min(1, minutes / maxMinutes)
                    let iIdx = min(Self.intensityLevels.count - 1, Int(t * Double(Self.intensityLevels.count)))
                    let bucket = cIdx * Self.intensityLevels.count + iIdx
                    crispBuckets[bucket].move(to: startPoint)
                    crispBuckets[bucket].addArc(center: center, radius: r, startAngle: g.startAngle, endAngle: g.endAngle, clockwise: false)
                    crispHasArcs[bucket] = true
                }
            }

            if glowHasArcs.contains(true) {
                let glowStyle = StrokeStyle(lineWidth: step * 0.72, lineCap: .round)
                context.drawLayer { glow in
                    glow.addFilter(.blur(radius: step * 1.15))
                    for gIdx in 0..<Self.glowPalette.count where glowHasArcs[gIdx] {
                        glow.stroke(glowBuckets[gIdx], with: .color(Self.glowPalette[gIdx].opacity(0.76)), style: glowStyle)
                    }
                }

                for cIdx in 0..<Self.crispPalette.count {
                    let color = Self.crispPalette[cIdx]
                    for iIdx in 0..<Self.intensityLevels.count {
                        let bucket = cIdx * Self.intensityLevels.count + iIdx
                        guard crispHasArcs[bucket] else { continue }
                        let level = Self.intensityLevels[iIdx]
                        context.stroke(
                            crispBuckets[bucket],
                            with: .color(color.opacity(0.32 + 0.68 * level)),
                            style: StrokeStyle(lineWidth: step * (0.32 + 0.55 * level), lineCap: .round)
                        )
                    }
                }
            }

            // 5. Crisp cardinal tick dots at 0 / 6 / 12 / 18h on the outer bezel ring.
            let dotDiameter = max(2.4, min(3.8, side * 0.016))
            let cardinalHours: [(Int, String)] = [(0, "0"), (6, "6"), (12, "12"), (18, "18")]
            for (hour, label) in cardinalHours {
                let angle = (Double(hour) * 15 - 90) * .pi / 180
                let tickPoint = CGPoint(
                    x: center.x + outerRingRadius * CGFloat(cos(angle)),
                    y: center.y + outerRingRadius * CGFloat(sin(angle))
                )
                let dotRect = CGRect(
                    x: tickPoint.x - dotDiameter / 2,
                    y: tickPoint.y - dotDiameter / 2,
                    width: dotDiameter,
                    height: dotDiameter
                )
                context.fill(
                    Path(ellipseIn: dotRect),
                    with: .color(.white.opacity(hour == 0 ? 0.90 : 0.55))
                )

                if showHourLabels {
                    let labelRadius = outerRingRadius + max(11, side * 0.056)
                    let labelPoint = CGPoint(
                        x: center.x + labelRadius * CGFloat(cos(angle)),
                        y: center.y + labelRadius * CGFloat(sin(angle))
                    )
                    context.draw(
                        Text(label)
                            .font(.system(size: 10, weight: hour == 0 ? .bold : .semibold, design: .monospaced))
                            .foregroundStyle(hour == 0 ? .white.opacity(0.82) : Theme.secondaryText),
                        at: labelPoint
                    )
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
