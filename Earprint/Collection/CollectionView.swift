import SwiftUI

struct CollectionView: View {
    let cards: [HeadphoneCard]
    var isSampleData: Bool = false
    var sampleBadgeText: LocalizedStringKey = "Sample data"
    var statusMessage: LocalizedStringKey? = nil
    var isLoading: Bool = false
    var isActiveTab: Bool = true
    var onConnectHealth: (() -> Void)? = nil
    var onPreviewFirstLaunch: (() -> Void)? = nil

    @State private var selected: HeadphoneCard?
    @State private var dossierCard: HeadphoneCard?
    #if DEBUG
    @State private var showCardTiers = ProcessInfo.processInfo.arguments.contains("-cardTiers")
    private let openIconPicker = ProcessInfo.processInfo.arguments.contains("-iconPicker")
    @State private var showSettings = ProcessInfo.processInfo.arguments.contains("-iconPicker")
        || ProcessInfo.processInfo.arguments.contains("-settings")
    #else
    @State private var showCardTiers = false
    private let openIconPicker = false
    @State private var showSettings = false
    #endif
    @State private var demoStarted = false
    /// Set by widget deep links (`earprint://card/<id>`). Optional so previews work without it.
    @Environment(DeepLinkRouter.self) private var router: DeepLinkRouter?
    @Environment(DeviceColorStore.self) private var colorStore: DeviceColorStore?
    @Environment(ActiveAudioRouteMonitor.self) private var routeMonitor: ActiveAudioRouteMonitor?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var space = LayoutSpace()

    private var listMotionActive: Bool {
        isActiveTab && !reduceMotion && selected == nil && dossierCard == nil && !showSettings && !showCardTiers
    }

    var body: some View {
        ZStack {
            Theme.canvasElevated.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                        .padding(.horizontal, 18)
                    if isSampleData && !cards.isEmpty {
                        SampleDataBanner(badgeText: sampleBadgeText, detail: statusMessage,
                                         isLoading: isLoading, onConnect: onConnectHealth)
                            .padding(.horizontal, 18)
                    }
                    if cards.isEmpty {
                        emptyCollectionState
                            .padding(.horizontal, 18)
                            .padding(.top, 24)
                    } else if space.isWide || space.verticalFold != nil {
                        // Wide / iPhone Duo displays keep multi-column cards aligned clear of the hinge.
                        let grid = AdaptiveGrid(space: space, padding: 18, spacing: 14, minItemWidth: 210)
                        LazyVGrid(columns: grid.columns, spacing: 14) {
                            ForEach(cards) { card in
                                verticalThumbnail(card)
                            }
                            lockedSlotVertical
                        }
                        .padding(.leading, grid.leadingPadding)
                        .padding(.trailing, grid.trailingPadding)
                    } else {
                        // Standard iPhones show full-width horizontal collector cards.
                        LazyVStack(spacing: 14) {
                            ForEach(cards) { card in
                                horizontalThumbnail(card)
                            }
                            lockedSlotHorizontal
                        }
                        .padding(.horizontal, 18)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .pauseMotionWhileScrolling("collection")
            .readLayoutSpace($space)

            if let selection = selected {
                let card = cards.first(where: { $0.matches(id: selection.id) }) ?? selection
                CardDetail(
                    card: card,
                    cards: cards,
                    colorStore: colorStore,
                    routeMonitor: routeMonitor,
                    onSelectCard: { next in
                        selected = next
                    },
                    openDossier: {
                        dossierCard = card
                    },
                    openTiers: {
                        showCardTiers = true
                    }
                ) {
                    selected = nil
                }
                .zIndex(1)
            }
        }
        .foregroundStyle(Theme.primaryText)
        .toolbar(selected == nil ? .visible : .hidden, for: .tabBar)
        .animation(.easeInOut(duration: 0.22), value: selected != nil)
        .fullScreenCover(item: $dossierCard) { card in
            DeviceDossierView(card: card, isSampleData: isSampleData) { dossierCard = nil }
        }
        .sheet(isPresented: $showCardTiers) {
            NavigationStack {
                CardTiersView(ownedCards: cards, showsDoneButton: true)
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                ownedCards: cards,
                openIconPicker: openIconPicker,
                onConnectHealth: onConnectHealth,
                onPreviewFirstLaunch: onPreviewFirstLaunch
            )
            .presentationDragIndicator(.visible)
        }
        .task(id: cards.first?.modelAssetName) {
            guard let asset = cards.first?.modelAssetName else { return }
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await HeadphoneModelLoader.prewarm(assetName: asset)
        }
        .task { await runDemoIfNeeded() }
        .onAppear {
            openPendingCard()
        }
        .onChange(of: router?.pendingCardID) { _, _ in openPendingCard() }
        .onChange(of: cards.map(\.id)) { _, _ in openPendingCard() }
        .onChange(of: isLoading) { _, _ in openPendingCard() }
    }

    /// Opens the card a widget asked for, then clears the request.
    /// Keeps the request pending while HealthKit is still loading so cold-launch deep links resolve once real cards arrive.
    private func openPendingCard() {
        guard let router, let id = router.pendingCardID else { return }
        if let card = cards.first(where: { $0.matches(id: id) }) {
            router.pendingCardID = nil
            selected = card
        } else if !isLoading && !isSampleData {
            router.pendingCardID = nil
        }
    }

    private var header: some View {
        let total = cards.reduce(0) { $0 + $1.lifetimeMinutes }
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("My headphones").font(.system(size: 30, weight: .heavy))
                Group {
                    if cards.isEmpty {
                        Text("Listening archive")
                    } else {
                        Text("\(cards.count) cards · \(total.minutesText) together")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
            }
            Spacer(minLength: 8)
            settingsButton
        }
        .padding(.top, 12)
    }

    private var settingsButton: some View {
        let button = Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 19, weight: .medium))
                .frame(width: 44, height: 44)
                .background(Theme.card, in: Circle())
                .overlay(Circle().strokeBorder(Theme.cardStroke, lineWidth: 1))
                .shadow(color: Theme.cardShadow, radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")

        #if DEBUG
        return button.contextMenu {
            Button("Developer Tools", systemImage: "hammer") {
                router?.developerScreen = .tools
            }
        }
        #else
        return button
        #endif
    }

