import Charts
import SwiftUI

/// Unified Activity Listening card: period hero total, non-redundant key facts, and interactive trend chart.
struct ActivityListeningCard: View {
    let stats: PeriodStats
    let rarity: Rarity
    let firstWear: Date?
    @Binding var selection: Date?
    var rangeText: String? = nil
    var chartHeight: CGFloat = 168
    var calendar: Calendar = .current

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 38
    @ScaledMetric(relativeTo: .caption2) private var barPillSize: CGFloat = 10
    @ScaledMetric(relativeTo: .caption2) private var mintedLabelSize: CGFloat = 11

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

    private var averageLabelText: LocalizedStringKey {
        switch stats.bucketUnit {
        case .day: "Avg \(average.minutesText) / day"
        case .weekOfYear: "Avg \(average.minutesText) / week"
        default: "Avg \(average.minutesText) / month"
        }
    }

    private var shortChartHeading: LocalizedStringKey {
        switch stats.bucketUnit {
        case .day: "Daily hours · Drag to inspect"
        case .weekOfYear: "Weekly hours · Drag to inspect"
        default: "Monthly hours · Drag to inspect"
        }
    }

    private var title: String {
        switch stats.period {
        case .week: AppLanguage.current.text("Last 7 Days")
        case .month: AppLanguage.current.text("Last 30 Days")
        case .year: AppLanguage.current.text("Last 12 Months")
        case .all: AppLanguage.current.text("All Time · by %@", AppLanguage.current.text(unitName))
        }
    }

