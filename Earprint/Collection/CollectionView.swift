import SwiftUI

struct CollectionView: View {
    let cards: [HeadphoneCard]
    var isSampleData: Bool = false
    var sampleBadgeText: String = "Sample data"
    var statusMessage: String? = nil
    var isLoading: Bool = false
    var onConnectHealth: (() -> Void)? = nil

    @Namespace private var hero
    @State private var selected: HeadphoneCard?
    @State private var dossierCard: HeadphoneCard?
    @State private var showIconPicker = false
    @State private var iconManager = AppIconManager()
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

            if let card = selected {
                CardDetail(
                    card: card,
                    cards: cards,
                    namespace: hero,
                    colorStore: colorStore,
                    isCurrentlyWorn: routeMonitor?.isCurrentlyWorn(card) ?? false,
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
            DeviceDossierView(card: card) { dossierCard = nil }
        }
        .sheet(isPresented: $showIconPicker) {
            AppIconPickerSheet(manager: iconManager)
                .presentationDetents([.fraction(0.90), .large])
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
        if let card = cards.first(where: { $0.id == id }) {
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
                Text(cards.isEmpty ? "Listening archive" : "\(cards.count) cards · \(total.minutesText) together")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 8)
            Button {
                showIconPicker = true
            } label: {
                AppIconThumbnail(choice: iconManager.current, size: 38)
                    .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change app icon")
        }
        .padding(.top, 12)
    }

    private var emptyCollectionState: some View {
        VStack(spacing: 14) {
            Image(systemName: "headphones")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.white.opacity(0.45))
            Text(isLoading ? "Reading Apple Health…" : "No headphones recorded yet")
                .font(.headline)
            Text("Wear your AirPods or Beats while listening and Earprint will mint a collectible card automatically.")
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
                ScaledCard { CardFront(card: card, colorOption: color, isCurrentlyWorn: worn) }
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
                        Text("Connect new headphones to unlock a collectible card")
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
                    Text("Connect new headphones\nto unlock a card")
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
        if args.contains("-iconPicker") {
            demoStarted = true
            showIconPicker = true
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

/// Pure helper for switching between cards in `CardDetail` via outside-the-card horizontal swipes.
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

struct CardDetail: View {
    let card: HeadphoneCard
    var cards: [HeadphoneCard] = []
    let namespace: Namespace.ID
    var colorStore: DeviceColorStore? = nil
    var isCurrentlyWorn: Bool = false
    var onSelectCard: (HeadphoneCard) -> Void = { _ in }
    var openDossier: () -> Void = {}
    let close: () -> Void

    @StateObject private var motion = TiltMotion()
    @State private var flipped = false
    @State private var angle: Double = 0
    @State private var dragTilt: CGSize = .zero
    @State private var backdropDragX: CGFloat = 0
    @State private var slideDirection: CGFloat = 1
    @State private var appeared = false
    @State private var showColorBar = ProcessInfo.processInfo.arguments.contains("-showColors")
    @State private var space = LayoutSpace()

    private var availableColors: [DeviceColorOption] {
        colorStore?.availableColors(for: card) ?? DeviceColorOption.options(for: card.modelKey)
    }

    private var selectedColor: DeviceColorOption? {
        colorStore?.selectedColor(for: card) ?? DeviceColorOption.defaultOption(for: card.modelKey)
    }

    private var resolvedFinish: HeadphoneFinish {
        selectedColor?.modelFinish ?? card.finish
    }

    private var resolvedFinishID: String {
        selectedColor?.id ?? "default"
    }

    private var currentCardIndex: Int? {
        CardDeckNavigation.index(of: card, in: cards)
    }

    private var tilt: CGSize {
        dragTilt == .zero ? motion.tilt : dragTilt
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
        if space.verticalFold != nil { return .sideBySide }
        if space.isWide {
            let split = ColumnSplit(space: space, padding: 24, gap: 36)
            let fits = min(split.leading, split.trailing) / CardMetrics.size.width >= 0.85
                && (space.size.height - 116) / CardMetrics.size.height >= 0.85
            if fits { return .sideBySide }
        }
        if space.isLandscape && space.size.height < 600 { return .besideControls }
        return .single
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
                .gesture(backdropSwipe)

            layout
                .offset(x: backdropDragX)
        }
        .overlay(alignment: .topTrailing) {
            topCloseButton
        }
        .readLayoutSpace($space)
        .onChange(of: mode) { _, newMode in
            // Side by side already shows the back, so keep the left card on its front.
            if newMode == .sideBySide && flipped { flip(force: true) }
        }
        .onChange(of: card.id) { _, _ in
            flipped = false
            angle = 0
            dragTilt = .zero
            showColorBar = false
        }
        .onAppear {
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

    /// Horizontal swipe on the backdrop outside the card switches between headphones.
    private var backdropSwipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                guard cards.count > 1 else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > abs(dy) * 1.1 else { return }
                let canMove = (dx < 0 && CardDeckNavigation.neighbor(of: card, in: cards, step: 1) != nil)
                    || (dx > 0 && CardDeckNavigation.neighbor(of: card, in: cards, step: -1) != nil)
                backdropDragX = canMove ? dx * 0.42 : dx * 0.14
            }
            .onEnded { value in
                guard cards.count > 1 else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { backdropDragX = 0 }
                    return
                }
                let dx = value.translation.width
                let predicted = value.predictedEndTranslation.width
                let dy = value.translation.height
                let isHorizontal = abs(dx) > abs(dy) * 1.1

                let step: Int? = if isHorizontal && (dx < -55 || predicted < -140) {
                    1
                } else if isHorizontal && (dx > 55 || predicted > 140) {
                    -1
                } else {
                    nil
                }

                if let step, let next = CardDeckNavigation.neighbor(of: card, in: cards, step: step) {
                    slideDirection = CGFloat(step)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                        backdropDragX = 0
                        onSelectCard(next)
                    }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        backdropDragX = 0
                    }
                }
            }
    }

