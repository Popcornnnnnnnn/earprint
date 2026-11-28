import SwiftUI

/// Caches generated sample dossiers so SwiftUI parent re-evaluations never regenerate sessions synchronously.
@MainActor
private enum DossierSampleCache {
    private struct Key: Hashable {
        let id: String
        let minutes: Int
        let sessions: Int
        let firstMet: String
        let lastUsed: String
        let isDemo: Bool
        let dayStart: TimeInterval
    }

    private static var entries: [Key: DeviceDossier] = [:]

    static func dossier(for card: HeadphoneCard, isDemo: Bool, referenceDate: Date) -> DeviceDossier {
        let key = Key(
            id: card.id,
            minutes: Int(card.lifetimeMinutes.rounded()),
            sessions: card.sessions,
            firstMet: card.firstMet,
            lastUsed: card.lastUsed,
            isDemo: isDemo,
            dayStart: Calendar.current.startOfDay(for: referenceDate).timeIntervalSince1970
        )
        if let cached = entries[key] { return cached }
        if entries.count > 12 { entries.removeAll(keepingCapacity: true) }
        let built = DeviceDossier.sample(for: card, now: referenceDate)
        entries[key] = built
        return built
    }
}

/// Top-level sections inside `DeviceDossierView`.
enum DossierTab: String, CaseIterable, Identifiable {
    case overview
    case activity
    case certificate

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .overview: "Overview"
        case .activity: "Activity"
        case .certificate: "Certificate"
        }
    }
}