    private var emptyCollectionState: some View {
        VStack(spacing: 14) {
            Image(systemName: "headphones")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Theme.tertiaryText)
            Text(isLoading ? "Reading Apple Health…" : "No supported headphones yet")
                .font(.headline)
            Text("Collection makes cards for AirPods with matching artwork. Your other listening stays in Apple Health.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            if let onConnectHealth, !isLoading {
                Button(action: onConnectHealth) {
                    Text("Sync Apple Health")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.invertedText)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Theme.invertedFill, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .padding(.horizontal, 20)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.surfaceFill))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
    }

    private func horizontalThumbnail(_ card: HeadphoneCard) -> some View {
        let color = colorStore?.selectedColor(for: card)
        let worn = routeMonitor?.isCurrentlyWorn(card) ?? false
        let disableTilt = reduceMotion
        let isLight = colorScheme == .light
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selected = card
        } label: {
            LiveTiltView(isActive: listMotionActive) { liveTilt in
                CardHorizontalFront(card: card, tilt: liveTilt, colorOption: color, isCurrentlyWorn: worn)
                    .overlay {
                        ScrollSheenSweep(cornerRadius: 24)
                    }
                    .background {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Theme.card)
                            .shadow(
                                color: isLight ? Theme.cardShadow : card.rarity.glow.opacity(0.32),
                                radius: isLight ? 12 : 14,
                                y: isLight ? 5 : 8
                            )
                    }
                    .rotation3DEffect(.degrees(Double(liveTilt.width) * 3.8), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
                    .rotation3DEffect(.degrees(Double(-liveTilt.height) * 3.0), axis: (x: 1, y: 0, z: 0), perspective: 0.7)
            }
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(CollectorCardPressStyle())
        .scrollTransition(.interactive(timingCurve: .easeOut), axis: .vertical) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1.0 : 0.955)
                .opacity(phase.isIdentity ? 1.0 : 0.86)
                .rotation3DEffect(
                    .degrees(disableTilt ? 0 : phase.value * -4.2),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.75
                )
        }
    }

    private func verticalThumbnail(_ card: HeadphoneCard) -> some View {
        let color = colorStore?.selectedColor(for: card)
        let worn = routeMonitor?.isCurrentlyWorn(card) ?? false
        let isLight = colorScheme == .light
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selected = card
        } label: {
            LiveTiltView(isActive: listMotionActive) { liveTilt in
                ScaledCard { CardFront(card: card, tilt: liveTilt, colorOption: color, isCurrentlyWorn: worn, showsChargingCase: false) }
                    .overlay {
                        ScrollSheenSweep(cornerRadius: 22)
                    }
                    .background {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Theme.card)
                            .shadow(
                                color: isLight ? Theme.cardShadow : card.rarity.glow.opacity(0.32),
                                radius: isLight ? 12 : 14,
                                y: isLight ? 5 : 8
                            )
                    }
                    .rotation3DEffect(.degrees(Double(liveTilt.width) * 3.5), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
                    .rotation3DEffect(.degrees(Double(-liveTilt.height) * 2.8), axis: (x: 1, y: 0, z: 0), perspective: 0.7)
            }
        }
        .buttonStyle(CollectorCardPressStyle())
        .scrollTransition(.interactive(timingCurve: .easeOut), axis: .vertical) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1.0 : 0.96)
                .opacity(phase.isIdentity ? 1.0 : 0.88)
        }
    }

    private var lockedSlotHorizontal: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
            .foregroundStyle(Theme.hairline)
            .frame(height: 86)
            .overlay {
                HStack(spacing: 14) {
                    Image(systemName: "lock.fill")
                        .font(.title3)
                        .frame(width: 40, height: 40)
                        .background(Theme.surfaceFill, in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Next pair").font(.subheadline.weight(.semibold))
                        Text("Listen with supported headphones to unlock a card")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Spacer()
                }
                .padding(.horizontal, 18)
                .foregroundStyle(Theme.secondaryText)
            }
    }

    private var lockedSlotVertical: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
            .foregroundStyle(Theme.hairline)
            .aspectRatio(CardMetrics.size.width / CardMetrics.size.height, contentMode: .fit)
            .overlay {
                VStack(spacing: 6) {
                    Image(systemName: "lock.fill").font(.title2)
                    Text("Next pair").font(.footnote.weight(.semibold))
                    Text("Listen with supported headphones\nto unlock a card")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 12)
                .foregroundStyle(Theme.tertiaryText)
            }
    }

    /// Launch arguments: `-dossier` / `-dossierDemo` open a card's dossier directly; `-demo` opens card detail.
    private func runDemoIfNeeded() async {
        let args = ProcessInfo.processInfo.arguments
        guard !demoStarted, !cards.isEmpty else { return }
        var index = 0
        if let i = args.firstIndex(of: "-demoIndex"), i + 1 < args.count, let n = Int(args[i + 1]) {
            index = min(max(0, n), cards.count - 1)
        }
        if args.contains("-dossier") || args.contains("-dossierDemo") {
            demoStarted = true
            dossierCard = cards[index]
            return
        }
        if args.contains("-cardDetail") {
            demoStarted = true
            selected = cards[index]
            return
        }
        guard args.contains("-demo") else { return }
        demoStarted = true
        try? await Task.sleep(for: .seconds(1.2))
        selected = cards[index]
    }
}

/// Deduplicated, family-grouped catalog of supported headphone models used by `ModelGalleryView`.
/// Merges hardware variant product IDs that share the exact same marketing name (e.g. AirPods 4 PIDs).
enum ModelGalleryCatalog {
    enum Family: String, CaseIterable, Identifiable {
        case airPods = "AirPods"
        case airPodsPro = "AirPods Pro"
        case airPodsMax = "AirPods Max"
        case beats = "Beats"
        case generic = "Generic"

        var id: String { rawValue }
    }

    struct Entry: Identifiable, Equatable {
        let id: String
        let family: Family
        let model: HeadphoneModelInfo
        let productIDs: [Int]
        let card: HeadphoneCard

        var productIDSummary: String? {
            guard !productIDs.isEmpty else { return nil }
            return productIDs.map { String(format: "0x%04X", $0) }.joined(separator: " · ")
        }

        var hasDedicated3DModel: Bool {
            card.modelAssetName != nil
        }

        static func == (lhs: Entry, rhs: Entry) -> Bool { lhs.id == rhs.id }
    }

    struct SectionGroup: Identifiable {
        let family: Family
        let entries: [Entry]
        var id: String { family.id }
    }

    static func family(for model: HeadphoneModelInfo) -> Family {
        switch model.key {
        case .airpods, .airpods3, .airpods4: return .airPods
        case .airpodsPro: return .airPodsPro
        case .airpodsMax: return .airPodsMax
        case .beatsEarbuds, .beatsEarhook, .beatsOverEar: return .beats
        case .earbudsGeneric, .overEarGeneric: return .generic
        }
    }

    static let sections: [SectionGroup] = buildSections(from: Array(HeadphoneModelCatalog.byProductID.values))
    static let allEntries: [Entry] = sections.flatMap(\.entries)
    static let allCards: [HeadphoneCard] = allEntries.map(\.card)
    static let allAppleAndBeatsCount: Int = allEntries.filter { $0.family != .generic }.count
    static let detailsByCardID: [String: String] = Dictionary(uniqueKeysWithValues: allEntries.compactMap { entry in
        entry.productIDSummary.map { (entry.id, $0) }
    })

    static func unlockedIDs(for ownedCards: [HeadphoneCard]) -> Set<String> {
        let ownedModels = Set(ownedCards.map { $0.model.lowercased() })
        guard !ownedModels.isEmpty else { return [] }
        var result: Set<String> = []
        result.reserveCapacity(ownedModels.count)
        for entry in allEntries where entry.family != .generic {
            if ownedModels.contains(entry.model.marketingName.lowercased()) {
                result.insert(entry.id)
            }
        }
        return result
    }

    static func isUnlocked(_ entry: Entry, ownedCards: [HeadphoneCard]) -> Bool {
        guard entry.family != .generic else { return false }
        let target = entry.model.marketingName.lowercased()
        return ownedCards.contains { $0.model.lowercased() == target }
    }

    static func unlockedCount(for ownedCards: [HeadphoneCard]) -> Int {
        unlockedIDs(for: ownedCards).count
    }

    static func buildSections(from products: [HeadphoneModelInfo]) -> [SectionGroup] {
        // Deduplicate by marketingName while keeping all variant Bluetooth product IDs sorted.
        var grouped: [String: (info: HeadphoneModelInfo, ids: [Int])] = [:]
        for info in products {
            let key = info.marketingName
            if var existing = grouped[key] {
                if let pid = info.productID, !existing.ids.contains(pid) {
                    existing.ids.append(pid)
                }
                grouped[key] = existing
            } else {
                grouped[key] = (info, info.productID.map { [$0] } ?? [])
            }
        }

        let genericEarbuds = HeadphoneModelInfo(
            productID: nil, marketingName: "Generic earbuds", shortName: "Earbuds",
            key: .earbudsGeneric, symbol: "earbuds", fallbackSymbol: "headphones", isApple: false
        )
        let genericOverEar = HeadphoneModelInfo(
            productID: nil, marketingName: "Generic headphones", shortName: "Headphones",
            key: .overEarGeneric, symbol: "headphones", fallbackSymbol: "headphones", isApple: false
        )

        var bucketed: [Family: [(info: HeadphoneModelInfo, ids: [Int])]] = [:]
        for value in grouped.values {
            let sortedIDs = value.ids.sorted()
            bucketed[family(for: value.info), default: []].append((value.info, sortedIDs))
        }
        bucketed[.generic] = [(genericEarbuds, []), (genericOverEar, [])]

        var serial = 1
        var result: [SectionGroup] = []
        for fam in Family.allCases {
            guard var items = bucketed[fam], !items.isEmpty else { continue }
            if fam != .generic {
                items.sort { lhs, rhs in
                    let lMin = lhs.ids.first ?? Int.max
                    let rMin = rhs.ids.first ?? Int.max
                    return (lMin, lhs.info.marketingName) < (rMin, rhs.info.marketingName)
                }
            }
            let entries: [Entry] = items.map { item in
                defer { serial += 1 }
                let idSlug = item.info.marketingName.lowercased().replacingOccurrences(of: " ", with: "-")
                let card = HeadphoneCard(
                    id: "catalog-\(idSlug)",
                    nickname: item.info.shortName,
                    model: item.info.marketingName,
                    symbol: item.info.resolvedSymbol,
                    lifetimeMinutes: 0,
                    sessions: 0,
                    longestMinutes: 0,
                    averageDecibels: 0,
                    firstMet: "",
                    lastUsed: "",
                    serial: serial,
                    grid: ListeningGrid(minutes: [], decibels: []),
                    modelKey: item.info.key,
                    kind: item.info.key.kind
                )
                return Entry(id: card.id, family: fam, model: item.info, productIDs: item.ids, card: card)
            }
            result.append(SectionGroup(family: fam, entries: entries))
        }
        return result
    }
}

struct ModelGalleryView: View {
    var ownedCards: [HeadphoneCard] = []

    @State private var selection: HeadphoneCard?
    @State private var colors = DeviceColorStore(defaults: UserDefaults(suiteName: "com.popcornnn.earprint.model-gallery") ?? .standard)

