import SwiftUI

// MARK: - Period switcher

/// Big pill with a sliding foil thumb. Swipe on it or tap a segment.
struct PeriodSwitcher: View {
    @Binding var period: DossierPeriod
    let rarity: Rarity
    let rangeText: String
    @Namespace private var thumb

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(DossierPeriod.allCases) { p in
                    Button {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { period = p }
                    } label: {
                        Text(LocalizedStringKey(p.title))
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(period == p ? rarity.ink : .white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background {
                                if period == p {
                                    Capsule()
                                        .fill(rarity.foil)
                                        .overlay(Capsule().fill(LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .top, endPoint: .center)))
                                        .shadow(color: rarity.glow.opacity(0.6), radius: 10, y: 2)
                                        .matchedGeometryEffect(id: "thumb", in: thumb)
                                }
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(period == p ? .isSelected : [])
                }
            }
            .padding(4)
            .background {
                Capsule().fill(.black.opacity(0.45))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1))
            }
            .gesture(
                DragGesture(minimumDistance: 20).onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    step(value.translation.width < 0 ? 1 : -1)
                }
            )
            .sensoryFeedback(.selection, trigger: period)

            Text(rangeText)
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundStyle(DossierPalette.dim)
                .contentTransition(.numericText())
                .animation(.snappy, value: rangeText)
        }
    }

    func step(_ delta: Int) {
        let all = DossierPeriod.allCases
        guard let i = all.firstIndex(of: period) else { return }
        let next = min(max(i + delta, 0), all.count - 1)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { period = all[next] }
    }
}

// MARK: - Airtime hero

/// Wearing time inside a bezel ring whose arc is the wear share against your other headphones.
struct AirtimeHero: View {
    let stats: PeriodStats
    let rarity: Rarity
    let otherDeviceCount: Int

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                bezel
                ring
                VStack(spacing: 2) {
                    Eyebrow(AppLanguage.current.text(stats.period.wornLabel), color: rarity.accent)
                    Text(stats.totalMinutes.minutesText)
                        .font(.system(size: 50, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .foregroundStyle(LinearGradient(colors: [.white, rarity.accent], startPoint: .top, endPoint: .bottom))
                        .contentTransition(.numericText(value: stats.totalMinutes))
                    HStack(spacing: 4) {
                        Text("\(Int((stats.share * 100).rounded()))%")
                            .font(.system(.headline, design: .rounded, weight: .heavy))
                            .contentTransition(.numericText(value: stats.share))
                        Text("wear share")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(DossierPalette.dim)
                    }
                }
                .padding(.horizontal, 44)
            }
            .frame(width: 280, height: 280)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Worn \(stats.totalMinutes.minutesText), \(Int((stats.share * 100).rounded())) percent of all headphone listening")

            HStack(spacing: 0) {
                fact(stats.dailyAverage.minutesText, "a day", value: stats.dailyAverage)
                divider
                changeFact
                divider
                fact("\(stats.activeDays)/\(stats.spanDays)", "days worn", value: Double(stats.activeDays))
            }
            .padding(.vertical, 12)
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(DossierPalette.hairline, lineWidth: 1))
        }
    }

    private var divider: some View { Rectangle().fill(DossierPalette.hairline).frame(width: 1, height: 34) }

    private func fact(_ text: String, _ caption: LocalizedStringKey, value: Double) -> some View {
        VStack(spacing: 3) {
            Text(text)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText(value: value))
            Text(caption).font(.caption).foregroundStyle(DossierPalette.dim)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var changeFact: some View {
        if let change = stats.change {
            let up = change >= 0
            VStack(spacing: 3) {
                HStack(spacing: 3) {
                    Image(systemName: up ? "arrow.up.right" : "arrow.down.right").font(.caption.weight(.heavy))
                    Text("\(Int((abs(change) * 100).rounded()))%")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .contentTransition(.numericText(value: change))
                }
                .foregroundStyle(up ? Theme.quiet.color : Theme.moderate.color)
                Text(LocalizedStringKey(stats.period.previousLabel)).font(.caption).foregroundStyle(DossierPalette.dim)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        } else {
            fact("\(stats.sessionCount)", "wears", value: Double(stats.sessionCount))
        }
    }

    /// Watch-style tick bezel.
    private var bezel: some View {
        Canvas { context, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2
            for i in 0..<120 {
                let a = Double(i) / 120 * 2 * .pi - .pi / 2
                let long = i % 10 == 0
                let r0 = r - (long ? 9 : 5)
                var p = Path()
                p.move(to: CGPoint(x: c.x + r0 * cos(a), y: c.y + r0 * sin(a)))
                p.addLine(to: CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a)))
                context.stroke(p, with: .color(.white.opacity(long ? 0.35 : 0.13)), lineWidth: long ? 1.5 : 1)
            }
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.07), style: StrokeStyle(lineWidth: 16))
            // Other headphones: the remainder, dotted.
            Circle()
                .trim(from: stats.share, to: 1)
                .stroke(.white.opacity(0.22), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [1, 6]))
                .rotationEffect(.degrees(-90))
            Circle()
                .trim(from: 0, to: max(0.002, stats.share))
                .stroke(AngularGradient(colors: rarity.baseColors + [rarity.baseColors[0]], center: .center, angle: .degrees(-90)),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: rarity.glow.opacity(0.7), radius: 12)
        }
        .padding(22)
        .animation(.spring(response: 0.8, dampingFraction: 0.8), value: stats.share)
    }
}