    var body: some View {
        let accent = DossierContrast.accentColor(rarity: rarity, proFoil: nil, colorScheme: colorScheme)
        let targetDays = stats.period.days
        let isPartialWindow = targetDays.map { stats.spanDays < $0 } ?? false
        let wornValue = targetDays.flatMap { stats.spanDays < $0 ? AppLanguage.current.text("%lld of %lld", stats.activeDays, $0) : nil }
            ?? "\(stats.activeDays)/\(stats.spanDays)"
        let showsShareFact = stats.share > 0 && stats.share < 1
        let shareValue = "\(Int((stats.share * 100).rounded()))%"
        let dailyCaption: LocalizedStringKey = isPartialWindow ? "Daily avg (\(stats.spanDays)d)" : "Daily avg"

        let isAX = dynamicTypeSize.isAccessibilitySize
        let headerTitleLayout = isAX
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        let heroRowLayout = isAX
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 10))

        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                headerTitleLayout {
                    Text(verbatim: selected.map { DossierTrendPlot.bucketTitle($0, unit: stats.bucketUnit, calendar: calendar) } ?? title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(DossierPalette.primaryText)
                        .lineLimit(isAX ? 2 : 1)
                        .minimumScaleFactor(0.8)
                        .accessibilityAddTraits(.isHeader)
                    if !isAX { Spacer(minLength: 8) }
                    if let rangeText, selected == nil {
                        Text(rangeText)
                            .font(.caption.weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(DossierPalette.dim)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }

                heroRowLayout {
                    let displayedMinutes = selected?.minutes ?? stats.totalMinutes
                    Text(displayedMinutes.minutesText)
                        .font(.system(size: min(heroSize, 48), weight: .heavy, design: .rounded))
                        .tracking(-0.8)
                        .monospacedDigit()
                        .foregroundStyle(DossierPalette.primaryText)
                        .lineLimit(isAX ? 2 : 1)
                        .minimumScaleFactor(0.80)
                        .contentTransition(reduceMotion ? .identity : .numericText(value: displayedMinutes))

                    if !isAX { Spacer(minLength: 8) }

                    if let s = selected {
                        let dbLabel = s.minutes > 0 ? "\(Int(s.averageDecibels.rounded())) dB(A)" : "—"
                        Text("\(dbLabel) · \(s.sessions) wears")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(DossierPalette.dim)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } else if let change = stats.change {
                        let up = change >= 0
                        let pct = Int((abs(change) * 100).rounded())
                        HStack(spacing: 3) {
                            Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption2.weight(.bold))
                            Text("\(pct)% \(AppLanguage.current.text(stats.period.shortPrevLabel))")
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                        }
                        .foregroundStyle(DossierPalette.primaryText.opacity(0.84))
                        .padding(.horizontal, 8.5)
                        .padding(.vertical, 3.5)
                        .background(DossierPalette.surfaceFill, in: Capsule())
                        .overlay(Capsule().strokeBorder(DossierPalette.hairline, lineWidth: 0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            up
                                ? "Up \(pct) percent \(AppLanguage.current.text(stats.period.previousLabel))"
                                : "Down \(pct) percent \(AppLanguage.current.text(stats.period.previousLabel))"
                        )
                    }
                }
            }

            Rectangle()
                .fill(DossierPalette.hairline)
                .frame(height: 1)

            let stackFacts = isAX || dynamicTypeSize >= .xxLarge
            if stackFacts {
                VStack(alignment: .leading, spacing: 10) {
                    fact(wornValue, "Days worn", position: .leading, isStacked: true)
                    if let best = stats.bestBucket {
                        let bestLabel = DossierTrendPlot.shortLabel(best, unit: stats.bucketUnit, calendar: calendar)
                        let bestCaption = stats.bucketUnit == .day
                            ? AppLanguage.current.text("Best day · %@", bestLabel)
                            : AppLanguage.current.text("Best · %@", bestLabel)
                        Rectangle().fill(DossierPalette.hairline).frame(height: 1)
                        fact(best.minutes.minutesText, bestCaption, verbatimCaption: true, position: showsShareFact ? .middle : .trailing, isStacked: true)
                    }
                    if showsShareFact {
                        Rectangle().fill(DossierPalette.hairline).frame(height: 1)
                        fact(shareValue, LocalizedStringKey(stats.period.shareCaption), position: .trailing, isStacked: true)
                    } else if stats.bestBucket == nil {
                        Rectangle().fill(DossierPalette.hairline).frame(height: 1)
                        fact(stats.dailyAverage.minutesText, dailyCaption, position: .trailing, isStacked: true)
                    }
                }
            } else {
                HStack(spacing: 0) {
                    fact(wornValue, "Days worn", position: .leading, isStacked: false)
                    if let best = stats.bestBucket {
                        let bestLabel = DossierTrendPlot.shortLabel(best, unit: stats.bucketUnit, calendar: calendar)
                        let bestCaption = stats.bucketUnit == .day
                            ? AppLanguage.current.text("Best day · %@", bestLabel)
                            : AppLanguage.current.text("Best · %@", bestLabel)
                        factDivider
                        fact(best.minutes.minutesText, bestCaption, verbatimCaption: true, position: showsShareFact ? .middle : .trailing, isStacked: false)
                    }
                    if showsShareFact {
                        factDivider
                        fact(shareValue, LocalizedStringKey(stats.period.shareCaption), position: .trailing, isStacked: false)
                    } else if stats.bestBucket == nil {
                        factDivider
                        fact(stats.dailyAverage.minutesText, dailyCaption, position: .trailing, isStacked: false)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            let chartHeaderLayout = isAX
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(spacing: 8))

            chartHeaderLayout {
                if selected != nil {
                    Text("Release to clear")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DossierPalette.dim)
                        .lineLimit(1)
                        .accessibilityHidden(true)
                    if !isAX {
                        Spacer(minLength: 8)
                    }
                } else {
                    Text(shortChartHeading)
                        .font(.caption)
                        .foregroundStyle(DossierPalette.dim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .accessibilityHidden(true)
                    if !isAX {
                        Spacer(minLength: 8)
                    }
                    if average > 0 {
                        HStack(spacing: 5) {
                            DashRuleGlyph(
                                width: 18,
                                color: colorScheme == .light ? Color.black.opacity(0.45) : Color.white.opacity(0.46),
                                lineWidth: 1.25,
                                dash: [4, 3]
                            )
                            Text(averageLabelText)
                                .font(.caption.weight(.medium))
                                .monospacedDigit()
                                .foregroundStyle(DossierPalette.dim)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                }
            }
            .padding(.top, 4)

            DossierTrendPlot(
                stats: stats,
                firstWear: firstWear,
                calendar: calendar,
                average: average,
                selection: $selection,
                showsMintedMarker: true,
                showsAverageRule: true,
                showsXAxis: true,
                barPillSize: barPillSize,
                mintedLabelSize: mintedLabelSize,
                accent: accent
            )
            .frame(height: isAX ? 208 : chartHeight)
            .padding(.top, showsMintedRule ? 12 : 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Listening over time for this pair")
            .accessibilityValue(chartAccessibilityValue)
            .accessibilityHint(chartAccessibilityHint)
            .accessibilityAdjustableAction { direction in
                let buckets = stats.buckets
                guard !buckets.isEmpty else { return }
                if let selected, let idx = buckets.firstIndex(where: { $0.id == selected.id }) {
                    let next = idx + (direction == .increment ? 1 : -1)
                    selection = buckets.indices.contains(next) ? buckets[next].start : nil
                } else {
                    selection = (direction == .increment ? buckets.first : buckets.last)?.start
                }
            }
            .dialClearAccessibilityAction(isActive: selected != nil) {
                selection = nil
            }

            LoudnessLegendRow(compact: false)
        }
        .sensoryFeedback(.selection, trigger: selected?.id)
    }

    private var chartAccessibilityValue: Text {
        if let s = selected {
            let title = DossierTrendPlot.bucketTitle(s, unit: stats.bucketUnit, calendar: calendar)
            if s.minutes > 0 && s.averageDecibels > 0 {
                return Text("\(title), \(s.minutes.minutesText), \(Int(s.averageDecibels.rounded())) decibels")
            }
            return Text("\(title), \(s.minutes.minutesText)")
        }
        return Text("\(stats.totalMinutes.minutesText) total, \(stats.activeDays) of \(stats.spanDays) days active")
    }

    private var chartAccessibilityHint: LocalizedStringKey {
        switch stats.bucketUnit {
        case .day: "Swipe up or down to inspect daily bars"
        case .weekOfYear: "Swipe up or down to inspect weekly bars"
        default: "Swipe up or down to inspect monthly bars"
        }
    }

    private var showsMintedRule: Bool {
        guard let firstWear, stats.bucketUnit == .day, let firstBucket = stats.buckets.first else { return false }
        return firstWear > firstBucket.end
    }

    private var factDivider: some View {
        Rectangle().fill(DossierPalette.hairline).frame(width: 1).padding(.vertical, 2)
    }

    private enum ColumnPosition {
        case leading
        case middle
        case trailing
    }

    private func fact(_ value: String, _ caption: String, verbatimCaption: Bool = false, position: ColumnPosition, isStacked: Bool) -> some View {
        let leadingPad: CGFloat = isStacked ? 0 : (position == .leading ? 0 : 12)
        let trailingPad: CGFloat = isStacked ? 0 : (position == .trailing ? 0 : 12)
        return VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(DossierPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Group {
                if verbatimCaption {
                    Text(verbatim: caption)
                } else {
                    Text(LocalizedStringKey(caption))
                }
            }
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

    private func fact(_ value: String, _ caption: LocalizedStringKey, position: ColumnPosition, isStacked: Bool) -> some View {
        let leadingPad: CGFloat = isStacked ? 0 : (position == .leading ? 0 : 12)
        let trailingPad: CGFloat = isStacked ? 0 : (position == .trailing ? 0 : 12)
        return VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(DossierPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(caption)
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

/// Shared bar chart renderer reused by both the live Activity tab and exported poster cards.
private struct DossierTrendPlot: View {
    let stats: PeriodStats
    let firstWear: Date?
    let calendar: Calendar
    let average: Double
    @Binding var selection: Date?
    let showsMintedMarker: Bool
    let showsAverageRule: Bool
    let showsXAxis: Bool
    var barPillSize: CGFloat = 10
    var mintedLabelSize: CGFloat = 11
    let accent: Color

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption2) private var axisLabelSize: CGFloat = 11

    private var selected: TrendBucket? {
        guard let selection else { return nil }
        return stats.buckets.first { selection >= $0.start && selection < $0.end }
    }

    private var showsMintedRule: Bool {
        guard showsMintedMarker, let firstWear, stats.bucketUnit == .day, let firstBucket = stats.buckets.first else {
            return false
        }
        return firstWear > firstBucket.end
    }

    var body: some View {
        let best = stats.bestBucket
        let isLight = colorScheme == .light
        let maxH = max((stats.buckets.map(\.minutes).max() ?? 60) / 60, 1.0)
        let yStep: Double = maxH <= 2 ? 1 : (maxH <= 5.5 ? 2 : ceil(maxH / 3))
        let yAxisMax = max(2.0, ceil(maxH / yStep) * yStep)
        let yTicks = stride(from: 0.0, through: yAxisMax, by: yStep).map { $0 }
        let yTop = max(yAxisMax * 1.03, maxH * 1.28)
        let avgH = average / 60
        let tickDates = xTickDates

        return Chart {
            if let firstWear, showsMintedRule, let firstBucket = stats.buckets.first {
                let mintDay = calendar.startOfDay(for: firstWear)
                let preMintEnd = min(mintDay, stats.buckets.last?.end ?? mintDay)
                if preMintEnd > firstBucket.start {
                    RectangleMark(
                        xStart: .value("Start", firstBucket.start),
                        xEnd: .value("Minted", preMintEnd)
                    )
                    .foregroundStyle(DossierPalette.surfaceFill.opacity(0.65))
                    .zIndex(-2)
                }
            }

            if average > 0 && showsAverageRule {
                RuleMark(y: .value("Average", avgH))
                    .lineStyle(StrokeStyle(lineWidth: 1.25, dash: [4, 3]))
                    .foregroundStyle(isLight ? Color.black.opacity(0.42) : Color.white.opacity(0.42))
                    .zIndex(-0.5)
            }

            ForEach(stats.buckets) { bucket in
                let isBest = best?.id == bucket.id
                let barColor = Theme.levelColor(db: bucket.averageDecibels, colorScheme: colorScheme)
                let style: LinearGradient = if bucket.minutes <= 0 {
                    LinearGradient(colors: [DossierPalette.hairline, DossierPalette.hairline], startPoint: .top, endPoint: .bottom)
                } else {
                    LinearGradient(
                        colors: [barColor, barColor.opacity(isLight ? 0.84 : 0.76)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

                let plottedHours = bucket.minutes > 0 ? max(bucket.minutes / 60, yTop * 0.028) : 0
                BarMark(
                    x: .value("Date", bucket.start, unit: stats.bucketUnit),
                    y: .value("Hours", plottedHours),
                    width: .ratio(stats.buckets.count > 20 ? 0.74 : 0.56)
                )
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: stats.buckets.count > 20 ? 1.5 : 4,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: stats.buckets.count > 20 ? 1.5 : 4
                    )
                )
                .foregroundStyle(style)
                .opacity(selected == nil || selected?.id == bucket.id ? 1 : 0.3)
                .annotation(position: .top, spacing: 3, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                    if selected?.id == bucket.id {
                        let bucketLabel = Self.shortLabel(bucket, unit: stats.bucketUnit, calendar: calendar)
                        let pillText: String = if bucket.minutes > 0 && bucket.averageDecibels > 0 {
                            "\(bucketLabel) · \(bucket.minutes.minutesText) · \(Int(bucket.averageDecibels.rounded())) dB(A)"
                        } else if bucket.minutes > 0 {
                            "\(bucketLabel) · \(bucket.minutes.minutesText)"
                        } else {
                            "\(bucketLabel) · 0m"
                        }
                        Text(pillText)
                            .font(.system(size: min(barPillSize, 12), weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(isLight ? Color.white : Color.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .fixedSize()
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(DossierPalette.primaryText, in: Capsule())
                            .accessibilityHidden(true)
                    } else if isBest {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(Theme.trophyGold)
                            .accessibilityHidden(true)
                    }
                }
            }

            if let firstWear, showsMintedRule {
                RuleMark(x: .value("Minted", calendar.startOfDay(for: firstWear), unit: .day))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .foregroundStyle(accent.opacity(0.75))
                    .zIndex(-1)
                    .annotation(position: .top, alignment: .leading, spacing: 6) {
                        Label("Minted", systemImage: "sparkle")
                            .font(.system(size: min(mintedLabelSize, 14), weight: .bold, design: .rounded))
                            .foregroundStyle(accent)
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
        .chartYScale(domain: 0...yTop)
        .chartPlotStyle { $0.padding(.trailing, 6) }
        .chartYAxis {
            AxisMarks(position: .trailing, values: yTicks) { value in
                let h = value.as(Double.self) ?? 0
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.75))
                    .foregroundStyle(isLight ? Color.black.opacity(0.14) : Color.white.opacity(0.11))
                AxisValueLabel {
                    let axisText = (h > 0 && h < 1)
                        ? "\(Int((h * 60).rounded()))m"
                        : "\(Int(h.rounded()))h"
                    Text(axisText)
                        .font(.system(size: min(axisLabelSize, 13.5), weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(DossierPalette.dim)
                }
            }
        }
        .chartXAxis {
            if showsXAxis {
                if !tickDates.isEmpty {
                    AxisMarks(values: tickDates) { value in
                        let anchor: UnitPoint = value.index == 0
                            ? .topLeading
                            : (value.index == tickDates.count - 1 ? .topTrailing : .top)
                        AxisValueLabel(
                            anchor: anchor,
                            collisionResolution: .disabled
                        ) {
                            if let date = value.as(Date.self) {
                                Text(date, format: calendarXFormat)
                                    .font(.system(size: min(axisLabelSize, 13.5)))
                                    .foregroundStyle(DossierPalette.dim)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                    }
                } else {
                    AxisMarks(values: xValues) { value in
                        AxisValueLabel(centered: stats.bucketUnit != .day) {
                            if let date = value.as(Date.self) {
                                Text(date, format: calendarXFormat)
                                    .font(.system(size: min(axisLabelSize, 13.5)))
                                    .foregroundStyle(DossierPalette.dim)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.82), value: stats.period)
    }

    private var xTickDates: [Date] {
        let buckets = stats.buckets
        guard stats.bucketUnit == .day, buckets.count > 10 else { return [] }
        let lastIdx = buckets.count - 1
        let endDate = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: buckets[lastIdx].start) ?? buckets[lastIdx].start
        let candidates: [Date] = if dynamicTypeSize >= .xxLarge {
            [buckets[0].start, endDate]
        } else {
            [
                buckets[0].start,
                calendar.date(bySettingHour: 12, minute: 0, second: 0, of: buckets[lastIdx / 2].start) ?? buckets[lastIdx / 2].start,
                endDate
            ]
        }
        var seen = Set<Date>()
        return candidates.filter { seen.insert($0).inserted }
    }

    private var xValues: AxisMarkValues {
        switch (stats.period, stats.bucketUnit) {
        case (.week, _): .stride(by: .day)
        case (_, .day): .stride(by: .day, count: 7)
        case (.year, _): .stride(by: .month)
        default: .stride(by: .month)
        }
    }

    private var calendarXFormat: Date.FormatStyle {
        var style: Date.FormatStyle = switch (stats.period, stats.bucketUnit) {
        case (.week, _): .dateTime.weekday(.abbreviated)
        case (_, .day): .dateTime.month(.abbreviated).day()
        case (.year, _): .dateTime.month(.narrow)
        default: .dateTime.month(.abbreviated)
        }
        style.timeZone = calendar.timeZone
        style.locale = AppLanguage.current.locale
        return style
    }

    static func bucketTitle(_ b: TrendBucket, unit: Calendar.Component, calendar: Calendar) -> String {
        switch unit {
        case .day:
            return b.start.dossierFullDay(calendar: calendar)
        case .weekOfYear:
            return AppLanguage.current.text("Week of %@", b.start.dossierShort(calendar: calendar))
        default:
            return DateText.formatTemplate(b.start, template: "MMMM y", calendar: calendar, locale: AppLanguage.current.locale)
        }
    }

    static func shortLabel(_ b: TrendBucket, unit: Calendar.Component, calendar: Calendar) -> String {
        switch unit {
        case .day:
            return b.start.dossierShort(calendar: calendar)
        case .weekOfYear:
            return AppLanguage.current.text("wk of %@", b.start.dossierShort(calendar: calendar))
        default:
            return DateText.formatTemplate(b.start, template: "MMM", calendar: calendar, locale: AppLanguage.current.locale)
        }
    }
}

/// Export-header wrapper delegating all chart rendering to the shared `DossierTrendPlot` renderer.
struct DossierTrendChart: View {
    let stats: PeriodStats
    let rarity: Rarity
    let firstWear: Date?
    @Binding var selection: Date?
    var showsInteractionHint = true
    var showsMintedMarker = true
    var chartHeight: CGFloat = 210
    var calendar: Calendar = .current

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    private var redactsAllTimeStart: Bool {
        !showsMintedMarker && stats.period == .all
    }

    private var title: String {
        switch stats.period {
        case .week: AppLanguage.current.text("Last 7 Days")
        case .month: AppLanguage.current.text("Last 30 Days")
        case .year: AppLanguage.current.text("Last 12 Months")
        case .all:
            redactsAllTimeStart
                ? AppLanguage.current.text("All Time")
                : AppLanguage.current.text("Since minted · by %@", AppLanguage.current.text(unitName))
        }
    }

    var body: some View {
        let accent = DossierContrast.accentColor(rarity: rarity, proFoil: nil, colorScheme: colorScheme)
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: selected.map { DossierTrendPlot.bucketTitle($0, unit: stats.bucketUnit, calendar: calendar) } ?? title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(DossierPalette.primaryText)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        let primaryValue = selected?.minutes ?? (redactsAllTimeStart ? stats.totalMinutes : average)
                        let isPartialSpan = stats.period.days.map { countedBuckets.count < $0 } ?? false
                        let subtitle: LocalizedStringKey? = if selected == nil && !redactsAllTimeStart {
                            if isPartialSpan && stats.bucketUnit == .day {
                                "avg / day (\(countedBuckets.count)d)"
                            } else {
                                "avg / \(unitName)"
                            }
                        } else {
                            nil
                        }
                        Text(primaryValue.minutesText)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .contentTransition(reduceMotion ? .identity : .numericText(value: primaryValue))
                        if let subtitle {
                            Text(subtitle)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(DossierPalette.dim)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 8)
                if let s = selected {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(s.minutes > 0 ? "\(Int(s.averageDecibels.rounded())) dB(A)" : "—")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(s.minutes > 0 ? Theme.levelTextColor(db: s.averageDecibels) : DossierPalette.dim)
                            .lineLimit(1)
                        Text("\(s.sessions) wears")
                            .font(.caption)
                            .foregroundStyle(DossierPalette.dim)
                            .lineLimit(1)
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else if let best = stats.bestBucket {
                    VStack(alignment: .trailing, spacing: 3) {
                        Label("Best \(unitName)", systemImage: "crown.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(accent)
                            .lineLimit(1)
                        let bestLabel = DossierTrendPlot.shortLabel(best, unit: stats.bucketUnit, calendar: calendar)
                        Text(showsMintedMarker ? "\(best.minutes.minutesText) · \(bestLabel)" : best.minutes.minutesText)
                            .font(.caption)
                            .foregroundStyle(DossierPalette.dim)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .snappy, value: selected?.id)

            DossierTrendPlot(
                stats: stats,
                firstWear: firstWear,
                calendar: calendar,
                average: average,
                selection: $selection,
                showsMintedMarker: showsMintedMarker,
                showsAverageRule: !redactsAllTimeStart,
                showsXAxis: showsMintedMarker,
                accent: accent
            )
            .frame(height: chartHeight)
            .padding(.top, 4)

            if showsInteractionHint {
                Text("Drag bars to inspect")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DossierPalette.dim)
                    .opacity(selection == nil ? 1 : 0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHidden(selection != nil)
            }
        }
        .sensoryFeedback(.selection, trigger: selected?.id)
    }
}

// MARK: - Day clock

/// 24-hour dial: one radial bar per hour, length = listening, color = loudness. Press and drag around it to scrub.
struct DayClock: View {
    let stats: PeriodStats
    let rarity: Rarity
    @Binding var selectedHour: Int?
    var showsPerDayAverage = true

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption2) private var bezelLabelSize: CGFloat = 11
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption2) private var peakEyebrowSize: CGFloat = 10.5
    @ScaledMetric(relativeTo: .title3) private var centerTitleSize: CGFloat = 20
    @ScaledMetric(relativeTo: .caption) private var centerDetailSize: CGFloat = 13

    var body: some View {
        let accent = DossierContrast.accentColor(rarity: rarity, proFoil: nil, colorScheme: colorScheme)
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let compact = size < 190
            let outer = size / 2 - (compact ? 18 : 26)
            let innerRadius = max(24, outer * 0.63)
            let labelDiameter = max(48, innerRadius * (dynamicTypeSize.isAccessibilitySize ? 1.72 : 1.56))
            ZStack {
                dial(size: size, outerRadius: outer, innerRadius: innerRadius, accent: accent)
                centerLabel(diameter: labelDiameter, compact: compact, accent: accent)
                    .frame(width: labelDiameter)
                ForEach([(0, "00"), (6, "06"), (12, "12"), (18, "18")], id: \.0) { hour, label in
                    let angle = (Double(hour) * 15 - 90) * .pi / 180
                    let baseR = outer + (compact ? 14 : 18)
                    let r = (hour == 6 || hour == 18) ? baseR + 2 : baseR
                    let numeralFont = Font.system(
                        size: compact ? 8.5 : min(bezelLabelSize, 13),
                        weight: hour == 0 ? .bold : .semibold,
                        design: .rounded
                    )
                    Text(label)
                        .font(numeralFont)
                        .monospacedDigit()
                        .foregroundStyle(hour == 0 ? DossierPalette.primaryText.opacity(0.88) : DossierPalette.dim)
                        .position(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Circle())
            .onTapGesture { location in select(location, center: center, innerRadius: innerRadius, outerRadius: outer, toggle: true) }
            .gesture(
                LongPressGesture(minimumDuration: 0.25)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onChanged { value in
                        if case .second(true, let drag?) = value { select(drag.location, center: center, innerRadius: innerRadius, outerRadius: outer, toggle: false) }
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .sensoryFeedback(.selection, trigger: selectedHour)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Listening by hour of day")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Swipe up or down to inspect hours")
        .accessibilityAdjustableAction { direction in
            selectedHour = EarprintDialMath.adjustedHour(current: selectedHour, direction: direction)
        }
        .dialClearAccessibilityAction(isActive: selectedHour != nil) {
            selectedHour = nil
        }
    }

    private var accessibilityValue: String {
        guard let h = selectedHour ?? stats.peakHour?.hour, stats.hours.indices.contains(h) else {
            return AppLanguage.current.text("No listening data")
        }
        let stat = stats.hours[h]
        let baseSummary: String
        if stat.minutes <= 0 {
            baseSummary = "\(DossierFormat.hourLabel(h)), \(AppLanguage.current.text("No listening data"))"
        } else {
            let timeText = showsPerDayAverage
                ? AppLanguage.current.text("%@ a day", (stat.minutes / Double(max(stats.spanDays, 1))).minutesText)
                : stat.minutes.minutesText
            baseSummary = stat.averageDecibels > 0
                ? AppLanguage.current.text("%@, %@, %lld decibels", DossierFormat.hourLabel(h), timeText, Int(stat.averageDecibels.rounded()))
                : "\(DossierFormat.hourLabel(h)), \(timeText)"
        }
        if selectedHour == nil {
            return AppLanguage.current.text("Peak hour %@", baseSummary)
        }
        return baseSummary
    }

    private func select(_ location: CGPoint, center: CGPoint, innerRadius: CGFloat, outerRadius: CGFloat, toggle: Bool) {
        let dx = location.x - center.x, dy = location.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        if distance < innerRadius || distance > outerRadius + 18 { if toggle { selectedHour = nil }; return }
        var degrees = atan2(dy, dx) * 180 / .pi + 90
        if degrees < 0 { degrees += 360 }
        let hour = Int(degrees / 15) % 24
        selectedHour = (toggle && selectedHour == hour) ? nil : hour
    }

    @ViewBuilder private func centerLabel(diameter: CGFloat, compact: Bool, accent: Color) -> some View {
        let h = selectedHour ?? stats.peakHour?.hour
        if let h {
            let stat = stats.hours[h]
            let displayMinutes = showsPerDayAverage ? (stat.minutes / Double(max(stats.spanDays, 1))) : stat.minutes
            let titleSize = compact ? max(12, diameter * 0.25) : min(max(16, centerTitleSize), 21)
            let detailSize = compact ? max(8, diameter * 0.145) : min(centerDetailSize, 12.5)
            VStack(spacing: 2) {
                if !compact {
                    Text(verbatim: AppLanguage.current.text(selectedHour == nil ? "PEAK HOUR" : "SELECTED"))
                        .font(.system(size: min(peakEyebrowSize, 11.0), weight: .bold, design: .rounded))
                        .tracking(0.35)
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Text(String(format: "%02d:00", h))
                    .font(.system(size: titleSize, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(DossierPalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .contentTransition(reduceMotion ? .identity : .numericText(value: Double(h)))
                Group {
                    if showsPerDayAverage {
                        Text("\(displayMinutes.minutesText) / day")
                    } else {
                        Text(displayMinutes.minutesText)
                    }
                }
                .font(.system(size: detailSize, weight: .semibold, design: .rounded))
                .foregroundStyle(DossierPalette.dim)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .contentTransition(reduceMotion ? .identity : .numericText(value: displayMinutes))
                if !compact, stat.minutes > 0, stat.averageDecibels > 0 {
                    HStack(spacing: 3.5) {
                        Circle()
                            .fill(Theme.levelColor(db: stat.averageDecibels, colorScheme: colorScheme))
                            .frame(width: 5.5, height: 5.5)
                            .accessibilityHidden(true)
                        Text("\(Int(stat.averageDecibels.rounded())) dB(A)")
                            .font(.system(size: min(centerDetailSize, 11.5), weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(DossierPalette.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            }
            .multilineTextAlignment(.center)
            .animation(reduceMotion ? nil : .snappy, value: h)
        } else {
            Text("No listening yet")
                .font(.system(size: compact ? 10 : 12, weight: .medium))
                .foregroundStyle(DossierPalette.dim)
                .multilineTextAlignment(.center)
        }
    }

    private func dial(size: CGFloat, outerRadius outer: CGFloat, innerRadius inner: CGFloat, accent: Color) -> some View {
        let isLight = colorScheme == .light
        let trackFill = isLight ? Color.black.opacity(0.10) : Color.white.opacity(0.11)
        let innerDiscFill = isLight ? Color.black.opacity(0.04) : Color.white.opacity(0.048)
        return Canvas { context, canvasSize in
            let c = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
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

            // Neutral architectural day/night outer bezel + 24 background tracks batched into 3 paths.
            var dayBand = Path()
            var nightBand = Path()
            var tracks = Path()
            for hour in 0..<24 {
                let band = sector(hour, from: outer + 5.8, to: outer + 8.8, gap: 0.6)
                if hour >= 22 || hour < 4 {
                    nightBand.addPath(band)
                } else {
                    dayBand.addPath(band)
                }
                tracks.addPath(sector(hour, from: inner, to: outer))
            }
            context.fill(dayBand, with: .color(isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.10)))
            context.fill(nightBand, with: .color(isLight ? Color(red: 0.22, green: 0.28, blue: 0.48).opacity(0.58) : Color(red: 0.52, green: 0.60, blue: 0.88).opacity(0.46)))
            context.fill(tracks, with: .color(trackFill))

            let rMid = (inner + outer) / 2
            let midColor = isLight ? Color.black.opacity(0.11) : Color.white.opacity(0.13)
            context.stroke(
                Path(ellipseIn: CGRect(x: c.x - rMid, y: c.y - rMid, width: rMid * 2, height: rMid * 2)),
                with: .color(midColor),
                style: StrokeStyle(lineWidth: 0.75, dash: [3, 3])
            )

            func bars(_ ctx: inout GraphicsContext) {
                for stat in stats.hours where stat.minutes > 0 {
                    let t = CGFloat(stat.minutes / maxMinutes)
                    let r1 = inner + (outer - inner) * max(0.08, t)
                    let baseColor = Theme.dialLevelColor(db: stat.averageDecibels, colorScheme: colorScheme)
                    let barOpacity: Double = if let selectedHour, selectedHour != stat.hour {
                        0.32
                    } else {
                        isLight ? (0.76 + 0.24 * Double(t)) : (0.68 + 0.32 * Double(t))
                    }
                    ctx.fill(sector(stat.hour, from: inner, to: r1), with: .color(baseColor.opacity(barOpacity)))
                }
            }
            context.drawLayer { glow in
                glow.addFilter(.blur(radius: 6))
                glow.opacity = isLight ? 0.16 : 0.40
                bars(&glow)
            }
            bars(&context)
            let haloColor = (isLight ? Color.white : Color.black).opacity(0.75)
            let focusStroke = DossierPalette.primaryText.opacity(isLight ? 0.86 : 0.94)
            if let selectedHour {
                let selectedPath = sector(selectedHour, from: inner, to: outer, gap: 1.0)
                context.stroke(selectedPath, with: .color(haloColor), style: StrokeStyle(lineWidth: 2.9, lineJoin: .round))
                context.stroke(selectedPath, with: .color(focusStroke), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
            } else if let peak = stats.peakHour?.hour {
                let peakPath = sector(peak, from: inner, to: outer, gap: 1.6)
                context.stroke(
                    peakPath,
                    with: .color(DossierPalette.primaryText.opacity(isLight ? 0.72 : 0.85)),
                    style: StrokeStyle(lineWidth: 1.4, lineJoin: .round)
                )
            }
            // Inner disc.
            context.fill(Path(ellipseIn: CGRect(x: c.x - (inner - 1), y: c.y - (inner - 1), width: (inner - 1) * 2, height: (inner - 1) * 2)),
                         with: .color(innerDiscFill))
        }
    }
}