    private func catalogSurfacesByCardID(unlocked: Set<String>) -> [String: Rarity] {
        Dictionary(uniqueKeysWithValues: ModelGalleryCatalog.allEntries.map { entry in
            if unlocked.contains(entry.id) {
                return (entry.id, Rarity.holo)
            }
            let surface: Rarity = switch entry.family {
            case .airPods: .silver
            case .airPodsPro: .platinum
            case .airPodsMax: .obsidian
            case .beats: .sapphire
            case .generic: .bronze
            }
            return (entry.id, surface)
        })
    }

    var body: some View {
        let unlockedIDs = ModelGalleryCatalog.unlockedIDs(for: ownedCards)
        ZStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "trophy.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.moderateColor)
                            .frame(width: 34, height: 34)
                            .background(Theme.moderateColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(unlockedIDs.count) of \(ModelGalleryCatalog.allAppleAndBeatsCount) unlocked")
                                .font(.subheadline.weight(.semibold))
                            Text("Listen with any supported pair to add it to your Collection.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }

                ForEach(ModelGalleryCatalog.sections) { section in
                    Section(LocalizedStringKey(section.family.rawValue)) {
                        ForEach(section.entries) { entry in
                            let unlocked = unlockedIDs.contains(entry.id)
                            Button {
                                selection = entry.card
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: entry.model.resolvedSymbol)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(unlocked ? Theme.quietColor : .secondary)
                                        .frame(width: 32, height: 32)
                                        .background(
                                            (unlocked ? Theme.quietColor.opacity(0.14) : Theme.surfaceFill),
                                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        )

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(entry.model.marketingName)
                                            .font(.body)
                                        HStack(spacing: 6) {
                                            Text(LocalizedStringKey(entry.hasDedicated3DModel ? "3D model" : "Generic 3D preview"))
                                            if let pids = entry.productIDSummary {
                                                Text("·")
                                                Text(pids).monospaced()
                                            }
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    }

                                    Spacer(minLength: 8)

                                    if unlocked {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.adaptive(
                                                light: UIColor(red: 0.12, green: 0.65, blue: 0.36, alpha: 1),
                                                dark: UIColor(red: 0.32, green: 0.86, blue: 0.56, alpha: 1)
                                            ))
                                            .accessibilityLabel("Unlocked")
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
            .accessibilityHidden(selection != nil)

            if let selection {
                CardDetail(
                    card: selection,
                    cards: ModelGalleryCatalog.allCards,
                    isModelPreview: true,
                    unlockedPreviewIDs: unlockedIDs,
                    catalogDetails: ModelGalleryCatalog.detailsByCardID,
                    catalogSurfaces: catalogSurfacesByCardID(unlocked: unlockedIDs),
                    colorStore: colors,
                    onSelectCard: { self.selection = $0 }
                ) {
                    self.selection = nil
                }
            }
        }
        .navigationTitle("Model Gallery")
        .toolbar(selection == nil ? .visible : .hidden, for: .navigationBar)
    }
}

/// Pure helper for switching between cards in `CardDetail`.
enum CardDeckNavigation {
    static func index(of card: HeadphoneCard, in cards: [HeadphoneCard]) -> Int? {
        cards.firstIndex(where: { $0.id == card.id })
    }

    /// Returns the neighboring card (`step = +1` for next / swipe left, `step = -1` for previous / swipe right).
    static func neighbor(of card: HeadphoneCard, in cards: [HeadphoneCard], step: Int) -> HeadphoneCard? {
        guard cards.count > 1, let current = index(of: card, in: cards) else { return nil }
        let target = current + step
        guard target >= 0, target < cards.count else { return nil }
        return cards[target]
    }

    /// Resolves the target card index on swipe end, handling deliberate half-drag stops,
    /// pull-back cancellations, and mid-flight catches cleanly.
    static func targetIndex(
        activeIndex: Int,
        count: Int,
        originPosition: CGFloat,
        currentPosition: CGFloat,
        dragDeltaX: CGFloat,
        predictedDeltaX: CGFloat
    ) -> Int {
        guard count > 1 else { return activeIndex }
        let caughtMidFlight = abs(originPosition - CGFloat(activeIndex)) >= 0.05
        if caughtMidFlight {
            let momentumShift = (predictedDeltaX - dragDeltaX) / 260
            let projected = currentPosition - momentumShift
            let lower = max(0, activeIndex - 1)
            let upper = min(count - 1, activeIndex + 1)
            return max(lower, min(upper, Int(projected.rounded())))
        }
        let momentum = predictedDeltaX - dragDeltaX
        let flickedLeft = (dragDeltaX < -24 && predictedDeltaX < -135)
            || (dragDeltaX <= -12 && predictedDeltaX < -135 && momentum < -110)
        let flickedRight = (dragDeltaX > 24 && predictedDeltaX > 135)
            || (dragDeltaX >= 12 && predictedDeltaX > 135 && momentum > 110)
        let draggedLeft = dragDeltaX < -56 && predictedDeltaX <= dragDeltaX + 30
        let draggedRight = dragDeltaX > 56 && predictedDeltaX >= dragDeltaX - 30
        if flickedLeft || draggedLeft {
            return min(count - 1, activeIndex + 1)
        }
        if flickedRight || draggedRight {
            return max(0, activeIndex - 1)
        }
        return activeIndex
    }

    /// Maps a global horizontal drag translation to a continuous deck position with gentle rubber-banding
    /// at deck boundaries and beyond a single-card step from `activeIndex`.
    static func dragPosition(
        origin: CGFloat,
        activeIndex: Int,
        count: Int,
        dragDeltaX: CGFloat
    ) -> CGFloat {
        guard count > 1 else { return CGFloat(activeIndex) }
        let raw = origin - dragDeltaX / 220
        let minTarget = CGFloat(max(0, activeIndex - 1))
        let maxTarget = CGFloat(min(count - 1, activeIndex + 1))
        if raw < minTarget {
            return minTarget + (raw - minTarget) * 0.22
        } else if raw > maxTarget {
            return maxTarget + (raw - maxTarget) * 0.22
        } else {
            return raw
        }
    }

    /// Returns true only when RealityKit's hidden-frame confirmation matches the active swap hide request
    /// and the user has not started a new deck drag in the meantime.
    static func shouldCompleteOverlaySwap(
        confirmedToken: Int,
        currentHideToken: Int,
        isHidingForSwap: Bool,
        isDragging: Bool
    ) -> Bool {
        confirmedToken == currentHideToken && isHidingForSwap && !isDragging
    }

    /// Returns true when the active card still owns the persistent 3D overlay after a cancelled swap hide,
    /// has a 3D asset, and has not yet reported a loaded model — requiring an explicit reload trigger.
    static func shouldTriggerOverlayReload(
        activeCardID: String,
        overlayCardID: String,
        loadedCardID: String?,
        hasAsset: Bool
    ) -> Bool {
        activeCardID == overlayCardID && loadedCardID != activeCardID && hasAsset
    }
}

/// Per-card flip state strictly keyed by `HeadphoneCard.id`.
/// Keying by card ID guarantees an incoming card never inherits the previous card's flip angle on the
/// render pass before `.onChange(of: card.id)` fires, while preserving outgoing flipped cards as they
/// glide off-screen or dissolve cleanly behind the active card.
struct CardDeckFlipState: Equatable {
    enum Phase: Equatable {
        case rotated(Double)
        case dissolvingBack(opacity: Double)
    }

    private(set) var phasesByCardID: [String: Phase] = [:]

    var trackedCardIDs: [String] {
        phasesByCardID.keys.sorted()
    }

    mutating func toggle(cardID: String, direction: CardFlipDirection = .left) {
        let current: Double
        if case .rotated(let angle) = phasesByCardID[cardID] {
            current = angle
        } else {
            current = 0
        }
        phasesByCardID[cardID] = .rotated(current + direction.rawValue)
    }

    /// Promotes `cardID` to active: keeps an active back-face rotation if caught mid-flight,
    /// or clears an already-dissolving tucked back face so the card lands cleanly face-up.
    mutating func promoteToActive(cardID: String) {
        if case .dissolvingBack = phasesByCardID[cardID] {
            phasesByCardID.removeValue(forKey: cardID)
        }
    }

    mutating func prepareDissolveBack(cardID: String) {
        guard isShowingBack(for: cardID) else { return }
        phasesByCardID[cardID] = .dissolvingBack(opacity: 1)
    }

    mutating func fadeOutDissolvingBack(cardID: String) {
        guard case .dissolvingBack = phasesByCardID[cardID] else { return }
        phasesByCardID[cardID] = .dissolvingBack(opacity: 0)
    }

    mutating func clear(cardID: String) {
        phasesByCardID.removeValue(forKey: cardID)
    }

    mutating func resetAll() {
        phasesByCardID.removeAll()
    }

    func hasTrackedFlip(for cardID: String) -> Bool {
        phasesByCardID[cardID] != nil
    }

    func isDissolvingBack(for cardID: String) -> Bool {
        if case .dissolvingBack = phasesByCardID[cardID] { return true }
        return false
    }

    func isShowingBack(for cardID: String) -> Bool {
        switch phasesByCardID[cardID] {
        case .rotated(let angle):
            return cos(angle * .pi / 180) < 0
        case .dissolvingBack(let opacity):
            return opacity > 0
        case nil:
            return false
        }
    }

    func frontFaceAngle(for cardID: String) -> Double {
        if case .rotated(let angle) = phasesByCardID[cardID] {
            return angle
        }
        return 0
    }

    func backFaceAngle(for cardID: String) -> Double {
        switch phasesByCardID[cardID] {
        case .rotated(let angle):
            return angle
        case .dissolvingBack:
            return -180
        case nil:
            return 0
        }
    }

    func backFaceOpacity(for cardID: String) -> Double {
        if case .dissolvingBack(let opacity) = phasesByCardID[cardID] {
            return opacity
        }
        return 1
    }

    func outgoingCardIDs(excluding activeCardID: String) -> [String] {
        phasesByCardID.keys.filter { $0 != activeCardID }.sorted()
    }
}

/// Pure geometric pose for one card in the physical Card Stack Deal (`Option B`) given its signed offset
/// `delta = cardIndex - visualPosition` (`0` = active top card, `> 0` = tucked behind in the deck, `< 0` = dealt off left).
/// Cards stay opaque on screen and use `dimAmount` to shade depth so stacked cards never ghost through each other.
struct CardStackPose: Equatable {
    var offsetX: CGFloat
    var offsetY: CGFloat
    var scale: CGFloat
    var rotationDegrees: Double
    var opacity: Double
    var dimAmount: Double
    var zIndex: Double

    static func pose(forDelta d: CGFloat) -> CardStackPose {
        if d < 0 {
            let p = min(1.5, -d)
            // Stay solid opaque while overlapping the deck; fade out cleanly only after clearing the card edge.
            let fade = p <= 0.78 ? 1.0 : max(0, Double(1 - (p - 0.78) / 0.22))
            return CardStackPose(
                offsetX: -p * 390,
                offsetY: p * 24,
                scale: 1.0,
                rotationDegrees: Double(-p * 15),
                opacity: fade,
                dimAmount: 0,
                zIndex: 120 - Double(p * 10)
            )
        } else {
            let depth = min(2.6, d)
            let fade = depth <= 2.1 ? 1.0 : max(0, Double(1 - (depth - 2.1) / 0.5))
            return CardStackPose(
                offsetX: depth * 15,
                offsetY: depth * 14,
                scale: max(0.80, 1 - depth * 0.08),
                rotationDegrees: Double(depth * 3.2),
                opacity: fade,
                dimAmount: min(0.56, Double(depth * 0.25)),
                zIndex: 100 - Double(depth * 20)
            )
        }
    }
}

/// Tracks the live interpolated `deckPosition` on 120Hz spring frames without triggering SwiftUI state invalidations.
@MainActor
private final class DeckPresentationTracker {
    var livePosition: CGFloat = 0
}

/// Evaluates `CardStackPose` on every 120Hz frame of a spring animation instead of linearly interpolating start/end values.
private struct CardStackEffect: ViewModifier, Animatable {
    let cardIndex: CGFloat
    var deckPosition: CGFloat
    let cardScale: CGFloat
    let appeared: Bool
    var appliesDim: Bool = true
    var appliesOpacity: Bool = true
    var presentationTracker: DeckPresentationTracker? = nil
    var tracksPresentation: Bool = false

    var animatableData: CGFloat {
        get { deckPosition }
        set { deckPosition = newValue }
    }

    func body(content: Content) -> some View {
        let _ = recordPresentationIfNeeded()
        let delta = cardIndex - deckPosition
        let pose = CardStackPose.pose(forDelta: delta)
        let effectiveOpacity: Double = if appliesOpacity {
            abs(delta) < 0.01 ? pose.opacity : (appeared ? pose.opacity : 0)
        } else {
            1
        }
        content
            .overlay {
                if appliesDim {
                    RoundedRectangle(cornerRadius: CardMetrics.corner * cardScale, style: .continuous)
                        .fill(Color.black.opacity(pose.dimAmount))
                        .allowsHitTesting(false)
                }
            }
            .scaleEffect(pose.scale)
            .rotationEffect(.degrees(pose.rotationDegrees))
            .offset(x: pose.offsetX * cardScale, y: pose.offsetY * cardScale)
            .opacity(effectiveOpacity)
    }

    private func recordPresentationIfNeeded() {
        if tracksPresentation {
            presentationTracker?.livePosition = deckPosition
        }
    }
}

enum CardFlipDirection: Double {
    case left = -180
    case right = 180

    static func isHorizontal(_ translation: CGSize) -> Bool {
        abs(translation.width) > abs(translation.height) * 1.2
    }

    static func swipe(translation: CGSize, predicted: CGSize) -> Self? {
        guard isHorizontal(translation) else { return nil }
        let width = translation.width
        let projected = predicted.width
        let flicked = abs(width) >= 24 && abs(projected) >= 115 && width * projected > 0
        guard abs(width) >= 76 || flicked else { return nil }
        return width < 0 ? .left : .right
    }
}

struct CardDetail: View {
    let card: HeadphoneCard
    var cards: [HeadphoneCard] = []
    var isModelPreview = false
    var unlockedPreviewIDs: Set<String> = []
    var catalogDetails: [String: String] = [:]
    var catalogSurfaces: [String: Rarity] = [:]
    var colorStore: DeviceColorStore? = nil
    var routeMonitor: ActiveAudioRouteMonitor? = nil
    var onSelectCard: (HeadphoneCard) -> Void = { _ in }
    var openDossier: () -> Void = {}
    var openTiers: (() -> Void)? = nil
    let close: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("cardDetail.hasSeenFlipHint") private var hasSeenFlipHint = false
    @State private var showsFlipHintThisVisit = false
    @State private var flipState = CardDeckFlipState()
    @State private var dragTilt: CGSize = .zero
    @State private var modelInteractionTilt: CGSize?
    /// Continuous visual index across `deckCards` (`0.0` = card 0, `1.0` = card 1, etc.).
    @State private var deckPosition: CGFloat = 0
    @State private var dragStartPosition: CGFloat? = nil
    @State private var dragOriginTranslationX: CGFloat = 0
    @State private var lastDeckDragEndTime: Date = .distantPast
    @GestureState private var isBackdropDragActive = false
    @GestureState private var isCardStackDragActive = false
    @GestureState private var isFlippedCardDragActive = false
    /// Keeps the persistent 3D RealityView clean across card switches without tearing down CAMetalLayer.
    @State private var presentationTracker = DeckPresentationTracker()
    @State private var overlayCardIndex: Int = 0
    @State private var overlayCardID: String = ""
    @State private var isHiding3DForSwap = false
    @State private var swapHideToken = 0
    @State private var modelReloadNonce = 0
    @State private var loaded3DCardID: String? = nil
    @State private var settled3DCardID: String? = nil
    @State private var settle3DTask: Task<Void, Never>? = nil
    @State private var clearOutgoingFlipTask: Task<Void, Never>? = nil
    @State private var flipHapticCount = 0
    @State private var appeared = false
    @State private var isDismissing = false
    @State private var holdsMotionHub = false
    @State private var showColorBar = ProcessInfo.processInfo.arguments.contains("-showColors")
    @State private var space = LayoutSpace()

    private var flipped: Bool { flipState.isShowingBack(for: card.id) }

    private var isDeckDragGestureActive: Bool {
        isBackdropDragActive || isCardStackDragActive || isFlippedCardDragActive
    }

    private var isDeckSettlingMidFlight: Bool {
        abs(presentationTracker.livePosition - CGFloat(activeIndex)) > 0.08
    }

    private var hasActiveOrRecentDeckDrag: Bool {
        dragStartPosition != nil
            || isDeckDragGestureActive
            || Date.now.timeIntervalSince(lastDeckDragEndTime) < 0.20
    }

    private var deckCards: [HeadphoneCard] {
        cards.isEmpty ? [card] : cards
    }

    private var activeIndex: Int {
        CardDeckNavigation.index(of: card, in: deckCards) ?? 0
    }

    private var availableColors: [DeviceColorOption] {
        colorStore?.availableColors(for: card) ?? DeviceColorOption.options(for: card.modelKey)
    }

    private var deckHasColorChoices: Bool {
        deckCards.contains { item in
            let options = colorStore?.availableColors(for: item) ?? DeviceColorOption.options(for: item.modelKey)
            return options.count > 1
        }
    }

    private func resolvedAssetName(for item: HeadphoneCard) -> String? {
        item.modelAssetName ?? (isModelPreview ? "" : nil)
    }

    private var deckHasAny3DModel: Bool {
        deckCards.contains { resolvedAssetName(for: $0) != nil }
    }

    private var overlayCard: HeadphoneCard {
        if deckCards.indices.contains(overlayCardIndex), deckCards[overlayCardIndex].id == overlayCardID {
            return deckCards[overlayCardIndex]
        }
        return deckCards.first(where: { $0.id == overlayCardID }) ?? card
    }

    private var resolvedOverlayIndex: Int {
        CardDeckNavigation.index(of: overlayCard, in: deckCards) ?? activeIndex
    }

    private var selectedColor: DeviceColorOption? {
        colorStore?.selectedColor(for: card) ?? DeviceColorOption.defaultOption(for: card.modelKey)
    }

    /// How the detail uses the space (see docs/IPHONE_DUO.md).
    private enum Mode: Equatable {
        /// One flip card. Phones in portrait and the outer Duo display in portrait.
        case single
        /// Short landscape space (phone or outer Duo display on its side): card on the left, controls on the right.
        case besideControls
        /// Front (3D) and back (stats) as two cards: the inner Duo display, or a book-folded Duo (one card per half).
        case sideBySide
        /// Laptop-folded Duo: card above the fold, controls below it.
        case foldStacked(CGRect)
    }

    private var mode: Mode {
        if let fold = space.horizontalFold { return .foldStacked(fold) }
        if !isModelPreview, space.verticalFold != nil { return .sideBySide }
        if !isModelPreview, space.isWide {
            let split = ColumnSplit(space: space, padding: 24, gap: 36)
            let fits = min(split.leading, split.trailing) / CardMetrics.size.width >= 0.85
                && (space.size.height - 116) / CardMetrics.size.height >= 0.85
            if fits { return .sideBySide }
        }
        if space.isLandscape && space.size.height < 600 { return .besideControls }
        return .single
    }

    private var canFlip: Bool {
        !isModelPreview && mode != .sideBySide
    }

    private var canShowFlipHint: Bool {
        space.size.width > 0 && canFlip
    }

    private var repeatsFlipHint: Bool {
        #if DEBUG
        !ProcessInfo.processInfo.arguments.contains("-cardHintOnce")
        #elseif EARPRINT_REPEAT_CARD_HINT
        true
        #else
        false
        #endif
    }

    var body: some View {
        let isLight = colorScheme == .light
        ZStack {
            ZStack {
                Theme.detailBackdrop
                RadialGradient(
                    colors: [card.rarity.glow.opacity(isLight ? 0.14 : 0.20), .clear],
                    center: UnitPoint(x: 0.5, y: 0.42),
                    startRadius: 20,
                    endRadius: 340
                )
                .animation(.easeInOut(duration: 0.35), value: card.id)
            }
            .ignoresSafeArea()
            .opacity(appeared ? 1 : 0)
            .contentShape(Rectangle())
            .gesture(cardNavigationSwipe(updating: $isBackdropDragActive))
            .onTapGesture(perform: handleBackdropTap)

            layout
                .scaleEffect(appeared ? 1 : 0.94)
                .opacity(appeared ? 1 : 0)
        }
        .overlay(alignment: .topTrailing) {
            topCloseButton
        }
        .readLayoutSpace($space)
        .onChange(of: canShowFlipHint, initial: true) { _, canShow in
            guard canShow, !repeatsFlipHint, !hasSeenFlipHint else { return }
            showsFlipHintThisVisit = true
            hasSeenFlipHint = true
        }
        .onChange(of: mode) { _, newMode in
            if newMode == .sideBySide {
                clearOutgoingFlipTask?.cancel()
                clearOutgoingFlipTask = nil
                flipState.resetAll()
            }
        }
        .onChange(of: card.id) { _, newID in
            clearOutgoingFlipTask?.cancel()
            clearOutgoingFlipTask = nil
            flipState.promoteToActive(cardID: newID)
            dragTilt = .zero
            modelInteractionTilt = nil
            showColorBar = false
            withAnimation(.spring(response: 0.38, dampingFraction: 0.92)) {
                deckPosition = CGFloat(activeIndex)
            }
            schedule3DSettleIfNeeded()
            scheduleOutgoingFlipCleanupIfNeeded()
        }
        .onChange(of: activeIndex) { _, newIndex in
            guard dragStartPosition == nil else { return }
            if overlayCardID == card.id {
                overlayCardIndex = newIndex
            }
            if abs(deckPosition - CGFloat(newIndex)) > 0.001 {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.92)) {
                    deckPosition = CGFloat(newIndex)
                }
            }
        }
        .onChange(of: flipped) { _, isFlipped in
            if !isFlipped {
                schedule3DSettleIfNeeded()
            }
        }
        .onChange(of: isDeckDragGestureActive) { _, active in
            if !active && dragStartPosition != nil {
                cancelDeckDrag()
            }
        }
        .onAppear {
            deckPosition = CGFloat(activeIndex)
            presentationTracker.livePosition = CGFloat(activeIndex)
            overlayCardIndex = activeIndex
            overlayCardID = card.id
            isHiding3DForSwap = false
            settled3DCardID = nil
            loaded3DCardID = nil
            if !reduceMotion && !holdsMotionHub {
                holdsMotionHub = true
                MotionHub.shared.acquire()
            }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { appeared = true }
            Task { await prewarmNeighbors(around: activeIndex) }
            Task { await runDemoIfNeeded() }
        }
        .onDisappear {
            settle3DTask?.cancel()
            clearOutgoingFlipTask?.cancel()
            dragStartPosition = nil
            dragOriginTranslationX = 0
            MotionHub.shared.setScrolling(false, source: "cardDeck")
            if holdsMotionHub {
                holdsMotionHub = false
                MotionHub.shared.release()
            }
        }
    }

    private func handleBackdropTap() {
        guard !hasActiveOrRecentDeckDrag, !isDeckSettlingMidFlight else { return }
        dismissDetail()
    }

    private func dismissDetail() {
        guard !isDismissing else { return }
        isDismissing = true
        if reduceMotion {
            close()
            return
        }
        withAnimation(.easeOut(duration: 0.20)) {
            appeared = false
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            close()
        }
    }

    private func prewarmNeighbors(around index: Int) async {
        for offset in [-1, 1] {
            let idx = index + offset
            guard deckCards.indices.contains(idx),
                  let asset = deckCards[idx].modelAssetName else { continue }
            await HeadphoneModelLoader.prewarm(assetName: asset)
        }
    }

    private var topCloseButton: some View {
        Button(action: dismissDetail) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.primaryText.opacity(0.9))
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                .shadow(color: Theme.cardShadow, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.top, 14)
        .padding(.trailing, 18)
        .opacity(appeared ? 1 : 0)
        .accessibilityLabel("Close")
    }

    /// Horizontal swipe across the card or stage deals to neighboring cards.
    /// Evaluates translation in `.global` space on stationary containers so card movement never feeds back
    /// into gesture deltas, and tracks liveness via `@GestureState` so system cancellations recover cleanly.
    private func cardNavigationSwipe(updating gestureActive: GestureState<Bool>) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .updating(gestureActive) { _, active, _ in
                active = true
            }
            .onChanged { value in
                guard deckCards.count > 1 else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                guard dragStartPosition != nil || abs(dx) > abs(dy) * 1.05 else { return }

                if dragStartPosition == nil {
                    settle3DTask?.cancel()
                    settle3DTask = nil
                    clearOutgoingFlipTask?.cancel()
                    clearOutgoingFlipTask = nil
                    isHiding3DForSwap = false
                    dragStartPosition = presentationTracker.livePosition
                    dragOriginTranslationX = dx
                    MotionHub.shared.setScrolling(true, source: "cardDeck")
                }
                let origin = dragStartPosition ?? CGFloat(activeIndex)
                let effectiveDX = dx - dragOriginTranslationX
                let clamped = CardDeckNavigation.dragPosition(
                    origin: origin,
                    activeIndex: activeIndex,
                    count: deckCards.count,
                    dragDeltaX: effectiveDX
                )
                var instant = Transaction()
                instant.disablesAnimations = true
                withTransaction(instant) {
                    deckPosition = clamped
                }
                presentationTracker.livePosition = clamped
            }
            .onEnded { value in
                guard let origin = dragStartPosition else { return }
                let originX = dragOriginTranslationX
                dragStartPosition = nil
                dragOriginTranslationX = 0
                lastDeckDragEndTime = .now
                MotionHub.shared.setScrolling(false, source: "cardDeck")
                let dx = value.translation.width - originX
                let predicted = value.predictedEndTranslation.width - originX
                let target = CardDeckNavigation.targetIndex(
                    activeIndex: activeIndex,
                    count: deckCards.count,
                    originPosition: origin,
                    currentPosition: deckPosition,
                    dragDeltaX: dx,
                    predictedDeltaX: predicted
                )

                if target != activeIndex {
                    selectCard(at: target)
                    return
                }
                withAnimation(.spring(response: 0.38, dampingFraction: 0.92)) {
                    deckPosition = CGFloat(activeIndex)
                }
                schedule3DSettleIfNeeded()
                scheduleOutgoingFlipCleanupIfNeeded()
            }
    }

