import Charts
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
    var lastSynced: Date? = nil
    var onConnectHealth: (() -> Void)? = nil
    var wrappedSummaryOverride: WrappedSummary? = nil

    @Environment(DeepLinkRouter.self) private var router: DeepLinkRouter?
    @Environment(DeviceColorStore.self) private var colorStore: DeviceColorStore?
    @Environment(ActiveAudioRouteMonitor.self) private var routeMonitor: ActiveAudioRouteMonitor?
    @Environment(DeviceLifecycleStore.self) private var lifecycleStore: DeviceLifecycleStore?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var selectedCardID: String? = nil
    @State private var showPairPicker = false
    @State private var showShare = ProcessInfo.processInfo.arguments.contains("-showShare")
    @State private var space = LayoutSpace()
    @State private var showWrapped = false
    @State private var showTiers = false
    @State private var wrappedContent: WrappedContent?
    @State private var loadedWrappedRevision: WrappedRevision?
    @State private var isLoadingWrapped = false
    @State private var isScrolled = false

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
        let revision = WrappedRevision(
            sample: isSampleData,
            empty: isEmptyState,
            cacheModification: lastSynced,
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
        if let wrappedSummaryOverride { return wrappedSummaryOverride }
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
        let wrappedInput = wrappedInput
        let headerHorizontalPadding: CGFloat = (space.isWide || (space.isLandscape && space.size.width >= 520)) ? 24 : 18

        ZStack {
            backdrop(rarity: currentRarity)

            ScrollView {
                Group {
                    if isEmptyState {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(alignment: .center, spacing: 12) {
                                Text("Rings")
                                    .font(.title.weight(.bold))
                                    .accessibilityAddTraits(.isHeader)
                                Spacer()
                            }
                            emptyRingsState(summary: currentSummary)
                        }
                        .padding(.horizontal, space.isWide ? 24 : 18)
                    } else if space.isWide || (space.isLandscape && space.size.width >= 520) {
                        let split = ColumnSplit(space: space, padding: 24, gap: 24)
                        VStack(alignment: .leading, spacing: 18) {
                            healthStatus
                            HStack(alignment: .top, spacing: split.gap) {
                                VStack(alignment: .leading, spacing: 18) {
                                    RingsHeroCard(summary: currentSummary, rarity: currentRarity)
                                    AllTimeArchiveCard(
                                        summary: currentSummary,
                                        rarity: currentRarity,
                                        isAccessibilitySize: dynamicTypeSize.isAccessibilitySize,
                                        showingAllPairs: showingAllPairs,
                                        pairCount: cards.count,
                                        onOpenTiers: cards.isEmpty ? nil : { showTiers = true }
                                    )
                                }
                                .frame(width: split.leading)

                                VStack(alignment: .leading, spacing: 18) {
                                    WeeklyRhythmCard(summary: currentSummary, rarity: currentRarity, showingAllPairs: showingAllPairs)
                                    wrappedEntry
                                }
                                .frame(width: split.trailing)
                            }
                            if !isSampleData {
                                ringsFooterNote(summary: currentSummary)
                            }
                        }
                        .padding(.horizontal, split.padding)
                    } else {
                        VStack(alignment: .leading, spacing: 18) {
                            healthStatus
                            RingsHeroCard(summary: currentSummary, rarity: currentRarity)
                            WeeklyRhythmCard(summary: currentSummary, rarity: currentRarity, showingAllPairs: showingAllPairs)
                            AllTimeArchiveCard(
                                summary: currentSummary,
                                rarity: currentRarity,
                                isAccessibilitySize: dynamicTypeSize.isAccessibilitySize,
                                showingAllPairs: showingAllPairs,
                                pairCount: cards.count,
                                onOpenTiers: cards.isEmpty ? nil : { showTiers = true }
                            )
                            wrappedEntry
                            if !isSampleData {
                                ringsFooterNote(summary: currentSummary)
                            }
                        }
                        .padding(.horizontal, 18)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, isEmptyState ? 10 : 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.automatic)
            .pauseMotionWhileScrolling("rings")
            .onScrollGeometryChange(for: Bool.self) { geo in
                (geo.contentOffset.y + geo.contentInsets.top) > 12
            } action: { _, scrolled in
                if isScrolled != scrolled {
                    isScrolled = scrolled
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if !isEmptyState {
                    header(card: currentCard, summary: currentSummary, rarity: currentRarity, color: currentColor, isWorn: isWorn, isRetired: isRetired)
                        .padding(.horizontal, headerHorizontalPadding)
                        .padding(.top, 10)
                        .padding(.bottom, 10)
                        .background {
                            Group {
                                if reduceTransparency {
                                    Rectangle().fill(Theme.canvas)
                                } else {
                                    Rectangle()
                                        .fill(.ultraThinMaterial)
                                        .overlay(Theme.canvas.opacity(colorScheme == .light ? 0.72 : 0.82))
                                }
                            }
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Theme.hairline).frame(height: 1)
                            }
                            .ignoresSafeArea(edges: .top)
                            .opacity(isScrolled ? 1 : 0)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isScrolled)
                            .allowsHitTesting(false)
                        }
                }
            }
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
        .sheet(isPresented: $showTiers) {
            CardTiersView(ownedCards: cards, showsDoneButton: true)
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
        let cardForArt = summary.topCard ?? selectedCard ?? primaryCard ?? cards.first
        let color = cardForArt.flatMap { c in
            colorStore?.selectedColor(for: c) ?? DeviceColorOption.defaultOption(for: c.modelKey)
        }
        let yearText = summary.year.formatted(.number.grouping(.never))

        let tileRarity = cardForArt?.rarity ?? Rarity(minutes: summary.totalMinutes)
        let accent = DossierContrast.accentColor(rarity: tileRarity, proFoil: nil, colorScheme: colorScheme)

        let artworkBadge = ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    colorScheme == .light
                        ? AnyShapeStyle(LinearGradient(
                            colors: [Theme.artworkWellLightTop, Theme.artworkWellLightBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        : AnyShapeStyle(LinearGradient(
                            colors: [
                                Color(red: 0.055, green: 0.062, blue: 0.088),
                                Color(red: 0.085, green: 0.095, blue: 0.132)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                )
                .overlay {
                    LinearGradient(
                        colors: [tileRarity.glow.opacity(colorScheme == .light ? 0.24 : 0.18), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(colorScheme == .light ? Color.black.opacity(0.12) : Color.white.opacity(0.14), lineWidth: 0.75)
                )
            if let cardForArt {
                WrappedHeroArtwork(
                    card: cardForArt,
                    colorOption: color,
                    fallbackSymbol: summary.topDeviceSymbol
                )
                .frame(width: 34, height: 34)
                .shadow(color: colorScheme == .light ? .black.opacity(0.16) : .clear, radius: 2, y: 1)
            } else {
                Image(systemName: summary.topDeviceSymbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
            }
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)

        let titleBlock = VStack(alignment: .leading, spacing: 3) {
            Text("\(yearText) Earprint Wrapped")
                .font(.headline.weight(.bold))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.85)
            if summary.isThinData {
                Text("Your year in review")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.85)
            } else {
                Text("Replay your listening story")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.85)
            }
        }

        let chevronIcon = Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(accent)
            .accessibilityHidden(true)

        return Button {
            showWrapped = true
        } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            artworkBadge
                            Spacer(minLength: 8)
                            chevronIcon
                        }
                        titleBlock
                    }
                } else {
                    HStack(spacing: 14) {
                        artworkBadge
                        titleBlock
                        Spacer(minLength: 4)
                        chevronIcon
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ringsPanel(cornerRadius: 22)
        }
        .buttonStyle(RingsControlPressStyle())
        .accessibilityElement(children: .combine)
    }

    private func ringsFooterNote(summary: ListeningSummary) -> some View {
        let synced = lastSynced ?? summary.periodEndDate
        let reference = summary.periodEndDate ?? Date()
        let footerCopy: String
        if let synced {
            let sameYear = Calendar.current.component(.year, from: synced) == Calendar.current.component(.year, from: reference)
            let template = sameYear ? "MMM d" : "MMM d, yyyy"
            let dateStr = DateText.formatTemplate(synced, template: template, calendar: .current, locale: AppLanguage.current.locale)
            footerCopy = AppLanguage.current.text("Computed locally from Apple Health · Updated %@", dateStr)
        } else {
            footerCopy = AppLanguage.current.text("Computed locally from Apple Health")
        }
        return Text("\(Image(systemName: "lock.shield.fill")) \(footerCopy)")
            .font(.footnote)
            .foregroundStyle(Theme.secondaryText)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.88)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
            .accessibilityLabel(Text(verbatim: footerCopy))
    }

    // MARK: - Backdrop

    private func backdrop(rarity: Rarity) -> some View {
        let isLight = colorScheme == .light
        return ZStack {
            Theme.canvas.ignoresSafeArea()
            RadialGradient(
                colors: [rarity.glow.opacity(isLight ? 0.09 : 0.12), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 380
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Header & Compact Pair Control

    private func header(
        card: HeadphoneCard?,
        summary: ListeningSummary,
        rarity: Rarity,
        color: DeviceColorOption?,
        isWorn: Bool,
        isRetired: Bool = false
    ) -> some View {
        let pickerTitle: String = if let card {
            isSampleData ? card.model : card.nickname
        } else {
            AppLanguage.current.text("All Headphones")
        }
        let pickerMeta: String = if card != nil {
            AppLanguage.current.text(rarity.shortName)
        } else {
            AppLanguage.current.text("%lld pairs", cards.count)
        }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text("Rings")
                    .font(.title.weight(.bold))
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 8)

                Button { showShare = true } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.primaryText)
                        .frame(width: 40, height: 40)
                        .background(Theme.card, in: Circle())
                        .overlay(Circle().strokeBorder(Theme.controlStroke, lineWidth: colorScheme == .light ? 1.0 : 0.75))
                        .shadow(color: colorScheme == .light ? Theme.cardShadow.opacity(0.75) : .clear, radius: 6, y: 2)
                        .frame(width: 44, height: 44, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(RingsControlPressStyle())
                .accessibilityLabel("Share my Earprint")
            }

            if cards.count > 1 {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showPairPicker = true
                } label: {
                    pairPickerLabel(
                        card: card,
                        color: color,
                        symbol: summary.deviceSymbol,
                        title: pickerTitle,
                        meta: pickerMeta,
                        isWorn: isWorn,
                        isRetired: isRetired,
                        chevron: "chevron.up.chevron.down"
                    )
                }
                .buttonStyle(RingsControlPressStyle())
                .accessibilityHint("Switch between all headphones or a single pair")
            } else if let card {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    router?.pendingCardID = card.id
                    router?.tab = .collection
                } label: {
                    pairPickerLabel(
                        card: card,
                        color: color,
                        symbol: summary.deviceSymbol,
                        title: pickerTitle,
                        meta: pickerMeta,
                        isWorn: isWorn,
                        isRetired: isRetired,
                        chevron: "chevron.right"
                    )
                }
                .buttonStyle(RingsControlPressStyle())
                .accessibilityHint("View card in Collection")
            } else {
                pairPickerLabel(
                    card: nil,
                    color: nil,
                    symbol: summary.deviceSymbol,
                    title: pickerTitle,
                    meta: pickerMeta,
                    isWorn: isWorn,
                    isRetired: isRetired,
                    chevron: nil
                )
            }
        }
    }

    private func pairPickerLabel(
        card: HeadphoneCard?,
        color: DeviceColorOption?,
        symbol: String,
        title: String,
        meta: String,
        isWorn: Bool,
        isRetired: Bool,
        chevron: String?
    ) -> some View {
        HStack(spacing: 8) {
            if let card {
                ZStack {
                    if colorScheme == .light {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.artworkWellLightTop, Theme.artworkWellLightBottom],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)
                            .overlay(Circle().strokeBorder(Color.black.opacity(0.16), lineWidth: 0.75))
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 28, height: 28)
                            .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 0.75))
                    }
                    HeadphoneArtwork(card: card, colorOption: color, showsChargingCase: false, showsShadow: false)
                        .frame(width: 22, height: 22)
                        .shadow(color: colorScheme == .light ? .black.opacity(0.22) : .clear, radius: 2, y: 1)
                }
            } else {
                Image(systemName: "headphones")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
            }

            if isWorn {
                ActiveWearDot()
            } else if isRetired {
                Image(systemName: "archivebox.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
            }

            let pickerTextLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                : AnyLayout(HStackLayout(spacing: 5))

            pickerTextLayout {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.85)

                if !dynamicTypeSize.isAccessibilitySize {
                    Text("·")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.tertiaryText)
                        .accessibilityHidden(true)
                }

                Text(meta)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            if let chevron {
                Image(systemName: chevron)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(.leading, card != nil ? 7 : 12)
        .padding(.trailing, 13)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : 0)
        .frame(minHeight: 42)
        .background(Theme.card, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.controlStroke, lineWidth: colorScheme == .light ? 1.0 : 0.75))
        .shadow(color: colorScheme == .light ? Theme.cardShadow.opacity(0.75) : .clear, radius: 6, y: 2)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
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
                EarprintGlyph(grid: summary.grid, showHourLabels: false, forcedColorScheme: colorScheme)
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
                        .accessibilityHidden(true)
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
                    .buttonStyle(RingsControlPressStyle())

                    if statusMessage != nil, let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        Link(destination: settingsURL) {
                            Label("Open Settings", systemImage: "gearshape")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.secondaryText)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .ringsPanel(cornerRadius: 22)
    }
}

