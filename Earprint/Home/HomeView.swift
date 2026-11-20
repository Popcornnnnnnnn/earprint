import SwiftUI

struct HomeView: View {
    let summary: ListeningSummary
    var primaryCard: HeadphoneCard? = nil
    var isSampleData: Bool = false
    var sampleBadgeText: LocalizedStringKey = "Sample data"
    var statusMessage: LocalizedStringKey? = nil
    var isLoading: Bool = false
    var onConnectHealth: (() -> Void)? = nil

    @Environment(DeepLinkRouter.self) private var router: DeepLinkRouter?
    @Environment(DeviceColorStore.self) private var colorStore: DeviceColorStore?
    @Environment(ActiveAudioRouteMonitor.self) private var routeMonitor: ActiveAudioRouteMonitor?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @StateObject private var motion = TiltMotion()
    @State private var showShare = ProcessInfo.processInfo.arguments.contains("-showShare")
    @State private var space = LayoutSpace()
    @ScaledMetric(relativeTo: .largeTitle) private var listeningTimeSize: CGFloat = 40

    private var motionActive: Bool { !reduceMotion && !showShare }
    private var liveTilt: CGSize { motionActive ? motion.tilt : .zero }

    private var activeRarity: Rarity {
        primaryCard?.rarity ?? Rarity(minutes: summary.lifetimeMinutes)
    }

    private var primaryColor: DeviceColorOption? {
        guard let primaryCard else { return nil }
        return colorStore?.selectedColor(for: primaryCard) ?? DeviceColorOption.defaultOption(for: primaryCard.modelKey)
    }

    private var isPrimaryWorn: Bool {
        guard let primaryCard else { return false }
        return routeMonitor?.isCurrentlyWorn(primaryCard) ?? false
    }

