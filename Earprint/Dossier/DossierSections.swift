import SwiftUI

// MARK: - Period switcher

/// Clean segmented period control with sliding neutral capsule thumb.
struct PeriodSwitcher: View {
    @Binding var period: DossierPeriod
    let rarity: Rarity
    var rangeText: String? = nil
    @Namespace private var thumb
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let isLight = colorScheme == .light
        let accent = DossierContrast.accentColor(rarity: rarity, proFoil: nil, colorScheme: colorScheme)
        let isAX = dynamicTypeSize.isAccessibilitySize
        VStack(spacing: 8) {
            Group {
                if isAX {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            periodButton(.week, isLight: isLight, accent: accent, isAX: true)
                            periodButton(.month, isLight: isLight, accent: accent, isAX: true)
                        }
                        HStack(spacing: 4) {
                            periodButton(.year, isLight: isLight, accent: accent, isAX: true)
                            periodButton(.all, isLight: isLight, accent: accent, isAX: true)
                        }
                    }
                    .padding(4)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(DossierPalette.surfaceFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(DossierPalette.hairline, lineWidth: 0.75)
                            )
                    }
                } else {
                    HStack(spacing: 4) {
                        ForEach(DossierPeriod.allCases) { p in
                            periodButton(p, isLight: isLight, accent: accent, isAX: false)
                        }
                    }
                    .padding(.horizontal, 3.5)
                    .background {
                        Capsule()
                            .fill(DossierPalette.surfaceFill)
                            .overlay(Capsule().strokeBorder(DossierPalette.hairline, lineWidth: 0.75))
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 20).onEnded { value in
                    guard abs(value.translation.width) > max(24, abs(value.translation.height) * 1.5) else { return }
                    step(value.translation.width < 0 ? 1 : -1)
                }
            )
            .sensoryFeedback(.selection, trigger: period)

            if let rangeText {
                Text(rangeText)
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(DossierPalette.dim)
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .animation(reduceMotion ? nil : .snappy, value: rangeText)
            }
        }
    }

    private func periodButton(_ p: DossierPeriod, isLight: Bool, accent: Color, isAX: Bool) -> some View {
        let selected = period == p
        let thumbCorner: CGFloat = isAX ? 14 : 999
        let thumbFill = isLight ? Theme.card : Color(red: 0.165, green: 0.172, blue: 0.225)
        let thumbBackground = RoundedRectangle(cornerRadius: thumbCorner, style: .continuous)
            .fill(thumbFill)
            .overlay(
                RoundedRectangle(cornerRadius: thumbCorner, style: .continuous)
                    .strokeBorder(isLight ? accent.opacity(0.36) : accent.opacity(0.45), lineWidth: isLight ? 0.85 : 0.95)
            )
            .shadow(color: isLight ? Theme.cardShadow : Color.black.opacity(0.32), radius: 4, y: 1)
        return Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.82)) { period = p }
        } label: {
            Text(LocalizedStringKey(p.title))
                .font(.subheadline.weight(selected ? .bold : .medium))
                .foregroundStyle(selected ? accent : DossierPalette.dim)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background {
                    if selected {
                        if reduceMotion {
                            thumbBackground
                        } else {
                            thumbBackground
                                .matchedGeometryEffect(id: "thumb", in: thumb)
                        }
                    }
                }
                .padding(.vertical, isAX ? 0 : 3.5)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(period == p ? .isSelected : [])
    }

    func step(_ delta: Int) {
        let all = DossierPeriod.allCases
        guard let i = all.firstIndex(of: period) else { return }
        let next = min(max(i + delta, 0), all.count - 1)
        withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.82)) { period = all[next] }
    }
}

// MARK: - Consolidated Hearing Health & Session Profile

struct HearingHealthCard: View {
    let stats: PeriodStats

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let hasAudio = stats.totalMinutes > 0 && stats.averageDecibels > 0
        let db = hasAudio ? stats.averageDecibels : 0
        let roundedDB = Int(db.rounded())
        let textColor = hasAudio ? Theme.levelTextColor(db: db) : DossierPalette.dim
        let verdict = !hasAudio ? "No data" : Theme.levelZoneName(db: db)
        let dosePct = hasAudio ? Int((stats.weeklyDose * 100).rounded()) : 0
        let doseTextColor = stats.weeklyDose < 0.5 ? DossierPalette.primaryText : (stats.weeklyDose < 1 ? Theme.moderateText : Theme.loudText)

