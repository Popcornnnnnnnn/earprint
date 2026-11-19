import SwiftUI

struct CollectionView: View {
    let cards: [HeadphoneCard]
    @Namespace private var hero
    @State private var selected: HeadphoneCard?
    @State private var demoStarted = false
    @State private var space = LayoutSpace()

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()

            ScrollView {
                // Columns follow the width: 2 on iPhone & inner portrait, 4 on inner landscape, even on a foldable display.
                let grid = AdaptiveGrid(space: space, padding: 18, spacing: 14, minItemWidth: 170)
                VStack(alignment: .leading, spacing: 18) {
                    header
                        .padding(.horizontal, 18)
                    LazyVGrid(columns: grid.columns, spacing: 14) {
                        ForEach(cards) { card in
                            thumbnail(card)
                        }
                        lockedSlot
                    }
                    .padding(.leading, grid.leadingPadding)
                    .padding(.trailing, grid.trailingPadding)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .readLayoutSpace($space)

            if let card = selected {
                CardDetail(card: card, namespace: hero) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { selected = nil }
                }
                .zIndex(1)
            }
        }
        .foregroundStyle(.white)
        .task { await runDemoIfNeeded() }
    }

    private var header: some View {
        let total = cards.reduce(0) { $0 + $1.lifetimeMinutes }
        return VStack(alignment: .leading, spacing: 6) {
            Text("My headphones").font(.system(size: 30, weight: .heavy))
            Text("\(cards.count) cards · \(total.minutesText) together")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.top, 12)
    }

    private func thumbnail(_ card: HeadphoneCard) -> some View {
        ZStack {
            if selected != card {
                ScaledCard { CardFront(card: card) }
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

    private var lockedSlot: some View {
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

    /// `-demo` launch argument: open the first card so a screen recording shows the motion.
    private func runDemoIfNeeded() async {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-demo"), !demoStarted, !cards.isEmpty else { return }
        demoStarted = true
        var index = 0
        if let i = args.firstIndex(of: "-demoIndex"), i + 1 < args.count, let n = Int(args[i + 1]) { index = min(n, cards.count - 1) }
        try? await Task.sleep(for: .seconds(1.2))
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { selected = cards[index] }
    }
}

struct CardDetail: View {
    let card: HeadphoneCard
    let namespace: Namespace.ID
    let close: () -> Void

    @StateObject private var motion = TiltMotion()
    @State private var flipped = false
    @State private var angle: Double = 0
    @State private var dragTilt: CGSize = .zero
    @State private var appeared = false
    @State private var space = LayoutSpace()

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
                .onTapGesture(perform: close)

            layout
        }
        .readLayoutSpace($space)
        .onChange(of: mode) { _, newMode in
            // Side by side already shows the back, so keep the left card on its front.
            if newMode == .sideBySide && flipped { flip(force: true) }
        }
        .onAppear {
            motion.start()
            withAnimation(.easeOut(duration: 0.35)) { appeared = true }
            Task { await runDemoIfNeeded() }
        }
        .onDisappear { motion.stop() }
    }

    @ViewBuilder private var layout: some View {
        let design = CardMetrics.size
        let size = space.size
        switch mode {
        case .single:
            // Text + buttons take about 120 pt. Never grow on phones; grow a little on big screens.
            let scale = min(space.isWide ? 1.35 : 1, (size.height - 120) / design.height, (size.width - 40) / design.width)
            VStack(spacing: 22) {
                interactiveCard(scale: scale)
                hint
                buttons
            }
        case .besideControls:
            let scale = min(1, (size.height - 24) / design.height, (size.width * 0.6) / design.width)
            HStack(spacing: 32) {
                interactiveCard(scale: scale)
                VStack(spacing: 18) {
                    hint
                    buttons
                }
            }
        case .sideBySide:
            let split = ColumnSplit(space: space, padding: 24, gap: 36)
            let scale = min(1.35, min(split.leading, split.trailing) / design.width, (size.height - 116) / design.height)
            HStack(alignment: .top, spacing: split.gap) {
                VStack(spacing: 18) {
                    interactiveCard(scale: scale)
                    hint
                        .frame(minHeight: 42)
                }
                .frame(width: split.leading)
                VStack(spacing: 18) {
                    backCard(scale: scale)
                    buttons
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
                    .frame(maxWidth: .infinity, maxHeight: fold.minY)
                Color.clear.frame(height: fold.height)
                VStack(spacing: 16) {
                    hint
                    buttons
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func interactiveCard(scale: CGFloat) -> some View {
        let scale = max(scale, 0.3)
        return flipCard
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
            .scaleEffect(scale)
            .frame(width: CardMetrics.size.width * scale, height: CardMetrics.size.height * scale)
            .shadow(color: card.rarity.glow.opacity(0.4), radius: 24, y: 14)
            .opacity(appeared ? 1 : 0)
    }

    private var hint: some View {
        Text(mode == .sideBySide ? "Drag or tilt your phone" : flipped ? "Tap to flip back" : "Tap to flip · tilt your phone")
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.5))
            .opacity(appeared ? 1 : 0)
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            pillButton("Share card", "square.and.arrow.up")
            pillButton("Close", "xmark", action: close)
        }
        .opacity(appeared ? 1 : 0)
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

    /// The card front with a live 3D model that pops out above the card's top edge.
    private var frontWithModel: some View {
        ZStack {
            CardFront(card: card, tilt: tilt, showSymbol: false)
            Ellipse()
                .fill(.black.opacity(0.35))
                .frame(width: 150, height: 18)
                .blur(radius: 10)
                .offset(x: -tilt.width * 10, y: 40)
            HeadphoneModelView(kind: card.headphoneKind, finish: card.finish, tint: card.foilTint, tilt: tilt)
                .frame(width: 340, height: 300)
                .offset(y: -62)
        }
    }

    private var dragToTilt: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                dragTilt = CGSize(width: max(-1, min(1, value.translation.width / 120)),
                                  height: max(-1, min(1, value.translation.height / 160)))
            }
            .onEnded { value in
                if abs(value.translation.width) > 140 {
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

    private func pillButton(_ title: String, _ icon: String, action: @escaping () -> Void = {}) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
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