    var body: some View {
        ZStack {
            backdrop

            ScrollView {
                Group {
                    if space.isWide || (space.isLandscape && space.size.width >= 520) {
                        let split = ColumnSplit(space: space, padding: 24, gap: 24)
                        HStack(alignment: .top, spacing: split.gap) {
                            VStack(alignment: .leading, spacing: 16) {
                                header
                                healthStatus
                                weeklyOverview
                                hearingBudget
                            }
                            .frame(width: split.leading)
                            VStack(alignment: .leading, spacing: 16) {
                                heroEarprint
                                history
                            }
                            .frame(width: split.trailing)
                        }
                        .padding(.horizontal, split.padding)
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            header
                            healthStatus
                            heroEarprint
                            weeklyOverview
                            hearingBudget
                            history
                        }
                        .padding(.horizontal, 18)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .readLayoutSpace($space)
        }
        .foregroundStyle(.white)
        .sheet(isPresented: $showShare) {
            ShareSheet(summary: summary, primaryCard: primaryCard, colorOption: primaryColor)
        }
        .onAppear {
            if motionActive { motion.start() }
        }
        .onDisappear { motion.stop() }
        .onChange(of: motionActive) { _, active in
            if active { motion.start() } else { motion.stop() }
        }
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        ZStack {
            DossierPalette.ink.ignoresSafeArea()
            RadialGradient(
                colors: [activeRarity.glow.opacity(0.22), activeRarity.accent.opacity(0.06), .clear],
                center: .topTrailing,
                startRadius: 16,
                endRadius: 420
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Header & Active Pair Pill

    private var header: some View {
        let pairName = isSampleData
            ? (primaryCard?.model ?? summary.deviceModel)
            : (primaryCard?.nickname ?? summary.deviceName)
        let pairModel = primaryCard?.model ?? summary.deviceModel
        let pairSubtitle: String? = (!isSampleData && pairModel != pairName) ? pairModel : nil

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text("Rings")
                    .font(.system(size: 30, weight: .heavy))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Button { showShare = true } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 44, height: 44)
                        .background(Theme.card, in: Circle())
                        .overlay(Circle().strokeBorder(DossierPalette.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share my Earprint")
            }

            if let card = primaryCard {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    router?.pendingCardID = card.id
                    router?.tab = .collection
                } label: {
                    activePairPill(name: pairName, subtitle: pairSubtitle, showsChevron: true)
                }
                .buttonStyle(.plain)
                .accessibilityHint("View card in Collection")
            } else {
                activePairPill(name: pairName, subtitle: pairSubtitle, showsChevron: false)
            }
        }
    }

    private func activePairPill(name: String, subtitle: String?, showsChevron: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [activeRarity.glow.opacity(0.22), .white.opacity(0.04)],
                            center: .center,
                            startRadius: 2,
                            endRadius: 22
                        )
                    )
                if let card = primaryCard {
                    HeadphoneArtwork(card: card, colorOption: primaryColor, showsChargingCase: false)
                        .padding(3)
                } else {
                    Image(systemName: summary.deviceSymbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(activeRarity.accent)
                }
            }
            .frame(width: 40, height: 40)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(name)
                        .font(.system(size: 14.5, weight: .bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    if isPrimaryWorn {
                        ActiveWearDot()
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 5) {
                Text(LocalizedStringKey(activeRarity.title))
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(0.6)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(activeRarity.accent.opacity(0.15), in: Capsule())
                    .overlay(Capsule().strokeBorder(activeRarity.accent.opacity(0.38), lineWidth: 1))
                    .foregroundStyle(activeRarity.accent)

                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DossierPalette.faint)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(DossierPalette.panel, in: shape)
        .overlay(shape.strokeBorder(DossierPalette.hairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var healthStatus: some View {
        if isSampleData {
            SampleDataBanner(badgeText: sampleBadgeText, detail: statusMessage,
                             isLoading: isLoading, onConnect: onConnectHealth)
        }
    }

    // MARK: - Hero 28-Day Earprint Stage

    private var heroEarprint: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        let has28DayData = summary.grid.totalMinutes(lastDays: 28) > 0

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 8) {
                Eyebrow("28-DAY EARPRINT")
                Spacer(minLength: 8)
                if has28DayData {
                    HStack(spacing: 5) {
                        Text(summary.persona.emoji)
                            .font(.caption2)
                        Text(LocalizedStringKey(summary.persona.title))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.07), in: Capsule())
                    .overlay(Capsule().strokeBorder(DossierPalette.hairline, lineWidth: 1))
                }
            }

            ZStack {
                EarprintGlyph(grid: summary.grid, showHourLabels: true)
                    .frame(maxWidth: 224)
                    .background {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [activeRarity.glow.opacity(0.14), .clear],
                                    center: .center,
                                    startRadius: 14,
                                    endRadius: 114
                                )
                            )
                    }
                    .accessibilityHidden(true)

                VStack(spacing: 4) {
                    Text(summary.weekMinutes.minutesText)
                        .font(.system(size: 15.5, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .foregroundStyle(.white)
                    if summary.weekMinutes > 0 {
                        let db = summary.weekDecibels
                        let dbColor = Theme.levelColor(db: db)
                        Text("\(Int(db.rounded())) dB")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(dbColor)
                            .padding(.horizontal, 6.5)
                            .padding(.vertical, 2)
                            .background(dbColor.opacity(0.15), in: Capsule())
                            .overlay(Capsule().strokeBorder(dbColor.opacity(0.35), lineWidth: 0.75))
                    } else {
                        Text("7d")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(DossierPalette.dim)
                    }
                }
                .frame(width: 64)
                .accessibilityElement(children: .combine)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 16) {
                legendDot(Theme.quiet.color, "Quiet")
                legendDot(Theme.moderate.color, "Moderate")
                legendDot(Theme.loud.color, "Loud")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(18)
        .background {
            shape.fill(DossierPalette.panel)
                .overlay {
                    RadialGradient(
                        colors: [activeRarity.glow.opacity(0.18), activeRarity.accent.opacity(0.06), .clear],
                        center: UnitPoint(x: 0.5 + liveTilt.width * 0.14, y: 0.35 + liveTilt.height * 0.10),
                        startRadius: 12,
                        endRadius: 235
                    )
                    .clipShape(shape)
                }
        }
        .overlay {
            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        .white.opacity(0.46),
                        .white.opacity(0.10),
                        activeRarity.glow.opacity(0.42),
                        .white.opacity(0.30)
                    ],
                    startPoint: UnitPoint(x: 0.2 + liveTilt.width * 0.5, y: 0.0 + liveTilt.height * 0.4),
                    endPoint: UnitPoint(x: 0.8 + liveTilt.width * 0.5, y: 1.0 + liveTilt.height * 0.4)
                ),
                lineWidth: 1.25
            )
        }
    }

    private func legendDot(_ color: Color, _ label: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6.5, height: 6.5)
                .shadow(color: color.opacity(0.55), radius: 3)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.secondaryText)
        }
    }

    // MARK: - Last 7 Days Rhythm Card

    private var weeklyOverview: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow("LAST 7 DAYS")
                Spacer(minLength: 8)
                Text(summary.periodLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DossierPalette.dim)
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .lastTextBaseline, spacing: 14) {
                    weeklyListeningTime.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    weeklyLevel.fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 10) {
                    weeklyListeningTime
                    weeklyLevel
                }
            }
            dailyListeningBars
        }
        .padding(18)
        .background(DossierPalette.panel, in: shape)
        .overlay(shape.strokeBorder(DossierPalette.hairline, lineWidth: 1))
    }

    private var weeklyListeningTime: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(summary.weekMinutes.minutesText)
                .font(.system(size: listeningTimeSize, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text("Listening time")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }

    private var weeklyLevel: some View {
        let level = summary.weekDecibels
        return VStack(alignment: .leading, spacing: 3) {
            Group {
                if summary.weekMinutes > 0 {
                    Text("\(Int(level.rounded())) dB")
                } else {
                    Text(verbatim: "—")
                }
            }
            .font(.title2.weight(.bold).monospacedDigit())
            .foregroundStyle(summary.weekMinutes > 0 ? Theme.levelColor(db: level) : Theme.secondaryText)
            Text("Avg. level")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }

    private var dailyListeningBars: some View {
        let start = max(0, summary.grid.days - 7)
        let dayIndices = Array(start..<summary.grid.days)
        let dailyMinutes = dayIndices.map { summary.grid.minutes[$0].reduce(0, +) }
        let maxMinutes = max(dailyMinutes.max() ?? 0, 1)

        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(dayIndices.enumerated()), id: \.offset) { offset, dayIdx in
                let minutes = dailyMinutes[offset]
                let dayDB = dayAverageDecibels(dayIndex: dayIdx)
                let barColor = dayDB.map { Theme.levelColor(db: $0) } ?? Theme.quiet.color
                let isToday = (dayIdx == summary.grid.days - 1)

                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isToday ? Color.white.opacity(0.09) : Color.white.opacity(0.045))
                        .overlay {
                            if isToday && minutes <= 0 {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                            }
                        }

                    if minutes > 0 {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(isToday ? barColor : barColor.opacity(0.58))
                            .frame(height: max(4, 46 * minutes / maxMinutes))
                            .overlay {
                                if isToday {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .strokeBorder(.white.opacity(0.55), lineWidth: 1)
                                }
                            }
                            .shadow(color: isToday ? barColor.opacity(0.45) : .clear, radius: 5)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Day \(offset + 1) of \(dayIndices.count)")
                .accessibilityValue(Text(minutes.minutesText))
            }
        }
        .frame(height: 46)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Daily listening, earliest to latest")
    }

    private func dayAverageDecibels(dayIndex: Int) -> Double? {
        guard summary.grid.minutes.indices.contains(dayIndex),
              summary.grid.decibels.indices.contains(dayIndex) else { return nil }
        var energy = 0.0
        var weight = 0.0
        for hour in 0..<24 {
            let minutes = summary.grid.minutes[dayIndex][hour]
            guard minutes > 0 else { continue }
            let db = summary.grid.decibels[dayIndex][hour]
            energy += pow(10, db / 10) * minutes
            weight += minutes
        }
        guard weight > 0 else { return nil }
        return 10 * log10(energy / weight)
    }

    // MARK: - Hearing Budget Card

    private var hearingBudget: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        let used = summary.weeklyBudgetUsed
        let tint = used >= 1 ? Theme.loud.color : (used >= 0.75 ? Theme.moderate.color : Theme.quiet.color)
        let clamped = min(max(used, 0), 1)

        return VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "ear")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(tint)
                        .accessibilityHidden(true)
                    Eyebrow("HEARING BUDGET")
                }
                Spacer()
                Text("\(Int((used * 100).rounded()))% used")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(tint)
            }

            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.07))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Theme.quiet.color, Theme.moderate.color, Theme.loud.color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .mask(alignment: .leading) {
                            Capsule()
                                .frame(width: used > 0 ? max(8, width * clamped) : 0)
                        }
                        .shadow(color: tint.opacity(0.42), radius: 5)
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true)

            Text("7-day exposure for this pair · WHO reference: 40 hours at 80 dB(A)")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(18)
        .background(DossierPalette.panel, in: shape)
        .overlay(shape.strokeBorder(DossierPalette.hairline, lineWidth: 1))
    }

    // MARK: - All-Time Archive Card

    private var history: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow("ALL-TIME ARCHIVE")
                Spacer(minLength: 8)
                if summary.firstUse != "—" {
                    Text("Since \(summary.firstUse)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DossierPalette.dim)
                }
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    statWell("Listening time", summary.lifetimeMinutes.minutesText)
                    statWell("Sessions", summary.sessions.formatted())
                    statWell("Avg. session", summary.averageSessionMinutes.minutesText)
                    statWell("Longest session", summary.longestSessionMinutes.minutesText)
                }
            } else {
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        statWell("Listening time", summary.lifetimeMinutes.minutesText)
                        statWell("Sessions", summary.sessions.formatted())
                    }
                    GridRow {
                        statWell("Avg. session", summary.averageSessionMinutes.minutesText)
                        statWell("Longest session", summary.longestSessionMinutes.minutesText)
                    }
                }
            }
        }
        .padding(18)
        .background(DossierPalette.panel, in: shape)
        .overlay(shape.strokeBorder(DossierPalette.hairline, lineWidth: 1))
    }

    private func statWell(_ title: LocalizedStringKey, _ value: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.24), in: shape)
        .overlay(shape.strokeBorder(DossierPalette.hairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HomeView(summary: SampleData.summary, primaryCard: SampleCards.all.first, isSampleData: true)
}