        let doseTitle: LocalizedStringKey = switch stats.period {
        case .week: "Weekly WHO dose · 40h @ 80 dB(A)"
        case .month, .year, .all: "Avg weekly WHO dose · 40h @ 80 dB(A)"
        }

        let isAX = dynamicTypeSize.isAccessibilitySize
        let headerLayout = isAX
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        let avgPeakLegendLayout = isAX
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        let doseRowLayout = isAX
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 3))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))

        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                headerLayout {
                    Text("Hearing Health")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(DossierPalette.primaryText)
                        .accessibilityAddTraits(.isHeader)
                    if !isAX { Spacer(minLength: 8) }
                    if hasAudio {
                        let verdictZone: LocalizedStringKey = roundedDB < 66
                            ? "Quiet average"
                            : (roundedDB < 76 ? "Moderate average" : "Loud average")
                        Label(LocalizedStringKey(verdict), systemImage: roundedDB < 66 ? "checkmark.shield.fill" : (roundedDB < 76 ? "speaker.wave.2.fill" : "exclamationmark.triangle.fill"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(textColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(textColor.opacity(colorScheme == .light ? 0.10 : 0.16), in: Capsule())
                            .overlay(Capsule().strokeBorder(textColor.opacity(0.28), lineWidth: 0.75))
                            .accessibilityLabel(verdictZone)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    let avgSpoken = AppLanguage.current.text(
                        "%1$lld decibels average, %2$@ zone. Scale: quiet under 66, moderate 66 to 75, loud 76 plus decibels",
                        roundedDB,
                        AppLanguage.current.text(Theme.levelZoneName(db: db))
                    )
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(hasAudio ? "\(roundedDB)" : "—")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(DossierPalette.primaryText)
                            .contentTransition(reduceMotion ? .identity : .numericText(value: db))
                        if hasAudio {
                            Text("dB(A)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DossierPalette.dim)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(hasAudio ? Text(verbatim: avgSpoken) : Text("No data"))

                    if hasAudio {
                        avgPeakLegendLayout {
                            HStack(spacing: 4) {
                                DownTriangle()
                                    .fill(DossierPalette.primaryText)
                                    .frame(width: 7, height: 5)
                                    .accessibilityHidden(true)
                                Text("Average")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(DossierPalette.dim)
                            }
                            if !isAX { Spacer(minLength: 8) }
                            if stats.peakDecibels > 0 {
                                let peakRounded = Int(stats.peakDecibels.rounded())
                                HStack(spacing: 5) {
                                    Rectangle()
                                        .fill(DossierPalette.primaryText)
                                        .frame(width: 6.5, height: 6.5)
                                        .rotationEffect(.degrees(45))
                                        .accessibilityHidden(true)
                                    Text("Peak sample \(peakRounded) dB(A)")
                                        .font(.caption.weight(.medium))
                                        .monospacedDigit()
                                        .foregroundStyle(DossierPalette.dim)
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(Text(verbatim: AppLanguage.current.text("Peak sample %lld decibels", peakRounded)))
                            }
                        }
                    }
                }
            }

            LoudnessMeter(db: hasAudio ? db : nil, peakDB: hasAudio && stats.peakDecibels > 0 ? stats.peakDecibels : nil)
                .frame(height: 44)

            if hasAudio {
                Rectangle()
                    .fill(DossierPalette.hairline)
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: 6) {
                    doseRowLayout {
                        Text(doseTitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(DossierPalette.dim)
                            .lineLimit(isAX ? 2 : 1)
                            .minimumScaleFactor(0.82)
                        if !isAX { Spacer(minLength: 8) }
                        Text("\(dosePct)% of limit")
                            .font(.footnote.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(doseTextColor)
                            .lineLimit(1)
                            .contentTransition(reduceMotion ? .identity : .numericText(value: stats.weeklyDose))
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(stats.period == .week
                        ? "7-day WHO safe-listening dose, \(dosePct) percent of 40 hours per week at 80 decibels"
                        : "Average weekly WHO safe-listening dose, \(dosePct) percent of 40 hours per week at 80 decibels")

                    if stats.totalMinutes > 0 {
                        let doseBarTint = stats.weeklyDose >= 1 ? Theme.loudColor : (stats.weeklyDose >= 0.5 ? Theme.moderateColor : Theme.quietColor)
                        let clampedDose = min(max(0, stats.weeklyDose), 1)
                        let isLight = colorScheme == .light
                        let trackFill = isLight ? Color.black.opacity(0.14) : Color.white.opacity(0.16)
                        GeometryReader { geo in
                            let w = max(0, geo.size.width)
                            let fillW = (w > 0 && stats.weeklyDose > 0) ? min(w, max(6.0, w * clampedDose)) : 0
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(trackFill)
                                    .overlay(Capsule().strokeBorder(trackFill, lineWidth: 0.75))
                                if fillW > 0 {
                                    Capsule()
                                        .fill(doseBarTint)
                                        .frame(width: fillW)
                                }
                            }
                            .clipShape(Capsule())
                            .frame(height: 6)
                        }
                        .frame(height: 6)
                        .accessibilityHidden(true)
                    }
                }
            } else {
                Text("No loudness samples in this period")
                    .font(.footnote)
                    .foregroundStyle(DossierPalette.dim)
            }
        }
    }
}

struct SessionProfileCard: View {
    let stats: PeriodStats
    let rarity: Rarity
    var calendar: Calendar = .current

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title3) private var statValueSize: CGFloat = 24
    @ScaledMetric(relativeTo: .headline) private var longestValueSize: CGFloat = 18

    var body: some View {
        let isAX = dynamicTypeSize.isAccessibilitySize
        let headerLayout = isAX
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))

        VStack(alignment: .leading, spacing: 14) {
            headerLayout {
                Text("Wear Profile")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(DossierPalette.primaryText)
                    .accessibilityAddTraits(.isHeader)
                if !isAX { Spacer(minLength: 8) }
                Text(LocalizedStringKey(stats.period.windowTitle))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DossierPalette.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            if isAX {
                VStack(alignment: .leading, spacing: 10) {
                    profileStat(title: "Wears", value: "\(stats.sessionCount)", position: .leading, isStacked: true)
                    Rectangle().fill(DossierPalette.hairline).frame(height: 1)
                    profileStat(title: "Avg / wear", value: stats.sessionCount > 0 ? stats.averagePerWear.minutesText : "—", position: .trailing, isStacked: true)
                }
            } else {
                HStack(spacing: 0) {
                    profileStat(title: "Wears", value: "\(stats.sessionCount)", position: .leading, isStacked: false)
                    Rectangle().fill(DossierPalette.hairline).frame(width: 1).padding(.vertical, 2)
                    profileStat(title: "Avg / wear", value: stats.sessionCount > 0 ? stats.averagePerWear.minutesText : "—", position: .trailing, isStacked: false)
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            if let s = stats.longest {
                Rectangle()
                    .fill(DossierPalette.hairline)
                    .frame(height: 1)

                let longestLayout = isAX
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                    : AnyLayout(HStackLayout(alignment: .top))

                VStack(alignment: .leading, spacing: 10) {
                    longestLayout {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text("Longest wear")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(DossierPalette.dim)
                                if s.isEstimated {
                                    Text("EST.")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(DossierPalette.surfaceFill, in: Capsule())
                                        .overlay(Capsule().strokeBorder(DossierPalette.hairline, lineWidth: 0.75))
                                        .foregroundStyle(DossierPalette.dim)
                                        .accessibilityLabel("estimated")
                                }
                            }
                            Text(s.minutes.minutesText)
                                .font(.system(size: min(longestValueSize, 24), weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }
                        if !isAX { Spacer() }
                        VStack(alignment: isAX ? .leading : .trailing, spacing: 2) {
                            Text(s.start.dossierWeekdayShort(calendar: calendar))
                                .font(.footnote.weight(.semibold))
                                .lineLimit(isAX ? 2 : 1)
                                .minimumScaleFactor(0.8)
                            let metaLayout = isAX
                                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                                : AnyLayout(HStackLayout(spacing: 5))
                            metaLayout {
                                Text("\(s.start.dossierTime(calendar: calendar)) → \(s.end.dossierTime(calendar: calendar))")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(DossierPalette.dim)
                                if s.averageDecibels > 0 {
                                    if !isAX {
                                        Text("·")
                                            .font(.caption)
                                            .foregroundStyle(DossierPalette.faint)
                                    }
                                    HStack(spacing: 3.5) {
                                        Circle()
                                            .fill(Theme.levelColor(db: s.averageDecibels))
                                            .frame(width: 5.5, height: 5.5)
                                            .accessibilityHidden(true)
                                        Text("\(Int(s.averageDecibels.rounded())) dB(A)")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(DossierPalette.dim)
                                    }
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel(Text(verbatim: AppLanguage.current.text("%lld decibels", Int(s.averageDecibels.rounded()))))
                                }
                            }
                            .lineLimit(isAX ? 2 : 1)
                            .minimumScaleFactor(0.8)
                        }
                    }
                    .accessibilityElement(children: .combine)

                    SessionTrack(session: s, calendar: calendar)
                        .frame(height: 40)
                }
            }
        }
    }

    private enum ColumnPosition {
        case leading
        case middle
        case trailing
    }

    private func profileStat(title: LocalizedStringKey, value: String, position: ColumnPosition, isStacked: Bool) -> some View {
        let leadingPad: CGFloat = isStacked ? 0 : (position == .leading ? 0 : 12)
        let trailingPad: CGFloat = isStacked ? 0 : (position == .trailing ? 0 : 12)
        return VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: isStacked ? statValueSize : min(statValueSize, 26), weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.caption)
                .foregroundStyle(DossierPalette.dim)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.leading, leadingPad)
        .padding(.trailing, trailingPad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// A 24-hour strip with the session highlighted (wraps past midnight).
struct SessionTrack: View {
    let session: WearSession
    var calendar: Calendar = .current

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .caption2) private var tickSize: CGFloat = 11

    var body: some View {
        GeometryReader { geo in
            let startMin = Double(calendar.component(.hour, from: session.start) * 60 + calendar.component(.minute, from: session.start))
            let segs = segments(start: startMin, length: session.minutes)
            let wraps = segs.count > 1
            let w = geo.size.width
            let tickColor = colorScheme == .light ? Color.black.opacity(0.20) : Color.white.opacity(0.22)

            ZStack(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    Capsule().fill(Theme.surfaceFillStrong)
                    ForEach([6, 12, 18], id: \.self) { h in
                        Rectangle()
                            .fill(tickColor)
                            .frame(width: 1, height: 11)
                            .offset(x: w * CGFloat(h) / 24 - 0.5)
                    }
                    ForEach(Array(segs.enumerated()), id: \.0) { index, seg in
                        let segShape: AnyShape = if !wraps {
                            AnyShape(Capsule())
                        } else if index == 0 {
                            AnyShape(UnevenRoundedRectangle(
                                topLeadingRadius: 5.5,
                                bottomLeadingRadius: 5.5,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 0
                            ))
                        } else {
                            AnyShape(UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 5.5,
                                topTrailingRadius: 5.5
                            ))
                        }
                        segShape
                            .fill(Theme.levelColor(db: session.averageDecibels, colorScheme: colorScheme))
                            .frame(width: max(4, w * seg.1 / 1440), height: 11)
                            .offset(x: w * seg.0 / 1440)
                    }
                }
                .frame(width: w, height: 11)
                .clipShape(Capsule())

                ForEach([0, 6, 12, 18, 24], id: \.self) { h in
                    let tickX: CGFloat = h == 0 ? 0.5 : (h == 24 ? max(0.5, w - 0.5) : w * CGFloat(h) / 24)
                    Rectangle()
                        .fill(tickColor)
                        .frame(width: 1, height: 4)
                        .position(x: tickX, y: 14.5)
                }

                ZStack(alignment: .leading) {
                    Text("00")
                        .padding(.leading, 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach([6, 12, 18], id: \.self) { h in
                        Text(String(format: "%02d", h))
                            .position(x: w * CGFloat(h) / 24, y: 8)
                    }
                    Text("24")
                        .padding(.trailing, 2)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.system(size: min(tickSize, 13), weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DossierPalette.dim)
                .frame(height: 16)
                .offset(y: 19)
            }
        }
        .accessibilityHidden(true)
    }

    private func segments(start: Double, length: Double) -> [(Double, Double)] {
        let clampedLength = min(max(0, length), 1440)
        let end = start + clampedLength
        if end <= 1440 { return [(start, clampedLength)] }
        return [(start, 1440 - start), (0, end - 1440)]
    }
}

/// Inverted triangle indicator shared by the `LoudnessMeter` needle and `HearingHealthCard` readout.
private struct DownTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Gradient scale 40–100 dB(A) with a stationary precision gauge needle.
struct LoudnessMeter: View {
    let db: Double?
    var peakDB: Double? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption2) private var tickSize: CGFloat = 11

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let gap: CGFloat = 2
            let halfGap = gap / 2
            let x66 = w * (26.0 / 60.0)
            let x76 = w * (36.0 / 60.0)
            let quietW = max(0, x66 - halfGap)
            let modX = x66 + halfGap
            let modW = max(0, (x76 - halfGap) - modX)
            let loudX = x76 + halfGap
            let loudW = max(0, w - loudX)
            ZStack(alignment: .topLeading) {
                ZStack(alignment: .leading) {
                    UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 3, bottomTrailingRadius: 1, topTrailingRadius: 1)
                        .fill(Theme.quietColor)
                        .frame(width: quietW, height: 6)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Theme.moderateColor)
                        .frame(width: modW, height: 6)
                        .offset(x: modX)
                    UnevenRoundedRectangle(topLeadingRadius: 1, bottomLeadingRadius: 1, bottomTrailingRadius: 3, topTrailingRadius: 3)
                        .fill(Theme.loudColor)
                        .frame(width: loudW, height: 6)
                        .offset(x: loudX)
                }
                .frame(width: w, height: 6, alignment: .leading)
                .offset(y: 11)
                .opacity(0.90)

                let avgX = db.map { d -> CGFloat in
                    let t = CGFloat(min(max((d.rounded() - 40) / 60, 0), 1))
                    return min(max(4.5, w * t), max(4.5, w - 4.5))
                }
                let rawPeakX = peakDB.map { p -> CGFloat in
                    let pt = CGFloat(min(max((p.rounded() - 40) / 60, 0), 1))
                    return min(max(5.5, w * pt), max(5.5, w - 5.5))
                }
                let isPeakCrowded = avgX != nil && rawPeakX != nil && abs(rawPeakX! - avgX!) < 12

                if let rawPeakX {
                    Group {
                        Rectangle()
                            .fill(Theme.card)
                            .frame(width: 3.5, height: 6.5)
                            .position(x: rawPeakX, y: 14)
                        Rectangle()
                            .fill(DossierPalette.primaryText)
                            .frame(width: 1.5, height: isPeakCrowded ? 10 : 8)
                            .position(x: rawPeakX, y: isPeakCrowded ? 12 : 13)
                        let headX = isPeakCrowded
                            ? (rawPeakX >= avgX! ? min(w - 5.5, avgX! + 12) : max(5.5, avgX! - 12))
                            : rawPeakX
                        Rectangle()
                            .fill(DossierPalette.primaryText)
                            .frame(width: 6, height: 6)
                            .rotationEffect(.degrees(45))
                            .position(x: headX, y: isPeakCrowded ? 3 : 5)
                    }
                    .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.7), value: peakDB)
                }

                if let avgX {
                    Group {
                        Rectangle()
                            .fill(Theme.card)
                            .frame(width: 3.5, height: 6.5)
                            .position(x: avgX, y: 14)
                        Rectangle()
                            .fill(DossierPalette.primaryText)
                            .frame(width: 1.5, height: 9)
                            .position(x: avgX, y: 12.5)
                        DownTriangle()
                            .fill(DossierPalette.primaryText)
                            .frame(width: 9, height: 6)
                            .offset(x: avgX - 4.5, y: 2)
                    }
                    .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.7), value: db)
                }

                ForEach([0.5, x66, x76, max(0.5, w - 0.5)], id: \.self) { tickX in
                    Rectangle()
                        .fill(colorScheme == .light ? Color.black.opacity(0.22) : Color.white.opacity(0.24))
                        .frame(width: 1, height: 4)
                        .position(x: tickX, y: 20.5)
                }

                ZStack(alignment: .leading) {
                    Text("40")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("66")
                        .position(x: x66, y: 8)
                    Text("76")
                        .position(x: x76, y: 8)
                    Text("100")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.system(size: min(tickSize, 13), weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DossierPalette.dim)
                .frame(height: 16)
                .offset(y: 25)
            }
        }
        .accessibilityHidden(true)
    }
}
