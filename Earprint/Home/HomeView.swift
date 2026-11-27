import SwiftUI

struct HomeView: View {
    let summary: ListeningSummary
    var primaryCard: HeadphoneCard? = nil
    var cards: [HeadphoneCard] = []
    var summaryForCardID: ((String?) -> ListeningSummary)? = nil
    var isSampleData: Bool = false
    var isEmptyState: Bool = false
    var sampleBadgeText: LocalizedStringKey = "Sample data"
    var statusMessage: LocalizedStringKey? = nil
    var isLoading: Bool = false
    var isActiveTab: Bool = true
    var onConnectHealth: (() -> Void)? = nil

    @Environment(DeepLinkRouter.self) private var router: DeepLinkRouter?
    @Environment(DeviceColorStore.self) private var colorStore: DeviceColorStore?
    @Environment(ActiveAudioRouteMonitor.self) private var routeMonitor: ActiveAudioRouteMonitor?
    @Environment(DeviceLifecycleStore.self) private var lifecycleStore: DeviceLifecycleStore?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .headline) private var pillTitleSize: CGFloat = 15.5

    @State private var selectedCardID: String? = nil
    @State private var showPairPicker = false
    @State private var showShare = ProcessInfo.processInfo.arguments.contains("-showShare")
    @State private var space = LayoutSpace()
    @State private var showWrapped = false
    @State private var wrappedContent: WrappedContent?
    @State private var loadedWrappedRevision: WrappedRevision?
    @State private var isLoadingWrapped = false

    private struct WrappedContent: Sendable {
        let summary: WrappedSummary
        let aggregate: ListeningAggregate?
        let cards: [HeadphoneCard]
    }

    private struct WrappedRevision: Equatable {
        let sample: Bool
        let empty: Bool
        let cacheModification: Date?
        let cardMetadata: [[String]]
    }

    private struct WrappedInput: Equatable {
        let active: Bool
        let revision: WrappedRevision
    }

    private static let emptyWrapped = WrappedAggregator.summarize(aggregate: ListeningAggregate(), cards: [])

    private var wrappedInput: WrappedInput {
        let modification: Date? = if !isSampleData && !isEmptyState && isActiveTab {
            try? AggregateCache().url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        } else {
            nil
        }
        let revision = WrappedRevision(
            sample: isSampleData,
            empty: isEmptyState,
            cacheModification: modification,
            cardMetadata: cards.map { [$0.id, $0.nickname, $0.model] + $0.aliasIDs }
        )
        return WrappedInput(active: isActiveTab, revision: revision)
    }

    private var wrappedSummary: WrappedSummary {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-wrappedThin") {
            return WrappedSummary(
                year: 2026, totalMinutes: 145, totalSessions: 6, activeDays: 2,
                topDeviceName: SampleCards.all[0].nickname,
                topDeviceModel: SampleCards.all[0].model,
                topDeviceKey: SampleCards.all[0].modelKey,
                topDeviceSymbol: SampleCards.all[0].symbol,
                topDeviceMinutes: 145, topCard: SampleCards.all[0],
                peakMonth: 11, peakMonthMinutes: 145, longestStreakDays: 2,
                averageDecibels: 61, persona: .allDay, whoSafeWeeksCount: 1
            )
        }
        #endif
        if isSampleData { return .sample() }
        return isEmptyState ? Self.emptyWrapped : wrappedContent?.summary ?? Self.emptyWrapped
    }

    private var selectedCard: HeadphoneCard? {
        if let selectedCardID, let matched = cards.first(where: { $0.matches(id: selectedCardID) }) {
            return matched
        }
        if cards.count == 1 {
            return cards.first
        }
        return primaryCard
    }

    private func resolveSummary(for card: HeadphoneCard?) -> ListeningSummary {
        if let summaryForCardID {
            return summaryForCardID(card?.id)
        }
        return summary
    }

    var body: some View {
        let currentCard = selectedCard
        let currentSummary = resolveSummary(for: currentCard)
        let currentRarity = currentCard?.rarity ?? Rarity(minutes: currentSummary.lifetimeMinutes)
        let currentColor = currentCard.flatMap { card in
            colorStore?.selectedColor(for: card) ?? DeviceColorOption.defaultOption(for: card.modelKey)
        }
        let isRetired = currentCard.map { lifecycleStore?.isRetired($0) ?? false } ?? false
        let isWorn = !isRetired && (currentCard.map { routeMonitor?.isCurrentlyWorn($0) ?? false } ?? false)
        let showingAllPairs = currentCard == nil && cards.count > 1
        let tiltActive = isActiveTab && !showShare && !showWrapped && !showPairPicker
        let wrappedInput = wrappedInput

        ZStack {
            backdrop(rarity: currentRarity)

            ScrollView {
                Group {
                    if isEmptyState {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(alignment: .center, spacing: 12) {
                                Text("Rings")
                                    .font(.system(size: 32, weight: .heavy))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Theme.primaryText, Theme.primaryText.opacity(0.84)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .accessibilityAddTraits(.isHeader)
                                Spacer()
                            }
                            if !isEmptyState {
                                wrappedEntry
                            }
                            emptyRingsState(summary: currentSummary)
                        }
                        .padding(.horizontal, space.isWide ? 24 : 18)
                    } else if space.isWide || (space.isLandscape && space.size.width >= 520) {
                        let split = ColumnSplit(space: space, padding: 24, gap: 24)
                        HStack(alignment: .top, spacing: split.gap) {
                            VStack(alignment: .leading, spacing: 16) {
                                header(card: currentCard, summary: currentSummary, rarity: currentRarity, color: currentColor, isWorn: isWorn, isRetired: isRetired)
                                wrappedEntry
                                healthStatus
                                WeeklyRhythmCard(summary: currentSummary, rarity: currentRarity)
                                HearingBudgetCard(summary: currentSummary, showingAllPairs: showingAllPairs)
                            }
                            .frame(width: split.leading)
                            VStack(alignment: .leading, spacing: 16) {
                                RingsHeroCard(summary: currentSummary, rarity: currentRarity, tiltActive: tiltActive)
                                AllTimeArchiveCard(summary: currentSummary, rarity: currentRarity, isAccessibilitySize: dynamicTypeSize.isAccessibilitySize)
                            }
                            .frame(width: split.trailing)
                        }
                        .padding(.horizontal, split.padding)
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            header(card: currentCard, summary: currentSummary, rarity: currentRarity, color: currentColor, isWorn: isWorn, isRetired: isRetired)
                            wrappedEntry
                            healthStatus
                            RingsHeroCard(summary: currentSummary, rarity: currentRarity, tiltActive: tiltActive)
                            WeeklyRhythmCard(summary: currentSummary, rarity: currentRarity)
                            HearingBudgetCard(summary: currentSummary, showingAllPairs: showingAllPairs)
                            AllTimeArchiveCard(summary: currentSummary, rarity: currentRarity, isAccessibilitySize: dynamicTypeSize.isAccessibilitySize)
                        }
                        .padding(.horizontal, 18)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .pauseMotionWhileScrolling("rings")
            .readLayoutSpace($space)
        }
        .foregroundStyle(Theme.primaryText)
        .sheet(isPresented: $showShare) {
            ShareSheet(summary: currentSummary, primaryCard: currentCard, colorOption: currentColor)
        }
        .sheet(isPresented: $showPairPicker) {
            let allMinutes = cards.reduce(0.0) { $0 + $1.lifetimeMinutes }
            let allRarity = Rarity(minutes: allMinutes)
            let retiredIDs = Set(cards.filter { lifecycleStore?.isRetired($0) ?? false }.map(\.id))
            RingsPairPickerSheet(
                cards: cards,
                retiredCardIDs: retiredIDs,
                selectedCard: currentCard,
                allMinutes: allMinutes,
                allRarity: allRarity,
                isSampleData: isSampleData,
                colorStore: colorStore,
                routeMonitor: routeMonitor,
                onSelectCardID: { id in
                    selectedCardID = id
                    showPairPicker = false
                },
                onOpen3DCard: currentCard.map { card in
                    {
                        showPairPicker = false
                        router?.pendingCardID = card.id
                        router?.tab = .collection
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showWrapped) {
            WrappedStoryView(summary: wrappedSummary,
                             aggregate: (isSampleData || isEmptyState) ? nil : wrappedContent?.aggregate,
                             cards: wrappedContent?.cards ?? [],
                             isLoading: !isSampleData && !isEmptyState && isLoadingWrapped && wrappedContent == nil)
        }
        .onAppear {
            if router?.pendingWrapped == true {
                router?.pendingWrapped = false
                showWrapped = true
            }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-pairPicker"), cards.count > 1, !showPairPicker {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    showPairPicker = true
                }
            }
            #endif
        }
        .onChange(of: router?.pendingWrapped) { _, shouldOpen in
            if shouldOpen == true {
                router?.pendingWrapped = false
                showWrapped = true
            }
        }
        .task(id: wrappedInput) {
            let revision = wrappedInput.revision
            guard wrappedInput.active, !revision.sample, !revision.empty else {
                isLoadingWrapped = false
                if revision.empty {
                    wrappedContent = nil
                    loadedWrappedRevision = nil
                }
                return
            }
            if loadedWrappedRevision == revision && wrappedContent != nil {
                isLoadingWrapped = false
                return
            }
            isLoadingWrapped = true
            let cards = cards
            let content = await Task.detached(priority: .utility) {
                let aggregate = AggregateCache().load()?.aggregate
                let summary = aggregate.map { WrappedAggregator.summarize(aggregate: $0, cards: cards) }
                return summary.map { WrappedContent(summary: $0, aggregate: aggregate, cards: cards) }
            }.value
            guard !Task.isCancelled else { return }
            isLoadingWrapped = false
            wrappedContent = content
            loadedWrappedRevision = revision
        }
    }

    private var wrappedEntry: some View {
        let summary = wrappedSummary
        let isLight = colorScheme == .light
        let mint = Color(red: 0.68, green: 0.97, blue: 0.87)
        let lightTeal = Color(red: 0.04, green: 0.56, blue: 0.50)
        let cardForArt = summary.topCard ?? selectedCard ?? primaryCard ?? cards.first
        let color = cardForArt.flatMap { c in
            colorStore?.selectedColor(for: c) ?? DeviceColorOption.defaultOption(for: c.modelKey)
        }
        let yearText = summary.year.formatted(.number.grouping(.never))

        return Button {
            showWrapped = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isLight ? lightTeal.opacity(0.10) : mint.opacity(0.13))
                    if let cardForArt {
                        WrappedHeroArtwork(
                            card: cardForArt,
                            colorOption: color,
                            fallbackSymbol: summary.topDeviceSymbol
                        )
                        .frame(width: 40, height: 40)
                    } else {
                        Image(systemName: summary.topDeviceSymbol)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(isLight ? lightTeal : mint)
                    }
                }
                .frame(width: 52, height: 52)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(yearText) Earprint Wrapped")
                        .font(.system(.headline, design: .rounded, weight: .heavy))
                        .foregroundStyle(isLight ? Theme.primaryText : .white)
                    if summary.isThinData {
                        Text("\(yearText) First Card")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isLight ? lightTeal : mint)
                    } else {
                        Text("\(summary.totalMinutes.minutesText) listened in \(yearText)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isLight ? lightTeal : mint)
                    }
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(isLight ? lightTeal : mint)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isLight {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [mint.opacity(0.16), lightTeal.opacity(0.05), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(lightTeal.opacity(0.24), lineWidth: 1)
                        )
                        .shadow(color: Theme.cardShadow, radius: 10, y: 4)
                } else {
                    FoilSurface(rarity: .obsidian, tilt: CGSize(width: -0.4, height: 0.15), proFoil: .obsidianPrism)
                        .clipShape(.rect(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(mint.opacity(0.32), lineWidth: 1))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Atmospheric Backdrop

    private func backdrop(rarity: Rarity) -> some View {
        let isLight = colorScheme == .light
        return ZStack {
            DossierPalette.ink.ignoresSafeArea()
            RadialGradient(
                colors: [rarity.glow.opacity(isLight ? 0.14 : 0.24), rarity.accent.opacity(isLight ? 0.04 : 0.07), .clear],
                center: .topTrailing,
                startRadius: 16,
                endRadius: 430
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [rarity.accent.opacity(isLight ? 0.06 : 0.10), .clear],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 340
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Header & Collector Switcher Pill

    private func header(
        card: HeadphoneCard?,
        summary: ListeningSummary,
        rarity: Rarity,
        color: DeviceColorOption?,
        isWorn: Bool,
        isRetired: Bool = false
    ) -> some View {
        let pairName: String = if let card {
            isSampleData ? card.model : card.nickname
        } else {
            summary.deviceName
        }
        let pairModel = card?.model ?? summary.deviceModel
        let pairSubtitle: String? = if card == nil {
            pairModel != pairName ? pairModel : nil
        } else if !isSampleData && pairModel != pairName {
            pairModel
        } else {
            nil
        }
        let isLight = colorScheme == .light

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Text("Rings")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.primaryText, Theme.primaryText.opacity(0.84)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 8)

                Button { showShare = true } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.primaryText.opacity(0.92))
                        .frame(width: 44, height: 44)
                        .background {
                            if isLight {
                                Circle().fill(Theme.card)
                                    .shadow(color: Theme.cardShadow, radius: 6, y: 2)
                            } else {
                                Circle().fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.11), Color.white.opacity(0.03)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            }
                        }
                        .overlay(
                            Circle().strokeBorder(
                                LinearGradient(
                                    colors: [isLight ? Theme.cardStroke : .white.opacity(0.28), rarity.accent.opacity(0.24), Theme.hairline],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share my Earprint")
            }

            if cards.count > 1 {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showPairPicker = true
                } label: {
                    activePairPill(
                        card: card,
                        summary: summary,
                        rarity: rarity,
                        color: color,
                        isWorn: isWorn,
                        isRetired: isRetired,
                        name: pairName,
                        subtitle: pairSubtitle,
                        trailingSymbol: "chevron.up.chevron.down"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint("Switch between all headphones or a single pair")
            } else if let card {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    router?.pendingCardID = card.id
                    router?.tab = .collection
                } label: {
                    activePairPill(
                        card: card,
                        summary: summary,
                        rarity: rarity,
                        color: color,
                        isWorn: isWorn,
                        isRetired: isRetired,
                        name: pairName,
                        subtitle: pairSubtitle,
                        trailingSymbol: "chevron.right"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint("View card in Collection")
            } else {
                activePairPill(
                    card: nil,
                    summary: summary,
                    rarity: rarity,
                    color: nil,
                    isWorn: false,
                    isRetired: false,
                    name: pairName,
                    subtitle: pairSubtitle,
                    trailingSymbol: nil
                )
            }
        }
    }

    private func activePairPill(
        card: HeadphoneCard?,
        summary: ListeningSummary,
        rarity: Rarity,
        color: DeviceColorOption?,
        isWorn: Bool,
        isRetired: Bool = false,
        name: String,
        subtitle: String?,
        trailingSymbol: String?
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        let isPrestigeTier = rarity == .holo || rarity == .obsidian
        let clampedTitleSize = min(max(pillTitleSize, 14.5), 19.5)
        let isLight = colorScheme == .light

        return HStack(spacing: 11) {
            // Collector emblem medallion with concentric metallic/foil rim
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                rarity.glow.opacity(isLight ? 0.24 : 0.36),
                                rarity.accent.opacity(isLight ? 0.08 : 0.10),
                                isLight ? Color.black.opacity(0.06) : Color.black.opacity(0.42)
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: 24
                        )
                    )
                Circle()
                    .inset(by: 3)
                    .strokeBorder(Theme.hairline, lineWidth: 0.7)
                if isPrestigeTier {
                    Circle()
                        .strokeBorder(rarity.foil, lineWidth: 1.35)
                } else {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [isLight ? Theme.cardStroke : .white.opacity(0.36), rarity.accent.opacity(0.58), Theme.hairline],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.15
                        )
                }
                if let card {
                    HeadphoneArtwork(card: card, colorOption: color, showsChargingCase: false, showsShadow: false)
                        .padding(5)
                } else {
                    Image(systemName: summary.deviceSymbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.primaryText, rarity.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)

            // Single-line primary title + concise metadata subtitle
            VStack(alignment: .leading, spacing: 2.5) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: clampedTitleSize, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                    if isWorn {
                        ActiveWearDot()
                    } else if isRetired {
                        Image(systemName: "archivebox.fill")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(Theme.secondaryText)
                            .accessibilityLabel("Vaulted")
                    }
                }

                HStack(spacing: 5) {
                    if let subtitle {
                        Text(subtitle)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text("·")
                            .foregroundStyle(DossierPalette.faint)
                    }
                    Text(summary.lifetimeMinutes.minutesText)
                        .monospacedDigit()
                        .foregroundStyle(rarity.accent.opacity(0.92))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Compact metallic foil tier badge + switcher chevron
            HStack(spacing: 7) {
                HStack(spacing: 3.5) {
                    if isPrestigeTier {
                        Image(systemName: "sparkle")
                            .font(.system(size: 8.5, weight: .black))
                    }
                    Text(LocalizedStringKey(rarity.shortName.uppercased()))
                        .font(.system(size: 9.5, weight: .black, design: .rounded))
                        .tracking(0.8)
                        .lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(rarity.ink)
                .shadow(color: rarity.ink == .white ? .black.opacity(0.32) : .clear, radius: 1, y: 0.5)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background {
                    Capsule()
                        .fill(rarity.foil)
                        .shadow(color: rarity.glow.opacity(0.36), radius: 6, y: 2)
                        .overlay(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(rarity.ink == .white ? 0.24 : 0.44), .clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        )
                }
                .overlay(
                    Capsule().strokeBorder(
                        rarity.ink == .white ? .white.opacity(0.30) : .black.opacity(0.16),
                        lineWidth: 0.75
                    )
                )

                if let trailingSymbol {
                    Image(systemName: trailingSymbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.tertiaryText)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            Group {
                if isLight {
                    shape.fill(Theme.card)
                        .shadow(color: Theme.cardShadow, radius: 12, y: 4)
                } else {
                    shape.fill(
                        LinearGradient(
                            colors: [Color(red: 0.105, green: 0.105, blue: 0.15), Color(red: 0.065, green: 0.065, blue: 0.095)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: rarity.glow.opacity(0.14), radius: 14, y: 6)
                }
            }
            .overlay {
                RadialGradient(
                    colors: [rarity.glow.opacity(isLight ? 0.11 : 0.20), .clear],
                    center: .leading,
                    startRadius: 4,
                    endRadius: 160
                )
                .clipShape(shape)
            }
            .overlay(alignment: .top) {
                if !isLight {
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.22), rarity.accent.opacity(0.24), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 1)
                    .padding(.horizontal, 20)
                }
            }
        }
        .overlay {
            shape.strokeBorder(
                LinearGradient(
                    colors: [isLight ? Theme.cardStroke : .white.opacity(0.28), rarity.accent.opacity(0.25), Theme.hairline],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var healthStatus: some View {
        if isSampleData {
            SampleDataBanner(badgeText: sampleBadgeText, detail: statusMessage,
                             isLoading: isLoading, onConnect: onConnectHealth)
        }
    }

    private func emptyRingsState(summary: ListeningSummary) -> some View {
        let isLight = colorScheme == .light
        return VStack(spacing: 16) {
            ZStack {
                EarprintGlyph(grid: summary.grid, showHourLabels: false)
                    .equatable()
                    .frame(width: 170, height: 170)
                    .opacity(isLight ? 0.74 : 0.48)
                if isLoading {
                    ProgressView()
                        .tint(Theme.primaryText)
                } else {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Theme.quietColor)
                }
            }
            .padding(.top, 4)

            Text(isLoading ? "Reading Apple Health…" : "No listening data yet")
                .font(.headline)
                .foregroundStyle(Theme.primaryText)

            Text(statusMessage ?? "Connect Apple Health to see your 28-day listening rings. iOS records audio levels while playing audio.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            if let onConnectHealth, !isLoading {
                VStack(spacing: 10) {
                    Button(action: onConnectHealth) {
                        Label("Sync Apple Health", systemImage: "heart.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.invertedText)
                            .padding(.horizontal, 22)
                            .frame(minHeight: 44)
                            .background(Theme.invertedFill, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    if statusMessage != nil, let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        Link(destination: settingsURL) {
                            Label("Open Settings", systemImage: "gearshape")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.secondaryText)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 36)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .ringsPanel(cornerRadius: 28, tint: Theme.quietColor, tintCenter: .center)
    }
}

// MARK: - Rings Surface Modifier

private struct RingsGlassPanel: ViewModifier {
    var cornerRadius: CGFloat = 24
    var tint: Color = Theme.primaryText
    var tintCenter: UnitPoint = .topLeading

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let isLight = colorScheme == .light
        content
            .background {
                Group {
                    if isLight {
                        shape.fill(Theme.card)
                            .shadow(color: Theme.cardShadow, radius: 12, y: 5)
                    } else {
                        shape.fill(
                            LinearGradient(
                                colors: [Color(red: 0.098, green: 0.098, blue: 0.142), Color(red: 0.060, green: 0.060, blue: 0.090)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.32), radius: 14, y: 8)
                    }
                }
                .overlay {
                    RadialGradient(
                        colors: [tint.opacity(isLight ? 0.08 : 0.13), .clear],
                        center: tintCenter,
                        startRadius: 8,
                        endRadius: 230
                    )
                    .clipShape(shape)
                }
                .overlay(alignment: .top) {
                    if !isLight {
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.18), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(height: 1)
                        .padding(.horizontal, 24)
                    }
                }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [isLight ? Theme.cardStroke : .white.opacity(0.24), tint.opacity(0.18), Theme.hairline],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
    }
}

private extension View {
    func ringsPanel(cornerRadius: CGFloat = 24, tint: Color = Theme.primaryText, tintCenter: UnitPoint = .topLeading) -> some View {
        modifier(RingsGlassPanel(cornerRadius: cornerRadius, tint: tint, tintCenter: tintCenter))
    }
}

// MARK: - Hero 28-Day Earprint Chronometer Card (Tilt-Isolated)

private struct RingsHeroCard: View {
    let summary: ListeningSummary
    let rarity: Rarity
    let tiltActive: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        let has28DayData = summary.has28DayData
        let weekMinutes = summary.weekMinutes
        let weekDB = summary.weekDecibels
        let persona = summary.persona
        let isLight = colorScheme == .light
        let dbColor = weekMinutes > 0 ? Theme.levelColor(db: weekDB, colorScheme: colorScheme) : DossierPalette.dim

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(rarity.accent)
                        .frame(width: 6, height: 6)
                        .shadow(color: rarity.glow.opacity(isLight ? 0.35 : 0.85), radius: 4)
                    Eyebrow("28-DAY EARPRINT", color: Theme.primaryText.opacity(0.70))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 8)
                if has28DayData {
                    HStack(spacing: 5) {
                        Text(persona.emoji)
                            .font(.caption2)
                        Text(LocalizedStringKey(persona.title))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.primaryText.opacity(0.92))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5.5)
                    .background(Theme.surfaceFill, in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(
                            LinearGradient(
                                colors: [Theme.hairline, rarity.accent.opacity(0.32)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.9
                        )
                    )
                }
            }

            // Proportional chronometer dial: center complication scales with the glyph so it never overlaps rings.
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                let wellSize = min(84, max(52, side * 0.335))

                ZStack {
                    // Soft collector aura behind the chronometer dial
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [rarity.glow.opacity(0.20), rarity.accent.opacity(0.06), .clear],
                                center: .center,
                                startRadius: side * 0.08,
                                endRadius: side * 0.52
                            )
                        )
                        .accessibilityHidden(true)

                    EarprintGlyph(grid: summary.grid, showHourLabels: true)
                        .equatable()
                        .accessibilityHidden(true)

                    // Recessed watch-complication center dial well with double concentric bezel
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: isLight ? [
                                        dbColor.opacity(weekMinutes > 0 ? 0.10 : 0.03),
                                        Color(red: 0.96, green: 0.965, blue: 0.98),
                                        Color(red: 0.92, green: 0.93, blue: 0.95)
                                    ] : [
                                        dbColor.opacity(weekMinutes > 0 ? 0.14 : 0.04),
                                        Color(red: 0.075, green: 0.075, blue: 0.115).opacity(0.95),
                                        Color(red: 0.042, green: 0.042, blue: 0.070).opacity(0.92)
                                    ],
                                    center: .top,
                                    startRadius: 2,
                                    endRadius: wellSize * 0.58
                                )
                            )
                        Circle()
                            .inset(by: 3)
                            .strokeBorder(Theme.hairline, lineWidth: 0.65)
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [isLight ? Theme.cardStroke : .white.opacity(0.22), rarity.accent.opacity(0.24), Theme.hairline],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.95
                            )

                        VStack(spacing: 3.5) {
                            Text(weekMinutes.minutesText)
                                .font(.system(size: max(12.5, wellSize * 0.196), weight: .heavy, design: .rounded))
                                .monospacedDigit()
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                                .foregroundStyle(
                                    isLight
                                        ? AnyShapeStyle(Theme.primaryText)
                                        : AnyShapeStyle(LinearGradient(colors: [Theme.primaryText, rarity.accent.opacity(0.94)], startPoint: .top, endPoint: .bottom))
                                )
                            if weekMinutes > 0 {
                                Text("\(Int(weekDB.rounded())) dB")
                                    .font(.system(size: max(8.5, wellSize * 0.112), weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(dbColor)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(dbColor.opacity(0.16), in: Capsule())
                                    .overlay(Capsule().strokeBorder(dbColor.opacity(0.42), lineWidth: 0.75))
                            } else {
                                Text("7d")
                                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(DossierPalette.dim)
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                    .frame(width: wellSize, height: wellSize)
                    .accessibilityElement(children: .combine)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 244)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, Theme.hairline, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            HStack(spacing: 10) {
                legendChip(Theme.quietColor, "Quiet")
                legendChip(Theme.moderateColor, "Moderate")
                legendChip(Theme.loudColor, "Loud")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(18)
        .background {
            Group {
                if isLight {
                    shape.fill(Theme.card)
                        .shadow(color: Theme.cardShadow, radius: 14, y: 6)
                } else {
                    shape.fill(
                        LinearGradient(
                            colors: [Color(red: 0.098, green: 0.098, blue: 0.145), Color(red: 0.054, green: 0.054, blue: 0.086)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: rarity.glow.opacity(0.16), radius: 18, y: 10)
                }
            }
            .overlay(alignment: .top) {
                if !isLight {
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.24), rarity.accent.opacity(0.26), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 1)
                    .padding(.horizontal, 28)
                }
            }
            // Isolated tilt spotlight: only this lightweight gradient redraws on tilt; EarprintGlyph stays untouched.
            RingsHeroTiltGlow(rarity: rarity, shape: shape, isActive: tiltActive)
        }
        .overlay {
            RingsHeroTiltBorder(rarity: rarity, shape: shape, isActive: tiltActive)
        }
    }

    private func legendChip(_ color: Color, _ label: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6.5, height: 6.5)
                .shadow(color: color.opacity(0.45), radius: 3)
            Text(label)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(Theme.primaryText.opacity(0.82))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Theme.surfaceFill, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 0.75))
    }
}

private struct RingsHeroTiltGlow: View {
    let rarity: Rarity
    let shape: RoundedRectangle
    let isActive: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isLight = colorScheme == .light
        LiveTiltView(isActive: isActive) { tilt in
            RadialGradient(
                colors: [rarity.glow.opacity(isLight ? 0.10 : 0.20), rarity.accent.opacity(isLight ? 0.04 : 0.07), .clear],
                center: UnitPoint(x: 0.5 + tilt.width * 0.16, y: 0.32 + tilt.height * 0.12),
                startRadius: 10,
                endRadius: 245
            )
            .clipShape(shape)
        }
        .allowsHitTesting(false)
    }
}

private struct RingsHeroTiltBorder: View {
    let rarity: Rarity
    let shape: RoundedRectangle
    let isActive: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isLight = colorScheme == .light
        LiveTiltView(isActive: isActive) { tilt in
            shape.strokeBorder(
                LinearGradient(
                    colors: isLight ? [
                        Color.black.opacity(0.10),
                        Color.black.opacity(0.05),
                        rarity.glow.opacity(0.32),
                        rarity.accent.opacity(0.18)
                    ] : [
                        .white.opacity(0.46),
                        .white.opacity(0.09),
                        rarity.glow.opacity(0.48),
                        rarity.accent.opacity(0.28)
                    ],
                    startPoint: UnitPoint(x: 0.15 + tilt.width * 0.45, y: 0.0 + tilt.height * 0.35),
                    endPoint: UnitPoint(x: 0.85 + tilt.width * 0.45, y: 1.0 + tilt.height * 0.35)
                ),
                lineWidth: 1.25
            )
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Cached Localized Weekday Symbols for WeeklyRhythmCard

@MainActor
private enum WeekdayLabelCache {
    struct Labels {
        let short: [String]
        let full: [String]
    }

    private struct Key: Hashable {
        let localeID: String
        let dayStartEpoch: TimeInterval
        let count: Int
    }

    private static var lastKey: Key?
    private static var lastLabels: Labels = Labels(short: [], full: [])

    static func labels(locale: Locale, count: Int, now: Date = Date()) -> Labels {
        var calendar = Calendar.current
        calendar.locale = locale
        let today = calendar.startOfDay(for: now)
        let key = Key(localeID: locale.identifier, dayStartEpoch: today.timeIntervalSince1970, count: count)
        if key == lastKey {
            return lastLabels
        }
        let shortSymbols = calendar.shortStandaloneWeekdaySymbols
        let fullSymbols = calendar.standaloneWeekdaySymbols
        var short: [String] = []
        var full: [String] = []
        short.reserveCapacity(count)
        full.reserveCapacity(count)
        for offset in 0..<count {
            let daysAgo = (count - 1) - offset
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            let idx = max(0, min(6, calendar.component(.weekday, from: date) - 1))
            short.append(shortSymbols.indices.contains(idx) ? shortSymbols[idx] : "")
            full.append(fullSymbols.indices.contains(idx) ? fullSymbols[idx] : "")
        }
        let built = Labels(short: short, full: full)
        lastKey = key
        lastLabels = built
        return built
    }
}

// MARK: - Interactive Last 7 Days Rhythm Card

private struct WeeklyRhythmCard: View {
    let summary: ListeningSummary
    let rarity: Rarity

    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .largeTitle) private var listeningTimeSize: CGFloat = 38
    @State private var selectedOffset: Int? = nil

    private struct DayPoint: Identifiable {
        let id: Int
        let minutes: Double
        let decibels: Double?
        let isToday: Bool
        let shortWeekday: String
        let fullWeekday: String
    }

    private func buildDayPoints() -> [DayPoint] {
        let metrics = summary.last7Days
        let count = metrics.count
        guard count > 0 else { return [] }
        let labels = WeekdayLabelCache.labels(locale: locale, count: count)
        var result: [DayPoint] = []
        result.reserveCapacity(count)
        for offset in 0..<count {
            let item = metrics[offset]
            result.append(DayPoint(
                id: offset,
                minutes: item.minutes,
                decibels: item.decibels,
                isToday: offset == count - 1,
                shortWeekday: labels.short.indices.contains(offset) ? labels.short[offset] : "",
                fullWeekday: labels.full.indices.contains(offset) ? labels.full[offset] : ""
            ))
        }
        return result
    }

    var body: some View {
        let points = buildDayPoints()
        let selected = selectedOffset.flatMap { idx in points.indices.contains(idx) ? points[idx] : nil }
        let displayedMinutes = selected?.minutes ?? summary.weekMinutes
        let displayedDB = selected?.decibels ?? (summary.weekMinutes > 0 ? summary.weekDecibels : nil)
        let maxMinutes = max(points.map(\.minutes).max() ?? 0, 1)
        let activeDayCount = points.filter { $0.minutes > 0 }.count
        let averageMinutes = activeDayCount > 0 ? summary.weekMinutes / Double(points.count) : 0
        let avgRatio = min(1, max(0, averageMinutes / maxMinutes))

        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(rarity.accent)
                        .accessibilityHidden(true)
                    Eyebrow("LAST 7 DAYS", color: Theme.primaryText.opacity(0.68))
                }
                Spacer(minLength: 8)
                Text(summary.periodLabel)
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Theme.surfaceFill, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 0.75))
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .lastTextBaseline, spacing: 14) {
                    metricTime(minutes: displayedMinutes, selected: selected)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    metricLevel(db: displayedDB)
                        .fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 10) {
                    metricTime(minutes: displayedMinutes, selected: selected)
                    metricLevel(db: displayedDB)
                }
            }

            // Equalizer bars with dashed daily-average reference guide + localized weekday labels
            VStack(spacing: 7) {
                if averageMinutes > 0 {
                    HStack(spacing: 5) {
                        Spacer(minLength: 0)
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 1))
                            path.addLine(to: CGPoint(x: 12, y: 1))
                        }
                        .stroke(Theme.primaryText.opacity(0.32), style: StrokeStyle(lineWidth: 1, dash: [2.5, 2.5]))
                        .frame(width: 12, height: 2)
                        Text("AVG")
                            .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                            .tracking(0.6)
                            .foregroundStyle(Theme.secondaryText)
                        Text(averageMinutes.minutesText)
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .accessibilityHidden(true)
                }

                ZStack(alignment: .top) {
                    if averageMinutes > 0 {
                        GeometryReader { geo in
                            let lineY = 62 * (1 - avgRatio)
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: lineY))
                                path.addLine(to: CGPoint(x: geo.size.width, y: lineY))
                            }
                            .stroke(Theme.primaryText.opacity(0.24), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        }
                        .frame(height: 62)
                        .allowsHitTesting(false)
                    }

                    HStack(alignment: .bottom, spacing: 7) {
                        ForEach(points) { point in
                            let barColor = point.decibels.map { Theme.levelColor(db: $0, colorScheme: colorScheme) } ?? Theme.quietColor
                            let isSelected = selected?.id == point.id
                            let isHighlighted = selected == nil ? point.isToday : isSelected
                            let isDimmed = selected != nil && !isSelected
                            let barHeight = point.minutes > 0 ? max(6, 62 * point.minutes / maxMinutes) : 0

                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.snappy(duration: 0.22)) {
                                    selectedOffset = (selectedOffset == point.id) ? nil : point.id
                                }
                            } label: {
                                VStack(spacing: 7) {
                                    ZStack(alignment: .bottom) {
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .fill(
                                                isSelected
                                                    ? rarity.accent.opacity(0.14)
                                                    : (point.isToday ? Theme.surfaceFillStrong : Theme.surfaceFill)
                                            )
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                    .strokeBorder(
                                                        isSelected
                                                            ? rarity.accent.opacity(0.45)
                                                            : Theme.hairline,
                                                        lineWidth: isSelected ? 1 : 0.75
                                                    )
                                            }

                                        if point.minutes > 0 {
                                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                .fill(
                                                    LinearGradient(
                                                        colors: isHighlighted
                                                            ? [barColor, barColor.opacity(0.75)]
                                                            : [barColor.opacity(0.78), barColor.opacity(0.42)],
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                    )
                                                )
                                                .frame(height: barHeight)
                                                .overlay(alignment: .top) {
                                                    Capsule()
                                                        .fill(.white.opacity(isHighlighted ? 0.78 : 0.30))
                                                        .frame(height: 2)
                                                        .padding(.horizontal, 5)
                                                        .padding(.top, 2)
                                                }
                                                .overlay {
                                                    if isHighlighted {
                                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                            .strokeBorder(colorScheme == .light ? Color.black.opacity(0.18) : .white.opacity(0.58), lineWidth: 1)
                                                    }
                                                }
                                                .shadow(color: isHighlighted ? barColor.opacity(colorScheme == .light ? 0.25 : 0.45) : .clear, radius: 6, y: 2)
                                        }
                                    }
                                    .frame(height: 62)
                                    .opacity(isDimmed ? 0.42 : 1.0)

                                    VStack(spacing: 3) {
                                        Text(verbatim: point.shortWeekday)
                                            .font(.system(size: 10, weight: (point.isToday || isSelected) ? .bold : .medium, design: .rounded))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.75)
                                            .foregroundStyle(
                                                isSelected ? rarity.accent : (point.isToday ? Theme.primaryText : Theme.secondaryText)
                                            )
                                        Circle()
                                            .fill(isSelected ? rarity.accent : (point.isToday ? rarity.accent.opacity(0.85) : .clear))
                                            .frame(width: 3.5, height: 3.5)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(point.isToday ? Text("Today") : Text(verbatim: point.fullWeekday))
                            .accessibilityValue(Text(point.minutes.minutesText))
                        }
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Daily listening, earliest to latest")
        }
        .padding(18)
        .ringsPanel(cornerRadius: 24, tint: rarity.accent, tintCenter: .topLeading)
        .onChange(of: summary) { _, _ in
            selectedOffset = nil
        }
    }

    private func metricTime(minutes: Double, selected: DayPoint?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(minutes.minutesText)
                .font(.system(size: listeningTimeSize, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(
                    LinearGradient(colors: [Theme.primaryText, Theme.primaryText.opacity(0.84)], startPoint: .top, endPoint: .bottom)
                )
                .contentTransition(.numericText(value: minutes))
            if let selected {
                HStack(spacing: 5) {
                    Circle()
                        .fill(rarity.accent)
                        .frame(width: 5, height: 5)
                    Group {
                        if selected.isToday {
                            Text("Today")
                        } else {
                            Text(verbatim: selected.fullWeekday)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(rarity.accent)
                }
            } else {
                Text("Listening time")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func metricLevel(db: Double?) -> some View {
        let color = db.map { Theme.levelColor(db: $0, colorScheme: colorScheme) } ?? Theme.secondaryText
        return VStack(alignment: .trailing, spacing: 3) {
            HStack(spacing: 5) {
                if db != nil {
                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                        .shadow(color: color.opacity(0.75), radius: 3)
                }
                Group {
                    if let db {
                        Text("\(Int(db.rounded())) dB")
                    } else {
                        Text(verbatim: "—")
                    }
                }
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
            }
            Text("Avg. level")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Hearing Budget Acoustic Telemetry Card

private struct HearingBudgetCard: View {
    let summary: ListeningSummary
    let showingAllPairs: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let used = max(0, summary.weeklyBudgetUsed)
        let displayPercent = Int((used * 100).rounded())
        let tint = used >= 1 ? Theme.loudColor : (used >= 0.75 ? Theme.moderateColor : Theme.quietColor)
        let clamped = min(used, 1)
        let hasVisibleFill = displayPercent > 0
        let isLight = colorScheme == .light

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(tint.opacity(0.16))
                        Circle()
                            .strokeBorder(tint.opacity(0.42), lineWidth: 0.85)
                        Image(systemName: "ear")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(tint)
                    }
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                    Eyebrow("HEARING BUDGET", color: Theme.primaryText.opacity(0.68))
                }
                Spacer()
                Text("\(displayPercent)% used")
                    .font(.caption.weight(.heavy).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                    .background(tint.opacity(0.14), in: Capsule())
                    .overlay(Capsule().strokeBorder(tint.opacity(0.40), lineWidth: 0.9))
            }

            // Precision quarter-ticked acoustic gauge bar + scale markings
            VStack(spacing: 5) {
                GeometryReader { geo in
                    let width = max(0, geo.size.width)
                    let fillWidth = (hasVisibleFill && width > 0) ? min(width, max(10, width * clamped)) : 0
                    let pipX: CGFloat = if width <= 10 {
                        width / 2
                    } else if hasVisibleFill {
                        min(width - 5, max(5, fillWidth - 4))
                    } else {
                        5
                    }

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(isLight ? Theme.surfaceFillStrong : Color.black.opacity(0.38))
                            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 0.8))

                        // Quarter calibration ticks (25% / 50% / 75%)
                        ForEach([0.25, 0.50, 0.75], id: \.self) { mark in
                            Rectangle()
                                .fill(Theme.primaryText.opacity(0.15))
                                .frame(width: 1, height: 6)
                                .offset(x: width * mark)
                        }

                        if fillWidth > 0 {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.quietColor, Theme.moderateColor, Theme.loudColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .mask(alignment: .leading) {
                                    Capsule().frame(width: fillWidth)
                                }
                                .shadow(color: tint.opacity(isLight ? 0.25 : 0.48), radius: 5)
                        }

                        // Luminous precision indicator bead
                        Circle()
                            .fill(hasVisibleFill ? .white : tint.opacity(0.85))
                            .frame(width: 8, height: 8)
                            .overlay(Circle().strokeBorder(tint, lineWidth: 1.5))
                            .shadow(color: tint.opacity(isLight ? 0.35 : 0.75), radius: 4)
                            .offset(x: max(1, pipX - 4))
                    }
                }
                .frame(height: 10)

                HStack {
                    Text(verbatim: "0%")
                    Spacer()
                    Text(verbatim: "50%")
                    Spacer()
                    Text(verbatim: "100%")
                }
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.secondaryText)
            }
            .accessibilityHidden(true)

            Text(
                showingAllPairs
                    ? "7-day exposure across all pairs · WHO reference: 40 hours at 80 dB(A)"
                    : "7-day exposure for this pair · WHO reference: 40 hours at 80 dB(A)"
            )
            .font(.caption)
            .foregroundStyle(Theme.secondaryText)
        }
        .padding(18)
        .ringsPanel(cornerRadius: 24, tint: tint, tintCenter: .topTrailing)
    }
}

// MARK: - All-Time Archive Vault Card

private struct AllTimeArchiveCard: View {
    let summary: ListeningSummary
    let rarity: Rarity
    let isAccessibilitySize: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let hours = summary.lifetimeMinutes / 60
        let progress = rarity.progressToNextTier(minutes: summary.lifetimeMinutes)
        let isLight = colorScheme == .light

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(rarity.accent)
                        .accessibilityHidden(true)
                    Eyebrow("ALL-TIME ARCHIVE", color: Theme.primaryText.opacity(0.68))
                }
                Spacer(minLength: 8)
                if summary.firstUse != "—" {
                    Text("Since \(summary.firstUse)")
                        .font(.system(.caption2, design: .monospaced, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Theme.surfaceFill, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 0.75))
                }
            }

            if isAccessibilitySize {
                VStack(spacing: 10) {
                    statWell("Listening time", summary.lifetimeMinutes.minutesText, icon: "clock.fill", tint: rarity.accent, featured: true)
                    statWell("Sessions", summary.sessions.formatted(), icon: "waveform.path.ecg", tint: Theme.quietColor)
                    statWell("Avg. session", summary.averageSessionMinutes.minutesText, icon: "timer", tint: Theme.primaryText.opacity(0.75))
                    statWell("Longest session", summary.longestSessionMinutes.minutesText, icon: "flame.fill", tint: Theme.moderateColor)
                }
            } else {
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        statWell("Listening time", summary.lifetimeMinutes.minutesText, icon: "clock.fill", tint: rarity.accent, featured: true)
                        statWell("Sessions", summary.sessions.formatted(), icon: "waveform.path.ecg", tint: Theme.quietColor)
                    }
                    GridRow {
                        statWell("Avg. session", summary.averageSessionMinutes.minutesText, icon: "timer", tint: Theme.primaryText.opacity(0.75))
                        statWell("Longest session", summary.longestSessionMinutes.minutesText, icon: "flame.fill", tint: Theme.moderateColor)
                    }
                }
            }

            // Sleek Collector Tier Progress footer tying Rings into the 6-tier vault
            VStack(alignment: .leading, spacing: 7) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Theme.hairline, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)

                HStack(spacing: 8) {
                    Text(LocalizedStringKey(rarity.title))
                        .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(rarity.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 6)

                    if let next = rarity.nextTierHours {
                        let remaining = max(1, Int(ceil(next - hours)))
                        Text("\(remaining)h to next tier")
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Theme.primaryText.opacity(0.70))
                            .lineLimit(1)
                    } else {
                        Text("Max tier reached ✦")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(rarity.accent)
                            .lineLimit(1)
                    }
                }

                GeometryReader { geo in
                    let w = max(0, geo.size.width)
                    let barW = (w > 0 && progress > 0) ? min(w, max(8, w * progress)) : 0
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.surfaceFillStrong)
                        if barW > 0 {
                            Capsule()
                                .fill(rarity.foil)
                                .frame(width: barW)
                                .overlay(alignment: .top) {
                                    Capsule()
                                        .fill(.white.opacity(0.32))
                                        .frame(height: 1.5)
                                        .padding(.horizontal, 3)
                                }
                                .shadow(color: rarity.glow.opacity(isLight ? 0.25 : 0.45), radius: 4)
                        }
                    }
                }
                .frame(height: 5.5)
                .accessibilityHidden(true)
            }
            .padding(.top, 2)
        }
        .padding(18)
        .ringsPanel(cornerRadius: 24, tint: rarity.glow, tintCenter: .bottomTrailing)
    }

    private func statWell(
        _ title: LocalizedStringKey,
        _ value: String,
        icon: String,
        tint: Color,
        featured: Bool = false
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let isLight = colorScheme == .light
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(tint.opacity(0.90))
                    .accessibilityHidden(true)
            }

            Text(value)
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(featured ? tint : Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Group {
                if isLight {
                    shape.fill(featured ? tint.opacity(0.08) : Theme.surfaceFill)
                } else {
                    shape.fill(
                        LinearGradient(
                            colors: featured
                                ? [tint.opacity(0.15), Color.black.opacity(0.28)]
                                : [Color.white.opacity(0.048), Color.black.opacity(0.26)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
            }
            .overlay(alignment: .top) {
                if featured {
                    LinearGradient(
                        colors: [.clear, tint.opacity(0.45), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 1)
                    .padding(.horizontal, 14)
                }
            }
        }
        .overlay {
            shape.strokeBorder(
                LinearGradient(
                    colors: featured
                        ? [tint.opacity(0.42), Theme.hairline]
                        : [Theme.hairline, Theme.hairline.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.9
            )
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HomeView(summary: SampleData.summary, primaryCard: SampleCards.all.first, cards: SampleCards.all, isSampleData: true)
}

private struct RingsPairPickerSheet: View {
    let cards: [HeadphoneCard]
    var retiredCardIDs: Set<String> = []
    let selectedCard: HeadphoneCard?
    let allMinutes: Double
    let allRarity: Rarity
    let isSampleData: Bool
    var colorStore: DeviceColorStore?
    var routeMonitor: ActiveAudioRouteMonitor?
    let onSelectCardID: (String?) -> Void
    var onOpen3DCard: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .headline) private var rowTitleSize: CGFloat = 15.5

    var body: some View {
        let isLight = colorScheme == .light
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Headphones")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text("\(cards.count) pairs")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                        .frame(width: 34, height: 34)
                        .background(Theme.surfaceFill, in: Circle())
                        .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Done")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    pickerRow(
                        title: LocalizedStringKey("All Headphones"),
                        subtitle: LocalizedStringKey("\(cards.count) pairs · \(allMinutes.minutesText)"),
                        rarity: allRarity,
                        card: nil,
                        color: nil,
                        isWorn: false,
                        isSelected: selectedCard == nil,
                        isLight: isLight
                    ) {
                        onSelectCardID(nil)
                    }

                    let activeCards = cards.filter { !retiredCardIDs.contains($0.id) }
                    let retiredCards = cards.filter { retiredCardIDs.contains($0.id) }

                    ForEach(activeCards) { item in
                        let title = isSampleData ? item.model : item.nickname
                        let subtitleKey: LocalizedStringKey = (!isSampleData && item.model != title)
                            ? "\(item.model) · \(item.lifetimeMinutes.minutesText)"
                            : "\(item.sessions) sessions · \(item.lifetimeMinutes.minutesText)"
                        let color = colorStore?.selectedColor(for: item) ?? DeviceColorOption.defaultOption(for: item.modelKey)
                        let worn = routeMonitor?.isCurrentlyWorn(item) ?? false

                        pickerRow(
                            title: LocalizedStringKey(title),
                            subtitle: subtitleKey,
                            rarity: item.rarity,
                            card: item,
                            color: color,
                            isWorn: worn,
                            isRetired: false,
                            isSelected: selectedCard?.id == item.id,
                            isLight: isLight
                        ) {
                            onSelectCardID(item.id)
                        }
                    }

                    if !retiredCards.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "archivebox.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("VAULT")
                                .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                                .tracking(1.4)
                        }
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.top, 8)
                        .padding(.horizontal, 4)

                        ForEach(retiredCards) { item in
                            let title = isSampleData ? item.model : item.nickname
                            let subtitleKey: LocalizedStringKey = (!isSampleData && item.model != title)
                                ? "\(item.model) · \(item.lifetimeMinutes.minutesText)"
                                : "\(item.sessions) sessions · \(item.lifetimeMinutes.minutesText)"
                            let color = colorStore?.selectedColor(for: item) ?? DeviceColorOption.defaultOption(for: item.modelKey)

                            pickerRow(
                                title: LocalizedStringKey(title),
                                subtitle: subtitleKey,
                                rarity: item.rarity,
                                card: item,
                                color: color,
                                isWorn: false,
                                isRetired: true,
                                isSelected: selectedCard?.id == item.id,
                                isLight: isLight
                            ) {
                                onSelectCardID(item.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 2)
                .padding(.bottom, 14)
            }
            .scrollIndicators(.hidden)

            if let selectedCard, let onOpen3DCard {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onOpen3DCard()
                } label: {
                    Label("Open \(isSampleData ? selectedCard.model : selectedCard.nickname) 3D Card", systemImage: "rectangle.stack")
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(Theme.invertedText)
                        .background(Theme.invertedFill, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
        .background(Theme.canvasElevated.ignoresSafeArea())
        .foregroundStyle(Theme.primaryText)
    }

    private func pickerRow(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        rarity: Rarity,
        card: HeadphoneCard?,
        color: DeviceColorOption?,
        isWorn: Bool,
        isRetired: Bool = false,
        isSelected: Bool,
        isLight: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let clampedTitle = min(max(rowTitleSize, 14.5), 20)
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    rarity.glow.opacity(isLight ? 0.22 : 0.34),
                                    rarity.accent.opacity(isLight ? 0.08 : 0.14),
                                    isLight ? Color.black.opacity(0.04) : Color(white: 0.12)
                                ],
                                center: .center,
                                startRadius: 2,
                                endRadius: 24
                            )
                        )
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [isLight ? Theme.cardStroke : .white.opacity(0.32), rarity.accent.opacity(0.55), Theme.hairline],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.1
                        )
                    if let card {
                        HeadphoneArtwork(card: card, colorOption: color, showsChargingCase: false, showsShadow: false)
                            .padding(5)
                    } else {
                        Image(systemName: "headphones")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Theme.primaryText, rarity.accent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2.5) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: clampedTitle, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .truncationMode(.tail)
                            .layoutPriority(1)
                        if isWorn {
                            ActiveWearDot()
                        } else if isRetired {
                            Image(systemName: "archivebox.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.secondaryText)
                                .accessibilityLabel("Vaulted")
                        }
                    }
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(LocalizedStringKey(rarity.shortName.uppercased()))
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(rarity.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(rarity.foil, in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(
                            rarity.ink == .white ? .white.opacity(0.28) : .black.opacity(0.16),
                            lineWidth: 0.75
                        )
                    )
                    .fixedSize(horizontal: true, vertical: false)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isLight && rarity == .silver ? Theme.primaryText : rarity.accent)
                } else {
                    Circle()
                        .strokeBorder(Theme.hairline, lineWidth: 1.4)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                shape.fill(Theme.card)
                    .overlay {
                        if isSelected {
                            shape.fill(rarity.accent.opacity(isLight ? 0.06 : 0.10))
                        }
                    }
                    .shadow(
                        color: isSelected
                            ? (isLight ? Theme.cardShadow : rarity.glow.opacity(0.18))
                            : (isLight ? Theme.cardShadow.opacity(0.45) : .clear),
                        radius: 10,
                        y: 4
                    )
            }
            .overlay {
                shape.strokeBorder(
                    isSelected ? rarity.accent.opacity(isLight ? 0.65 : 0.75) : Theme.hairline,
                    lineWidth: isSelected ? 1.5 : 0.9
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
