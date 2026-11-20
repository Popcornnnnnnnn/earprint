import SwiftUI

/// Design size of a card. Thumbnails render at this size and scale down, so every card looks identical at any size.
enum CardMetrics {
    static let size = CGSize(width: 300, height: 440)
    static let corner: CGFloat = 26
}

/// Keep each face visible only while it faces the viewer, using the angle of the current frame.
struct CardFaceRotation: ViewModifier, Animatable {
    var angle: Double
    var isBack = false

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        let showsFront = cos(angle * .pi / 180) > 0
        content
            .opacity(showsFront == isBack ? 0 : 1)
            .rotation3DEffect(.degrees(angle + (isBack ? 180 : 0)), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
    }
}

/// Static micro-texture for `FoilSurface`, isolated as `Equatable` so tilt changes never redraw the Canvas.
private struct FoilTexturePattern: View, Equatable {
    let material: FoilMaterial

    var body: some View {
        Canvas { context, size in
            switch material {
            case .brushed:
                var path = Path()
                stride(from: CGFloat(0), to: size.height, by: 3.5).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(.white.opacity(0.065)), lineWidth: 0.75)

            case .carbon:
                var pathA = Path()
                stride(from: -size.height, to: size.width + size.height, by: 7).forEach { x in
                    pathA.move(to: CGPoint(x: x, y: size.height))
                    pathA.addLine(to: CGPoint(x: x + size.height, y: 0))
                    pathA.move(to: CGPoint(x: x, y: 0))
                    pathA.addLine(to: CGPoint(x: x + size.height, y: size.height))
                }
                context.stroke(pathA, with: .color(.white.opacity(0.055)), lineWidth: 1)

            case .matteGrain, .frosted, .satin, .faceted, .holo:
                var path = Path()
                stride(from: -size.height, to: size.width, by: 5).forEach { x in
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x + size.height, y: 0))
                }
                let lineOpacity: Double = switch material {
                case .holo: 0.10
                case .matteGrain, .frosted: 0.04
                default: 0.06
                }
                context.stroke(path, with: .color(.white.opacity(lineOpacity)), lineWidth: 1)
            }
        }
    }
}

/// Foil surface: base gradient + finish-specific micro texture + prism sheen + specular highlight that move with tilt.
struct FoilSurface: View {
    let rarity: Rarity
    var tilt: CGSize = .zero

    var body: some View {
        ZStack {
            AngularGradient(colors: rarity.baseColors, center: UnitPoint(x: 0.5 + tilt.width * 0.3, y: 0.4 + tilt.height * 0.3),
                            angle: .degrees(200 + tilt.width * 60))

            // Distinct surface finish pattern matching each tier's material craft (static, never redrawn on tilt).
            FoilTexturePattern(material: rarity.material)
                .equatable()

            if rarity.material == .faceted {
                LinearGradient(
                    colors: [.clear, .white.opacity(0.16), .clear, .white.opacity(0.12), .clear],
                    startPoint: UnitPoint(x: 0.0 + tilt.width * 0.4, y: 0.1),
                    endPoint: UnitPoint(x: 1.0 + tilt.width * 0.4, y: 0.9)
                )
                .blendMode(.overlay)
            } else if rarity.material == .satin {
                LinearGradient(
                    colors: [.clear, .white.opacity(0.18), .clear],
                    startPoint: UnitPoint(x: 0.1 + tilt.width * 0.5, y: 0),
                    endPoint: UnitPoint(x: 0.9 + tilt.width * 0.5, y: 1)
                )
                .blendMode(.softLight)
            } else if rarity.material == .carbon {
                RadialGradient(
                    colors: [.clear, Color.black.opacity(0.32)],
                    center: .center,
                    startRadius: 40,
                    endRadius: 240
                )
            }

            if rarity.sheenOpacity > 0 {
                LinearGradient(colors: [.clear, .pink.opacity(0.35), .yellow.opacity(0.3), .cyan.opacity(0.35), .purple.opacity(0.3), .clear],
                               startPoint: UnitPoint(x: -0.2 + tilt.width * 0.6, y: 0),
                               endPoint: UnitPoint(x: 1.2 + tilt.width * 0.6, y: 1))
                    .blendMode(.colorDodge)
                    .opacity(rarity.sheenOpacity)
            }

            // Specular highlight that slides across as the card tilts.
            LinearGradient(colors: [.clear, .white.opacity(rarity.material == .matteGrain ? 0.35 : 0.55), .clear],
                           startPoint: UnitPoint(x: 0.1 + tilt.width * 0.8, y: 0.0 + tilt.height * 0.5),
                           endPoint: UnitPoint(x: 0.6 + tilt.width * 0.8, y: 0.7 + tilt.height * 0.5))
                .blendMode(.overlay)
        }
    }
}

