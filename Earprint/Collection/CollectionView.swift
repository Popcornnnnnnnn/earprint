import SwiftUI

struct CollectionView: View {
    let cards: [HeadphoneCard]
    var isSampleData: Bool = false
    var sampleBadgeText: LocalizedStringKey = "Sample data"
    var statusMessage: LocalizedStringKey? = nil
    var isLoading: Bool = false
    var isActiveTab: Bool = true
    var onConnectHealth: (() -> Void)? = nil

    @Namespace private var hero
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
    @State private var space = LayoutSpace()

    private var listMotionActive: Bool {
        isActiveTab && !reduceMotion && selected == nil && dossierCard == nil && !showSettings && !showCardTiers
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()

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
                    namespace: hero,
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
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { selected = nil }
                }
                .zIndex(1)
            }
        }
        .foregroundStyle(.white)
        .fullScreenCover(item: $dossierCard) { card in
            DeviceDossierView(card: card, isSampleData: isSampleData) { dossierCard = nil }
        }
        .sheet(isPresented: $showCardTiers) {
            NavigationStack {
                CardTiersView(ownedCards: cards, showsDoneButton: true)
            }
            .preferredColorScheme(.dark)
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(ownedCards: cards, openIconPicker: openIconPicker)
                .presentationDragIndicator(.visible)
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
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { selected = card }
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
                .foregroundStyle(.white.opacity(0.55))
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
                .foregroundStyle(.white.opacity(0.45))
            Text(isLoading ? "Reading Apple Health…" : "No supported headphones yet")
                .font(.headline)
            Text("Collection makes cards for AirPods with matching artwork. Your other listening stays in Apple Health.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.52))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            if let onConnectHealth, !isLoading {
                Button(action: onConnectHealth) {
                    Text("Sync Apple Health")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .padding(.horizontal, 20)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
    }

    private func horizontalThumbnail(_ card: HeadphoneCard) -> some View {
        let color = colorStore?.selectedColor(for: card)
        let worn = routeMonitor?.isCurrentlyWorn(card) ?? false
        let disableTilt = reduceMotion
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { selected = card }
        } label: {
            ZStack {
                if selected != card {
                    LiveTiltView(isActive: listMotionActive) { liveTilt in
                        CardHorizontalFront(card: card, tilt: liveTilt, colorOption: color, isCurrentlyWorn: worn)
                            .overlay {
                                ScrollSheenSweep(cornerRadius: 24)
                            }
                            .background {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(Color.black)
                                    .shadow(color: card.rarity.glow.opacity(0.32), radius: 14, y: 8)
                            }
                            .rotation3DEffect(.degrees(Double(liveTilt.width) * 3.8), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
                            .rotation3DEffect(.degrees(Double(-liveTilt.height) * 3.0), axis: (x: 1, y: 0, z: 0), perspective: 0.7)
                    }
                    .matchedGeometryEffect(id: card.id, in: hero)
                    .transition(.identity)
                } else {
                    Color.clear.frame(height: 188)
                }
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
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { selected = card }
        } label: {
            ZStack {
                if selected != card {
                    LiveTiltView(isActive: listMotionActive) { liveTilt in
                        ScaledCard { CardFront(card: card, tilt: liveTilt, colorOption: color, isCurrentlyWorn: worn, showsChargingCase: false) }
                            .overlay {
                                ScrollSheenSweep(cornerRadius: 22)
                            }
                            .background {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.black)
                                    .shadow(color: card.rarity.glow.opacity(0.32), radius: 14, y: 8)
                            }
                            .rotation3DEffect(.degrees(Double(liveTilt.width) * 3.5), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
                            .rotation3DEffect(.degrees(Double(-liveTilt.height) * 2.8), axis: (x: 1, y: 0, z: 0), perspective: 0.7)
                    }
                    .matchedGeometryEffect(id: card.id, in: hero)
                    .transition(.identity)
                } else {
                    Color.clear.aspectRatio(CardMetrics.size.width / CardMetrics.size.height, contentMode: .fit)
                }
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
            .foregroundStyle(.white.opacity(0.18))
            .frame(height: 86)
            .overlay {
                HStack(spacing: 14) {
                    Image(systemName: "lock.fill")
                        .font(.title3)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.06), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Next pair").font(.subheadline.weight(.semibold))
                        Text("Listen with supported headphones to unlock a card")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.42))
                    }
                    Spacer()
                }
                .padding(.horizontal, 18)
                .foregroundStyle(.white.opacity(0.55))
            }
    }

    private var lockedSlotVertical: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
            .foregroundStyle(.white.opacity(0.2))
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
                .foregroundStyle(.white.opacity(0.35))
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
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { selected = cards[index] }
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

    @Namespace private var hero
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
            case .beats: .gold
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
                            .foregroundStyle(Color(red: 0.94, green: 0.78, blue: 0.36))
                            .frame(width: 34, height: 34)
                            .background(Color(red: 0.94, green: 0.78, blue: 0.36).opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
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
                                        .foregroundStyle(unlocked ? Color(red: 0.45, green: 0.90, blue: 0.76) : .secondary)
                                        .frame(width: 32, height: 32)
                                        .background(
                                            (unlocked ? Color(red: 0.45, green: 0.90, blue: 0.76).opacity(0.14) : Color.white.opacity(0.06)),
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
                                            .foregroundStyle(Color(red: 0.32, green: 0.86, blue: 0.56))
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
                    namespace: hero,
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

/// Evaluates `CardStackPose` on every 120Hz frame of a spring animation instead of linearly interpolating start/end values.
private struct CardStackEffect: ViewModifier, Animatable {
    let cardIndex: CGFloat
    var deckPosition: CGFloat
    let cardScale: CGFloat
    let appeared: Bool

    var animatableData: CGFloat {
        get { deckPosition }
        set { deckPosition = newValue }
    }

    func body(content: Content) -> some View {
        let delta = cardIndex - deckPosition
        let pose = CardStackPose.pose(forDelta: delta)
        let effectiveOpacity = abs(delta) < 0.01 ? pose.opacity : (appeared ? pose.opacity : 0)
        content
            .overlay {
                if pose.dimAmount > 0.005 {
                    RoundedRectangle(cornerRadius: CardMetrics.corner * cardScale, style: .continuous)
                        .fill(Color.black.opacity(pose.dimAmount))
                        .allowsHitTesting(false)
                }
            }
            .scaleEffect(pose.scale)
            .rotationEffect(.degrees(pose.rotationDegrees))
            .offset(x: pose.offsetX * cardScale, y: pose.offsetY * cardScale)
            .opacity(effectiveOpacity)
            .zIndex(pose.zIndex)
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
    let namespace: Namespace.ID
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
    @AppStorage("cardDetail.hasSeenFlipHint") private var hasSeenFlipHint = false
    @State private var showsFlipHintThisVisit = false
    @State private var flipped = false
    @State private var angle: Double = 0
    @State private var dragTilt: CGSize = .zero
    @State private var modelInteractionTilt: CGSize?
    /// Continuous visual index across `deckCards` (`0.0` = card 0, `1.0` = card 1, etc.).
    @State private var deckPosition: CGFloat = 0
    @State private var dragStartPosition: CGFloat? = nil
    /// Keeps the active card's 3D RealityView settled and immune to half-swipe cancellation glitches.
    @State private var active3DCardID: String? = nil
    @State private var ready3DCardIDs: Set<String> = []
    @State private var settle3DTask: Task<Void, Never>? = nil
    @State private var appeared = false
    @State private var showColorBar = ProcessInfo.processInfo.arguments.contains("-showColors")
    @State private var space = LayoutSpace()

    private var deckCards: [HeadphoneCard] {
        cards.isEmpty ? [card] : cards
    }

    private var activeIndex: Int {
        CardDeckNavigation.index(of: card, in: deckCards) ?? 0
    }

    private var availableColors: [DeviceColorOption] {
        colorStore?.availableColors(for: card) ?? DeviceColorOption.options(for: card.modelKey)
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
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.55))
                .ignoresSafeArea()
                .opacity(appeared ? 1 : 0)
                .contentShape(Rectangle())
                .gesture(cardNavigationSwipe)
                .onTapGesture(perform: close)

            layout
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
                flipped = false
                angle = 0
            }
        }
        .onChange(of: card.id) { _, _ in
            flipped = false
            angle = 0
            dragTilt = .zero
            modelInteractionTilt = nil
            showColorBar = false
            settle3DTask?.cancel()
            withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                deckPosition = CGFloat(activeIndex)
            }
            // Wait for the card stack spring to settle before attaching RealityKit so swipes stay locked at 120Hz.
            let targetID = card.id
            settle3DTask = Task {
                try? await Task.sleep(for: .milliseconds(220))
                guard !Task.isCancelled else { return }
                active3DCardID = targetID
                await prewarmNeighbors(around: activeIndex)
            }
        }
        .onAppear {
            deckPosition = CGFloat(activeIndex)
            active3DCardID = card.id
            withAnimation(.easeOut(duration: 0.35)) { appeared = true }
            Task { await prewarmNeighbors(around: activeIndex) }
            Task { await runDemoIfNeeded() }
        }
        .onDisappear {
            settle3DTask?.cancel()
            MotionHub.shared.setScrolling(false, source: "cardDeck")
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
        Button(action: close) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.top, 14)
        .padding(.trailing, 18)
        .opacity(appeared ? 1 : 0)
        .accessibilityLabel("Close")
    }

    /// Horizontal swipe across the card or stage deals to neighboring cards.
    /// Does NOT tear down the active card's 3D view during the drag so cancelling half-way never leaves it stuck.
    private var cardNavigationSwipe: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard deckCards.count > 1 else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                guard dragStartPosition != nil || abs(dx) > abs(dy) * 1.05 else { return }

                if dragStartPosition == nil {
                    dragStartPosition = CGFloat(activeIndex)
                    MotionHub.shared.setScrolling(true, source: "cardDeck")
                }
                let origin = dragStartPosition ?? CGFloat(activeIndex)
                let raw = origin - dx / 220
                let maxIdx = CGFloat(deckCards.count - 1)
                let clamped: CGFloat
                if raw < 0 {
                    clamped = raw * 0.22
                } else if raw > maxIdx {
                    clamped = maxIdx + (raw - maxIdx) * 0.22
                } else {
                    clamped = raw
                }
                var instant = Transaction()
                instant.disablesAnimations = true
                withTransaction(instant) {
                    deckPosition = clamped
                }
            }
            .onEnded { value in
                guard let origin = dragStartPosition else { return }
                dragStartPosition = nil
                MotionHub.shared.setScrolling(false, source: "cardDeck")
                let dx = value.translation.width
                let predicted = value.predictedEndTranslation.width
                let dy = value.translation.height
                let isHorizontal = abs(dx) > abs(dy) * 1.05 || abs(deckPosition - origin) > 0.10

                let step: Int? = if isHorizontal && (dx < -48 || predicted < -135) {
                    1
                } else if isHorizontal && (dx > 48 || predicted > 135) {
                    -1
                } else {
                    nil
                }

                if let step, selectNeighbor(step: step) { return }
                withAnimation(.spring(response: 0.40, dampingFraction: 0.82)) {
                    deckPosition = CGFloat(activeIndex)
                }
            }
    }

    @discardableResult
    private func selectNeighbor(step: Int) -> Bool {
        guard let neighbor = CardDeckNavigation.neighbor(of: card, in: deckCards, step: step) else { return false }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onSelectCard(neighbor)
        return true
    }

    @ViewBuilder private var layout: some View {
        let design = CardMetrics.size
        let size = space.size
        switch mode {
        case .single:
            let controlsHeight: CGFloat = availableColors.count > 1 ? (showColorBar ? 204 : 138) : 90
            let scale = min(space.isWide ? 1.35 : 1.14, (size.height - controlsHeight) / design.height, (size.width - 36) / design.width)
            VStack(spacing: 18) {
                cardStack(scale: scale)
                cardControls
                colorControls
            }
        case .besideControls:
            let scale = min(1, (size.height - 24) / design.height, (size.width * 0.6) / design.width)
            HStack(spacing: 32) {
                cardStack(scale: scale)
                VStack(spacing: 18) {
                    cardControls
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
                    colorControls
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// Physical trading-card stack: every card keeps a single stable view identity (no structural if/else swap
    /// mid-flight) driven by `CardStackEffect` (`Animatable`) for locked 120Hz spring curves.
    private func cardStack(scale: CGFloat) -> some View {
        let scale = max(scale, 0.3)
        // Window mounted cards to the visible stack neighborhood (at most 6 cards) so large collections stay fast.
        let indices = max(0, activeIndex - 2)..<min(deckCards.count, activeIndex + 4)
        return ZStack {
            ForEach(Array(deckCards[indices].enumerated()), id: \.element.id) { offset, item in
                let idx = indices.lowerBound + offset
                deckCard(item, index: idx, scale: scale)
                    .modifier(CardStackEffect(cardIndex: CGFloat(idx), deckPosition: deckPosition, cardScale: scale, appeared: appeared))
            }
        }
        .frame(width: CardMetrics.size.width * scale, height: CardMetrics.size.height * scale)
        .matchedGeometryEffect(id: card.id, in: namespace)
    }

    private func deckCard(_ item: HeadphoneCard, index: Int, scale: CGFloat) -> some View {
        let isTop = index == activeIndex
        let activeAngle = isTop ? angle : 0
        let surfaceRarity = isModelPreview ? (catalogSurfaces[item.id] ?? .silver) : item.rarity
        let overrideTilt: CGSize? = isTop
            ? (modelInteractionTilt ?? (dragTilt == .zero ? nil : dragTilt))
            : .zero

        return LiveTiltView(isActive: isTop && !flipped, overrideTilt: overrideTilt) { activeTilt in
            ZStack {
                deckFrontFace(item, isTop: isTop, activeTilt: activeTilt, surfaceRarity: surfaceRarity)
                    .contentShape(RoundedRectangle(cornerRadius: CardMetrics.corner))
                    .onTapGesture { if canFlip { flip() } }
                    .accessibilityElement(children: .contain)
                    .accessibilityAction(named: Text("Flip card")) { if canFlip { flip() } }
                    .allowsHitTesting(!flipped)
                    .accessibilityHidden(flipped || !isTop)
                    .modifier(CardFaceRotation(angle: activeAngle))

                if isTop && canFlip {
                    CardBack(
                        card: item,
                        openDossier: flipped && !isModelPreview ? openDossier : nil,
                        openTiers: flipped && !isModelPreview ? openTiers : nil,
                        flip: { flip() }
                    )
                    .contentShape(RoundedRectangle(cornerRadius: CardMetrics.corner))
                    .simultaneousGesture(cardNavigationSwipe)
                    .allowsHitTesting(flipped)
                    .accessibilityHidden(!flipped)
                    .modifier(CardFaceRotation(angle: activeAngle, isBack: true))
                }
            }
            .background {
                RoundedRectangle(cornerRadius: CardMetrics.corner, style: .continuous)
                    .fill(Color.black)
                    .shadow(
                        color: isTop ? surfaceRarity.glow.opacity(0.48) : .black.opacity(0.42),
                        radius: isTop ? 24 : 16,
                        y: isTop ? 16 : 12
                    )
                    .rotation3DEffect(.degrees(activeAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            }
            .scaleEffect(scale)
            .frame(width: CardMetrics.size.width * scale, height: CardMetrics.size.height * scale)
            .rotation3DEffect(.degrees(Double(activeTilt.width) * 12), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(Double(-activeTilt.height) * 12), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .allowsHitTesting(isTop)
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.8), trigger: flipped)
        }
    }

    private func deckFrontFace(
        _ item: HeadphoneCard,
        isTop: Bool,
        activeTilt: CGSize,
        surfaceRarity: Rarity
    ) -> some View {
        let itemColor = colorStore?.selectedColor(for: item) ?? DeviceColorOption.defaultOption(for: item.modelKey)
        let itemFinish = itemColor?.modelFinish ?? item.finish
        let itemFinishID = itemColor?.id ?? "default"
        let itemWorn = routeMonitor?.isCurrentlyWorn(item) ?? false
        let assetName = item.modelAssetName ?? (isModelPreview ? "" : nil)
        // Keep the active 3D RealityView settled cleanly and undisturbed by half-swipes.
        let show3D = item.id == active3DCardID && assetName != nil
        let is3DReady = show3D && ready3DCardIDs.contains(item.id)
        let surfaceTint = surfaceRarity.studioTint
        let catalogBadge: LocalizedStringKey? = isModelPreview
            ? (unlockedPreviewIDs.contains(item.id) ? "UNLOCKED" : "CATALOG")
            : nil

        return ZStack {
            CardFront(
                card: item,
                tilt: activeTilt,
                showSymbol: !is3DReady,
                colorOption: itemColor,
                isCurrentlyWorn: itemWorn,
                usesProductArtwork: !isModelPreview || item.modelAssetName != nil,
                showsListeningStats: !isModelPreview,
                surfaceRarityOverride: isModelPreview ? surfaceRarity : nil,
                badgeOverride: catalogBadge,
                catalogDetail: isModelPreview ? catalogDetails[item.id] : nil
            )
            .contentShape(RoundedRectangle(cornerRadius: CardMetrics.corner))
            .gesture(isTop ? cardNavigationSwipe : nil)

            if show3D, let assetName {
                Ellipse()
                    .fill(.black.opacity(0.30))
                    .frame(width: 146, height: 16)
                    .blur(radius: 10)
                    .offset(x: -activeTilt.width * 8, y: 37)
                    .opacity(is3DReady ? 1 : 0)
                    .allowsHitTesting(false)
                HeadphoneModelView(
                    kind: item.kind,
                    finish: itemFinish,
                    finishID: itemFinishID,
                    modelKey: item.modelKey,
                    assetName: assetName,
                    modelSize: 0.18,
                    tint: surfaceTint,
                    tilt: activeTilt,
                    onManipulationChanged: { manipulating in
                        modelInteractionTilt = manipulating ? activeTilt : nil
                    },
                    onModelReady: {
                        withAnimation(.easeOut(duration: reduceMotion ? 0.10 : 0.18)) {
                            _ = ready3DCardIDs.insert(item.id)
                        }
                    }
                )
                .frame(width: 300, height: 230)
                .offset(y: -47)
                .opacity(is3DReady ? 1 : 0)
                .allowsHitTesting(is3DReady)
                .accessibilityHidden(!is3DReady)
                .onDisappear { ready3DCardIDs.remove(item.id) }
            }
        }
    }

    private func backCard(scale: CGFloat) -> some View {
        let scale = max(scale, 0.3)
        return CardBack(card: card, openDossier: isModelPreview ? nil : openDossier, openTiers: isModelPreview ? nil : openTiers)
            .id(card.id)
            .background {
                RoundedRectangle(cornerRadius: CardMetrics.corner, style: .continuous)
                    .fill(Color.black)
                    .shadow(color: card.rarity.glow.opacity(0.4), radius: 24, y: 14)
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
                        .fill(idx == activeIndex ? Color.white.opacity(0.85) : Color.white.opacity(0.24))
                        .frame(width: idx == activeIndex ? 16 : 6, height: 6)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: activeIndex)
        } else {
            Text("\(activeIndex + 1) / \(deckCards.count)")
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(.white.opacity(0.08), in: Capsule())
        }
    }

    @ViewBuilder
    private var colorControls: some View {
        if availableColors.count > 1, let active = selectedColor {
            VStack(spacing: 12) {
                if showColorBar {
                    deviceColorStrip
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                colorToggleButton(active)
            }
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.32, dampingFraction: 0.84), value: showColorBar)
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
                    .overlay(Circle().strokeBorder(.white.opacity(0.45), lineWidth: 1))
                Text(LocalizedStringKey(active.title))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .foregroundStyle(.white)
            .background(
                Capsule().fill(showColorBar ? .white.opacity(0.24) : .white.opacity(0.12))
            )
            .overlay(
                Capsule().strokeBorder(.white.opacity(showColorBar ? 0.4 : 0.14), lineWidth: 1)
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
                                    .strokeBorder(.white, lineWidth: 2)
                                    .frame(width: 34, height: 34)
                            }
                            Circle()
                                .fill(LinearGradient(colors: [option.swatchTop, option.swatchBottom], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 26, height: 26)
                                .overlay(Circle().strokeBorder(.white.opacity(0.28), lineWidth: 0.9))
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
        .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1))
    }

    private func flip(_ direction: CardFlipDirection = .left) {
        // Side by side already shows both faces, and Model Gallery catalog cards have no stats back.
        guard canFlip else { return }
        withAnimation(.snappy(duration: 0.38, extraBounce: 0)) {
            flipped.toggle()
            angle += direction.rawValue
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
