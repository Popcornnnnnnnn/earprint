import SwiftUI

struct CollectionView: View {
    let cards: [HeadphoneCard]
    var isSampleData: Bool = false
    var sampleBadgeText: LocalizedStringKey = "Sample data"
    var statusMessage: LocalizedStringKey? = nil
    var isLoading: Bool = false
    var onConnectHealth: (() -> Void)? = nil

    @Namespace private var hero
    @State private var selected: HeadphoneCard?
    @State private var dossierCard: HeadphoneCard?
    #if DEBUG
    private let openIconPicker = ProcessInfo.processInfo.arguments.contains("-iconPicker")
    @State private var showSettings = ProcessInfo.processInfo.arguments.contains("-iconPicker")
        || ProcessInfo.processInfo.arguments.contains("-settings")
    #else
    private let openIconPicker = false
    @State private var showSettings = false
    #endif
    @State private var demoStarted = false
    /// Set by widget deep links (`earprint://card/<id>`). Optional so previews work without it.
    @Environment(DeepLinkRouter.self) private var router: DeepLinkRouter?
    @Environment(DeviceColorStore.self) private var colorStore: DeviceColorStore?
    @Environment(ActiveAudioRouteMonitor.self) private var routeMonitor: ActiveAudioRouteMonitor?
    @State private var space = LayoutSpace()

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
        .sheet(isPresented: $showSettings) {
            SettingsView(ownedCards: cards, openIconPicker: openIconPicker)
                .presentationDragIndicator(.visible)
        }
        .task { await runDemoIfNeeded() }
        .onAppear(perform: openPendingCard)
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
        return ZStack {
            if selected != card {
                CardHorizontalFront(card: card, colorOption: color, isCurrentlyWorn: worn)
                    .matchedGeometryEffect(id: card.id, in: hero)
                    .shadow(color: card.rarity.glow.opacity(0.32), radius: 16, y: 8)
                    .transition(.identity)
            } else {
                Color.clear.frame(height: 188)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { selected = card }
        }
    }