/// Subtle LED-style green indicator shown quietly on a card when that pair is currently connected/worn.
struct ActiveWearDot: View {
    var body: some View {
        Circle()
            .fill(Color(red: 0.20, green: 0.84, blue: 0.44))
            .frame(width: 7, height: 7)
            .shadow(color: Color(red: 0.20, green: 0.84, blue: 0.44).opacity(0.65), radius: 3.5)
            .accessibilityLabel("Currently connected")
    }
}

/// Caches asset catalog presence checks so `HeadphoneArtwork` doesn't probe `UIImage(named:)` repeatedly during scrolling.
@MainActor
private enum ArtworkAssetCache {
    private static var availability: [String: Bool] = [:]

    static func exists(_ name: String) -> Bool {
        if let cached = availability[name] { return cached }
        let present = UIImage(named: name) != nil
        availability[name] = present
        return present
    }
}

/// Realistic transparent 3D product render for a headphone card (used on card faces & thumbnails).
struct HeadphoneArtwork: View {
    let card: HeadphoneCard
    var colorOption: DeviceColorOption? = nil
    var showsChargingCase = true
    var usesProductArtwork = true
    var showsShadow = true

    private var assetName: String? {
        guard usesProductArtwork else { return nil }
        if let custom = colorOption?.cardAssetName, ArtworkAssetCache.exists(custom) {
            return custom
        }
        let fallback = showsChargingCase ? card.modelKey.collectibleArtwork : card.modelKey.collectionArtwork
        if let fallback, ArtworkAssetCache.exists(fallback) {
            return fallback
        }
        return nil
    }

    var body: some View {
        if let assetName {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .shadow(color: showsShadow ? .black.opacity(0.28) : .clear, radius: showsShadow ? 9 : 0, y: showsShadow ? 6 : 0)
        } else {
            Image(systemName: card.symbol)
                .font(.system(size: 100, weight: .thin))
                .foregroundStyle(card.rarity.ink.opacity(0.85))
        }
    }
}

/// Full-width horizontal collector card used in the main Collection list on standard iPhones.
struct CardHorizontalFront: View {
    let card: HeadphoneCard
    var tilt: CGSize = .zero
    var colorOption: DeviceColorOption? = nil
    var isCurrentlyWorn: Bool = false

    var body: some View {
        let ink = card.rarity.ink
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(LocalizedStringKey(card.rarity.title))
                    .font(.system(size: 10.5, weight: .heavy))
                    .tracking(1.4)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(.black.opacity(0.28), in: Capsule())
                    .foregroundStyle(.white)
                Spacer()
                if isCurrentlyWorn {
                    ActiveWearDot()
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 8)
                    Text(card.model)
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(2)

                    Text(card.lifetimeMinutes.minutesText)
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                        .padding(.top, 2)

                    HStack(spacing: 6) {
                        Text("\(card.sessions) sessions")
                        Text("·")
                        Text("since \(card.firstMet)")
                    }
                    .font(.system(size: 11.5, weight: .semibold))
                    .opacity(0.68)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: tilt.width * 2.5, y: tilt.height * 1.8)

