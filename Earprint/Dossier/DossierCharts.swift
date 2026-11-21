import Charts
import SwiftUI

/// Bar chart of listening per bucket with drag-to-scrub, a floating label and haptic ticks.
struct DossierTrendChart: View {
    let stats: PeriodStats
    let rarity: Rarity
    let firstWear: Date?
    @Binding var selection: Date?
    var showsInteractionHint = true
    var showsMintedMarker = true

    @Environment(\.colorScheme) private var colorScheme

    private var selected: TrendBucket? {
        guard let selection else { return nil }
        return stats.buckets.first { selection >= $0.start && selection < $0.end }
    }

    private var countedBuckets: [TrendBucket] {
        guard let firstWear else { return stats.buckets }
        return stats.buckets.filter { $0.end > firstWear }
    }

    private var average: Double {
        let list = countedBuckets
        return list.isEmpty ? 0 : list.reduce(0) { $0 + $1.minutes } / Double(list.count)
    }

    private var unitName: String {
        switch stats.bucketUnit {
        case .day: "day"
        case .weekOfYear: "week"
        default: "month"
        }
    }

    private var title: String {
        switch stats.period {
        case .week: "Last 7 days"
        case .month: "Last 30 days"
        case .year: "Last 12 months"
        case .all: "Since minted · by \(unitName)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(selected.map { bucketTitle($0) } ?? title)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text((selected?.minutes ?? average).minutesText)
                            .font(.system(.title, design: .rounded, weight: .heavy))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: selected?.minutes ?? average))
                        Text(selected == nil ? "avg / \(unitName)" : "")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(DossierPalette.dim)
                    }
                }
                Spacer()
                if let s = selected {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(s.minutes > 0 ? "\(Int(s.averageDecibels.rounded())) dB(A)" : "—")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(s.minutes > 0 ? Theme.levelColor(db: s.averageDecibels, colorScheme: colorScheme) : DossierPalette.dim)
                        Text("\(s.sessions) wears")
                            .font(.caption)
                            .foregroundStyle(DossierPalette.dim)
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else if let best = stats.bestBucket {
                    VStack(alignment: .trailing, spacing: 3) {
                        Label("Best \(unitName)", systemImage: "crown.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(rarity.accent)
                        Text("\(best.minutes.minutesText) · \(shortLabel(best))")
                            .font(.caption)
                            .foregroundStyle(DossierPalette.dim)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.snappy, value: selected?.id)

            chart
                .frame(height: 210)
                .padding(.top, 4)

            if showsInteractionHint {
                Text(selection == nil ? "Drag across the bars to scrub · color shows loudness" : " ")
                    .font(.caption2)
                    .foregroundStyle(DossierPalette.faint)
            }
        }
        .sensoryFeedback(.selection, trigger: selected?.id)
    }

    private var chart: some View {
        let best = stats.bestBucket
        return Chart {
            ForEach(stats.buckets) { bucket in
                BarMark(
                    x: .value("Date", bucket.start, unit: stats.bucketUnit),
                    y: .value("Hours", bucket.minutes / 60),
                    width: .ratio(stats.buckets.count > 20 ? 0.62 : 0.56)
                )
                .cornerRadius(stats.buckets.count > 20 ? 2.5 : 5)
                .foregroundStyle(barStyle(bucket, best: best?.id == bucket.id))
                .opacity(selected == nil || selected?.id == bucket.id ? 1 : 0.3)
                .annotation(position: .top, spacing: 3) {
                    if best?.id == bucket.id, selected == nil {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(rarity.accent)
                            .shadow(color: rarity.glow, radius: 4)
                    }
                }
            }

            if average > 0 {
                RuleMark(y: .value("Average", average / 60))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .foregroundStyle(DossierPalette.faint)
            }

            if showsMintedMarker, let firstWear, stats.bucketUnit == .day, let firstBucket = stats.buckets.first, firstWear > firstBucket.end {
                RuleMark(x: .value("Minted", Calendar.current.startOfDay(for: firstWear), unit: .day))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .foregroundStyle(rarity.accent.opacity(0.7))
                    .annotation(position: .top, alignment: .leading, spacing: 2) {
                        Label("MINTED", systemImage: "sparkle")
                            .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(rarity.accent)
                    }
            }

            if let s = selected {
                RuleMark(x: .value("Selected", s.start, unit: stats.bucketUnit))
                    .foregroundStyle(DossierPalette.surfaceFill)
                    .lineStyle(StrokeStyle(lineWidth: 18))
                    .zIndex(-1)
            }
        }
        .chartXSelection(value: $selection)
        .chartYScale(domain: 0...(max((stats.buckets.map(\.minutes).max() ?? 60) / 60, 1) * 1.18))
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(DossierPalette.hairline)
                AxisValueLabel {
                    if let h = value.as(Double.self) { Text("\(Int(h))h").foregroundStyle(DossierPalette.faint) }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: xValues) { value in
                AxisValueLabel(format: xFormat, centered: true)
                    .foregroundStyle(DossierPalette.dim)
            }
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.82), value: stats.period)
    }

    private var xValues: AxisMarkValues {
        switch (stats.period, stats.bucketUnit) {
        case (.week, _): .stride(by: .day)
        case (_, .day): .stride(by: .day, count: 7)
        case (.year, _): .stride(by: .month)
        default: .stride(by: .month)
        }
    }

    private var xFormat: Date.FormatStyle {
        switch (stats.period, stats.bucketUnit) {
        case (.week, _): .dateTime.weekday(.abbreviated)
        case (_, .day): .dateTime.month(.abbreviated).day()
        case (.year, _): .dateTime.month(.narrow)
        default: .dateTime.month(.abbreviated)
        }
    }

    private func barStyle(_ bucket: TrendBucket, best: Bool) -> LinearGradient {
        let color = bucket.minutes > 0 ? Theme.levelColor(db: bucket.averageDecibels, colorScheme: colorScheme) : DossierPalette.hairline
        if best {
            return LinearGradient(colors: [rarity.accent, color], startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(colors: [color, color.opacity(colorScheme == .light ? 0.55 : 0.35)], startPoint: .top, endPoint: .bottom)
    }

    private func bucketTitle(_ b: TrendBucket) -> String {
        switch stats.bucketUnit {
        case .day: b.start.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        case .weekOfYear: "Week of \(b.start.dossierShort)"
        default: b.start.formatted(.dateTime.month(.wide).year())
        }
    }

    private func shortLabel(_ b: TrendBucket) -> String {
        switch stats.bucketUnit {
        case .day: b.start.dossierShort
        case .weekOfYear: "wk of \(b.start.dossierShort)"
        default: b.start.formatted(.dateTime.month(.abbreviated))
        }
    }
}

// MARK: - Day clock

/// 24-hour dial: one radial bar per hour, length = listening, color = loudness. Press and drag around it to scrub.
struct DayClock: View {
    let stats: PeriodStats
    let rarity: Rarity
    @Binding var selectedHour: Int?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let nightAccent = Color.adaptive(
            light: UIColor(red: 0.28, green: 0.36, blue: 0.78, alpha: 1),
            dark: UIColor(red: 0.6, green: 0.65, blue: 1, alpha: 1)
        )
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                dial(size: size)
                centerLabel
                    .frame(width: size * 0.5)
                ForEach([(0, "moon.stars.fill"), (6, "sunrise.fill"), (12, "sun.max.fill"), (18, "sunset.fill")], id: \.0) { hour, icon in
                    let angle = (Double(hour) * 15 - 90) * .pi / 180
                    let r = size / 2 - 11
                    VStack(spacing: 1) {
                        Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                        Text(String(format: "%02d", hour)).font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(hour == 0 ? nightAccent : (hour == 12 ? Theme.moderateColor : DossierPalette.dim))
                    .position(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Circle())
            .onTapGesture { location in select(location, center: center, size: size, toggle: true) }
            .gesture(
                LongPressGesture(minimumDuration: 0.15)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onChanged { value in
                        if case .second(true, let drag?) = value { select(drag.location, center: center, size: size, toggle: false) }
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .sensoryFeedback(.selection, trigger: selectedHour)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Listening by hour of day")
        .accessibilityValue(accessibilityValue)
        .accessibilityAdjustableAction { direction in
            let current = selectedHour ?? (stats.peakHour?.hour ?? 0)
            selectedHour = (current + (direction == .increment ? 1 : 23)) % 24
        }
    }

    private var accessibilityValue: String {
        let h = selectedHour ?? stats.peakHour?.hour ?? 0
        let stat = stats.hours[h]
        return "\(DossierFormat.hourLabel(h)), \((stat.minutes / Double(stats.spanDays)).minutesText) a day"
    }

    private func select(_ location: CGPoint, center: CGPoint, size: CGFloat, toggle: Bool) {
        let dx = location.x - center.x, dy = location.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        if distance < size * 0.2 { if toggle { selectedHour = nil }; return }
        var degrees = atan2(dy, dx) * 180 / .pi + 90
        if degrees < 0 { degrees += 360 }
        let hour = Int(degrees / 15) % 24
        selectedHour = (toggle && selectedHour == hour) ? nil : hour
    }

    @ViewBuilder private var centerLabel: some View {
        let h = selectedHour ?? stats.peakHour?.hour
        if let h {
            let stat = stats.hours[h]
            let perDay = stat.minutes / Double(max(stats.spanDays, 1))
            VStack(spacing: 2) {
                Eyebrow(selectedHour == nil ? "Peak hour" : "Selected", color: rarity.accent)
                Text(String(format: "%02d:00", h))
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(h)))
                Text("\(perDay.minutesText) a day")
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .contentTransition(.numericText(value: perDay))
                if stat.minutes > 0 {
                    Text("\(Int(stat.averageDecibels.rounded())) dB(A)")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.levelColor(db: stat.averageDecibels, colorScheme: colorScheme))
                }
            }
            .multilineTextAlignment(.center)
            .animation(.snappy, value: h)
        } else {
            Text("No listening yet").font(.footnote).foregroundStyle(DossierPalette.dim)
        }
    }

    private func dial(size: CGFloat) -> some View {
        let isLight = colorScheme == .light
        let trackFill = isLight ? Color.black.opacity(0.05) : Color.white.opacity(0.035)
        let selectionStroke = isLight ? Color.black.opacity(0.75) : Color.white.opacity(0.9)
        let innerDiscFill = isLight ? Color.black.opacity(0.04) : Color.white.opacity(0.03)
        return Canvas { context, canvasSize in
            let c = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let outer = size / 2 - 33
            let inner = outer * 0.49
            let maxMinutes = max(stats.hours.map(\.minutes).max() ?? 1, 1)

            func sector(_ hour: Int, from r0: CGFloat, to r1: CGFloat, gap: Double = 2.2) -> Path {
                let a0 = Angle.degrees(Double(hour) * 15 - 90 + gap / 2)
                let a1 = Angle.degrees(Double(hour + 1) * 15 - 90 - gap / 2)
                var p = Path()
                p.addArc(center: c, radius: r1, startAngle: a0, endAngle: a1, clockwise: false)
                p.addArc(center: c, radius: r0, startAngle: a1, endAngle: a0, clockwise: true)
                p.closeSubpath()
                return p
            }

            // Day & night outer band + 24 background tracks batched into 3 paths (instead of 48 draw calls).
            var dayBand = Path()
            var nightBand = Path()
            var tracks = Path()
            for hour in 0..<24 {
                let band = sector(hour, from: outer + 4, to: outer + 7, gap: 0.6)
                if (6..<18).contains(hour) {
                    dayBand.addPath(band)
                } else {
                    nightBand.addPath(band)
                }
                tracks.addPath(sector(hour, from: inner, to: outer))
            }
            context.fill(dayBand, with: .color(Theme.moderateColor.opacity(0.35)))
            context.fill(nightBand, with: .color(Color(red: 0.45, green: 0.5, blue: 1).opacity(0.35)))
            context.fill(tracks, with: .color(trackFill))
            func bars(_ ctx: inout GraphicsContext) {
                for stat in stats.hours where stat.minutes > 0 {
                    let t = CGFloat(stat.minutes / maxMinutes)
                    let r1 = inner + (outer - inner) * max(0.08, t)
                    var color = Theme.levelColor(db: stat.averageDecibels, colorScheme: colorScheme)
                    if let selectedHour, selectedHour != stat.hour { color = color.opacity(0.3) }
                    ctx.fill(sector(stat.hour, from: inner, to: r1), with: .color(color.opacity(0.4 + 0.6 * Double(t))))
                }
            }
            context.drawLayer { glow in
                glow.addFilter(.blur(radius: 8))
                glow.opacity = isLight ? 0.25 : 0.7
                bars(&glow)
            }
            bars(&context)
            if let selectedHour {
                context.stroke(sector(selectedHour, from: inner - 3, to: outer + 2, gap: 0.8), with: .color(selectionStroke), lineWidth: 1.5)
            }
            // Inner disc.
            context.fill(Path(ellipseIn: CGRect(x: c.x - inner + 6, y: c.y - inner + 6, width: (inner - 6) * 2, height: (inner - 6) * 2)),
                         with: .color(innerDiscFill))
        }
    }
}