/// Full-screen dossier for a single headphone: PSA-style grading slab, period airtime,
/// interactive trend & 24-hour charts, hearing health, milestones, and hardware certificate.
struct DeviceDossierView: View {
    let card: HeadphoneCard
    private var dossier: DeviceDossier { currentDossier }
    var onClose: (() -> Void)?
    private let dossierProvider: ((DeviceRetirement?) -> DeviceDossier?)?
    private let activeCardCount: Int
    private let librarySyncToken: Date?
    private let includesHealthDetails: Bool
    private let isSampleData: Bool
    private let isDemo: Bool
    private let referenceDate: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.locale) private var locale
    @Environment(DeviceColorStore.self) private var colorStore: DeviceColorStore?
    @Environment(DeviceLifecycleStore.self) private var lifecycleStore: DeviceLifecycleStore?

    @ScaledMetric(relativeTo: .title3) private var careerStatSize: CGFloat = 24
    @State private var currentDossier: DeviceDossier
    @State private var activeTab: DossierTab
    @State private var period: DossierPeriod
    @State private var selectedDate: Date?
    @State private var selectedHour: Int?
    @State private var slabFlipped = false
    @State private var demoTilt: CGSize = .zero
    @State private var isScrolled = false
    @State private var demoStarted = false
    @State private var showShare = false
    @State private var shareInitialFormat: DossierShareFormat = .simple
    @State private var showSlabStudio = false
    @State private var showRetireSheet = false
    @State private var showFarewellBanner = false
    @State private var dismissedInactivityNudge = false
    @State private var showMonthlyBreakdown = false
    @State private var showTechnicalDetails = false
    @State private var viewportWidth: CGFloat = 393
    @Namespace private var tabNamespace

    private struct RefreshKey: Equatable {
        let cardID: String
        let aliasIDs: [String]
        let lifetimeMinutes: Double
        let sessions: Int
        let lastWearDate: Date?
        let librarySyncToken: Date?
        let retirement: DeviceRetirement?
    }

    init(
        card: HeadphoneCard,
        dossier: DeviceDossier? = nil,
        dossierProvider: ((DeviceRetirement?) -> DeviceDossier?)? = nil,
        activeCardCount: Int = 1,
        librarySyncToken: Date? = nil,
        isSampleData: Bool = false,
        initialTab: DossierTab = .overview,
        onClose: (() -> Void)? = nil
    ) {
        self.card = card
        self.dossierProvider = dossierProvider
        self.activeCardCount = activeCardCount
        self.librarySyncToken = librarySyncToken
        // Keep fixed referenceNow for deterministic demo launches; use current date for live cards.
        let args = ProcessInfo.processInfo.arguments
        let isDemo = args.contains("-dossier") || args.contains("-dossierDemo") || args.contains("-demo")
        let referenceDate = isDemo ? DossierSample.referenceNow : max(DossierSample.referenceNow, Date())
        let resolved = dossier ?? DossierSampleCache.dossier(for: card, isDemo: isDemo, referenceDate: referenceDate)
        self.isDemo = isDemo
        self.referenceDate = referenceDate
        _currentDossier = State(initialValue: resolved)
        var resolvedTab = initialTab
        if let i = args.firstIndex(of: "-dossierTab"), i + 1 < args.count,
           let parsed = DossierTab(rawValue: args[i + 1]) {
            resolvedTab = parsed
        }
        _activeTab = State(initialValue: resolvedTab)
        _period = State(initialValue: resolved.isRetired ? .all : .month)
        includesHealthDetails = dossier != nil
        self.isSampleData = isSampleData
        self.onClose = onClose
    }

    private var stats: PeriodStats { dossier.stats(period) }
    private var rarity: Rarity { dossier.rarity }
    private var displayCard: HeadphoneCard { dossier.cardSnapshot(from: card) }
    private var tiltActive: Bool { !showShare && !showSlabStudio && !showRetireSheet }
    private var demoOverrideTilt: CGSize? { demoTilt == .zero ? nil : demoTilt }
    private var liveRetirement: DeviceRetirement? { lifecycleStore?.retirement(for: card) }
    private var liveFirstWear: Date? {
        dossier.liveFirstWearDate ?? dossier.firstWear ?? DateText.parse(card.firstMet, dateFormat: "yyyy.MM.dd", calendar: .current)
    }
    private var liveLastWearStart: Date? { card.lastWearStartDate ?? dossier.liveLastWearStartDate }
    private var liveLastWear: Date? { card.lastWearDate ?? dossier.liveLastWearDate }

    private var refreshKey: RefreshKey {
        RefreshKey(
            cardID: card.id,
            aliasIDs: card.aliasIDs,
            lifetimeMinutes: card.lifetimeMinutes,
            sessions: card.sessions,
            lastWearDate: card.lastWearDate,
            librarySyncToken: librarySyncToken,
            retirement: liveRetirement
        )
    }

    private func refreshDossier(for retirement: DeviceRetirement?) {
        let wasRetired = currentDossier.isRetired
        if let provided = dossierProvider?(retirement) {
            currentDossier = provided
        } else if !includesHealthDetails {
            currentDossier = DeviceDossier.sample(for: card, retirement: retirement, now: referenceDate)
        }
        if !wasRetired, retirement != nil {
            period = .all
        }
    }

    private var headerAccent: Color {
        DossierContrast.accentColor(rarity: rarity, proFoil: nil, colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            backdrop
            ScrollViewReader { proxy in
                ScrollView {
                    dossierContent
                        .padding(.top, 12)
                        .padding(.bottom, 48)
                }
                .scrollIndicators(.automatic)
                .pauseMotionWhileScrolling("dossier")
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                    if width > 0 { viewportWidth = width }
                }
                .onScrollGeometryChange(for: Bool.self) { geo in
                    (geo.contentOffset.y + geo.contentInsets.top) > 12
                } action: { _, scrolled in
                    if isScrolled != scrolled {
                        isScrolled = scrolled
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    topBar
                }
                .onChange(of: activeTab) { _, _ in
                    isScrolled = false
                    withAnimation(.none) {
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
                .task {
                    await handleLaunchArguments(proxy: proxy)
                }
            }
        }
        .foregroundStyle(DossierPalette.primaryText)
        .sheet(isPresented: $showShare) {
            DossierShareSheet(
                card: displayCard,
                dossier: dossier,
                period: period,
                color: colorStore?.selectedColor(for: card),
                isSampleData: isSampleData,
                initialFormat: shareInitialFormat
            )
        }
        .sheet(isPresented: $showSlabStudio) {
            CustomizeSlabSheet(card: displayCard, dossier: dossier)
        }
        .sheet(isPresented: $showRetireSheet) {
            let existing = lifecycleStore?.retirement(for: card) ?? dossier.retirement
            RetireDeviceSheet(
                card: card,
                firstWear: liveFirstWear,
                lastWear: liveLastWear,
                existingRetirement: existing,
                colorOption: colorStore?.selectedColor(for: card),
                onSave: { newRetirement in
                    let wasNew = existing == nil
                    lifecycleStore?.saveRetirement(newRetirement, for: card)
                    if wasNew {
                        showFarewellBanner = true
                    }
                },
                onUnretire: existing != nil ? {
                    showFarewellBanner = false
                    lifecycleStore?.unretire(card)
                } : nil
            )
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            if let store = lifecycleStore, store.retirement(for: card) != currentDossier.retirement {
                refreshDossier(for: store.retirement(for: card))
            } else if dossierProvider != nil {
                refreshDossier(for: liveRetirement ?? currentDossier.retirement)
            }
        }
        .onChange(of: refreshKey) { _, updated in
            refreshDossier(for: updated.retirement)
        }
        .onChange(of: period) {
            selectedDate = nil
            selectedHour = nil
        }
    }

    private var dossierContent: some View {
        VStack(spacing: 18) {
            Color.clear.frame(height: 0).id("top")
            dataSourceNote

            switch activeTab {
            case .overview:
                overviewContent
            case .activity:
                activityContent
            case .certificate:
                certificateContent
            }
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
    }

    private var overviewContent: some View {
        let unlocked = dossier.milestones.filter { !$0.isFuture }.count
        return VStack(spacing: 18) {
            lifecycleBanner
            slabStage
                .id("slab")
            careerSummaryCard
                .id("career")
            MilestoneTimelineCard(
                milestones: dossier.milestones,
                rarity: rarity,
                calendar: dossier.calendar,
                showsHeader: true,
                unlockedCount: unlocked,
                previewLimit: 4,
                referenceDate: dossier.now
            )
            .id("milestones")
        }
    }

    private var activityContent: some View {
        VStack(spacing: 18) {
            PeriodSwitcher(
                period: $period,
                rarity: rarity
            )
            ActivityListeningCard(
                stats: stats,
                rarity: rarity,
                firstWear: dossier.firstWear,
                selection: $selectedDate,
                rangeText: DateText.range(stats.start, stats.end, calendar: dossier.calendar, locale: AppLanguage.current.locale),
                chartHeight: 168,
                calendar: dossier.calendar
            )
            .dossierTile()
            .id("charts")
            HearingHealthCard(stats: stats)
                .dossierTile()
                .id("habits")
            timeOfDayCard
                .id("clock")
            SessionProfileCard(stats: stats, rarity: rarity, calendar: dossier.calendar)
                .dossierTile()
            if !dossier.careerRows.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    if period != .all {
                        HStack(spacing: 8) {
                            Text("All Time")
                                .font(.caption.weight(.bold))
                                .tracking(0.6)
                                .textCase(.uppercase)
                                .foregroundStyle(DossierPalette.dim)
                                .lineLimit(1)
                                .accessibilityAddTraits(.isHeader)
                            Rectangle()
                                .fill(DossierPalette.hairline)
                                .frame(height: 1)
                                .accessibilityHidden(true)
                        }
                        .padding(.top, 4)
                    }

                    MonthlyBreakdownCard(
                        dossier: dossier,
                        isExpanded: $showMonthlyBreakdown
                    )
                }
                .id("lifetime")
            }
        }
    }

    private var certificateContent: some View {
        VStack(spacing: 18) {
            CertificateLabel(
                card: displayCard,
                dossier: dossier,
                animateSeal: tiltActive && activeTab == .certificate,
                isInteractive: true,
                liveTiltActive: tiltActive && activeTab == .certificate,
                demoOverrideTilt: demoOverrideTilt
            )
            .id("certificate")

            GradeBreakdown(grade: dossier.grade, accent: rarity.accent, rarity: rarity, showsScoreHeader: true)
                .dossierTile()
                .id("grade")

            TechnicalDetailsCard(
                dossier: dossier,
                showsHealthProvenance: includesHealthDetails || isDemo,
                isExpanded: $showTechnicalDetails
            )

            if includesHealthDetails { footerNote }
        }
    }

    @ViewBuilder
    private var dataSourceNote: some View {
        #if DEBUG
        if !ProcessInfo.processInfo.arguments.contains("-hideSampleBanner") {
            rawDataSourceNote
        }
        #else
        rawDataSourceNote
        #endif
    }

    @ViewBuilder
    private var rawDataSourceNote: some View {
        if isSampleData {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.caption2.weight(.semibold))
                    .accessibilityHidden(true)
                Text("Sample data")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Theme.moderateText)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Theme.moderateColor.opacity(0.14), in: Capsule())
            .overlay(
                Capsule().strokeBorder(Theme.moderateColor.opacity(0.32), lineWidth: 0.75)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if !includesHealthDetails {
            Text("Dossier details are illustrative.")
                .font(.caption)
                .foregroundStyle(DossierPalette.dim)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Backdrop & Header

    private var backdrop: some View {
        let isLight = colorScheme == .light
        return ZStack {
            DossierPalette.ink.ignoresSafeArea()
            RadialGradient(
                colors: [headerAccent.opacity(isLight ? 0.04 : 0.06), .clear],
                center: UnitPoint(x: 0.5, y: 0.08),
                startRadius: 20,
                endRadius: 380
            )
            .ignoresSafeArea()
        }
    }

    private var topBar: some View {
        let tabSelectionAccent = headerAccent

        return VStack(spacing: 8) {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
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
                                .frame(width: 32, height: 32)
                                .overlay(Circle().strokeBorder(Color.black.opacity(0.16), lineWidth: 0.75))
                        } else {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 32, height: 32)
                                .overlay(Circle().strokeBorder(DossierPalette.hairline, lineWidth: 1))
                        }
                        if card.modelKey.collectionArtwork != nil {
                            HeadphoneArtwork(
                                card: card,
                                colorOption: colorStore?.selectedColor(for: card),
                                showsChargingCase: false,
                                showsShadow: false
                            )
                            .frame(width: 22, height: 22)
                            .shadow(color: colorScheme == .light ? .black.opacity(0.16) : .clear, radius: 1.5, y: 1)
                        } else {
                            Image(systemName: card.symbol)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DossierPalette.primaryText)
                        }
                    }
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(card.model)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(DossierPalette.primaryText)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                            .minimumScaleFactor(0.8)
                            .accessibilityAddTraits(.isHeader)
                        if dossier.retirement != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "archivebox.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                    .accessibilityHidden(true)
                                Text("Vaulted")
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(DossierPalette.dim)
                            .lineLimit(1)
                        } else {
                            Text("Active")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(DossierPalette.dim)
                                .lineLimit(1)
                        }
                    }
                }
                .accessibilityElement(children: .combine)

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Button {
                        showShare = true
                    } label: {
                        topBarIcon("square.and.arrow.up")
                    }
                    .buttonStyle(DossierIconPressStyle())
                    .accessibilityLabel("Share dossier")

                    Button {
                        if let onClose { onClose() } else { dismiss() }
                    } label: {
                        topBarIcon("xmark", alignment: .trailing)
                    }
                    .buttonStyle(DossierIconPressStyle())
                    .accessibilityLabel("Close dossier")
                }
            }

            let tabButtons = HStack(spacing: 0) {
                ForEach(DossierTab.allCases) { tab in
                    let isSelected = activeTab == tab
                    Button {
                        withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
                            activeTab = tab
                        }
                    } label: {
                        Text(tab.title)
                            .font(.subheadline.weight(isSelected ? .bold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(isSelected ? DossierPalette.primaryText : DossierPalette.dim)
                            .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 12 : 5)
                            .frame(minHeight: 44)
                            .overlay(alignment: .bottom) {
                                if isSelected {
                                    if reduceMotion {
                                        Capsule()
                                            .fill(tabSelectionAccent)
                                            .frame(height: 2.5)
                                    } else {
                                        Capsule()
                                            .fill(tabSelectionAccent)
                                            .frame(height: 2.5)
                                            .matchedGeometryEffect(id: "dossierTabUnderline", in: tabNamespace)
                                    }
                                }
                            }
                            .modifier(TabWidthModifier(isScrollableAX: dynamicTypeSize.isAccessibilitySize))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .sensoryFeedback(.selection, trigger: activeTab)

            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.horizontal, showsIndicators: false) {
                    tabButtons
                }
            } else {
                tabButtons
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 0)
        .background {
            Group {
                if reduceTransparency {
                    Rectangle().fill(DossierPalette.ink)
                } else {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(DossierPalette.ink.opacity(colorScheme == .light ? 0.72 : 0.68))
                }
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(DossierPalette.hairline)
                    .frame(height: 1)
                    .opacity(isScrolled ? 1 : 0.70)
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    private func topBarIcon(_ symbol: String, alignment: Alignment = .center) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(DossierPalette.primaryText)
            .frame(width: 40, height: 40)
            .background(Theme.card, in: Circle())
            .overlay(Circle().strokeBorder(Theme.controlStroke, lineWidth: colorScheme == .light ? 1.0 : 0.75))
            .shadow(color: colorScheme == .light ? Theme.cardShadow.opacity(0.65) : .clear, radius: 6, y: 2)
            .frame(width: 44, height: 44, alignment: alignment)
            .contentShape(Rectangle())
    }

    // MARK: - Hero Slab Stage

    private var slabStage: some View {
        let slabScale = min(1.0, max(0.85, (viewportWidth - 52) / SlabMetrics.width))
        return VStack(spacing: 16) {
            if dynamicTypeSize.isAccessibilitySize {
                let grade = dossier.grade
                let axScoreColor: Color = grade.hasRecentData
                    ? DossierContrast.accentColor(rarity: dossier.rarity, proFoil: nil, colorScheme: colorScheme)
                    : DossierPalette.dim
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(displayCard.model)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(DossierPalette.primaryText)
                            Text(verbatim: AppLanguage.current.text(dossier.rarity.displayName).uppercased())
                                .font(.caption.weight(.bold))
                                .tracking(0.4)
                                .foregroundStyle(headerAccent)
                        }
                        Spacer(minLength: 8)
                        Button {
                            withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
                                activeTab = .certificate
                            }
                        } label: {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("30D EAR GRADE")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(DossierPalette.dim)
                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                    Text(grade.scoreText)
                                        .font(.title3.weight(.heavy))
                                        .monospacedDigit()
                                        .foregroundStyle(axScoreColor)
                                    if grade.hasRecentData {
                                        Text(verbatim: "/10")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(DossierPalette.dim)
                                    }
                                }
                                Text(LocalizedStringKey(grade.label))
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(axScoreColor)
                            }
                            .frame(minHeight: 44, alignment: .trailing)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Rectangle()
                        .fill(DossierPalette.hairline)
                        .frame(height: 1)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayCard.lifetimeMinutes.minutesText)
                            .font(.title2.weight(.heavy))
                            .monospacedDigit()
                            .foregroundStyle(DossierPalette.primaryText)
                        Text("\(displayCard.sessions) wears")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(DossierPalette.dim)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .dossierTile()
            }

            LiveTiltView(
                isActive: tiltActive && activeTab == .overview,
                overrideTilt: demoOverrideTilt
            ) { slabTilt in
                GradingSlab(
                    card: displayCard,
                    dossier: dossier,
                    tilt: slabTilt,
                    flipped: slabFlipped,
                    animateSeal: tiltActive && activeTab == .overview,
                    onInspectGrade: {
                        withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
                            activeTab = .certificate
                        }
                    }
                )
                    .rotation3DEffect(.degrees(reduceMotion ? 0 : Double(slabTilt.width) * 10), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                    .rotation3DEffect(.degrees(reduceMotion ? 0 : Double(-slabTilt.height) * 8), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            }
            .frame(width: SlabMetrics.width, height: SlabMetrics.height)
            .scaleEffect(slabScale)
            .frame(width: SlabMetrics.width * slabScale, height: SlabMetrics.height * slabScale)
            .onTapGesture {
                withAnimation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.78)) {
                    slabFlipped.toggle()
                }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(slabFlipped ? "Double-tap to show front, or use actions to inspect Ear Grade" : "Double-tap to flip slab, or use actions to inspect Ear Grade")
            .accessibilityAction(named: Text("Flip slab")) {
                withAnimation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.78)) {
                    slabFlipped.toggle()
                }
            }
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.75), trigger: slabFlipped)

            let stackActions = lifecycleStore != nil
                ? dynamicTypeSize >= .xLarge
                : dynamicTypeSize >= .xxLarge
            let actionLayout = stackActions
                ? AnyLayout(VStackLayout(spacing: 10))
                : AnyLayout(HStackLayout(spacing: 8))

            actionLayout {
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.78)) {
                        slabFlipped.toggle()
                    }
                } label: {
                    Label(slabFlipped ? "Show Front" : "Flip", systemImage: "rectangle.2.swap")
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(DossierPalette.primaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .frame(maxWidth: stackActions ? .infinity : nil, minHeight: 44)
                        .background(Theme.card, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.controlStroke, lineWidth: 1))
                        .shadow(color: Theme.cardShadow, radius: 6, y: 2)
                }
                .buttonStyle(DossierIconPressStyle())

                Button {
                    showSlabStudio = true
                } label: {
                    Label("Customize", systemImage: "slider.horizontal.3")
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(DossierPalette.primaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .frame(maxWidth: stackActions ? .infinity : nil, minHeight: 44)
                        .background(Theme.card, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.controlStroke, lineWidth: 1))
                        .shadow(color: Theme.cardShadow, radius: 6, y: 2)
                }
                .buttonStyle(DossierIconPressStyle())

                if lifecycleStore != nil {
                    Button {
                        showRetireSheet = true
                    } label: {
                        Label(
                            dossier.isRetired ? "Vaulted" : "Vault",
                            systemImage: dossier.isRetired ? "archivebox.fill" : "archivebox"
                        )
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(dossier.isRetired ? headerAccent : DossierPalette.primaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .frame(maxWidth: stackActions ? .infinity : nil, minHeight: 44)
                        .background(Theme.card, in: Capsule())
                        .overlay(
                            Capsule().strokeBorder(
                                dossier.isRetired ? headerAccent.opacity(0.60) : Theme.controlStroke,
                                lineWidth: 1
                            )
                        )
                        .shadow(color: Theme.cardShadow, radius: 6, y: 2)
                    }
                    .buttonStyle(DossierIconPressStyle())
                }
            }
        }
    }

    @ViewBuilder
    private var lifecycleBanner: some View {
        let bannerActionLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))

        if let store = lifecycleStore,
           store.hasUnacknowledgedPostRetirementActivity(for: card, lastWearEnd: liveLastWear, lastWearStart: liveLastWearStart),
           let lastWear = liveLastWear {
            let acknowledgedTimestamp = max(lastWear, liveLastWearStart ?? lastWear)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.badge.exclamationmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(rarity.accent)
                    Text("Back from retirement?")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                }
                Text("New listening was recorded on \(DateText.dotted(lastWear, calendar: .current)). Restore this pair to Active or keep it in the Vault?")
                    .font(.caption)
                    .foregroundStyle(DossierPalette.dim)
                bannerActionLayout {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        store.unretire(card)
                    } label: {
                        Text("Restore to Active")
                            .font(.caption.weight(.bold))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, minHeight: 44)
                            .foregroundStyle(Theme.invertedText)
                            .background(Theme.invertedFill, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.acknowledgePostRetirementActivity(for: card, activityDate: acknowledgedTimestamp)
                    } label: {
                        Text("Keep Vaulted")
                            .font(.caption.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, minHeight: 44)
                            .foregroundStyle(DossierPalette.primaryText)
                            .background(DossierPalette.surfaceFill, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(DossierPalette.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(rarity.accent.opacity(0.45), lineWidth: 1))
        } else if showFarewellBanner, dossier.isRetired {
            let farewellLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(spacing: 12))
            farewellLayout {
                HStack(spacing: 12) {
                    Image(systemName: "archivebox.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(rarity.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sealed in Vault")
                            .font(.subheadline.weight(.bold))
                        Text("Export a Hall of Fame farewell poster.")
                            .font(.caption)
                            .foregroundStyle(DossierPalette.dim)
                    }
                }
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 4)
                }
                Button {
                    shareInitialFormat = .simple
                    showShare = true
                } label: {
                    Text("Share Farewell Poster")
                        .font(.caption.weight(.bold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, minHeight: 44)
                        .foregroundStyle(Theme.invertedText)
                        .background(Theme.invertedFill, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(DossierPalette.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(rarity.accent.opacity(0.45), lineWidth: 1))
        } else if !dossier.isRetired,
                  !dismissedInactivityNudge,
                  lifecycleStore?.shouldSuggestRetirement(
                      for: card,
                      lastWear: liveLastWear,
                      totalActiveCardCount: activeCardCount,
                      now: dossier.now,
                      calendar: dossier.calendar
                  ) == true {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "archivebox")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DossierPalette.dim)
                            .accessibilityHidden(true)
                        Text("Unused for 90+ days · Retire to Vault?")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(DossierPalette.primaryText.opacity(0.86))
                            .lineLimit(3)
                    }
                    HStack(spacing: 8) {
                        Button("Retire") {
                            showRetireSheet = true
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(rarity.accent)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                        Spacer(minLength: 4)
                        Button {
                            withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
                                dismissedInactivityNudge = true
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(DossierPalette.faint)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dismiss")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(DossierPalette.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(DossierPalette.hairline, lineWidth: 1))
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "archivebox")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DossierPalette.dim)
                        .accessibilityHidden(true)
                    Text("Unused for 90+ days · Retire to Vault?")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DossierPalette.primaryText.opacity(0.86))
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    Button("Retire") {
                        showRetireSheet = true
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(rarity.accent)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    Button {
                        withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
                            dismissedInactivityNudge = true
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(DossierPalette.faint)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss")
                }
                .padding(.leading, 12)
                .padding(.trailing, 4)
                .padding(.vertical, 2)
                .background(DossierPalette.panel, in: Capsule())
                .overlay(Capsule().strokeBorder(DossierPalette.hairline, lineWidth: 1))
            }
        }
    }

    private var careerSummaryCard: some View {
        let allStats = dossier.stats(.all)
        let wearsPerDayText = allStats.sessionsPerDay >= 10
            ? "\(Int(allStats.sessionsPerDay.rounded()))"
            : String(format: "%.1f", allStats.sessionsPerDay)
        let isAX = dynamicTypeSize.isAccessibilitySize
        let careerHeaderLayout = isAX
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))

        return VStack(alignment: .leading, spacing: 14) {
            careerHeaderLayout {
                Text("Lifetime")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(DossierPalette.primaryText)
                    .accessibilityAddTraits(.isHeader)
                if !isAX { Spacer(minLength: 8) }
                Group {
                    if let retirement = dossier.retirement {
                        Text("Retired \(retirement.formattedRetiredDate)")
                    } else if let lastWear = dossier.lastWear {
                        Text("Last worn \(lastWear.start.dossierRelative(to: dossier.now, calendar: dossier.calendar))")
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(DossierPalette.dim)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }

            let avgDayLabel: LocalizedStringKey = dossier.recordDays == allStats.spanDays ? "Avg / day" : "Avg / calendar day"
            if isAX {
                VStack(alignment: .leading, spacing: 10) {
                    careerCell("Active days", "\(dossier.recordDays)", isLeading: true)
                    Rectangle().fill(DossierPalette.hairline).frame(height: 1)
                    careerCell(avgDayLabel, allStats.dailyAverage.minutesText, isLeading: true)
                    Rectangle().fill(DossierPalette.hairline).frame(height: 1)
                    careerCell("Wears / day", wearsPerDayText, isLeading: true)
                    Rectangle().fill(DossierPalette.hairline).frame(height: 1)
                    if allStats.share > 0 && allStats.share < 0.995 {
                        careerCell("Share of all listening", "\(Int((allStats.share * 100).rounded()))%", isLeading: true)
                    } else {
                        careerCell("Avg / wear", allStats.sessionCount > 0 ? allStats.averagePerWear.minutesText : "—", isLeading: true)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    HStack(spacing: 0) {
                        careerCell("Active days", "\(dossier.recordDays)", isLeading: true)
                        careerCell(avgDayLabel, allStats.dailyAverage.minutesText, isLeading: false)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    Rectangle().fill(DossierPalette.hairline).frame(height: 1)
                    HStack(spacing: 0) {
                        careerCell("Wears / day", wearsPerDayText, isLeading: true)
                        if allStats.share > 0 && allStats.share < 0.995 {
                            careerCell("Share of all listening", "\(Int((allStats.share * 100).rounded()))%", isLeading: false)
                        } else {
                            careerCell("Avg / wear", allStats.sessionCount > 0 ? allStats.averagePerWear.minutesText : "—", isLeading: false)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .overlay(alignment: .center) {
                    Rectangle()
                        .fill(DossierPalette.hairline)
                        .frame(width: 1)
                }
            }

            if let retirement = dossier.retirement, !retirement.farewellNote.isEmpty {
                Rectangle().fill(DossierPalette.hairline).frame(height: 1)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: retirement.reason.symbol)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(headerAccent)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("“\(retirement.farewellNote)”")
                            .font(.footnote.italic())
                            .foregroundStyle(DossierPalette.primaryText.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(LocalizedStringKey(retirement.reason.title))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(DossierPalette.dim)
                    }
                }
            }
        }
        .dossierTile()
    }

    private func careerCell(
        _ title: LocalizedStringKey,
        _ value: String,
        unit: String? = nil,
        valueColor: Color = DossierPalette.primaryText,
        dotColor: Color? = nil,
        isLeading: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                if let dotColor {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 6.5, height: 6.5)
                }
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: dynamicTypeSize.isAccessibilitySize ? careerStatSize : min(careerStatSize, 26), weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(valueColor)
                    if let unit {
                        Text(unit)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(DossierPalette.dim)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(DossierPalette.dim)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.leading, dynamicTypeSize.isAccessibilitySize ? 0 : (isLeading ? 0 : 12))
        .padding(.trailing, dynamicTypeSize.isAccessibilitySize ? 0 : (isLeading ? 12 : 0))
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var timeOfDayCard: some View {
        let lateNightMinutes = stats.hours
            .filter { $0.hour >= 22 || $0.hour <= 3 }
            .reduce(0.0) { $0 + $1.minutes }
        let periodNightShare = stats.totalMinutes > 0 ? lateNightMinutes / stats.totalMinutes : 0
        let nightPct = Int((periodNightShare * 100).rounded())
        let nightIconColor: Color = nightPct > 25
            ? Theme.moderateText
            : (colorScheme == .light ? Color(red: 0.22, green: 0.28, blue: 0.54) : Color(red: 0.58, green: 0.66, blue: 0.94))

        let headerLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))

        return VStack(alignment: .leading, spacing: 14) {
            headerLayout {
                Text("Time of Day")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(DossierPalette.primaryText)
                    .accessibilityAddTraits(.isHeader)
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                HStack(spacing: 5) {
                    Image(systemName: "moon.stars.fill")
                        .foregroundStyle(nightIconColor)
                        .accessibilityHidden(true)
                    Text("\(nightPct)% late (22:00–04:00)")
                        .foregroundStyle(nightPct > 25 ? Theme.moderateText : DossierPalette.dim)
                }
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(DossierPalette.surfaceFill, in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(DossierPalette.hairline, lineWidth: 0.75)
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(nightPct) percent late night, 22:00 to 04:00")
            }

            DayClock(stats: stats, rarity: rarity, selectedHour: $selectedHour)
                .frame(maxWidth: 248)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)

            let peakRaw = stats.peakHour?.minutes ?? 0
            let peakDisp = stats.spanDays > 1 ? peakRaw / Double(stats.spanDays) : peakRaw
            let captionText: String = if let h = selectedHour, stats.hours[h].minutes > 0, stats.hours[h].averageDecibels > 0 {
                "\(DossierFormat.hourLabel(h)) · \(Int(stats.hours[h].averageDecibels.rounded())) dB(A) · \(AppLanguage.current.text("Tap center to clear"))"
            } else if selectedHour != nil {
                AppLanguage.current.text("Tap center or hour to clear")
            } else if peakDisp > 0 {
                AppLanguage.current.text("Bar = avg daily time · Tap or drag an hour")
            } else {
                AppLanguage.current.text("Relative to period peak")
            }
            Text(verbatim: captionText)
                .font(.caption)
                .foregroundStyle(DossierPalette.dim)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        }
        .dossierTile()
    }

    private var footerNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.shield.fill")
                .font(.footnote)
                .accessibilityHidden(true)
            Text("Computed locally from Apple Health")
                .font(.footnote)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(DossierPalette.dim)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Launch arguments (-dossierTab / -dossierScroll / -dossierDemo)

    private func handleLaunchArguments(proxy: ScrollViewProxy) async {
        let args = ProcessInfo.processInfo.arguments

        if let i = args.firstIndex(of: "-dossierPeriod"), i + 1 < args.count,
           let p = DossierPeriod(rawValue: args[i + 1]) {
            period = p
        }

        if let i = args.firstIndex(of: "-dossierTab"), i + 1 < args.count,
           let tab = DossierTab(rawValue: args[i + 1]) {
            activeTab = tab
        }

        if let i = args.firstIndex(of: "-dossierScroll"), i + 1 < args.count {
            let target = args[i + 1]
            switch target {
            case "airtime", "charts", "clock", "habits", "lifetime":
                activeTab = .activity
            case "certificate", "grade":
                activeTab = .certificate
            default:
                activeTab = .overview
            }
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.none) {
                proxy.scrollTo(target, anchor: .top)
            }
            return
        }

        #if DEBUG
        if args.contains("-customizeSlab"), !showSlabStudio {
            try? await Task.sleep(for: .milliseconds(550))
            showSlabStudio = true
            return
        }
        if args.contains("-dossierShareLong"), !showShare {
            try? await Task.sleep(for: .milliseconds(500))
            shareInitialFormat = .long
            showShare = true
            return
        }
        if args.contains("-dossierShare"), !showShare {
            try? await Task.sleep(for: .milliseconds(500))
            shareInitialFormat = .simple
            showShare = true
            return
        }
        #endif

        guard args.contains("-dossierDemo"), !demoStarted else { return }
        demoStarted = true
        await runDemoSequence(proxy: proxy)
    }

    private func runDemoSequence(proxy: ScrollViewProxy) async {
        // 1. Subtle tilt shimmer on the acrylic grading slab in Overview.
        activeTab = .overview
        try? await Task.sleep(for: .milliseconds(450))
        for step in 0..<36 {
            let t = Double(step) / 35
            demoTilt = CGSize(width: sin(t * .pi * 2) * 0.85, height: sin(t * .pi * 2) * 0.25)
            try? await Task.sleep(for: .milliseconds(25))
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { demoTilt = .zero }
        try? await Task.sleep(for: .milliseconds(250))

        // 2. Switch to Activity and cycle periods so ring + numeric transitions animate.
        withAnimation(.snappy(duration: 0.25)) {
            activeTab = .activity
        }
        try? await Task.sleep(for: .milliseconds(600))
        for nextPeriod in [DossierPeriod.week, .year, .all, .month] {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.8)) {
                period = nextPeriod
            }
            try? await Task.sleep(for: .milliseconds(800))
        }

        // 3. Scroll to the 30-day trend chart and scrub across active bars.
        withAnimation(.easeInOut(duration: 0.6)) {
            proxy.scrollTo("charts", anchor: .top)
        }
        try? await Task.sleep(for: .milliseconds(700))
        let scrubBuckets = stats.buckets.filter { $0.minutes > 0 }
        let stepCount = min(8, scrubBuckets.count)
        if stepCount > 0 {
            let strideVal = max(1, scrubBuckets.count / stepCount)
            for idx in stride(from: 0, to: scrubBuckets.count, by: strideVal).prefix(stepCount) {
                selectedDate = scrubBuckets[idx].start
                try? await Task.sleep(for: .milliseconds(280))
            }
        }
        selectedDate = nil
        try? await Task.sleep(for: .milliseconds(400))

        // 4. Switch to Certificate tab to conclude.
        withAnimation(.snappy(duration: 0.3)) {
            activeTab = .certificate
        }
        try? await Task.sleep(for: .milliseconds(900))
    }
}