                HeadphoneArtwork(card: card, colorOption: colorOption, showsChargingCase: false)
                    .frame(width: 128, height: 128)
                    .offset(x: -tilt.width * 10, y: -tilt.height * 8)
            }
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 188)
        .background(FoilSurface(rarity: card.rarity, tilt: tilt))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.68),
                            .white.opacity(0.18),
                            card.rarity.glow.opacity(0.45),
                            .white.opacity(0.50)
                        ],
                        startPoint: UnitPoint(x: 0.2 + tilt.width * 0.5, y: 0.0 + tilt.height * 0.4),
                        endPoint: UnitPoint(x: 0.8 + tilt.width * 0.5, y: 1.0 + tilt.height * 0.4)
                    ),
                    lineWidth: 1.5
                )
        )
    }
}

struct CardFront: View {
    let card: HeadphoneCard
    var tilt: CGSize = .zero
    /// Hidden when a live 3D model is drawn on top of the card instead.
    var showSymbol = true
    var colorOption: DeviceColorOption? = nil
    var isCurrentlyWorn: Bool = false
    var showsChargingCase = true
    var usesProductArtwork = true
    /// Catalog / Model Gallery cards hide listening hours, session counts, and dates.
    var showsListeningStats = true
    var surfaceRarityOverride: Rarity? = nil
    var badgeOverride: LocalizedStringKey? = nil
    var catalogDetail: String? = nil

    var body: some View {
        let surfaceRarity = surfaceRarityOverride ?? card.rarity
        let ink = surfaceRarity.ink
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(badgeOverride ?? LocalizedStringKey(surfaceRarity.title))
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.6)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(.black.opacity(0.28), in: Capsule())
                    .foregroundStyle(.white)
                Spacer()
                if isCurrentlyWorn {
                    ActiveWearDot()
                }
            }

            Spacer()

            HeadphoneArtwork(card: card, colorOption: colorOption, showsChargingCase: showsChargingCase,
                             usesProductArtwork: usesProductArtwork)
                .frame(height: showsChargingCase ? 186 : 165)
                .opacity(showSymbol ? 1 : 0)
                .offset(x: tilt.width * -8, y: tilt.height * -8)
                .frame(maxWidth: .infinity)

            Spacer()

            if showsListeningStats {
                Text(card.model)
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(card.lifetimeMinutes.minutesText)
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .padding(.top, 2)

                HStack {
                    Label("\(card.sessions)", systemImage: "ear")
                    Spacer()
                    Text("since \(card.firstMet)")
                }
                .font(.system(size: 12, weight: .semibold))
                .opacity(0.7)
                .padding(.top, 6)
            } else {
                Text(card.model)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                if let catalogDetail, !catalogDetail.isEmpty {
                    Text(catalogDetail)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .opacity(0.68)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.top, 5)
                }
            }
        }
        .foregroundStyle(ink)
        .padding(22)
        .frame(width: CardMetrics.size.width, height: CardMetrics.size.height)
        .background(FoilSurface(rarity: surfaceRarity, tilt: tilt))
        .clipShape(RoundedRectangle(cornerRadius: CardMetrics.corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CardMetrics.corner, style: .continuous)
            .strokeBorder(.white.opacity(0.45), lineWidth: 1.5))
    }
}