    private func cancelDeckDrag() {
        guard dragStartPosition != nil else { return }
        dragStartPosition = nil
        dragOriginTranslationX = 0
        lastDeckDragEndTime = .now
        MotionHub.shared.setScrolling(false, source: "cardDeck")
        withAnimation(.spring(response: 0.38, dampingFraction: 0.92)) {
            deckPosition = CGFloat(activeIndex)
        }
        schedule3DSettleIfNeeded()
        scheduleOutgoingFlipCleanupIfNeeded()
    }

    private func selectCard(at index: Int) {
        guard deckCards.indices.contains(index) else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onSelectCard(deckCards[index])
    }

    @discardableResult
    private func selectNeighbor(step: Int) -> Bool {
        guard let neighbor = CardDeckNavigation.neighbor(of: card, in: deckCards, step: step) else { return false }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onSelectCard(neighbor)
        return true
    }

    private func schedule3DSettleIfNeeded() {
        settle3DTask?.cancel()
        settle3DTask = nil
        guard dragStartPosition == nil else { return }

        if overlayCardID == card.id && resolvedOverlayIndex == activeIndex {
            isHiding3DForSwap = false
            if loaded3DCardID == card.id && !flipped && settled3DCardID != card.id {
                withAnimation(.easeOut(duration: reduceMotion ? 0.08 : 0.16)) {
                    settled3DCardID = card.id
                }
            } else if CardDeckNavigation.shouldTriggerOverlayReload(
                activeCardID: card.id,
                overlayCardID: overlayCardID,
                loadedCardID: loaded3DCardID,
                hasAsset: resolvedAssetName(for: card) != nil
            ) {
                modelReloadNonce += 1
            }
            return
        }

        let targetID = card.id
        let targetIndex = activeIndex
        let currentOverlayIdx = resolvedOverlayIndex
        let overlayHasModel = resolvedAssetName(for: overlayCard) != nil

        settle3DTask = Task { @MainActor in
            for _ in 0..<30 {
                if Task.isCancelled || dragStartPosition != nil { return }
                let livePos = presentationTracker.livePosition
                let cleared: Bool
                if !overlayHasModel && loaded3DCardID == nil {
                    cleared = abs(livePos - CGFloat(targetIndex)) <= 0.14
                } else if currentOverlayIdx < targetIndex {
                    cleared = (livePos - CGFloat(currentOverlayIdx)) >= 0.88
                } else {
                    cleared = (livePos - CGFloat(targetIndex)) <= 0.10
                }
                if cleared { break }
                try? await Task.sleep(for: .milliseconds(16))
            }

            guard !Task.isCancelled, dragStartPosition == nil, card.id == targetID else { return }
            guard deckHasAny3DModel else {
                completeOverlaySwapToActiveCard()
                return
            }
            settled3DCardID = nil
            isHiding3DForSwap = true
            swapHideToken += 1
            let token = swapHideToken
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled,
                  CardDeckNavigation.shouldCompleteOverlaySwap(
                      confirmedToken: token,
                      currentHideToken: swapHideToken,
                      isHidingForSwap: isHiding3DForSwap,
                      isDragging: dragStartPosition != nil
                  ) else { return }
            completeOverlaySwapToActiveCard()
        }
    }