    private func verticalThumbnail(_ card: HeadphoneCard) -> some View {
        let color = colorStore?.selectedColor(for: card)
        let worn = routeMonitor?.isCurrentlyWorn(card) ?? false
        return ZStack {
            if selected != card {
                ScaledCard { CardFront(card: card, colorOption: color, isCurrentlyWorn: worn, showsChargingCase: false) }
                    .matchedGeometryEffect(id: card.id, in: hero)
                    .shadow(color: card.rarity.glow.opacity(0.35), radius: 14, y: 8)
                    .transition(.identity)
            } else {
                Color.clear.aspectRatio(CardMetrics.size.width / CardMetrics.size.height, contentMode: .fit)
            }
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { selected = card }
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

    static func isUnlocked(_ entry: Entry, ownedCards: [HeadphoneCard]) -> Bool {
        guard entry.family != .generic else { return false }
        let target = entry.model.marketingName.lowercased()
        return ownedCards.contains { $0.model.lowercased() == target }
    }

    static func unlockedCount(for ownedCards: [HeadphoneCard]) -> Int {
        allEntries.filter { isUnlocked($0, ownedCards: ownedCards) }.count
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

    private var unlockedCardIDs: Set<String> {
        Set(ModelGalleryCatalog.allEntries.filter { ModelGalleryCatalog.isUnlocked($0, ownedCards: ownedCards) }.map(\.id))
    }

    private var catalogDetailsByCardID: [String: String] {
        Dictionary(uniqueKeysWithValues: ModelGalleryCatalog.allEntries.compactMap { entry in
            entry.productIDSummary.map { (entry.id, $0) }
        })
    }

    var body: some View {
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
                            Text("\(unlockedCardIDs.count) of \(ModelGalleryCatalog.allAppleAndBeatsCount) unlocked")
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
                            let unlocked = unlockedCardIDs.contains(entry.id)
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
                    unlockedPreviewIDs: unlockedCardIDs,
                    catalogDetails: catalogDetailsByCardID,
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
struct CardStackPose: Equatable {
    var offsetX: CGFloat
    var offsetY: CGFloat
    var scale: CGFloat
    var rotationDegrees: Double
    var opacity: Double
    var zIndex: Double

    static func pose(forDelta d: CGFloat) -> CardStackPose {
        if d < 0 {
            let p = min(1.5, -d)
            return CardStackPose(
                offsetX: -p * 340,
                offsetY: p * 22,
                scale: 1.0,
                rotationDegrees: Double(-p * 15),
                opacity: max(0, Double(1 - p * 0.96)),
                zIndex: 120 - Double(p * 10)
            )
        } else {
            let depth = min(2.6, d)
            return CardStackPose(
                offsetX: depth * 15,
                offsetY: depth * 14,
                scale: max(0.80, 1 - depth * 0.08),
                rotationDegrees: Double(depth * 3.2),
                opacity: max(0, Double(1 - depth * 0.34)),
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
    var colorStore: DeviceColorStore? = nil
    var routeMonitor: ActiveAudioRouteMonitor? = nil
    var onSelectCard: (HeadphoneCard) -> Void = { _ in }
    var openDossier: () -> Void = {}
    let close: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("cardDetail.hasSeenFlipHint") private var hasSeenFlipHint = false
    @State private var showsFlipHintThisVisit = false
    @StateObject private var motion = TiltMotion()
    @State private var flipped = false
    @State private var angle: Double = 0
    @State private var dragAngle: Double = 0
    @State private var dragTilt: CGSize = .zero
    @State private var modelInteractionTilt: CGSize?
    /// Continuous visual index across `deckCards` (`0.0` = card 0, `1.0` = card 1, etc.).
    @State private var deckPosition: CGFloat = 0
    @State private var dragStartPosition: CGFloat? = nil
    /// Set when the live 3D model has finished attaching so 2D artwork crossfades smoothly away.
    @State private var ready3DCardID: String? = nil
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

    private var tilt: CGSize {
        modelInteractionTilt ?? (dragTilt == .zero ? motion.tilt : dragTilt)
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
                dragAngle = 0
            }
        }
        .onChange(of: card.id) { _, _ in
            flipped = false
            angle = 0
            dragAngle = 0
            dragTilt = .zero
            modelInteractionTilt = nil
            ready3DCardID = nil
            showColorBar = false
            withAnimation(.spring(response: 0.44, dampingFraction: 0.84)) {
                deckPosition = CGFloat(activeIndex)
            }
        }
        .onAppear {
            deckPosition = CGFloat(activeIndex)
            motion.start()
            withAnimation(.easeOut(duration: 0.35)) { appeared = true }
            Task { await runDemoIfNeeded() }
        }
        .onDisappear { motion.stop() }
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

    /// Only the controls beneath the card handle horizontal paging.
    private var cardNavigationSwipe: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard deckCards.count > 1 else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                guard dragStartPosition != nil || abs(dx) > abs(dy) * 1.05 else { return }

                if dragStartPosition == nil {
                    dragStartPosition = CGFloat(activeIndex)
                    // Keep the live view out of the deck while it is tracking the finger.
                    ready3DCardID = nil
                    motion.stop()
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
                motion.start()
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
        // The preview catalog is much larger than a listening collection. Only lay out the exposed cards.
        let indices = isModelPreview
            ? max(0, activeIndex - 2)..<min(deckCards.count, activeIndex + 5)
            : deckCards.indices
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
        let itemColor = colorStore?.selectedColor(for: item) ?? DeviceColorOption.defaultOption(for: item.modelKey)
        let itemFinish = itemColor?.modelFinish ?? item.finish
        let itemFinishID = itemColor?.id ?? "default"
        let itemWorn = routeMonitor?.isCurrentlyWorn(item) ?? false
        let assetName = item.modelAssetName ?? (isModelPreview ? "" : nil)
        let show3D = isTop && dragStartPosition == nil && assetName != nil
        let is3DReady = show3D && ready3DCardID == item.id
        let revealLift: CGFloat = item.kind == .earbuds ? 12 : 4
        let activeAngle = isTop ? angle + dragAngle : 0
        let activeTilt = isTop ? tilt : .zero

        let catalogBadge: LocalizedStringKey? = isModelPreview
            ? (unlockedPreviewIDs.contains(item.id) ? "UNLOCKED" : "CATALOG")
            : nil

        return ZStack {
            ZStack {
                CardFront(
                    card: item,
                    tilt: activeTilt,
                    showSymbol: !is3DReady,
                    colorOption: itemColor,
                    isCurrentlyWorn: itemWorn,
                    usesProductArtwork: !isModelPreview || item.modelAssetName != nil,
                    showsListeningStats: !isModelPreview,
                    badgeOverride: catalogBadge,
                    catalogDetail: isModelPreview ? catalogDetails[item.id] : nil
                )
                .contentShape(RoundedRectangle(cornerRadius: CardMetrics.corner))
                .gesture(isTop ? cardDrag : nil)

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
                        tint: item.foilTint,
                        tilt: activeTilt,
                        onManipulationChanged: { manipulating in
                            modelInteractionTilt = manipulating ? tilt : nil
                        },
                        onModelReady: {
                            withAnimation(.easeOut(duration: reduceMotion ? 0.10 : 0.18)) {
                                ready3DCardID = item.id
                            }
                        }
                    )
                    .frame(width: 300, height: 230)
                    .scaleEffect(is3DReady || reduceMotion ? 1 : 0.96)
                    .offset(y: -47 + (is3DReady || reduceMotion ? 0 : revealLift))
                    .opacity(is3DReady ? 1 : 0)
                    .allowsHitTesting(is3DReady)
                    .accessibilityHidden(!is3DReady)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: CardMetrics.corner))
            .onTapGesture { if canFlip { flip() } }
            .accessibilityElement(children: .contain)
            .accessibilityAction(named: Text("Flip card")) { if canFlip { flip() } }
            .allowsHitTesting(!flipped)
            .accessibilityHidden(flipped || !isTop)
            .modifier(CardFaceRotation(angle: activeAngle))

            if isTop && canFlip {
                CardBack(card: item, openDossier: flipped && !isModelPreview ? openDossier : nil, flip: { flip() })
                    .contentShape(RoundedRectangle(cornerRadius: CardMetrics.corner))
                    .simultaneousGesture(cardDrag)
                    .allowsHitTesting(flipped)
                    .accessibilityHidden(!flipped)
                    .modifier(CardFaceRotation(angle: activeAngle, isBack: true))
            }
        }
        .scaleEffect(scale)
        .frame(width: CardMetrics.size.width * scale, height: CardMetrics.size.height * scale)
        .rotation3DEffect(.degrees(Double(activeTilt.width) * 12), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .rotation3DEffect(.degrees(Double(-activeTilt.height) * 12), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
        .shadow(
            color: isTop ? item.rarity.glow.opacity(0.52) : .black.opacity(0.45),
            radius: isTop ? 28 : 20,
            x: isTop ? -activeTilt.width * 14 : 0,
            y: isTop ? 18 - activeTilt.height * 10 : 12
        )
        .allowsHitTesting(isTop)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.8), trigger: flipped)
    }

    private func backCard(scale: CGFloat) -> some View {
        let scale = max(scale, 0.3)
        return CardBack(card: card, openDossier: isModelPreview ? nil : openDossier)
            .id(card.id)
            .scaleEffect(scale)
            .frame(width: CardMetrics.size.width * scale, height: CardMetrics.size.height * scale)
            .shadow(color: card.rarity.glow.opacity(0.4), radius: 24, y: 14)
            .opacity(appeared ? 1 : 0)
    }

    private var cardControls: some View {
        let showHints = repeatsFlipHint || showsFlipHintThisVisit
        return VStack(spacing: 6) {
            if canShowFlipHint && showHints {
                Text("Tap or swipe the card to flip")
                    .font(.caption)
            }
            if deckCards.count > 1 {
                VStack(spacing: 8) {
                    if showHints || isModelPreview {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 9, weight: .semibold))
                            Text("Swipe here to switch cards")
                                .font(.caption)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.60))
                    }
                    deckPageIndicator
                }
                .frame(maxWidth: 340)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
                .gesture(cardNavigationSwipe)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Swipe here to switch cards"))
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

    private var cardDrag: some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .onChanged { value in
                let translation = value.translation
                if canFlip && CardFlipDirection.isHorizontal(translation) {
                    dragAngle = max(-68, min(68, Double(translation.width) * 0.56))
                    dragTilt = .zero
                } else {
                    dragAngle = 0
                    dragTilt = CGSize(width: max(-1, min(1, translation.width / 120)),
                                      height: max(-1, min(1, translation.height / 160)))
                }
            }
            .onEnded { value in
                if canFlip, let direction = CardFlipDirection.swipe(
                    translation: value.translation, predicted: value.predictedEndTranslation
                ) {
                    flip(direction)
                } else {
                    withAnimation(.snappy(duration: 0.32, extraBounce: 0)) {
                        dragAngle = 0
                        dragTilt = .zero
                    }
                }
            }
    }

    private func flip(_ direction: CardFlipDirection = .left) {
        // Side by side already shows both faces, and Model Gallery catalog cards have no stats back.
        guard canFlip else { return }
        withAnimation(.snappy(duration: 0.38, extraBounce: 0)) {
            flipped.toggle()
            angle += direction.rawValue
            dragAngle = 0
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