struct CardBack: View {
    let card: HeadphoneCard
    var openDossier: (() -> Void)? = nil
    var openTiers: (() -> Void)? = nil
    var flip: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let flip {
                stats
                    .contentShape(Rectangle())
                    .onTapGesture(perform: flip)
                    .accessibilityElement(children: .contain)
                    .accessibilityAction(named: Text("Flip card"), flip)
            } else {
                stats
            }
            HStack(spacing: 16) {
                tierProgress
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let openDossier {
                    Button(action: openDossier) {
                        Label("Dossier", systemImage: "doc.text")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(.white.opacity(0.1), in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(width: CardMetrics.size.width, height: CardMetrics.size.height)
        .background(
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.10)
                RadialGradient(colors: [card.rarity.glow.opacity(0.35), .clear], center: .top, startRadius: 0, endRadius: 320)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: CardMetrics.corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CardMetrics.corner, style: .continuous)
            .strokeBorder(LinearGradient(colors: card.rarity.baseColors, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2))
    }

    private var stats: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("STATS").font(.system(size: 11, weight: .heavy)).tracking(2).opacity(0.6)
                Spacer()
                Text(card.model).font(.system(size: 11, weight: .semibold)).opacity(0.6)
            }

            ZStack {
                EarprintGlyph(grid: card.grid, showHourLabels: false)
                    .equatable()
                VStack(spacing: 0) {
                    Text("4 weeks").font(.system(size: 10, weight: .semibold)).opacity(0.6)
                    Text("listening").font(.system(size: 10)).opacity(0.5)
                }
            }
            .frame(height: 150)
            .frame(maxWidth: .infinity)

            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    stat("Lifetime", card.lifetimeMinutes, unit: .minutes)
                    stat("Sessions", Double(card.sessions), unit: .count)
                }
                GridRow {
                    stat("Longest", card.longestMinutes, unit: .minutes)
                    stat("Avg level", card.averageDecibels, unit: .decibels)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private enum Unit { case minutes, count, decibels }

    private func stat(_ title: LocalizedStringKey, _ value: Double, unit: Unit) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 11)).opacity(0.55)
            Group {
                switch unit {
                case .minutes: Text(value.minutesText)
                case .count: Text("\(Int(value))")
                case .decibels: Text("\(Int(value)) dB")
                }
            }
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder private var tierProgress: some View {
        let content = tierProgressBody
        if let openTiers {
            Button(action: openTiers) {
                content
            }
            .buttonStyle(.plain)
            .accessibilityHint("View all card tiers")
        } else {
            content
        }
    }

    @ViewBuilder private var tierProgressBody: some View {
        let hours = card.lifetimeMinutes / 60
        if let next = card.rarity.nextTierHours {
            let remaining = max(1, Int(ceil(next - hours)))
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text("\(remaining)h to next tier").font(.system(size: 11, weight: .semibold)).opacity(0.72)
                    if openTiers != nil {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .opacity(0.55)
                    }
                }
                ProgressView(value: card.rarity.progressToNextTier(minutes: card.lifetimeMinutes))
                    .tint(card.rarity.glow)
            }
        } else {
            HStack(spacing: 5) {
                Text("Max tier reached ✦").font(.system(size: 12, weight: .semibold)).foregroundStyle(card.rarity.glow)
                if openTiers != nil {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(card.rarity.glow.opacity(0.7))
                }
            }
        }
    }
}

/// Renders a design-size card scaled to whatever frame it is given.
struct ScaledCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { geo in
            content
                .scaleEffect(geo.size.width / CardMetrics.size.width, anchor: .topLeading)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .aspectRatio(CardMetrics.size.width / CardMetrics.size.height, contentMode: .fit)
    }
}

/// Tactile press-in 3D tilt/scale spring for collector cards in the Collection list.
struct CollectorCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.968 : 1.0)
            .rotation3DEffect(
                .degrees(configuration.isPressed ? 3.2 : 0),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.7
            )
            .brightness(configuration.isPressed ? 0.03 : 0)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

/// Scroll-driven diagonal specular glint that sweeps smoothly across a collector card as it moves through the viewport.
struct ScrollSheenSweep: View {
    var cornerRadius: CGFloat = 24

    var body: some View {
        Color.clear
            .overlay {
                LinearGradient(
                    colors: [.clear, .white.opacity(0.09), .white.opacity(0.26), .white.opacity(0.09), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 210)
                .rotationEffect(.degrees(20))
                .scaleEffect(y: 2.4)
                .visualEffect { content, proxy in
                    let frame = proxy.frame(in: .scrollView(axis: .vertical))
                    let bounds = proxy.bounds(of: .scrollView(axis: .vertical)) ?? CGRect(x: 0, y: 0, width: 390, height: 800)
                    let progress = bounds.height > 0 ? (frame.midY / bounds.height) * 2 - 1 : 0
                    let clamped = max(-1.3, min(1.3, progress))
                    return content
                        .offset(x: clamped * 220)
                        .opacity(max(0, 1 - abs(clamped) * 0.72))
                }
            }
            .blendMode(.overlay)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .allowsHitTesting(false)
    }
}