    private func scheduleOutgoingFlipCleanupIfNeeded() {
        clearOutgoingFlipTask?.cancel()
        clearOutgoingFlipTask = nil
        let outgoingIDs = flipState.outgoingCardIDs(excluding: card.id)
        guard dragStartPosition == nil, !outgoingIDs.isEmpty else { return }

        let targetIndex = activeIndex
        let outgoingIndices: [String: Int] = Dictionary(uniqueKeysWithValues: outgoingIDs.compactMap { id in
            deckCards.firstIndex(where: { $0.id == id }).map { (id, $0) }
        })

        clearOutgoingFlipTask = Task { @MainActor in
            for _ in 0..<35 {
                if Task.isCancelled || dragStartPosition != nil { return }
                let livePos = presentationTracker.livePosition
                let allDone = outgoingIDs.allSatisfy { id in
                    guard let idx = outgoingIndices[id] else { return true }
                    if idx < targetIndex {
                        return (livePos - CGFloat(idx)) >= 0.995
                    } else {
                        return abs(livePos - CGFloat(targetIndex)) <= 0.03
                    }
                }
                if allDone { break }
                try? await Task.sleep(for: .milliseconds(16))
            }

            guard !Task.isCancelled, dragStartPosition == nil else { return }

            var tuckedToDissolve: [String] = []
            for id in flipState.outgoingCardIDs(excluding: card.id) {
                let idx = deckCards.firstIndex(where: { $0.id == id })
                if let idx, idx > activeIndex, flipState.isShowingBack(for: id), !reduceMotion {
                    tuckedToDissolve.append(id)
                } else {
                    var instant = Transaction()
                    instant.disablesAnimations = true
                    withTransaction(instant) {
                        flipState.clear(cardID: id)
                    }
                }
            }

            guard !tuckedToDissolve.isEmpty else { return }

            // Commit face-up `CardFront` behind opaque `CardBack` in a non-animated frame first,
            // then dissolve `CardBack` cleanly with zero 3D perspective flare protruding past the top card.
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                for id in tuckedToDissolve {
                    flipState.prepareDissolveBack(cardID: id)
                }
            }

            try? await Task.sleep(for: .milliseconds(16))
            guard !Task.isCancelled, dragStartPosition == nil else { return }

            let activeDissolving = tuckedToDissolve.filter { $0 != card.id && flipState.isDissolvingBack(for: $0) }
            guard !activeDissolving.isEmpty else { return }

            withAnimation(.easeOut(duration: 0.22)) {
                for id in activeDissolving {
                    flipState.fadeOutDissolvingBack(cardID: id)
                }
            }

            try? await Task.sleep(for: .milliseconds(240))
            guard !Task.isCancelled, dragStartPosition == nil else { return }

            var cleanup = Transaction()
            cleanup.disablesAnimations = true
            withTransaction(cleanup) {
                for id in activeDissolving where id != card.id && flipState.isDissolvingBack(for: id) {
                    flipState.clear(cardID: id)
                }
            }
        }
    }

    private func completeOverlaySwapToActiveCard() {
        isHiding3DForSwap = false
        overlayCardIndex = activeIndex
        overlayCardID = card.id
        settled3DCardID = nil
        if loaded3DCardID != card.id {
            loaded3DCardID = nil
        }
        if loaded3DCardID == card.id && !flipped && dragStartPosition == nil {
            withAnimation(.easeOut(duration: reduceMotion ? 0.08 : 0.16)) {
                settled3DCardID = card.id
            }
        }
        Task { await prewarmNeighbors(around: activeIndex) }
    }

    @ViewBuilder private var layout: some View {
        let design = CardMetrics.size
        let size = space.size
        switch mode {
        case .single:
            let controlsHeight: CGFloat = deckHasColorChoices ? 142 : 94
            let scale = min(space.isWide ? 1.35 : 1.14, (size.height - controlsHeight) / design.height, (size.width - 36) / design.width)
            VStack(spacing: 16) {
                cardStack(scale: scale)
                cardControls
                    .frame(minHeight: 42)
                    .opacity(showColorBar ? 0 : 1)
                colorControls
            }
        case .besideControls:
            let scale = min(1, (size.height - 24) / design.height, (size.width * 0.6) / design.width)
            HStack(spacing: 32) {
                cardStack(scale: scale)
                VStack(spacing: 18) {
                    cardControls
                        .opacity(showColorBar ? 0 : 1)
                    colorControls
                }
            }
        case .sideBySide:
            let split = ColumnSplit(space: space, padding: 24, gap: 36)
            let scale = min(1.35, min(split.leading, split.trailing) / design.width, (size.height - 116) / design.height)
            HStack(alignment: .top, spacing: split.gap) {
                VStack(spacing: 18) {
                    cardStack(scale: scale)
                    cardControls
                        .frame(minHeight: 42)
                }
                .frame(width: split.leading)
                VStack(spacing: 18) {
                    backCard(scale: scale)
                    colorControls
                }
                .frame(width: split.trailing)
            }
            .padding(.horizontal, split.padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .foldStacked(let fold):
            // The fold frame already includes margins; keep the card fully above it.
            let scale = min(1.25, (fold.minY - 24) / design.height, (size.width - 40) / design.width)
            VStack(spacing: 0) {
                cardStack(scale: scale)
                    .frame(maxWidth: .infinity)
                    .frame(height: max(0, fold.minY))
                Color.clear.frame(height: fold.height)
                VStack(spacing: 16) {
                    cardControls
                        .opacity(showColorBar ? 0 : 1)
                    colorControls
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// Physical trading-card stack: every card keeps a single stable view identity (no structural if/else swap
    /// mid-flight) driven by `CardStackEffect` (`Animatable`), plus one persistent 3D RealityView overlay.
    private func cardStack(scale: CGFloat) -> some View {
        let scale = max(scale, 0.3)
        // Window mounted cards to the visible stack neighborhood (while keeping outgoing overlay/flipped cards mounted).
        let overlayIdx = resolvedOverlayIndex
        let trackedFlipIndices = flipState.trackedCardIDs.compactMap { id in
            deckCards.firstIndex(where: { $0.id == id })
        }
        let minTrackedFlip = trackedFlipIndices.min() ?? activeIndex
        let maxTrackedFlip = trackedFlipIndices.max() ?? activeIndex
        let lower = max(0, min(activeIndex - 2, overlayIdx, minTrackedFlip))
        let upper = min(deckCards.count, max(activeIndex + 4, overlayIdx + 1, maxTrackedFlip + 1))
        let indices = lower..<upper
        return ZStack {
            ForEach(Array(deckCards[indices].enumerated()), id: \.element.id) { offset, item in
                let idx = indices.lowerBound + offset
                deckCard(item, index: idx, scale: scale)
                    .modifier(CardStackEffect(
                        cardIndex: CGFloat(idx),
                        deckPosition: deckPosition,
                        cardScale: scale,
                        appeared: appeared,
                        presentationTracker: presentationTracker,
                        tracksPresentation: idx == activeIndex
                    ))
                    .zIndex(Double(deckCards.count - idx))
            }

            if deckHasAny3DModel {
                persistent3DOverlay(scale: scale)
                    .zIndex(Double(deckCards.count - overlayIdx) + 0.5)
            }
        }
        .frame(width: CardMetrics.size.width * scale, height: CardMetrics.size.height * scale)
        .gesture(
            cardNavigationSwipe(updating: $isCardStackDragActive)
                .exclusively(before: TapGesture().onEnded {
                    if canFlip && !flipped {
                        flip()
                    }
                }),
            isEnabled: !flipped
        )
        .simultaneousGesture(cardNavigationSwipe(updating: $isFlippedCardDragActive), isEnabled: flipped)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.8), trigger: flipHapticCount)
    }

    @ViewBuilder
    private func persistent3DOverlay(scale: CGFloat) -> some View {
        let targetCard = overlayCard
        let targetIdx = resolvedOverlayIndex
        let surfaceRarity = isModelPreview ? (catalogSurfaces[targetCard.id] ?? .silver) : targetCard.rarity
        let itemColor = colorStore?.selectedColor(for: targetCard) ?? DeviceColorOption.defaultOption(for: targetCard.modelKey)
        let itemFinish = itemColor?.modelFinish ?? targetCard.finish
        let itemFinishID = itemColor?.id ?? "default"
        let activeAsset = resolvedAssetName(for: targetCard)
        let overlayShowsBack = canFlip && flipState.isShowingBack(for: targetCard.id)
        let canShow3DNow = activeAsset != nil && !isHiding3DForSwap && !overlayShowsBack && targetCard.id == settled3DCardID
        let canInteractWith3D = canShow3DNow && targetCard.id == card.id && dragStartPosition == nil
        let overrideTilt: CGSize? = modelInteractionTilt ?? (dragTilt == .zero ? nil : dragTilt)

        LiveTiltView(isActive: !overlayShowsBack, overrideTilt: overrideTilt) { activeTilt in
            ZStack {
                Ellipse()
                    .fill(.black.opacity(0.30))
                    .frame(width: 146, height: 16)
                    .blur(radius: 10)
                    .offset(x: -activeTilt.width * 8, y: 37)
                    .opacity(canShow3DNow ? 1 : 0)
                    .allowsHitTesting(false)

                HeadphoneModelView(
                    modelID: targetCard.id,
                    kind: targetCard.kind,
                    finish: itemFinish,
                    finishID: itemFinishID,
                    modelKey: targetCard.modelKey,
                    assetName: activeAsset,
                    modelSize: 0.18,
                    tint: surfaceRarity.studioTint,
                    tintKey: surfaceRarity.rawValue,
                    tilt: activeTilt,
                    isVisible: canShow3DNow,
                    hideToken: swapHideToken,
                    reloadNonce: modelReloadNonce,
                    depthDim: Float(CardStackPose.pose(forDelta: CGFloat(targetIdx) - deckPosition).dimAmount),
                    onTap: canFlip ? { flip() } : nil,
                    onManipulationChanged: { manipulating in
                        modelInteractionTilt = manipulating ? activeTilt : nil
                    },
                    onModelReady: { readyID in
                        loaded3DCardID = readyID
                        if readyID == card.id && readyID == overlayCardID && !isHiding3DForSwap && dragStartPosition == nil && !flipped {
                            withAnimation(.easeOut(duration: reduceMotion ? 0.08 : 0.16)) {
                                settled3DCardID = readyID
                            }
                        }
                    },
                    onHiddenConfirmed: { confirmedToken in
                        if CardDeckNavigation.shouldCompleteOverlaySwap(
                            confirmedToken: confirmedToken,
                            currentHideToken: swapHideToken,
                            isHidingForSwap: isHiding3DForSwap,
                            isDragging: dragStartPosition != nil
                        ) {
                            completeOverlaySwapToActiveCard()
                        } else if CardDeckNavigation.shouldTriggerOverlayReload(
                            activeCardID: card.id,
                            overlayCardID: overlayCardID,
                            loadedCardID: loaded3DCardID,
                            hasAsset: resolvedAssetName(for: card) != nil
                        ) {
                            modelReloadNonce += 1
                        }
                    }
                )
                .frame(width: 300, height: 230)
                .offset(y: -47)
                .allowsHitTesting(canInteractWith3D)
                .accessibilityHidden(!canInteractWith3D)
            }
            .frame(width: CardMetrics.size.width, height: CardMetrics.size.height)
            .scaleEffect(scale)
            .frame(width: CardMetrics.size.width * scale, height: CardMetrics.size.height * scale)
            .rotation3DEffect(.degrees(Double(activeTilt.width) * 12), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(Double(-activeTilt.height) * 12), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .allowsHitTesting(canInteractWith3D)
        }
        .modifier(CardStackEffect(
            cardIndex: CGFloat(targetIdx),
            deckPosition: deckPosition,
            cardScale: scale,
            appeared: appeared,
            appliesDim: false,
            appliesOpacity: false
        ))
    }

    private func deckCard(_ item: HeadphoneCard, index: Int, scale: CGFloat) -> some View {
        let isTop = index == activeIndex
        let hasTrackedFlip = flipState.hasTrackedFlip(for: item.id) && canFlip
        let showsBackFace = canFlip && flipState.isShowingBack(for: item.id)
        let usesLiveTilt = isTop || item.id == overlayCardID
        let frontAngle = canFlip ? flipState.frontFaceAngle(for: item.id) : 0
        let backAngle = canFlip ? flipState.backFaceAngle(for: item.id) : 0
        let backOpacity = canFlip ? flipState.backFaceOpacity(for: item.id) : 1
        let surfaceRarity = isModelPreview ? (catalogSurfaces[item.id] ?? .silver) : item.rarity
        let overrideTilt: CGSize? = usesLiveTilt
            ? (modelInteractionTilt ?? (dragTilt == .zero ? nil : dragTilt))
            : .zero

        return LiveTiltView(isActive: usesLiveTilt && !showsBackFace, overrideTilt: overrideTilt) { activeTilt in
            ZStack {
                deckFrontFace(item, isTop: isTop, activeTilt: activeTilt, surfaceRarity: surfaceRarity)
                    .contentShape(RoundedRectangle(cornerRadius: CardMetrics.corner))
                    .accessibilityElement(children: .contain)
                    .accessibilityAction(named: Text("Flip card")) { if canFlip { flip() } }
                    .allowsHitTesting(isTop && !flipped)
                    .accessibilityHidden(!isTop || flipped)
                    .modifier(CardFaceRotation(angle: frontAngle))

                if (isTop || hasTrackedFlip) && canFlip {
                    CardBack(
                        card: item,
                        openDossier: !isModelPreview ? {
                            guard isTop, flipped, !hasActiveOrRecentDeckDrag else { return }
                            openDossier()
                        } : nil,
                        openTiers: !isModelPreview ? openTiers.map { action in
                            {
                                guard isTop, flipped, !hasActiveOrRecentDeckDrag else { return }
                                action()
                            }
                        } : nil,
                        flip: isTop ? { flip() } : nil
                    )
                    .contentShape(RoundedRectangle(cornerRadius: CardMetrics.corner))
                    .allowsHitTesting(isTop && flipped)
                    .accessibilityHidden(!(isTop && flipped))
                    .modifier(CardFaceRotation(angle: backAngle, isBack: true))
                    .opacity(backOpacity)
                    .transition(.identity)
                }
            }
            .background {
                let isLight = colorScheme == .light
                RoundedRectangle(cornerRadius: CardMetrics.corner, style: .continuous)
                    .fill(Theme.card)
                    .shadow(
                        color: isTop
                            ? surfaceRarity.glow.opacity(isLight ? 0.30 : 0.48)
                            : (isLight ? Theme.cardShadow : .black.opacity(0.42)),
                        radius: isTop ? 24 : 16,
                        y: isTop ? 16 : 12
                    )
                    .animation(.easeOut(duration: 0.25), value: isTop)
                    .rotation3DEffect(.degrees(frontAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            }
            .scaleEffect(scale)
            .frame(width: CardMetrics.size.width * scale, height: CardMetrics.size.height * scale)
            .rotation3DEffect(.degrees(Double(activeTilt.width) * 12), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(Double(-activeTilt.height) * 12), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .animation(.easeOut(duration: 0.25), value: usesLiveTilt)
            .allowsHitTesting(isTop)
        }
    }

    private func deckFrontFace(
        _ item: HeadphoneCard,
        isTop: Bool,
        activeTilt: CGSize,
        surfaceRarity: Rarity
    ) -> some View {
        let itemColor = colorStore?.selectedColor(for: item) ?? DeviceColorOption.defaultOption(for: item.modelKey)
        let itemWorn = routeMonitor?.isCurrentlyWorn(item) ?? false
        let assetName = resolvedAssetName(for: item)
        let itemShowsBack = canFlip && flipState.isShowingBack(for: item.id)
        let isItemShowing3D = assetName != nil
            && item.id == settled3DCardID
            && item.id == overlayCardID
            && !isHiding3DForSwap
            && !itemShowsBack
        let catalogBadge: LocalizedStringKey? = isModelPreview
            ? (unlockedPreviewIDs.contains(item.id) ? "UNLOCKED" : "CATALOG")
            : nil

        return CardFront(
            card: item,
            tilt: activeTilt,
            showSymbol: !isItemShowing3D,
            colorOption: itemColor,
            isCurrentlyWorn: itemWorn,
            usesProductArtwork: !isModelPreview || item.modelAssetName != nil,
            showsListeningStats: !isModelPreview,
            surfaceRarityOverride: isModelPreview ? surfaceRarity : nil,
            badgeOverride: catalogBadge,
            catalogDetail: isModelPreview ? catalogDetails[item.id] : nil
        )
        .contentShape(RoundedRectangle(cornerRadius: CardMetrics.corner))
    }

    private func backCard(scale: CGFloat) -> some View {
        let scale = max(scale, 0.3)
        let isLight = colorScheme == .light
        return CardBack(card: card, openDossier: isModelPreview ? nil : openDossier, openTiers: isModelPreview ? nil : openTiers)
            .id(card.id)
            .background {
                RoundedRectangle(cornerRadius: CardMetrics.corner, style: .continuous)
                    .fill(Theme.card)
                    .shadow(color: isLight ? Theme.cardShadow : card.rarity.glow.opacity(0.4), radius: 24, y: 14)
            }
            .scaleEffect(scale)
            .frame(width: CardMetrics.size.width * scale, height: CardMetrics.size.height * scale)
            .opacity(appeared ? 1 : 0)
    }

    private var cardControls: some View {
        let showHints = repeatsFlipHint || showsFlipHintThisVisit
        return VStack(spacing: 8) {
            if showHints {
                if canFlip && deckCards.count > 1 {
                    Text("Tap to flip · swipe to switch")
                        .font(.caption)
                } else if canFlip {
                    Text("Tap card to flip")
                        .font(.caption)
                } else if isModelPreview && deckCards.count > 1 {
                    Text("Swipe to browse models")
                        .font(.caption)
                }
            }
            if deckCards.count > 1 {
                deckPageIndicator
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("Card \(activeIndex + 1) of \(deckCards.count)"))
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: selectNeighbor(step: 1)
                        case .decrement: selectNeighbor(step: -1)
                        @unknown default: break
                        }
                    }
            }
        }
        .foregroundStyle(Theme.secondaryText)
        .opacity(appeared ? 1 : 0)
    }

    @ViewBuilder
    private var deckPageIndicator: some View {
        if deckCards.count <= 8 {
            HStack(spacing: 6) {
                ForEach(deckCards.indices, id: \.self) { idx in
                    Capsule()
                        .fill(idx == activeIndex ? Theme.primaryText.opacity(0.85) : Theme.primaryText.opacity(0.22))
                        .frame(width: idx == activeIndex ? 16 : 6, height: 6)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: activeIndex)
        } else {
            Text("\(activeIndex + 1) / \(deckCards.count)")
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Theme.surfaceFill, in: Capsule())
        }
    }

    @ViewBuilder
    private var colorControls: some View {
        if deckHasColorChoices {
            ZStack {
                if availableColors.count > 1, let active = selectedColor {
                    colorToggleButton(active)
                } else {
                    Color.clear
                }
            }
            .frame(height: 46)
            .allowsHitTesting(availableColors.count > 1)
            .overlay(alignment: .top) {
                if showColorBar && availableColors.count > 1 {
                    let stripOffset: CGFloat = mode == .sideBySide ? 56 : -62
                    let stripAnchor: UnitPoint = mode == .sideBySide ? .top : .bottom
                    let stripMaxWidth = min(max(space.size.width - 48, 220), 330)
                    deviceColorStrip
                        .frame(width: stripMaxWidth)
                        .offset(y: stripOffset)
                        .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: stripAnchor)))
                }
            }
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.30, dampingFraction: 0.84), value: showColorBar)
        }
    }

    private func colorToggleButton(_ active: DeviceColorOption) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showColorBar.toggle()
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(LinearGradient(colors: [active.swatchTop, active.swatchBottom], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 15, height: 15)
                    .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                Text(LocalizedStringKey(active.title))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .foregroundStyle(Theme.primaryText)
            .background(
                Capsule().fill(showColorBar ? Theme.surfaceFillStrong : Theme.surfaceFill)
            )
            .overlay(
                Capsule().strokeBorder(Theme.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Change device color, currently \(Text(LocalizedStringKey(active.title)))")
    }

    private var deviceColorStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(availableColors) { option in
                    let isSelected = option == selectedColor
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        colorStore?.select(option, for: card)
                    } label: {
                        ZStack {
                            if isSelected {
                                Circle()
                                    .strokeBorder(Theme.primaryText, lineWidth: 2)
                                    .frame(width: 34, height: 34)
                            }
                            Circle()
                                .fill(LinearGradient(colors: [option.swatchTop, option.swatchBottom], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 26, height: 26)
                                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 0.9))
                        }
                        .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(LocalizedStringKey(option.title)))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: 330)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
    }

    private func flip(_ direction: CardFlipDirection = .left) {
        // Side by side already shows both faces, and Model Gallery catalog cards have no stats back.
        guard canFlip, !hasActiveOrRecentDeckDrag, !isDeckSettlingMidFlight else { return }
        flipHapticCount += 1
        withAnimation(.snappy(duration: 0.38, extraBounce: 0)) {
            flipState.toggle(cardID: card.id, direction: direction)
            dragTilt = .zero
        }
    }

    /// With `-demo`, play tilt and flip so the simulator recording shows every effect.
    private func runDemoIfNeeded() async {
        let args = ProcessInfo.processInfo.arguments
        #if DEBUG
        if args.contains("-cardDetail"), args.contains("-cardBack") {
            flip()
            return
        }
        #endif
        guard args.contains("-demo") else { return }
        try? await Task.sleep(for: .seconds(1.0))
        for step in 0..<60 {
            let t = Double(step) / 59
            dragTilt = CGSize(width: sin(t * .pi * 2) * 0.9, height: sin(t * .pi * 4) * 0.35)
            try? await Task.sleep(for: .milliseconds(25))
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { dragTilt = .zero }
        try? await Task.sleep(for: .seconds(0.6))
        flip()
        try? await Task.sleep(for: .seconds(2.6))
        flip()
    }
}

#Preview {
    CollectionView(cards: SampleCards.all)
}
