import SwiftUI

/// Listening minutes and loudness per day and hour. Day 0 is the oldest day.
struct ListeningGrid: Equatable {
    var minutes: [[Double]] {
        didSet { recomputeCached28DayStats() }
    }
    var decibels: [[Double]] {
        didSet { recomputeCached28DayStats() }
    }

    private(set) var last28Minutes: Double = 0
    private(set) var last28AverageDecibels: Double = 0

    init(minutes: [[Double]], decibels: [[Double]]) {
        self.minutes = minutes
        self.decibels = decibels
        recomputeCached28DayStats()
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.minutes == rhs.minutes && lhs.decibels == rhs.decibels
    }

    private mutating func recomputeCached28DayStats() {
        last28Minutes = Self.computeTotalMinutes(minutes: minutes, lastDays: 28)
        last28AverageDecibels = Self.computeAverageDecibels(minutes: minutes, decibels: decibels, lastDays: 28)
    }

    private static func computeTotalMinutes(minutes: [[Double]], lastDays: Int) -> Double {
        var total = 0.0
        for day in minutes.suffix(lastDays) {
            for value in day {
                total += value
            }
        }
        return total
    }

    private static func computeAverageDecibels(minutes: [[Double]], decibels: [[Double]], lastDays: Int) -> Double {
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
        if lastDays == 28 { return last28Minutes }
        return Self.computeTotalMinutes(minutes: minutes, lastDays: lastDays)
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
        if lastDays == 28 { return last28AverageDecibels }
        return Self.computeAverageDecibels(minutes: minutes, decibels: decibels, lastDays: lastDays)
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
    var highlightedHour: Int? = nil
    var forcedColorScheme: ColorScheme? = nil
    var dynamicTypeSize: DynamicTypeSize = .medium

    @Environment(\.colorScheme) private var envColorScheme
    @ScaledMetric(relativeTo: .caption2) private var cardinalLabelSize: CGFloat = 12

    private struct HourGeometry {
        let startAngle: Angle
        let endAngle: Angle
        let cosStart: CGFloat
        let sinStart: CGFloat
    }

    private static let arcGap: Double = 0.9
    private static let intensityLevels: [Double] = [0.12, 0.24, 0.37, 0.50, 0.63, 0.76, 0.88, 1.00]
    private static let bucketGeometries: [[HourGeometry]] = intensityLevels.map { level in
        let fullHalfSpan = (15.0 - 2 * arcGap) / 2
        let halfSpan = fullHalfSpan * (0.30 + 0.70 * level)
        return (0..<24).map { hour in
            let centerDeg = Double(hour) * 15 - 90 + 7.5
            let start = Angle.degrees(centerDeg - halfSpan)
            let end = Angle.degrees(centerDeg + halfSpan)
            let rad = start.radians
            return HourGeometry(startAngle: start, endAngle: end, cosStart: CGFloat(cos(rad)), sinStart: CGFloat(sin(rad)))
        }
    }

    private static let crispPaletteDark: [Color] = makeCrispPalette(colorScheme: .dark)
    private static let crispPaletteLight: [Color] = makeCrispPalette(colorScheme: .light)
    private static let glowPaletteDark: [Color] = makeGlowPalette(colorScheme: .dark)
    private static let glowPaletteLight: [Color] = makeGlowPalette(colorScheme: .light)

    private static func makeCrispPalette(colorScheme: ColorScheme) -> [Color] {
        [58, 66, 68, 70, 72, 74, 76, 77.5, 79, 80.5, 82, 85].map {
            Theme.dialLevelColor(db: $0, colorScheme: colorScheme)
        }
    }

    private static func makeGlowPalette(colorScheme: ColorScheme) -> [Color] {
        [58, 67, 71, 75, 79, 84].map {
            Theme.levelColor(db: $0, colorScheme: colorScheme)
        }
    }

    private static func crispColorIndex(for db: Double) -> Int {
        let rounded = Int(db.rounded())
        if rounded < 66 { return 0 }
        if rounded < 76 { return 1 + min(4, max(0, Int((db - 66) / 1.7))) }
        if rounded < 82 { return 7 + min(3, max(0, Int((db - 76) / 1.5))) }
        return 11
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.showHourLabels == rhs.showHourLabels
            && lhs.highlightedHour == rhs.highlightedHour
            && lhs.forcedColorScheme == rhs.forcedColorScheme
            && lhs.dynamicTypeSize == rhs.dynamicTypeSize
            && lhs.grid == rhs.grid
    }

    var body: some View {
        let scheme = forcedColorScheme ?? envColorScheme
        let isLight = scheme == .light
        let crispPalette = isLight ? Self.crispPaletteLight : Self.crispPaletteDark
        let glowPalette = isLight ? Self.glowPaletteLight : Self.glowPaletteDark
        let innerRingColor = isLight ? Color.black.opacity(0.24) : Color.white.opacity(0.23)
        let outerRingColor = isLight ? Color.black.opacity(0.29) : Color.white.opacity(0.27)
        let tickColor = isLight ? Color.black.opacity(0.28) : Color.white.opacity(0.26)
        let dotZeroColor = isLight ? Color.black.opacity(0.78) : Color.white.opacity(0.90)
        let dotMinorColor = isLight ? Color.black.opacity(0.50) : Color.white.opacity(0.55)
        let labelZeroColor = isLight ? Color(red: 0.08, green: 0.09, blue: 0.12).opacity(0.90) : Color.white.opacity(0.86)
        let labelMinorColor = isLight ? Color(red: 0.08, green: 0.09, blue: 0.12).opacity(0.70) : Color.white.opacity(0.74)
        let glowAlpha: Double = isLight ? 0.26 : 0.28
        let minArcAlpha: Double = isLight ? 0.84 : 0.72

        Canvas { context, size in
            let side = min(size.width, size.height)
            let isCompact = side <= 220
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outerRatio: CGFloat = showHourLabels ? (isCompact ? 0.775 : 0.78) : 0.94
            let outer = side / 2 * outerRatio
            let innerRatio: CGFloat = isCompact ? 0.47 : 0.44
            let inner = outer * innerRatio
            let dayCount = grid.days
            let step = (outer - inner) / CGFloat(max(dayCount, 1))
            let maxMinutes: Double = 60.0
            let bezelGap = max(1.6, step * 0.55)
            let innerRingRadius = EarprintDialMath.innerRingRadius(side: side, showHourLabels: showHourLabels, dayCount: dayCount)
            let outerRingRadius = outer + bezelGap * (isCompact ? 0.55 : 0.80)
            let hairlineWidth = max(0.75, min(1.0, side * 0.0045))

            // 1. Unified architectural chronometer dial field (soft annular plate + cardinal/octant meridians).
            var annulus = Path()
            annulus.addEllipse(in: CGRect(
                x: center.x - outerRingRadius,
                y: center.y - outerRingRadius,
                width: outerRingRadius * 2,
                height: outerRingRadius * 2
            ))
            annulus.addEllipse(in: CGRect(
                x: center.x - innerRingRadius,
                y: center.y - innerRingRadius,
                width: innerRingRadius * 2,
                height: innerRingRadius * 2
            ))
            context.fill(
                annulus,
                with: .color(isLight ? Color.black.opacity(0.036) : Color.white.opacity(0.032)),
                style: FillStyle(eoFill: true)
            )

            var cardinalMeridians = Path()
            var octantMeridians = Path()
            for hour in [0, 3, 6, 9, 12, 15, 18, 21] {
                let angle = (Double(hour) * 15 - 90) * .pi / 180
                let c = CGFloat(cos(angle)), s = CGFloat(sin(angle))
                let p0 = CGPoint(x: center.x + innerRingRadius * c, y: center.y + innerRingRadius * s)
                let p1 = CGPoint(x: center.x + outerRingRadius * c, y: center.y + outerRingRadius * s)
                if hour % 6 == 0 {
                    cardinalMeridians.move(to: p0)
                    cardinalMeridians.addLine(to: p1)
                } else {
                    octantMeridians.move(to: p0)
                    octantMeridians.addLine(to: p1)
                }
            }
            context.stroke(
                cardinalMeridians,
                with: .color(isLight ? Color.black.opacity(0.09) : Color.white.opacity(0.11)),
                lineWidth: 0.6
            )
            context.stroke(
                octantMeridians,
                with: .color(isLight ? Color.black.opacity(0.055) : Color.white.opacity(0.07)),
                lineWidth: 0.5
            )

            // Weekly concentric reference rings inside the 28-day field (days 7, 14, 21).
            if dayCount >= 21 {
                let refColor = isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.11)
                var weeklyRefs = Path()
                for markDay in [7, 14, 21] where markDay < dayCount {
                    let rr = inner + step * CGFloat(markDay)
                    weeklyRefs.addEllipse(in: CGRect(x: center.x - rr, y: center.y - rr, width: rr * 2, height: rr * 2))
                }
                context.stroke(weeklyRefs, with: .color(refColor), lineWidth: 0.65)
            }

            // Optional interactive hour sector highlight behind active arcs.
            if let highlightedHour, (0..<24).contains(highlightedHour) {
                let sectorStart = Angle.degrees(Double(highlightedHour) * 15 - 90 + Self.arcGap * 0.5)
                let sectorEnd = Angle.degrees(Double(highlightedHour + 1) * 15 - 90 - Self.arcGap * 0.5)
                var highlight = Path()
                highlight.addArc(center: center, radius: outerRingRadius, startAngle: sectorStart, endAngle: sectorEnd, clockwise: false)
                highlight.addArc(center: center, radius: innerRingRadius, startAngle: sectorEnd, endAngle: sectorStart, clockwise: true)
                highlight.closeSubpath()
                context.fill(highlight, with: .color(isLight ? Color.black.opacity(0.06) : Color.white.opacity(0.09)))
                context.stroke(highlight, with: .color(dotZeroColor.opacity(isLight ? 0.62 : 0.72)), lineWidth: max(1.1, hairlineWidth * 1.3))

                var outerAccent = Path()
                outerAccent.addArc(center: center, radius: outerRingRadius, startAngle: sectorStart, endAngle: sectorEnd, clockwise: false)
                context.stroke(outerAccent, with: .color(dotZeroColor), lineWidth: max(1.5, hairlineWidth * 1.8))
            }

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
            context.stroke(Path(ellipseIn: innerRingRect), with: .color(innerRingColor), lineWidth: hairlineWidth)
            context.stroke(Path(ellipseIn: outerRingRect), with: .color(outerRingColor), lineWidth: hairlineWidth * 1.15)

            // 3. Precision 24-hour chronometer bezel micro-ticks (batched into 1 Path).
            if showHourLabels {
                var minorTicks = Path()
                let tickLen = max(2.8, side * 0.016)
                for hour in 0..<24 where hour % 6 != 0 {
                    let angle = (Double(hour) * 15 - 90) * .pi / 180
                    let c = CGFloat(cos(angle)), s = CGFloat(sin(angle))
                    let r0 = outerRingRadius - tickLen * 0.35
                    let r1 = outerRingRadius + tickLen * 0.65
                    minorTicks.move(to: CGPoint(x: center.x + r0 * c, y: center.y + r0 * s))
                    minorTicks.addLine(to: CGPoint(x: center.x + r1 * c, y: center.y + r1 * s))
                }
                context.stroke(minorTicks, with: .color(tickColor), lineWidth: max(0.65, hairlineWidth * 0.85))
            }

            // 4. Bucket active arcs into batched paths (≤6 glow paths, ≤288 crisp paths vs up to 1,344 strokes).
            let recencyTiers: [Double] = isLight ? [0.74, 0.87, 1.00] : [0.66, 0.83, 1.00]
            var glowBuckets = Array(repeating: Path(), count: glowPalette.count)
            var glowHasArcs = Array(repeating: false, count: glowPalette.count)
            let crispCount = crispPalette.count * Self.intensityLevels.count * recencyTiers.count
            var crispBuckets = Array(repeating: Path(), count: crispCount)
            var crispHasArcs = Array(repeating: false, count: crispCount)

            for day in 0..<dayCount {
                let r = inner + step * (CGFloat(day) + 0.5)
                let dayMinutes = grid.minutes[day]
                let dayDB = grid.decibels.indices.contains(day) ? grid.decibels[day] : []
                let hours = min(24, min(dayMinutes.count, dayDB.count))
                let rIdx = min(recencyTiers.count - 1, day * recencyTiers.count / max(dayCount, 1))
                for hour in 0..<hours {
                    let minutes = dayMinutes[hour]
                    guard minutes > 0 else { continue }
                    let t = min(1, minutes / maxMinutes)
                    let iIdx = min(Self.intensityLevels.count - 1, Int(t * Double(Self.intensityLevels.count)))
                    let g = Self.bucketGeometries[iIdx][hour]
                    let startPoint = CGPoint(x: center.x + r * g.cosStart, y: center.y + r * g.sinStart)

                    let cIdx = Self.crispColorIndex(for: dayDB[hour])
                    if iIdx >= 2 || cIdx >= 7 {
                        let gIdx = cIdx / 2
                        glowBuckets[gIdx].move(to: startPoint)
                        glowBuckets[gIdx].addArc(center: center, radius: r, startAngle: g.startAngle, endAngle: g.endAngle, clockwise: false)
                        glowHasArcs[gIdx] = true
                    }

                    let bucket = (cIdx * Self.intensityLevels.count + iIdx) * recencyTiers.count + rIdx
                    crispBuckets[bucket].move(to: startPoint)
                    crispBuckets[bucket].addArc(center: center, radius: r, startAngle: g.startAngle, endAngle: g.endAngle, clockwise: false)
                    crispHasArcs[bucket] = true
                }
            }

            if glowHasArcs.contains(true) || crispHasArcs.contains(true) {
                if glowHasArcs.contains(true) {
                    let glowStyle = StrokeStyle(lineWidth: step * 0.65, lineCap: .round)
                    context.drawLayer { glow in
                        glow.addFilter(.blur(radius: step * (isLight ? (isCompact ? 0.42 : 0.58) : (isCompact ? 0.55 : 0.75))))
                        for gIdx in 0..<glowPalette.count where glowHasArcs[gIdx] {
                            let bucketGlowAlpha = gIdx >= 4 ? (isLight ? 0.36 : 0.50) : glowAlpha
                            glow.stroke(glowBuckets[gIdx], with: .color(glowPalette[gIdx].opacity(bucketGlowAlpha)), style: glowStyle)
                        }
                    }
                }

                for cIdx in 0..<crispPalette.count {
                    let color = crispPalette[cIdx]
                    let widthBoost: CGFloat = cIdx >= 7 ? 1.32 : (cIdx >= 1 ? 1.12 : 1.0)
                    let bandMinAlpha: Double = cIdx >= 7 ? max(minArcAlpha, 0.94) : (cIdx >= 1 ? max(minArcAlpha, 0.84) : minArcAlpha)
                    for iIdx in 0..<Self.intensityLevels.count {
                        let level = Self.intensityLevels[iIdx]
                        let baseWidth = isCompact ? max(1.05, step * (0.48 + 0.34 * level)) : step * (0.44 + 0.34 * level)
                        let baseAlpha = bandMinAlpha + (1 - bandMinAlpha) * level
                        for rIdx in 0..<recencyTiers.count {
                            let bucket = (cIdx * Self.intensityLevels.count + iIdx) * recencyTiers.count + rIdx
                            guard crispHasArcs[bucket] else { continue }
                            let finalAlpha = min(1.0, baseAlpha * recencyTiers[rIdx])
                            context.stroke(
                                crispBuckets[bucket],
                                with: .color(color.opacity(finalAlpha)),
                                style: StrokeStyle(
                                    lineWidth: min(step * 0.86, baseWidth * widthBoost),
                                    lineCap: .round
                                )
                            )
                        }
                    }
                }
            }

            // 5. Crisp cardinal tick dots at 00 / 06 / 12 / 18h on the outer bezel ring.
            let dotDiameter = max(2.4, min(3.8, side * 0.016))
            let cardinalHours: [(Int, String)] = [(0, "00"), (6, "06"), (12, "12"), (18, "18")]
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
                    with: .color(hour == 0 ? dotZeroColor : dotMinorColor)
                )

                if showHourLabels {
                    let cappedLabelSize = isCompact ? min(cardinalLabelSize, 11.5) : min(cardinalLabelSize, 13.5)
                    let baseLabelRadius = isCompact ? (outerRingRadius + 10.0) : (outerRingRadius + max(12.0, side * 0.056) + max(0, cappedLabelSize - 11) * 0.45)
                    let labelRadius = (hour == 6 || hour == 18) ? baseLabelRadius + 2.5 : baseLabelRadius
                    let labelPoint = CGPoint(
                        x: center.x + labelRadius * CGFloat(cos(angle)),
                        y: center.y + labelRadius * CGFloat(sin(angle))
                    )
                    context.draw(
                        Text(label)
                            .font(.system(size: cappedLabelSize, weight: hour == 0 ? .bold : .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(hour == 0 ? labelZeroColor : labelMinorColor),
                        at: labelPoint
                    )
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

extension View {
    @ViewBuilder
    func dialClearAccessibilityAction(isActive: Bool, action: @escaping () -> Void) -> some View {
        if isActive {
            accessibilityAction(named: Text("Clear selection"), action)
        } else {
            self
        }
    }
}

/// Shared hit-testing, per-hour summary, and VoiceOver value helpers for interactive `EarprintGlyph` dials.
enum EarprintDialMath {
    static func innerRingRadius(side: CGFloat, showHourLabels: Bool = true, dayCount: Int = 28) -> CGFloat {
        let isCompact = side <= 220
        let outerRatio: CGFloat = showHourLabels ? (isCompact ? 0.775 : 0.78) : 0.94
        let outer = side / 2 * outerRatio
        let innerRatio: CGFloat = isCompact ? 0.47 : 0.44
        let inner = outer * innerRatio
        let step = (outer - inner) / CGFloat(max(dayCount, 1))
        let bezelGap = max(1.6, step * 0.55)
        return max(2, inner - bezelGap * 0.55)
    }

    static func innerWellWidth(side: CGFloat, showHourLabels: Bool = true, dayCount: Int = 28) -> CGFloat {
        max(44, innerRingRadius(side: side, showHourLabels: showHourLabels, dayCount: dayCount) * 1.78)
    }

    static func selectHour(
        at location: CGPoint,
        size: CGFloat,
        current: Int?,
        toggle: Bool,
        showHourLabels: Bool = true,
        dayCount: Int = 28
    ) -> Int? {
        let center = CGPoint(x: size / 2, y: size / 2)
        let dx = location.x - center.x, dy = location.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        let outerHitRadius = size / 2 * (showHourLabels ? 0.88 : 0.98)
        if distance < innerRingRadius(side: size, showHourLabels: showHourLabels, dayCount: dayCount) || distance > outerHitRadius {
            return toggle ? nil : current
        }
        var degrees = atan2(dy, dx) * 180 / .pi + 90
        if degrees < 0 { degrees += 360 }
        let hour = Int(degrees / 15) % 24
        return (toggle && current == hour) ? nil : hour
    }

    static func hourSummary(grid: ListeningGrid, hour: Int, days: Int = 28) -> (avgMinutesPerDay: Double, avgDB: Double) {
        let daysSlice = grid.minutes.suffix(days)
        let dbSlice = grid.decibels.suffix(days)
        let count = max(1, daysSlice.count)
        var totalMin = 0.0
        var totalEnergy = 0.0
        for (mRow, dRow) in zip(daysSlice, dbSlice) {
            guard mRow.indices.contains(hour), mRow[hour] > 0 else { continue }
            let m = mRow[hour]
            totalMin += m
            if dRow.indices.contains(hour), dRow[hour] > 0 {
                totalEnergy += pow(10, dRow[hour] / 10) * m
            }
        }
        let avgDB = (totalMin > 0 && totalEnergy > 0) ? 10 * log10(totalEnergy / totalMin) : 0
        return (totalMin / Double(count), avgDB)
    }

    static func adjustedHour(current: Int?, direction: AccessibilityAdjustmentDirection) -> Int? {
        switch direction {
        case .increment:
            guard let current else { return 0 }
            return current == 23 ? nil : current + 1
        case .decrement:
            guard let current else { return 23 }
            return current == 0 ? nil : current - 1
        @unknown default:
            return current
        }
    }

    static func accessibilityValue(
        grid: ListeningGrid,
        selectedHour: Int?,
        totalMinutes: Double,
        averageDB: Double? = nil,
        formatMinutes: (Double) -> String
    ) -> Text {
        if let hour = selectedHour {
            let hStats = hourSummary(grid: grid, hour: hour)
            if hStats.avgMinutesPerDay > 0 {
                if hStats.avgDB > 0 {
                    return Text("\(String(format: "%02d:00", hour)), \(formatMinutes(hStats.avgMinutesPerDay)) a day, \(Int(hStats.avgDB.rounded())) decibels")
                }
                return Text("\(String(format: "%02d:00", hour)), \(formatMinutes(hStats.avgMinutesPerDay)) a day")
            }
            return Text("\(String(format: "%02d:00", hour)), No listening data")
        }
        if let averageDB {
            if totalMinutes > 0 && averageDB > 0 {
                return Text("\(formatMinutes(totalMinutes)), \(Int(averageDB.rounded())) decibels average")
            } else if totalMinutes > 0 {
                return Text("\(formatMinutes(totalMinutes))")
            }
            return Text("No listening data")
        }
        return Text("\(formatMinutes(totalMinutes))")
    }
}