// MARK: - Rings Surface Modifier

private extension View {
    func ringsPanel(cornerRadius: CGFloat = 22, strokeColor: Color? = nil) -> some View {
        elevatedCard(cornerRadius: cornerRadius, strokeColor: strokeColor)
    }
}

private struct RingsControlPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1.0)
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.975 : 1.0))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Hero 28-Day Earprint Chronometer Card

private struct RingsHeroCard: View {
    let summary: ListeningSummary
    let rarity: Rarity

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var heroTotalSize: CGFloat = 40
    @ScaledMetric(relativeTo: .headline) private var selectedHourSize: CGFloat = 17
    @ScaledMetric(relativeTo: .title2) private var centerDBSize: CGFloat = 20
    @ScaledMetric(relativeTo: .caption) private var centerSubSize: CGFloat = 12
    @State private var selectedHour: Int? = nil

    var body: some View {
        let monthMinutes = summary.monthMinutes
        let monthDB = summary.monthDecibels
        let persona = summary.persona
        let dbColor = (monthMinutes > 0 && monthDB > 0)
            ? Theme.levelColor(db: monthDB, colorScheme: colorScheme)
            : Theme.secondaryText
        let cal = Calendar.current
        let rangeEnd = summary.periodEndDate ?? Date()
        let rangeStart = cal.date(byAdding: .day, value: -27, to: rangeEnd) ?? rangeEnd

        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                let heroHeaderLayout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))

                heroHeaderLayout {
                    Text("28-Day Earprint")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                        .accessibilityAddTraits(.isHeader)
                    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
                    Text(DateText.range(rangeStart, rangeEnd, calendar: cal))
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Text(monthMinutes.minutesText)
                    .font(.system(size: min(heroTotalSize, 50), weight: .heavy, design: .rounded))
                    .tracking(-0.8)
                    .monospacedDigit()
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.75)
                if summary.has28DayData {
                    HStack(spacing: 5) {
                        Image(systemName: persona.symbol)
                            .font(.caption.weight(.semibold))
                            .accessibilityHidden(true)
                        Text(verbatim: "\(AppLanguage.current.text(persona.title)) · \(persona.shortDetail)")
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.8)
                    .accessibilityElement(children: .combine)
                }
            }

            GeometryReader { geo in
                let dialSide = min(geo.size.width, geo.size.height)
                let innerWellWidth = EarprintDialMath.innerWellWidth(side: dialSide, showHourLabels: true, dayCount: summary.grid.days)
                ZStack {
                    EarprintGlyph(
                        grid: summary.grid,
                        showHourLabels: true,
                        highlightedHour: selectedHour,
                        forcedColorScheme: colorScheme,
                        dynamicTypeSize: dynamicTypeSize
                    )
                    .equatable()

                    VStack(spacing: 3) {
                        if let hour = selectedHour {
                            let hStats = EarprintDialMath.hourSummary(grid: summary.grid, hour: hour)
                            Text(String(format: "%02d:00", hour))
                                .font(.system(size: min(selectedHourSize, 21), weight: .heavy, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Theme.primaryText)
                                .lineLimit(1)
                                .contentTransition(reduceMotion ? .identity : .numericText())
                            Text("\(hStats.avgMinutesPerDay.minutesText) / day")
                                .font(.system(size: min(centerSubSize, 13.5), weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Theme.secondaryText)
                                .lineLimit(1)
                            if hStats.avgDB > 0 {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Theme.levelColor(db: hStats.avgDB, colorScheme: colorScheme))
                                        .frame(width: 6, height: 6)
                                    Text("\(Int(hStats.avgDB.rounded())) dB(A)")
                                        .font(.system(size: min(centerSubSize, 13.5), weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(Theme.primaryText)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                            }
                        } else if monthMinutes > 0 && monthDB > 0 {
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text("\(Int(monthDB.rounded()))")
                                    .font(.system(size: min(centerDBSize, 24), weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.primaryText)
                                    .contentTransition(reduceMotion ? .identity : .numericText())
                                Text("dB(A)")
                                    .font(.system(size: min(centerSubSize, 15), weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(dbColor)
                                    .frame(width: 6.5, height: 6.5)
                                    .accessibilityHidden(true)
                                Text("28-day avg")
                                    .font(.system(size: min(centerSubSize, 15), weight: .medium))
                                    .foregroundStyle(Theme.secondaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        } else {
                            Text("28 days")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Theme.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: innerWellWidth)
                }
                .contentShape(Circle())
                .onTapGesture { location in
                    selectedHour = EarprintDialMath.selectHour(
                        at: location,
                        size: dialSide,
                        current: selectedHour,
                        toggle: true,
                        dayCount: summary.grid.days
                    )
                }
                .gesture(
                    LongPressGesture(minimumDuration: 0.25)
                        .sequenced(before: DragGesture(minimumDistance: 0))
                        .onChanged { value in
                            if case .second(true, let drag?) = value {
                                selectedHour = EarprintDialMath.selectHour(
                                    at: drag.location,
                                    size: dialSide,
                                    current: selectedHour,
                                    toggle: false,
                                    dayCount: summary.grid.days
                                )
                            }
                        }
                )
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 268)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .sensoryFeedback(.selection, trigger: selectedHour)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("28-day Earprint dial, oldest ring inside to newest outside")
            .accessibilityValue(
                EarprintDialMath.accessibilityValue(
                    grid: summary.grid,
                    selectedHour: selectedHour,
                    totalMinutes: monthMinutes,
                    averageDB: monthDB,
                    formatMinutes: { $0.minutesText }
                )
            )
            .accessibilityHint("Swipe up or down to inspect hours")
            .accessibilityAdjustableAction { direction in
                selectedHour = EarprintDialMath.adjustedHour(current: selectedHour, direction: direction)
            }
            .dialClearAccessibilityAction(isActive: selectedHour != nil) {
                selectedHour = nil
            }

            VStack(spacing: 6) {
                LoudnessLegendRow(compact: false)

                let captionText: LocalizedStringKey = if let hour = selectedHour {
                    if monthDB > 0 {
                        "Comparing \(String(format: "%02d:00", hour)) vs \(Int(monthDB.rounded())) dB(A) avg · Tap center to clear"
                    } else {
                        "Tap center or hour to clear"
                    }
                } else {
                    "Tap or drag an hour"
                }
                Text(captionText)
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                    .minimumScaleFactor(0.88)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
        }
        .padding(18)
        .ringsPanel(cornerRadius: 22)
        .onChange(of: summary) { _, _ in
            selectedHour = nil
        }
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
    let showingAllPairs: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title2) private var metricSize: CGFloat = 24
    @ScaledMetric(relativeTo: .caption2) private var axisLabelSize: CGFloat = 11
    @State private var selectedDate: Date? = nil

    private struct DayPoint: Identifiable {
        let id: Int
        let date: Date
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
        let cal = Calendar.current
        let endDay = cal.startOfDay(for: summary.periodEndDate ?? Date())
        let labels = WeekdayLabelCache.labels(locale: AppLanguage.current.locale, count: count, now: summary.periodEndDate ?? Date())
        var result: [DayPoint] = []
        result.reserveCapacity(count)
        for offset in 0..<count {
            let item = metrics[offset]
            let date = cal.date(byAdding: .day, value: -((count - 1) - offset), to: endDay) ?? endDay
            result.append(DayPoint(
                id: offset,
                date: date,
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
        let cal = Calendar.current
        let selected = selectedDate.flatMap { sel in
            let day = cal.startOfDay(for: sel)
            return points.first { cal.isDate($0.date, inSameDayAs: day) }
        }
        let displayedMinutes = selected?.minutes ?? summary.weekMinutes
        let displayedDB = selected?.decibels ?? (summary.weekMinutes > 0 ? summary.weekDecibels : nil)
        let peakMinutes = points.map(\.minutes).max() ?? 0
        let peakID = peakMinutes > 0 ? points.last(where: { $0.minutes == peakMinutes })?.id : nil
        let maxH = max(peakMinutes / 60.0, 1.0)
        let yStep: Double = maxH <= 2 ? 1 : (maxH <= 5.5 ? 2 : ceil(maxH / 3))
        let yTicksMax = maxH <= 2 ? 2.0 : (maxH <= 5.2 ? 4.0 : ceil(maxH / yStep) * yStep)
        let yTop = max(yTicksMax * 1.18, maxH * 1.44)
        let yTicks = stride(from: 0.0, through: yTicksMax, by: yStep).map { $0 }
        let averageMinutes = summary.weekMinutes > 0 ? summary.weekMinutes / Double(max(1, points.count)) : 0
        let avgH = averageMinutes / 60.0
        let accent = DossierContrast.accentColor(rarity: rarity, proFoil: nil, colorScheme: colorScheme)
        let isLight = colorScheme == .light

        let used = max(0, summary.weeklyBudgetUsed)
        let displayPercent = Int((used * 100).rounded())
        let budgetTextTint = used >= 1 ? Theme.loudText : (used >= 0.5 ? Theme.moderateText : Theme.primaryText)
        let budgetClamped = min(used, 1)

        VStack(alignment: .leading, spacing: 14) {
            let weeklyHeaderLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))

            weeklyHeaderLayout {
                Text("Last 7 Days")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                    .accessibilityAddTraits(.isHeader)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
                Text(summary.periodLabel)
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    metricTime(minutes: displayedMinutes, selected: selected, isPeak: selected?.id == peakID, accent: accent)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    metricLevel(db: displayedDB, isSelectedDay: selected != nil, alignment: .trailing)
                        .fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 10) {
                    metricTime(minutes: displayedMinutes, selected: selected, isPeak: selected?.id == peakID, accent: accent)
                    metricLevel(db: displayedDB, isSelectedDay: selected != nil, alignment: .leading)
                }
            }

            let subheaderLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(spacing: 8))

            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)

            subheaderLayout {
                if selected != nil {
                    Text("Release to clear")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                        .accessibilityHidden(true)
                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer(minLength: 8)
                    }
                } else if averageMinutes > 0 {
                    Text("Daily hours · Drag to inspect")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer(minLength: 8)
                    }
                    HStack(spacing: 5) {
                        DashRuleGlyph(
                            width: 18,
                            color: isLight ? Color.black.opacity(0.45) : Color.white.opacity(0.46),
                            lineWidth: 1.25,
                            dash: [4, 3]
                        )
                        Text("Avg \(averageMinutes.minutesText) / day")
                            .font(.caption.weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(Theme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }

            Chart {
                if averageMinutes > 0 {
                    RuleMark(y: .value("Average", avgH))
                        .lineStyle(StrokeStyle(lineWidth: 1.25, dash: [4, 3]))
                        .foregroundStyle(isLight ? Color.black.opacity(0.48) : Color.white.opacity(0.55))
                        .zIndex(-0.5)
                }

                ForEach(points) { point in
                    let barColor = point.decibels.map { Theme.levelColor(db: $0, colorScheme: colorScheme) } ?? Theme.secondaryText
                    let isSelected = selected?.id == point.id
                    let isDimmed = selected != nil && !isSelected
                    let plottedH = point.minutes > 0 ? max(point.minutes / 60.0, yTop * 0.028) : 0

                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Hours", plottedH),
                        width: .ratio(0.62)
                    )
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 4,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 4
                        )
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [barColor, barColor.opacity(isLight ? 0.84 : 0.76)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(isDimmed ? 0.36 : 1.0)
                    .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        if isSelected, point.minutes > 0 {
                            let tipText = point.decibels.map { "\(point.minutes.minutesText) · \(Int($0.rounded())) dB(A)" } ?? point.minutes.minutesText
                            Text(tipText)
                                .font(.caption2.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.invertedText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .fixedSize()
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Theme.invertedFill, in: Capsule())
                                .accessibilityHidden(true)
                        } else if selected == nil, point.id == peakID {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(Theme.trophyGold)
                                .accessibilityHidden(true)
                        }
                    }
                }

                if let selected {
                    RuleMark(x: .value("Selected", selected.date, unit: .day))
                        .foregroundStyle(accent.opacity(0.12))
                        .lineStyle(StrokeStyle(lineWidth: 26))
                        .zIndex(-1)
                }
            }
            .chartYScale(domain: 0...yTop)
            .chartPlotStyle { $0.padding(.trailing, 6) }
            .chartXSelection(value: $selectedDate)
            .sensoryFeedback(.selection, trigger: selected?.id)
            .chartYAxis {
                AxisMarks(position: .trailing, values: yTicks) { value in
                    let h = value.as(Double.self) ?? 0
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.75))
                        .foregroundStyle(isLight ? Color.black.opacity(0.14) : Color.white.opacity(0.11))
                    AxisValueLabel {
                        Text("\(Int(h.rounded()))h")
                            .font(.system(size: min(axisLabelSize, 13.5), weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(centered: true) {
                        if let date = value.as(Date.self),
                           let point = points.first(where: { cal.isDate($0.date, inSameDayAs: date) }) {
                            let isSelected = selected?.id == point.id
                            Text(verbatim: point.shortWeekday)
                                .font(.system(size: min(axisLabelSize, 13.5), weight: (point.isToday || isSelected) ? .bold : .medium))
                                .foregroundStyle(
                                    isSelected ? accent : (point.isToday ? Theme.primaryText : Theme.secondaryText)
                                )
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .padding(.horizontal, isSelected ? 6 : 0)
                                .padding(.vertical, 2)
                                .background {
                                    if isSelected {
                                        Capsule().fill(accent.opacity(0.16))
                                    }
                                }
                        }
                    }
                }
            }
            .padding(.top, 4)
            .frame(height: dynamicTypeSize.isAccessibilitySize ? 168 : 126)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Daily listening, earliest to latest")
            .accessibilityValue(chartAccessibilityValue(selected: selected, totalMinutes: summary.weekMinutes, avgMinutes: averageMinutes))
            .accessibilityHint("Swipe up or down to inspect daily bars")
            .accessibilityAdjustableAction { direction in
                guard !points.isEmpty else { return }
                if let selected {
                    let next = selected.id + (direction == .increment ? 1 : -1)
                    selectedDate = points.indices.contains(next) ? points[next].date : nil
                } else {
                    selectedDate = (direction == .increment ? points.first : points.last)?.date
                }
            }
            .dialClearAccessibilityAction(isActive: selectedDate != nil) {
                selectedDate = nil
            }

            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 6) {
                let doseHeaderLayout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))

                doseHeaderLayout {
                    Text("7-day WHO dose · 40h @ 80 dB(A)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        .minimumScaleFactor(0.82)
                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer()
                    }
                    Text("\(displayPercent)% of limit")
                        .font(.footnote.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(budgetTextTint)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("7-day WHO safe-listening dose, \(displayPercent) percent of 40 hours per week at 80 decibels")

                if summary.weekMinutes > 0 {
                    let budgetBarTint = used >= 1 ? Theme.loudColor : (used >= 0.5 ? Theme.moderateColor : Theme.quietColor)
                    let trackFill = isLight ? Color.black.opacity(0.14) : Color.white.opacity(0.16)
                    GeometryReader { geo in
                        let w = max(0, geo.size.width)
                        let fillW = (w > 0 && used > 0) ? min(w, max(6.0, w * budgetClamped)) : 0
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(trackFill)
                                .overlay(Capsule().strokeBorder(trackFill, lineWidth: 0.75))
                            if fillW > 0 {
                                Capsule()
                                    .fill(budgetBarTint)
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
        }
        .padding(18)
        .ringsPanel(cornerRadius: 22)
        .onChange(of: summary) { _, _ in
            selectedDate = nil
        }
    }

    private func chartAccessibilityValue(selected: DayPoint?, totalMinutes: Double, avgMinutes: Double) -> Text {
        if let selected {
            if let db = selected.decibels, selected.minutes > 0 {
                return Text("\(selected.fullWeekday), \(selected.minutes.minutesText), \(Int(db.rounded())) decibels")
            }
            return Text("\(selected.fullWeekday), \(selected.minutes.minutesText)")
        }
        return Text("\(totalMinutes.minutesText) total, \(avgMinutes.minutesText) daily average")
    }

    private func metricTime(minutes: Double, selected: DayPoint?, isPeak: Bool = false, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(minutes.minutesText)
                .font(.system(size: min(metricSize, 30), weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .contentTransition(reduceMotion ? .identity : .numericText(value: minutes))
            Group {
                if let selected {
                    let dayTitle = selected.isToday ? AppLanguage.current.text("Today") : selected.fullWeekday
                    let label = isPeak ? "\(dayTitle) · \(AppLanguage.current.text("Peak"))" : dayTitle
                    Text(verbatim: label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                } else {
                    Text("7-day total")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .frame(minHeight: 20, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func metricLevel(db: Double?, isSelectedDay: Bool, alignment: HorizontalAlignment = .trailing) -> some View {
        let subtitle: LocalizedStringKey = isSelectedDay ? "Day avg" : "7-day avg"
        let subAlignment: Alignment = alignment == .trailing ? .trailing : .leading
        let roundedDB = db.map { Int($0.rounded()) }
        let zoneText = db.map { AppLanguage.current.text(Theme.levelZoneName(db: $0)) }
        let spokenTitle = AppLanguage.current.text(isSelectedDay ? "Day avg" : "7-day avg")
        return VStack(alignment: alignment, spacing: 3) {
            if let db, let roundedDB, let zoneText {
                let textTint = Theme.levelTextColor(db: db)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(roundedDB)")
                        .font(.system(size: min(max(20, metricSize - 5), 24), weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.primaryText)
                    Text("dB(A)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .contentTransition(reduceMotion ? .identity : .numericText(value: db))

                HStack(alignment: .center, spacing: 6) {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                    HStack(spacing: 3.5) {
                        Image(systemName: roundedDB < 66 ? "checkmark.shield.fill" : (roundedDB < 76 ? "speaker.wave.2.fill" : "exclamationmark.triangle.fill"))
                            .font(.caption2.weight(.bold))
                            .accessibilityHidden(true)
                        Text(verbatim: zoneText)
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(textTint)
                    .padding(.horizontal, 6.5)
                    .padding(.vertical, 2)
                    .background(textTint.opacity(colorScheme == .light ? 0.10 : 0.16), in: Capsule())
                    .overlay(Capsule().strokeBorder(textTint.opacity(0.28), lineWidth: 0.75))
                    .lineLimit(1)
                    .fixedSize()
                }
                .frame(minHeight: 20, alignment: subAlignment)
            } else {
                Text("—")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.secondaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .frame(minHeight: 20, alignment: subAlignment)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            (roundedDB != nil && zoneText != nil)
                ? Text(verbatim: "\(roundedDB!) \(AppLanguage.current.text("decibels")), \(spokenTitle), \(zoneText!)")
                : Text(verbatim: "—, \(spokenTitle)")
        )
    }
}

// MARK: - All-Time Archive Card

private struct AllTimeArchiveCard: View {
    let summary: ListeningSummary
    let rarity: Rarity
    let isAccessibilitySize: Bool
    var showingAllPairs: Bool = false
    var pairCount: Int = 1
    var onOpenTiers: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title3) private var archiveStatSize: CGFloat = 20

    private var formattedFirstUse: String {
        if let parsed = DateText.parse(summary.firstUse, dateFormat: "yyyy.MM.dd", calendar: .current) {
            return DateText.formatTemplate(parsed, template: "MMM d, yyyy", calendar: .current, locale: AppLanguage.current.locale)
        }
        return summary.firstUse
    }

    var body: some View {
        let hours = summary.lifetimeMinutes / 60
        let progress = rarity.progressToNextTier(minutes: summary.lifetimeMinutes)
        let accent = DossierContrast.accentColor(rarity: rarity, proFoil: nil, colorScheme: colorScheme)

        VStack(alignment: .leading, spacing: 14) {
            let archiveHeaderLayout = isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))

            archiveHeaderLayout {
                Text("All Time")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                    .accessibilityAddTraits(.isHeader)
                if !isAccessibilitySize { Spacer(minLength: 8) }
                if summary.firstUse != "—" {
                    Text("Since \(formattedFirstUse)")
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            if isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    metricCell("Total", summary.lifetimeMinutes.minutesText, isLeading: true)
                    Rectangle().fill(Theme.hairline).frame(height: 1)
                    metricCell("Wears", summary.sessions.formatted(), isLeading: true)
                }
            } else {
                HStack(spacing: 0) {
                    metricCell("Total", summary.lifetimeMinutes.minutesText, isLeading: true)
                    Rectangle().fill(Theme.hairline).frame(width: 1).padding(.vertical, 2)
                    metricCell("Wears", summary.sessions.formatted(), isLeading: false)
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                Rectangle().fill(Theme.hairline).frame(height: 1)

                if let onOpenTiers {
                    Button(action: onOpenTiers) {
                        tierSection(accent: accent, hours: hours, progress: progress, isInteractive: true)
                            .padding(.vertical, 2)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(RingsControlPressStyle())
                    .accessibilityHint("View all card tiers")
                } else {
                    tierSection(accent: accent, hours: hours, progress: progress, isInteractive: false)
                }
            }
        }
        .padding(.top, 18)
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
        .ringsPanel(cornerRadius: 22)
    }

    private func tierTitleView(accent: Color, stackTierHeader: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "seal.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accent)
                .accessibilityHidden(true)
            let tierName = AppLanguage.current.text(rarity.displayName)
            let tierLabel = showingAllPairs
                ? "\(AppLanguage.current.text("Collection")) · \(tierName)"
                : tierName
            Text(verbatim: tierLabel)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(accent)
                .lineLimit(stackTierHeader ? 2 : 1)
                .minimumScaleFactor(0.85)
        }
    }

    @ViewBuilder
    private func tierTargetView(accent: Color, hours: Double, progress: Double, stackTierHeader: Bool) -> some View {
        if let nextTier = rarity.nextTier {
            let displayedHours = min(Int(nextTier.minimumHours) - 1, Int(hours.rounded()))
            let remaining = max(1, Int(nextTier.minimumHours) - displayedHours)
            Text("\(remaining)h to \(AppLanguage.current.text(nextTier.shortName))")
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(stackTierHeader ? 2 : 1)
                .minimumScaleFactor(0.85)
        } else {
            Text("Max tier reached")
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)
                .lineLimit(isAccessibilitySize ? 2 : 1)
        }
    }

    private func tierSection(
        accent: Color,
        hours: Double,
        progress: Double,
        isInteractive: Bool
    ) -> some View {
        let stackTierHeader = dynamicTypeSize >= .xLarge
        let tierName = AppLanguage.current.text(rarity.displayName)
        let tierLabel = showingAllPairs
            ? "\(AppLanguage.current.text("Collection")) · \(tierName)"
            : tierName
        let tierPct = Int((progress * 100).rounded())
        let tierVO: String = if let nextTier = rarity.nextTier {
            AppLanguage.current.text(
                "%@, %lld percent, %lld hours to %@",
                tierLabel,
                tierPct,
                max(1, Int(nextTier.minimumHours) - min(Int(nextTier.minimumHours) - 1, Int(hours.rounded()))),
                AppLanguage.current.text(nextTier.shortName)
            )
        } else {
            AppLanguage.current.text("%@, max tier reached", tierLabel)
        }

        return HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                if stackTierHeader {
                    VStack(alignment: .leading, spacing: 4) {
                        tierTitleView(accent: accent, stackTierHeader: true)
                        tierTargetView(accent: accent, hours: hours, progress: progress, stackTierHeader: true)
                    }
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 0) {
                            tierTitleView(accent: accent, stackTierHeader: false)
                                .fixedSize(horizontal: true, vertical: false)
                            Spacer(minLength: 10)
                            tierTargetView(accent: accent, hours: hours, progress: progress, stackTierHeader: false)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            tierTitleView(accent: accent, stackTierHeader: false)
                            tierTargetView(accent: accent, hours: hours, progress: progress, stackTierHeader: false)
                        }
                    }
                }

                if rarity.nextTier != nil {
                    let trackFill = colorScheme == .light ? Color.black.opacity(0.14) : Color.white.opacity(0.16)
                    GeometryReader { geo in
                        let w = max(0, geo.size.width)
                        let barW = (w > 0 && progress > 0) ? min(w, max(6.0, w * progress)) : 0
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(trackFill)
                                .overlay(Capsule().strokeBorder(trackFill, lineWidth: 0.75))
                            if barW > 0 {
                                Capsule()
                                    .fill(accent)
                                    .frame(width: barW)
                            }
                        }
                        .clipShape(Capsule())
                        .frame(height: 6)
                    }
                    .frame(height: 6)
                    .accessibilityHidden(true)
                }
            }

            if isInteractive {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(accent)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: tierVO))
    }

    private func metricCell(_ title: LocalizedStringKey, _ value: String, isLeading: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: isAccessibilitySize ? archiveStatSize : min(archiveStatSize, 24), weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.leading, isLeading ? 0 : 12)
        .padding(.trailing, isLeading ? 12 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .headline) private var rowTitleSize: CGFloat = 15.5
    @ScaledMetric(relativeTo: .caption2) private var vaultHeaderSize: CGFloat = 10.5
    @ScaledMetric(relativeTo: .caption2) private var rarityPillSize: CGFloat = 11

    var body: some View {
        let isLight = colorScheme == .light
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Headphones")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .accessibilityAddTraits(.isHeader)
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
                .buttonStyle(RingsControlPressStyle())
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
                            : "\(item.sessions) wears · \(item.lifetimeMinutes.minutesText)"
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
                                .font(.system(size: min(vaultHeaderSize, 15), weight: .bold))
                                .accessibilityHidden(true)
                            Text("VAULT")
                                .font(.system(size: min(vaultHeaderSize, 15), weight: .heavy, design: .rounded))
                                .tracking(1.4)
                        }
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.top, 8)
                        .padding(.horizontal, 4)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isHeader)

                        ForEach(retiredCards) { item in
                            let title = isSampleData ? item.model : item.nickname
                            let subtitleKey: LocalizedStringKey = (!isSampleData && item.model != title)
                                ? "\(item.model) · \(item.lifetimeMinutes.minutesText)"
                                : "\(item.sessions) wears · \(item.lifetimeMinutes.minutesText)"
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
                .buttonStyle(RingsControlPressStyle())
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
        let isAX = dynamicTypeSize.isAccessibilitySize
        let clampedTitle = min(max(rowTitleSize, 14.5), 20)
        let rarityBadge = Text(LocalizedStringKey(rarity.shortName.uppercased()))
            .font(.system(size: min(rarityPillSize, 15), weight: .bold, design: .rounded))
            .tracking(0.5)
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(rarity.foil, in: Capsule())
            .overlay(
                Capsule().strokeBorder(.white.opacity(0.28), lineWidth: 0.75)
            )
            .fixedSize(horizontal: true, vertical: false)

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    if card != nil && isLight {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.artworkWellLightTop, Theme.artworkWellLightBottom],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay {
                                RadialGradient(
                                    colors: [rarity.glow.opacity(0.24), .clear],
                                    center: .topLeading,
                                    startRadius: 2,
                                    endRadius: 34
                                )
                                .clipShape(Circle())
                            }
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.black.opacity(0.16), lineWidth: 1.0)
                            )
                    } else {
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
                    }
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

                VStack(alignment: .leading, spacing: isAX ? 6 : 2.5) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: clampedTitle, weight: .bold, design: .rounded))
                            .lineLimit(isAX ? 2 : 1)
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
                        .lineLimit(isAX ? 2 : 1)
                        .truncationMode(.tail)
                    if isAX {
                        rarityBadge
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !isAX {
                    rarityBadge
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isLight && rarity == .silver ? Theme.primaryText : rarity.accent)
                        .accessibilityHidden(true)
                } else {
                    Circle()
                        .strokeBorder(Theme.hairline, lineWidth: 1.4)
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)
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
        .buttonStyle(RingsControlPressStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