    @ViewBuilder private var layout: some View {
        let design = CardMetrics.size
        let size = space.size
        switch mode {
        case .single:
            let controlsHeight: CGFloat = availableColors.count > 1 ? (showColorBar ? 176 : 126) : 76
            let scale = min(space.isWide ? 1.35 : 1, (size.height - controlsHeight) / design.height, (size.width - 40) / design.width)
            VStack(spacing: 18) {
                interactiveCard(scale: scale)
                hintAndDots
                colorControls
            }
        case .besideControls:
            let scale = min(1, (size.height - 24) / design.height, (size.width * 0.6) / design.width)
            HStack(spacing: 32) {
                interactiveCard(scale: scale)
                VStack(spacing: 18) {
                    hintAndDots
                    colorControls
                }
            }
        case .sideBySide:
            let split = ColumnSplit(space: space, padding: 24, gap: 36)
            let scale = min(1.35, min(split.leading, split.trailing) / design.width, (size.height - 116) / design.height)
            HStack(alignment: .top, spacing: split.gap) {
                VStack(spacing: 18) {
                    interactiveCard(scale: scale)
                    hintAndDots
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
                interactiveCard(scale: scale)
                    .frame(maxWidth: .infinity)
                    .frame(height: max(0, fold.minY))
                Color.clear.frame(height: fold.height)
                VStack(spacing: 16) {
                    hintAndDots
                    colorControls
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func interactiveCard(scale: CGFloat) -> some View {
        let scale = max(scale, 0.3)
        let cardTransition = AnyTransition.asymmetric(
            insertion: .move(edge: slideDirection >= 0 ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: slideDirection >= 0 ? .leading : .trailing).combined(with: .opacity)
        )
        return flipCard
            .id(card.id)
            .transition(cardTransition)
            .scaleEffect(scale)
            .frame(width: CardMetrics.size.width * scale, height: CardMetrics.size.height * scale)
            .matchedGeometryEffect(id: card.id, in: namespace)
            .rotation3DEffect(.degrees(Double(tilt.width) * 12), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(Double(-tilt.height) * 12), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .shadow(color: card.rarity.glow.opacity(0.55), radius: 30, x: -tilt.width * 14, y: 18 - tilt.height * 10)
            .gesture(dragToTilt)
            .onTapGesture { flip() }
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.8), trigger: flipped)
    }

    private func backCard(scale: CGFloat) -> some View {
        let scale = max(scale, 0.3)
        return CardBack(card: card, revealed: appeared)
            .id(card.id)
            .scaleEffect(scale)
            .frame(width: CardMetrics.size.width * scale, height: CardMetrics.size.height * scale)
            .shadow(color: card.rarity.glow.opacity(0.4), radius: 24, y: 14)
            .opacity(appeared ? 1 : 0)
    }

    private var hintAndDots: some View {
        VStack(spacing: 10) {
            Text(mode == .sideBySide ? "Drag or tilt · swipe up for dossier" : flipped ? "Tap to flip back" : "Tap to flip · swipe up for dossier")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.52))
            if cards.count > 1, let activeIndex = currentCardIndex {
                HStack(spacing: 6) {
                    ForEach(cards.indices, id: \.self) { idx in
                        Capsule()
                            .fill(idx == activeIndex ? Color.white.opacity(0.85) : Color.white.opacity(0.24))
                            .frame(width: idx == activeIndex ? 16 : 6, height: 6)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: activeIndex)
            }
        }
        .opacity(appeared ? 1 : 0)
        .allowsHitTesting(false)
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
                Text(active.title)
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
        .accessibilityLabel("Change device color, currently \(active.title)")
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
                    .accessibilityLabel(option.title)
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

    private var flipCard: some View {
        ZStack {
            frontWithModel
                .opacity(angle.truncatingRemainder(dividingBy: 360) < 90 || angle.truncatingRemainder(dividingBy: 360) > 270 ? 1 : 0)
            CardBack(card: card, revealed: flipped)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(angle.truncatingRemainder(dividingBy: 360) >= 90 && angle.truncatingRemainder(dividingBy: 360) <= 270 ? 1 : 0)
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
    }

    /// The card front with a live 3D model framed cleanly in the upper stage, clear of name & hours below.
    private var frontWithModel: some View {
        ZStack {
            CardFront(card: card, tilt: tilt, showSymbol: false, colorOption: selectedColor, isCurrentlyWorn: isCurrentlyWorn)
            Ellipse()
                .fill(.black.opacity(0.30))
                .frame(width: 136, height: 16)
                .blur(radius: 10)
                .offset(x: -tilt.width * 8, y: 20)
            HeadphoneModelView(
                kind: card.kind,
                finish: resolvedFinish,
                finishID: resolvedFinishID,
                modelKey: card.modelKey,
                assetName: card.modelAssetName,
                modelSize: 0.145,
                tint: card.foilTint,
                tilt: tilt
            )
            .id(card.id)
            .frame(width: 300, height: 230)
            .offset(y: -64)
        }
    }

    private var dragToTilt: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                dragTilt = CGSize(width: max(-1, min(1, value.translation.width / 120)),
                                  height: max(-1, min(1, value.translation.height / 160)))
            }
            .onEnded { value in
                if value.translation.height < -90 && abs(value.translation.height) > abs(value.translation.width) * 1.4 {
                    openDossier()
                } else if abs(value.translation.width) > 140 {
                    flip()
                }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { dragTilt = .zero }
            }
    }

    private func flip(force: Bool = false) {
        // Side by side shows both faces at once, so there is nothing to flip.
        guard force || mode != .sideBySide else { return }
        flipped.toggle()
        withAnimation(.spring(response: 0.7, dampingFraction: 0.72)) {
            angle += 180
        }
    }

    /// With `-demo`, play tilt and flip so the simulator recording shows every effect.
    private func runDemoIfNeeded() async {
        guard ProcessInfo.processInfo.arguments.contains("-demo") else { return }
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