// MARK: - Habits bento

struct HabitsBento: View {
    let stats: PeriodStats
    let dossier: DeviceDossier
    let rarity: Rarity

    var body: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                wearsTile
                perWearTile
            }
            GridRow { longestTile.gridCellColumns(2) }
            GridRow { volumeTile.gridCellColumns(2) }
            GridRow {
                activeDaysTile
                sessionsPerDayTile
            }
        }
    }

    private func value(_ text: String, _ v: Double) -> some View {
        Text(text)
            .font(.system(.title2, design: .rounded, weight: .heavy))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .contentTransition(.numericText(value: v))
    }

    private var wearsTile: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Wears")
            value("\(stats.sessionCount)", Double(stats.sessionCount))
            Spacer(minLength: 0)
            TallyMarks(count: stats.sessionCount, color: rarity.accent)
                .frame(height: 30)
        }
        .frame(minHeight: 128)
        .dossierTile(tint: rarity.accent)
        .accessibilityElement(children: .combine)
    }

    private var perWearTile: some View {
        let longest = stats.longest?.minutes ?? 1
        let ratio = stats.averagePerWear / max(longest, 1)
        return VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Avg per wear")
            value(stats.averagePerWear.minutesText, stats.averagePerWear)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                ZStack {
                    Circle().stroke(.white.opacity(0.1), lineWidth: 5)
                    Circle().trim(from: 0, to: ratio).stroke(Theme.quiet.color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 28, height: 28)
                .animation(.spring, value: ratio)
                Text("\(Int((ratio * 100).rounded()))% of your longest")
                    .font(.caption2)
                    .foregroundStyle(DossierPalette.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(minHeight: 128)
        .dossierTile(tint: Theme.quiet.color)
        .accessibilityElement(children: .combine)
    }

    private var longestTile: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Eyebrow("Longest single wear")
                        if stats.longest?.isEstimated == true {
                            Text("EST.")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Theme.moderate.color.opacity(0.2), in: Capsule())
                                .foregroundStyle(Theme.moderate.color)
                                .accessibilityLabel("estimated")
                        }
                    }
                    value(stats.longest?.minutes.minutesText ?? "—", stats.longest?.minutes ?? 0)
                }
                Spacer()
                if let s = stats.longest {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(s.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .font(.footnote.weight(.semibold))
                        Text("\(s.start.dossierTime) → \(s.end.dossierTime)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(DossierPalette.dim)
                    }
                }
            }
            if let s = stats.longest {
                SessionTrack(session: s, rarity: rarity)
                    .frame(height: 26)
            }
        }
        .dossierTile(tint: rarity.accent)
        .accessibilityElement(children: .combine)
    }

    private var volumeTile: some View {
        let db = stats.averageDecibels
        let color = Theme.levelColor(db: db)
        let verdict = db < 60 ? "Comfortable" : (db < 72 ? "Moderate" : (db < 80 ? "Loud" : "Very loud"))
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow("Average volume")
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        value("\(Int(db.rounded()))", db)
                        Text("dB(A)").font(.footnote.weight(.semibold)).foregroundStyle(DossierPalette.dim)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Label(LocalizedStringKey(verdict), systemImage: db < 72 ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(color)
                    Text("peak \(Int(stats.peakDecibels.rounded())) dB")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(DossierPalette.dim)
                }
            }
            LoudnessMeter(db: db)
                .frame(height: 30)
            HStack {
                Text("Weekly hearing dose")
                    .font(.caption)
                    .foregroundStyle(DossierPalette.dim)
                Spacer()
                Text("\(max(1, Int((stats.weeklyDose * 100).rounded())))% of WHO limit")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(stats.weeklyDose < 0.5 ? Theme.quiet.color : (stats.weeklyDose < 1 ? Theme.moderate.color : Theme.loud.color))
                    .contentTransition(.numericText(value: stats.weeklyDose))
            }
        }
        .dossierTile(tint: color)
        .accessibilityElement(children: .combine)
    }

    private var activeDaysTile: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Days worn")
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                value("\(stats.activeDays)", Double(stats.activeDays))
                Text("/\(stats.spanDays)").font(.footnote.weight(.semibold)).foregroundStyle(DossierPalette.dim)
            }
            Spacer(minLength: 0)
            DayDots(days: Array(dossier.days.filter { $0.date >= stats.start }.suffix(35)), color: rarity.accent)
        }
        .frame(minHeight: 128)
        .dossierTile()
        .accessibilityElement(children: .combine)
    }

    private var sessionsPerDayTile: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Wears a day")
            value(String(format: "%.1f", stats.sessionsPerDay), stats.sessionsPerDay)
            Spacer(minLength: 0)
            Sparkline(values: stats.buckets.map { Double($0.sessions) }, color: Theme.quiet.color)
                .frame(height: 30)
        }
        .frame(minHeight: 128)
        .dossierTile()
        .accessibilityElement(children: .combine)
    }
}

