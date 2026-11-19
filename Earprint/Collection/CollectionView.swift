import SwiftUI

struct CollectionView: View {
    let cards: [HeadphoneCard]
    @Namespace private var hero
    @State private var selected: HeadphoneCard?
    @State private var dossierCard: HeadphoneCard?
    @State private var demoStarted = false

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(cards) { card in
                            thumbnail(card)
                        }
                        lockedSlot
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)

            if let card = selected {
                CardDetail(card: card, namespace: hero, openDossier: {
                    dossierCard = card
                }) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { selected = nil }
                }
                .zIndex(1)
            }
        }
        .foregroundStyle(.white)
        .fullScreenCover(item: $dossierCard) { card in
            DeviceDossierView(card: card) { dossierCard = nil }
        }
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
                    Text("Connect new headphones\nto unlock a card").font(.caption2).multilineTextAlignment(.center)
                }
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

struct CardDetail: View {
    let card: HeadphoneCard
    let namespace: Namespace.ID
    var openDossier: () -> Void = {}
    let close: () -> Void

    @StateObject private var motion = TiltMotion()
    @State private var flipped = false
    @State private var angle: Double = 0
    @State private var dragTilt: CGSize = .zero
    @State private var appeared = false

    private var tilt: CGSize {
        dragTilt == .zero ? motion.tilt : dragTilt
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.55))
                .ignoresSafeArea()
                .opacity(appeared ? 1 : 0)
                .onTapGesture(perform: close)

            VStack(spacing: 22) {
                flipCard
                    .matchedGeometryEffect(id: card.id, in: namespace)
                    .frame(width: CardMetrics.size.width, height: CardMetrics.size.height)
                    .rotation3DEffect(.degrees(Double(tilt.width) * 12), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                    .rotation3DEffect(.degrees(Double(-tilt.height) * 12), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                    .shadow(color: card.rarity.glow.opacity(0.55), radius: 30, x: -tilt.width * 14, y: 18 - tilt.height * 10)
                    .gesture(dragToTilt)
                    .onTapGesture(perform: flip)
                    .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.8), trigger: flipped)

                Text(flipped ? "Tap to flip back" : "Tap to flip · swipe up for dossier")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
                    .opacity(appeared ? 1 : 0)

                HStack(spacing: 10) {
                    pillButton("Dossier", "doc.text.magnifyingglass", highlighted: true, action: openDossier)
                    pillButton("Share card", "square.and.arrow.up")
                    pillButton("Close", "xmark", action: close)
                }
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            motion.start()
            withAnimation(.easeOut(duration: 0.35)) { appeared = true }
            Task { await runDemoIfNeeded() }
        }
        .onDisappear { motion.stop() }
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
                if value.translation.height < -90 && abs(value.translation.height) > abs(value.translation.width) * 1.4 {
                    openDossier()
                } else if abs(value.translation.width) > 140 {
                    flip()
                }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { dragTilt = .zero }
            }
    }

    private func flip() {
        flipped.toggle()
        withAnimation(.spring(response: 0.7, dampingFraction: 0.72)) {
            angle += 180
        }
    }

    private func pillButton(_ title: String, _ icon: String, highlighted: Bool = false, action: @escaping () -> Void = {}) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 15).padding(.vertical, 12)
                .foregroundStyle(highlighted ? card.rarity.ink : .white)
                .background {
                    if highlighted {
                        Capsule().fill(card.rarity.foil)
                    } else {
                        Capsule().fill(.white.opacity(0.12))
                    }
                }
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