private struct DossierDisclosurePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

// MARK: - Monthly Breakdown

private struct MonthlyBreakdownCard: View {
    let dossier: DeviceDossier
    @Binding var isExpanded: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    let headerTextLayout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                        : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))

                    headerTextLayout {
                        Text("Monthly Breakdown")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(DossierPalette.primaryText)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                            .minimumScaleFactor(0.82)
                            .accessibilityAddTraits(.isHeader)
                        if !dynamicTypeSize.isAccessibilitySize {
                            Spacer(minLength: 8)
                        }
                        Text("\(dossier.careerRows.count) months")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(DossierPalette.dim)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                            .layoutPriority(1)
                    }
                    if dynamicTypeSize.isAccessibilitySize {
                        Spacer(minLength: 8)
                    }
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DossierPalette.dim)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(DossierDisclosurePressStyle())
            .sensoryFeedback(.selection, trigger: isExpanded)
            .accessibilityValue(isExpanded ? Text("Expanded") : Text("Collapsed"))
            .accessibilityHint("Double-tap to toggle")

            if isExpanded {
                VStack(spacing: 10) {
                    Rectangle().fill(DossierPalette.hairline).frame(height: 1)

                    if dynamicTypeSize >= .xxLarge {
                        ForEach(Array(dossier.careerRows.enumerated()), id: \.element.id) { index, row in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(row.label)
                                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                                        .foregroundStyle(DossierPalette.primaryText.opacity(0.9))
                                    Spacer()
                                    Text(row.minutes.minutesText)
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .monospacedDigit()
                                }
                                HStack(spacing: 8) {
                                    Text("\(row.sessions) wears · max \(row.longest.minutesText)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(DossierPalette.dim)
                                    Spacer()
                                    Text("\(Int(row.averageDecibels.rounded())) dB(A)")
                                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                                        .foregroundStyle(Theme.levelTextColor(db: row.averageDecibels))
                                }
                            }
                            .accessibilityElement(children: .combine)
                            if index < dossier.careerRows.count - 1 {
                                Rectangle().fill(DossierPalette.hairline).frame(height: 1)
                            }
                        }
                    } else {
                        Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 8) {
                            GridRow {
                                Text("Month")
                                    .gridColumnAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("Time")
                                Text("Wears")
                                Text("Max")
                                Text("Avg")
                            }
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .foregroundStyle(DossierPalette.dim)
                            .accessibilityHidden(true)

                            ForEach(dossier.careerRows) { row in
                                GridRow {
                                    Text(row.label)
                                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                                        .foregroundStyle(DossierPalette.primaryText.opacity(0.9))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(row.minutes.minutesText)
                                        .font(.system(.caption, design: .rounded, weight: .bold))
                                        .monospacedDigit()
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    Text("\(row.sessions)")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(DossierPalette.dim)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    Text(row.longest.minutesText)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(DossierPalette.dim)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    Text("\(Int(row.averageDecibels.rounded())) dB(A)")
                                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                                        .foregroundStyle(Theme.levelTextColor(db: row.averageDecibels))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("\(row.label), \(row.minutes.minutesText), \(row.sessions) wears, longest \(row.longest.minutesText), \(Int(row.averageDecibels.rounded())) decibels")
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
        .dossierTile(padding: 0)
    }
}

// MARK: - Technical Details Card

private struct TechnicalDetailsCard: View {
    let dossier: DeviceDossier
    let showsHealthProvenance: Bool
    @Binding var isExpanded: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let hw = dossier.hardware
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    let headerTextLayout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                        : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))

                    headerTextLayout {
                        Text("Technical Details")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(DossierPalette.primaryText)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                            .minimumScaleFactor(0.85)
                            .layoutPriority(1)
                            .accessibilityAddTraits(.isHeader)
                        if !dynamicTypeSize.isAccessibilitySize {
                            Spacer()
                        }
                        Text("Device & Bundle ID")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(DossierPalette.dim)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    }
                    if dynamicTypeSize.isAccessibilitySize {
                        Spacer(minLength: 8)
                    }
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DossierPalette.dim)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(DossierDisclosurePressStyle())
            .sensoryFeedback(.selection, trigger: isExpanded)
            .accessibilityValue(isExpanded ? Text("Expanded") : Text("Collapsed"))
            .accessibilityHint("Double-tap to toggle")

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Rectangle().fill(DossierPalette.hairline).frame(height: 1)

                    let showsHardwareRow = (hw.hardwareVersion?.isEmpty == false) && (hw.firmwareVersion?.isEmpty == false)
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 10) {
                            detailCell("DEVICE NAME", hw.deviceName)
                            if showsHardwareRow, let hv = hw.hardwareVersion {
                                detailCell("HARDWARE", hv)
                            }
                            detailCell("SOURCE BUNDLE", hw.sourceBundleID)
                        }
                    } else {
                        Grid(alignment: .topLeading, horizontalSpacing: 14, verticalSpacing: 10) {
                            GridRow {
                                detailCell("DEVICE NAME", hw.deviceName)
                                if showsHardwareRow, let hv = hw.hardwareVersion {
                                    detailCell("HARDWARE", hv)
                                }
                            }
                            GridRow {
                                detailCell("SOURCE BUNDLE", hw.sourceBundleID)
                                    .gridCellColumns(showsHardwareRow ? 2 : 1)
                            }
                        }
                    }

                    if showsHealthProvenance {
                        Text("Collection numbers follow the order of first listening dates in Apple Health.")
                            .font(.caption)
                            .foregroundStyle(DossierPalette.dim)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
        .dossierTile(padding: 0)
    }

    private func detailCell(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(DossierPalette.dim)
            Text(value)
                .font(.system(.footnote, design: .monospaced, weight: .semibold))
                .foregroundStyle(DossierPalette.primaryText.opacity(0.92))
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Milestone Timeline

struct MilestoneTimelineCard: View {
    let milestones: [DossierMilestone]
    let rarity: Rarity
    var calendar: Calendar = .current
    var showsHeader: Bool = false
    var unlockedCount: Int? = nil
    var previewLimit: Int? = nil
    var referenceDate: Date? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption2) private var badgeFontSize: CGFloat = 11
    @State private var isExpanded = false

    var body: some View {
        let accent = DossierContrast.accentColor(rarity: rarity, proFoil: nil, colorScheme: colorScheme)
        let hasMore = previewLimit != nil && milestones.count > (previewLimit ?? 0)
        let visibleMilestones = (hasMore && !isExpanded) ? Self.previewMilestones(from: milestones, limit: previewLimit!) : milestones
        let hiddenGapCount = (hasMore && !isExpanded) ? max(0, milestones.count - visibleMilestones.count) : 0
        let refYear = referenceDate.map { calendar.component(.year, from: $0) }
        let isAX = dynamicTypeSize.isAccessibilitySize

        VStack(alignment: .leading, spacing: 0) {
            if showsHeader {
                let unlocked = unlockedCount ?? milestones.filter { !$0.isFuture }.count
                let countText: LocalizedStringKey = unlocked < milestones.count
                    ? "\(unlocked) of \(milestones.count) unlocked"
                    : "\(unlocked) unlocked"
                let milestoneHeaderLayout = isAX
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))

                milestoneHeaderLayout {
                    Text("Milestones")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(DossierPalette.primaryText)
                        .accessibilityAddTraits(.isHeader)
                    if !isAX { Spacer() }
                    Text(countText)
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(DossierPalette.dim)
                }
                .padding(.bottom, 16)
            }

            ForEach(Array(visibleMilestones.enumerated()), id: \.element.id) { index, item in
                let isLast = index == visibleMilestones.count - 1
                let hasGapAfter = index == 0 && hiddenGapCount > 0
                let nodeColor = color(for: item)
                let dateText: String = if item.isFuture {
                    if let refYear, calendar.component(.year, from: item.date) != refYear {
                        AppLanguage.current.text("ETA %@", DateText.formatTemplate(item.date, template: "MMM d, yyyy", calendar: calendar, locale: AppLanguage.current.locale))
                    } else {
                        AppLanguage.current.text("ETA %@", item.date.dossierShort(calendar: calendar))
                    }
                } else if let refYear, calendar.component(.year, from: item.date) == refYear {
                    item.date.dossierShort(calendar: calendar)
                } else {
                    DateText.formatTemplate(item.date, template: "MMM d, yyyy", calendar: calendar, locale: AppLanguage.current.locale)
                }

                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        ZStack {
                            if item.isFuture {
                                Circle()
                                    .strokeBorder(nodeColor.opacity(0.55), style: StrokeStyle(lineWidth: 1.4, dash: [3, 3]))
                                    .frame(width: 28, height: 28)
                            } else {
                                Circle()
                                    .fill(nodeColor.opacity(0.16))
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().strokeBorder(nodeColor.opacity(0.75), lineWidth: 1.4))
                            }
                            Image(systemName: icon(for: item.kind))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(item.isFuture ? nodeColor.opacity(0.8) : nodeColor)
                                .accessibilityHidden(true)
                        }

                        if !isLast {
                            Rectangle()
                                .fill(colorScheme == .light ? Color.black.opacity(0.16) : Color.white.opacity(0.16))
                                .frame(width: 1.0)
                                .frame(minHeight: hasGapAfter ? 11 : 28, maxHeight: .infinity)
                                .padding(.top, 3)
                                .padding(.bottom, hasGapAfter ? 0 : 3)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        if isAX {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(verbatim: item.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(item.isFuture ? DossierPalette.primaryText.opacity(0.78) : DossierPalette.primaryText)
                                    if item.kind == .retired {
                                        milestoneBadge("VAULTED", color: accent)
                                    } else if item.isFuture {
                                        milestoneBadge("NEXT", color: accent)
                                    }
                                }
                                Text(dateText)
                                    .font(.footnote.weight(.medium))
                                    .monospacedDigit()
                                    .foregroundStyle(item.isFuture ? accent : DossierPalette.dim)
                            }
                        } else {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(verbatim: item.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(item.isFuture ? DossierPalette.primaryText.opacity(0.78) : DossierPalette.primaryText)
                                if item.kind == .retired {
                                    milestoneBadge("VAULTED", color: accent)
                                } else if item.isFuture {
                                    milestoneBadge("NEXT", color: accent)
                                }
                                Spacer(minLength: 8)
                                Text(dateText)
                                    .font(.footnote.weight(.medium))
                                    .monospacedDigit()
                                    .foregroundStyle(item.isFuture ? accent : DossierPalette.dim)
                                    .lineLimit(1)
                                    .fixedSize()
                            }
                        }
                        if !item.detail.isEmpty {
                            Text(verbatim: item.detail)
                                .font(.footnote)
                                .foregroundStyle(DossierPalette.dim)
                        }
                    }
                    .padding(.top, 3)
                    .padding(.bottom, isLast ? 2 : (hasGapAfter ? 8 : 16))
                }
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)

                if hasGapAfter {
                    let railColor = colorScheme == .light ? Color.black.opacity(0.16) : Color.white.opacity(0.16)
                    let dotColor = colorScheme == .light ? Color.black.opacity(0.28) : Color.white.opacity(0.28)
                    let gapLabel = hiddenGapCount == 1
                        ? AppLanguage.current.text("1 milestone in between")
                        : AppLanguage.current.text("%lld milestones in between", hiddenGapCount)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 14) {
                            VStack(spacing: 3) {
                                ForEach(0..<3, id: \.self) { _ in
                                    Circle()
                                        .fill(dotColor)
                                        .frame(width: 2.5, height: 2.5)
                                }
                            }
                            .frame(width: 28)

                            Text(verbatim: gapLabel)
                                .font(.caption2.weight(.medium))
                                .monospacedDigit()
                                .foregroundStyle(DossierPalette.dim)
                        }
                        .padding(.vertical, 4)

                        Rectangle()
                            .fill(railColor)
                            .frame(width: 1.0, height: 11)
                            .frame(width: 28)
                            .padding(.bottom, 3)
                    }
                }
            }

            if hasMore {
                Rectangle()
                    .fill(DossierPalette.hairline)
                    .frame(height: 1)
                    .padding(.top, 12)
                Button {
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(isExpanded ? AppLanguage.current.text("Show fewer") : AppLanguage.current.text("Show all %lld", milestones.count))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(accent)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(accent)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(DossierDisclosurePressStyle())
                .sensoryFeedback(.selection, trigger: isExpanded)
                .accessibilityValue(isExpanded ? Text("Expanded") : Text("Collapsed"))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, hasMore ? 7 : 18)
        .dossierTile(padding: 0)
    }

    private static func previewMilestones(from milestones: [DossierMilestone], limit: Int) -> [DossierMilestone] {
        guard limit > 0, milestones.count > limit else { return milestones }
        guard limit > 1, let first = milestones.first else { return Array(milestones.prefix(limit)) }
        let tail = milestones.suffix(limit - 1)
        if tail.contains(where: { $0.id == first.id }) {
            return Array(milestones.suffix(limit))
        }
        return [first] + tail
    }

    private func milestoneBadge(_ label: LocalizedStringKey, color: Color) -> some View {
        Text(label)
            .font(.system(size: min(badgeFontSize, 14), weight: .bold, design: .rounded))
            .tracking(0.4)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(colorScheme == .light ? 0.14 : 0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.24), lineWidth: 0.75))
            .foregroundStyle(color)
    }

    private func icon(for kind: DossierMilestone.Kind) -> String {
        switch kind {
        case .minted: "sparkles"
        case .hours: "clock.fill"
        case .tier: "seal.fill"
        case .longest: "flame.fill"
        case .bestDay: "crown.fill"
        case .upcoming: "flag.checkered"
        case .retired: "archivebox.fill"
        }
    }

    private func color(for item: DossierMilestone) -> Color {
        let accent = DossierContrast.accentColor(rarity: rarity, proFoil: nil, colorScheme: colorScheme)
        switch item.kind {
        case .longest, .bestDay: return Theme.trophyGold
        case .retired: return DossierPalette.dim
        case .upcoming, .minted, .tier, .hours: return accent
        }
    }
}

private struct TabWidthModifier: ViewModifier {
    let isScrollableAX: Bool

    func body(content: Content) -> some View {
        if isScrollableAX {
            content.fixedSize(horizontal: true, vertical: false)
        } else {
            content.frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    DeviceDossierView(card: SampleCards.all[0], isSampleData: true)
}