/// Groups of five tally strokes, capped so it never overflows.
struct TallyMarks: View {
    let count: Int
    let color: Color

    var body: some View {
        Canvas { context, size in
            let groupWidth: CGFloat = 22
            let groups = min(Int(size.width / groupWidth), max(1, Int(ceil(Double(count) / 5))))
            let perGroupValue = max(1, Double(count) / Double(groups * 5))
            var drawn = 0
            for g in 0..<groups {
                let x0 = CGFloat(g) * groupWidth
                for i in 0..<4 where Double(drawn) * perGroupValue < Double(count) {
                    var p = Path()
                    p.move(to: CGPoint(x: x0 + CGFloat(i) * 4 + 2, y: 4))
                    p.addLine(to: CGPoint(x: x0 + CGFloat(i) * 4 + 1, y: size.height - 4))
                    context.stroke(p, with: .color(color.opacity(0.8)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    drawn += 1
                }
                if Double(drawn) * perGroupValue < Double(count) {
                    var slash = Path()
                    slash.move(to: CGPoint(x: x0 - 1, y: size.height - 7))
                    slash.addLine(to: CGPoint(x: x0 + 17, y: 7))
                    context.stroke(slash, with: .color(color), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    drawn += 1
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// A 24-hour strip with the session highlighted (wraps past midnight).
struct SessionTrack: View {
    let session: WearSession
    let rarity: Rarity

    var body: some View {
        GeometryReader { geo in
            let cal = Calendar.current
            let startMin = Double(cal.component(.hour, from: session.start) * 60 + cal.component(.minute, from: session.start))
            let w = geo.size.width
            ZStack(alignment: .topLeading) {
                Capsule().fill(.white.opacity(0.06)).frame(height: 8)
                ForEach(segments(start: startMin, length: session.minutes), id: \.0) { seg in
                    Capsule()
                        .fill(LinearGradient(colors: [rarity.accent, Theme.levelColor(db: session.averageDecibels)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(4, w * seg.1 / 1440), height: 8)
                        .offset(x: w * seg.0 / 1440)
                        .shadow(color: rarity.glow.opacity(0.6), radius: 5)
                }
                ForEach([0, 6, 12, 18, 24], id: \.self) { h in
                    Text(String(format: "%02d", h % 24))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DossierPalette.faint)
                        .position(x: min(max(8, w * CGFloat(h) / 24), w - 8), y: 20)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func segments(start: Double, length: Double) -> [(Double, Double)] {
        let end = start + length
        if end <= 1440 { return [(start, length)] }
        return [(start, 1440 - start), (0, end - 1440)]
    }
}

/// Gradient scale 40–100 dB(A) with a pointer.
struct LoudnessMeter: View {
    let db: Double

    var body: some View {
        GeometryReader { geo in
            let t = CGFloat(min(max((db - 40) / 60, 0), 1))
            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(LinearGradient(colors: [Theme.quiet.color, Theme.quiet.color, Theme.moderate.color, Theme.loud.color], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 6)
                    .opacity(0.85)
                Circle()
                    .fill(.white)
                    .frame(width: 14, height: 14)
                    .shadow(color: Theme.levelColor(db: db), radius: 6)
                    .offset(x: geo.size.width * t - 7, y: -4)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: db)
                ForEach([40, 60, 80, 100], id: \.self) { mark in
                    Text("\(mark)")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DossierPalette.faint)
                        .position(x: min(max(8, geo.size.width * CGFloat(mark - 40) / 60), geo.size.width - 10), y: 22)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct DayDots: View {
    let days: [DayStat]
    let color: Color

    var body: some View {
        let columns = days.count <= 7 ? 7 : (days.count <= 14 ? 7 : 10)
        let maxM = max(days.map(\.minutes).max() ?? 1, 1)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: columns), spacing: 3) {
            ForEach(days) { d in
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(d.minutes > 0 ? color.opacity(0.25 + 0.75 * d.minutes / maxM) : .white.opacity(0.07))
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .accessibilityHidden(true)
    }
}

struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard values.count > 1, let maxV = values.max(), maxV > 0 else { return }
            var path = Path()
            for (i, v) in values.enumerated() {
                let p = CGPoint(x: size.width * CGFloat(i) / CGFloat(values.count - 1), y: size.height - size.height * CGFloat(v / maxV) * 0.9 - 2)
                i == 0 ? path.move(to: p) : path.addLine(to: p)
            }
            var fill = path
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: 0, y: size.height))
            fill.closeSubpath()
            context.fill(fill, with: .linearGradient(Gradient(colors: [color.opacity(0.35), .clear]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}
