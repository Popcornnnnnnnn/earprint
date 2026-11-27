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
    var carbonOpacity: Double = 0.062

    var body: some View {
        Canvas { context, size in
            switch material {
            case .matteGrain:
                // Bead-blasted anodized micro-stipple (no linear grooves).
                var stipple = Path()
                let step: CGFloat = 6
                var row = 0
                stride(from: CGFloat(1), to: size.height, by: step).forEach { y in
                    let shift: CGFloat = row.isMultiple(of: 2) ? 0 : step * 0.5
                    stride(from: shift + 1, to: size.width, by: step).forEach { x in
                        stipple.addRect(CGRect(x: x, y: y, width: 1.1, height: 1.1))
                    }
                    row += 1
                }
                context.fill(stipple, with: .color(.white.opacity(0.042)))

            case .brushed:
                // Fine horizontal brushed alloy hairlines at subtle alternating weights.
                var primary = Path()
                var secondary = Path()
                var idx = 0
                stride(from: CGFloat(0), to: size.height, by: 3.0).forEach { y in
                    let target = idx.isMultiple(of: 3) ? 0 : 1
                    if target == 0 {
                        primary.move(to: CGPoint(x: 0, y: y))
                        primary.addLine(to: CGPoint(x: size.width, y: y))
                    } else {
                        secondary.move(to: CGPoint(x: 0, y: y))
                        secondary.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    idx += 1
                }
                context.stroke(primary, with: .color(.white.opacity(0.055)), lineWidth: 0.75)
                context.stroke(secondary, with: .color(.white.opacity(0.025)), lineWidth: 0.55)

            case .satin:
                // Ultra-fine vertical silk grain so satin finishes read smooth and directional.
                var path = Path()
                stride(from: CGFloat(0), to: size.width, by: 4.5).forEach { x in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                context.stroke(path, with: .color(.white.opacity(0.028)), lineWidth: 0.6)

            case .carbon:
                // Authentic 2x2 carbon-fiber twill weave.
                var weave = Path()
                stride(from: -size.height, to: size.width + size.height, by: 8.0).forEach { x in
                    weave.move(to: CGPoint(x: x, y: size.height))
                    weave.addLine(to: CGPoint(x: x + size.height, y: 0))
                    weave.move(to: CGPoint(x: x, y: 0))
                    weave.addLine(to: CGPoint(x: x + size.height, y: size.height))
                }
                context.stroke(weave, with: .color(.white.opacity(carbonOpacity)), lineWidth: 0.9)

            case .holo:
                // Delicate pearlescent cross-shimmer mesh.
                var shimmer = Path()
                stride(from: -size.height, to: size.width, by: 5.5).forEach { x in
                    shimmer.move(to: CGPoint(x: x, y: size.height))
                    shimmer.addLine(to: CGPoint(x: x + size.height, y: 0))
                }
                context.stroke(shimmer, with: .color(.white.opacity(0.055)), lineWidth: 0.8)
            }
        }
    }
}

/// Foil surface: sculptural iOS 18 `MeshGradient` liquid silk + soft specular catchlight + iridescent prism sweep on `.holo`.
struct FoilSurface: View {
    let rarity: Rarity
    var tilt: CGSize = .zero
    var proFoil: ProFoilStyle? = nil

    var body: some View {
        Group {
            if let proFoil {
                proSurface(proFoil)
            } else {
                tierSurface
            }
        }
        .compositingGroup()
    }

    private var tierSurface: some View {
        let colors = rarity.baseColors
        let mid = colors.indices.contains(0) ? colors[0] : rarity.glow
        let hi = colors.indices.contains(1) ? colors[1] : mid
        let sh = colors.indices.contains(2) ? colors[2] : mid
        let deep = colors.indices.contains(3) ? colors[3] : sh
        let tx = tilt.width
        let ty = tilt.height

        return ZStack {
            // 1. Native 3x3 sculptural silk mesh gradient tailored to each tier.
            baseLayer(mid: mid, hi: hi, sh: sh, deep: deep, tx: tx, ty: ty)

            // 2. Earned tiers stay clean liquid silk except subtle carbon twill on forged Titanium obsidian.
            if rarity.material == .carbon {
                FoilTexturePattern(material: .carbon, carbonOpacity: 0.036)
                    .equatable()
            }

            // 3. Soft liquid-glass silk highlight + contrast veil (+ rainbow refraction on 2,000h Prism).
            lightingOverlay(mid: mid, hi: hi, sh: sh, deep: deep, tx: tx, ty: ty)
        }
    }

    private func proSurface(_ style: ProFoilStyle) -> some View {
        let colors = style.baseColors
        let x = tilt.width
        let y = tilt.height
        return ZStack {
            LinearGradient(colors: [colors[3], colors[0], colors[1], colors[2], colors[3]],
                           startPoint: UnitPoint(x: 0.05 + x * 0.12, y: 0),
                           endPoint: UnitPoint(x: 0.9 + x * 0.12, y: 1))
            FoilTexturePattern(material: style.material)
                .equatable()
            switch style {
            case .goldBullion:
                LinearGradient(stops: [.init(color: .clear, location: 0.24),
                                       .init(color: colors[1], location: 0.49),
                                       .init(color: .white, location: 0.53),
                                       .init(color: .clear, location: 0.72)],
                               startPoint: UnitPoint(x: 0, y: -0.25 + y * 0.44),
                               endPoint: UnitPoint(x: 0.4, y: 1 + y * 0.44))
                    .blendMode(.softLight)
                    .opacity(style.sheenOpacity)
            case .obsidianPrism:
                RadialGradient(colors: [style.glow.opacity(0.5), .clear],
                               center: UnitPoint(x: 0.76 + x * 0.25, y: 0.13 + y * 0.28),
                               startRadius: 2, endRadius: 240)
                LinearGradient(stops: [.init(color: .clear, location: 0.28),
                                       .init(color: .cyan.opacity(0.55), location: 0.43),
                                       .init(color: style.glow, location: 0.49),
                                       .init(color: .pink.opacity(0.65), location: 0.55),
                                       .init(color: .clear, location: 0.68)],
                               startPoint: UnitPoint(x: -0.45 + x * 0.52, y: 0.08),
                               endPoint: UnitPoint(x: 1.04 + x * 0.52, y: 0.75))
                    .blendMode(.screen)
                    .opacity(style.sheenOpacity)
            case .sakuraPearl:
                RadialGradient(colors: [.white, colors[1].opacity(0.58), .clear],
                               center: UnitPoint(x: 0.26 + x * 0.32, y: 0.14 + y * 0.32),
                               startRadius: 4, endRadius: 260)
                    .blendMode(.screen)
                    .opacity(style.sheenOpacity)
                RadialGradient(colors: [Color(red: 0.68, green: 0.55, blue: 0.88).opacity(0.32), .clear],
                               center: UnitPoint(x: 0.86 - x * 0.33, y: 0.7), startRadius: 3, endRadius: 190)
                    .blendMode(.softLight)
            case .rawTitanium:
                RadialGradient(colors: [colors[1], .clear],
                               center: UnitPoint(x: 0.5 + x * 0.14, y: 0.05 + y * 0.1),
                               startRadius: 12, endRadius: 260)
                    .blendMode(.screen)
                    .opacity(style.sheenOpacity)
                LinearGradient(colors: [.clear, .black.opacity(0.36)], startPoint: .center, endPoint: .bottomTrailing)
            }
        }
    }

    private func baseLayer(mid: Color, hi: Color, sh: Color, deep: Color, tx: CGFloat, ty: CGFloat) -> some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: Rarity.meshPoints(tilt: CGSize(width: tx, height: ty)),
            colors: rarity.meshColors,
            smoothsColors: true
        )
    }

    @ViewBuilder
    private func lightingOverlay(mid: Color, hi: Color, sh: Color, deep: Color, tx: CGFloat, ty: CGFloat) -> some View {
        // Upper sculptural silk dome responding gently to tilt.
        RadialGradient(
            colors: [
                Color.white.opacity(rarity == .obsidian ? 0.16 : 0.22),
                hi.opacity(rarity == .obsidian ? 0.24 : 0.14),
                .clear
            ],
            center: UnitPoint(
                x: (rarity == .obsidian ? 0.80 : 0.24) + tx * 0.28,
                y: 0.16 + ty * 0.22
            ),
            startRadius: 6,
            endRadius: 280
        )
        .blendMode(.softLight)

        // Single clean diagonal silk-glass light ribbon.
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.26),
                .init(color: Color.white.opacity(0.18 + rarity.sheenOpacity * 0.16), location: 0.48),
                .init(color: Color.white.opacity(0.04), location: 0.57),
                .init(color: .clear, location: 0.72)
            ],
            startPoint: UnitPoint(x: -0.10 + tx * 0.48, y: 0.0 + ty * 0.30),
            endPoint: UnitPoint(x: 1.05 + tx * 0.48, y: 0.95 + ty * 0.30)
        )
        .blendMode(.softLight)

        // Exclusive 2,000h Prism Aurora chromatic color-dodge sweep.
        if rarity == .holo {
            LinearGradient(
                colors: [
                    .clear,
                    rarity.baseColors[0].opacity(0.32),
                    rarity.baseColors[2].opacity(0.34),
                    rarity.baseColors[3].opacity(0.36),
                    rarity.baseColors[4].opacity(0.30),
                    .clear
                ],
                startPoint: UnitPoint(x: -0.22 + tx * 0.58, y: 0.06 + ty * 0.34),
                endPoint: UnitPoint(x: 1.14 + tx * 0.58, y: 0.92 + ty * 0.34)
            )
            .blendMode(.colorDodge)
            .opacity(0.52)

            LinearGradient(
                colors: [.clear, .white.opacity(0.28), .clear],
                startPoint: UnitPoint(x: 0.04 + tx * 0.62, y: 0.04 + ty * 0.38),
                endPoint: UnitPoint(x: 0.72 + tx * 0.62, y: 0.76 + ty * 0.38)
            )
            .blendMode(.overlay)
        }

        // Subtle contrast veil so white typography stays legible over every gradient stop.
        LinearGradient(
            stops: rarity == .holo
                ? [
                    .init(color: Color(red: 0.03, green: 0.04, blue: 0.11).opacity(0.18), location: 0.0),
                    .init(color: Color(red: 0.03, green: 0.04, blue: 0.11).opacity(0.26), location: 0.45),
                    .init(color: Color(red: 0.03, green: 0.04, blue: 0.11).opacity(0.38), location: 1.0)
                ]
                : [
                    .init(color: .clear, location: 0.44),
                    .init(color: Color(red: 0.03, green: 0.04, blue: 0.09).opacity(0.24), location: 1.0)
                ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// Clean frosted glass tier pill with subtle prismatic highlight for 2,000h Prism Aurora cards.
struct TierBadgePill: View {
    let title: LocalizedStringKey
    var ink: Color = .white
    var isHolo: Bool = false
    var fontSize: CGFloat = 10.5
    var tracking: CGFloat = 1.4
    var horizontalPadding: CGFloat = 9
    var verticalPadding: CGFloat = 4

    var body: some View {
        HStack(spacing: 4) {
            if isHolo {
                Image(systemName: "sparkles")
                    .font(.system(size: max(8.5, fontSize - 1), weight: .bold))
            }
            Text(title)
                .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                .tracking(tracking)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .allowsTightening(true)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(Color.black.opacity(isHolo ? 0.44 : (ink == .white ? 0.28 : 0.74)), in: Capsule())
        .overlay(
            Capsule().strokeBorder(
                isHolo
                    ? AnyShapeStyle(LinearGradient(
                        colors: Rarity.holo.prismRimColors.map { $0.opacity(0.85) },
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    : AnyShapeStyle(Color.white.opacity(0.24)),
                lineWidth: isHolo ? 0.9 : 0.7
            )
        )
        .foregroundStyle(.white)
    }
}

/// Subtle soft studio lightbox lift behind headphone artwork.
struct StudioHeadphoneLift: View {
    var diameter: CGFloat = 148

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [.white.opacity(0.20), .clear],
                    center: .center,
                    startRadius: 4,
                    endRadius: diameter * 0.55
                )
            )
            .frame(width: diameter, height: diameter)
            .allowsHitTesting(false)
    }
}

/// Knife-edge specular glass rim for collector cards; full rainbow prism ring on 2,000h `.holo`.
struct CardSpecularBorder: View {
    var cornerRadius: CGFloat
    var rarity: Rarity
    var ink: Color
    var tilt: CGSize = .zero
    var usesPrismRim: Bool = true
    var glow: Color? = nil

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let isHoloRim = usesPrismRim && rarity == .holo
        let accentGlow = glow ?? rarity.glow
        ZStack {
            if isHoloRim {
                shape.strokeBorder(
                    AngularGradient(
                        colors: rarity.prismRimColors,
                        center: .center,
                        angle: .degrees(Double(tilt.width) * 75 + Double(tilt.height) * 40)
                    ),
                    lineWidth: 2.0
                )
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.55), .clear, .white.opacity(0.28)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
            } else {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            ink == .white ? Color.white.opacity(0.50) : Color.black.opacity(0.14),
                            ink == .white ? Color.white.opacity(0.14) : Color.black.opacity(0.05),
                            accentGlow.opacity(0.36),
                            ink == .white ? Color.white.opacity(0.24) : Color.black.opacity(0.14)
                        ],
                        startPoint: UnitPoint(x: 0.15 + tilt.width * 0.45, y: 0.0 + tilt.height * 0.35),
                        endPoint: UnitPoint(x: 0.85 + tilt.width * 0.45, y: 1.0 + tilt.height * 0.35)
                    ),
                    lineWidth: 1.35
                )
            }
        }
        .allowsHitTesting(false)
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

/// Compact pill shown on the top-right of vaulted cards instead of the live-wear dot.
private struct VaultedCardBadge: View {
    let ink: Color
    let reason: RetirementReason

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 9, weight: .bold))
            Text("VAULTED")
                .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                .tracking(0.8)
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(Color.black.opacity(ink == .white ? 0.34 : 0.74), in: Capsule())
        .foregroundStyle(.white)
        .accessibilityLabel("Vaulted · \(Text(LocalizedStringKey(reason.title)))")
    }
}

/// Full-width horizontal collector card used in the main Collection list on standard iPhones.
struct CardHorizontalFront: View {
    let card: HeadphoneCard
    var tilt: CGSize = .zero
    var colorOption: DeviceColorOption? = nil
    var isCurrentlyWorn: Bool = false
    var proFoil: ProFoilStyle? = nil
    var retirement: DeviceRetirement? = nil

    @Environment(\.proAccess) private var proAccess
    @Environment(SlabCustomizationStore.self) private var customizationStore: SlabCustomizationStore?

    var body: some View {
        let foil = proFoil ?? (proAccess.isUnlocked(.foilShaders)
            ? (customizationStore ?? .shared).customization(for: card.id).proFoil : nil)
        let ink = foil?.ink ?? card.rarity.ink
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                TierBadgePill(
                    title: LocalizedStringKey(card.rarity.title),
                    ink: ink,
                    isHolo: foil == nil && card.rarity == .holo,
                    fontSize: 10.5,
                    tracking: 1.4
                )
                Spacer()
                if let retirement {
                    VaultedCardBadge(ink: ink, reason: retirement.reason)
                } else if isCurrentlyWorn {
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
                        if let retirement {
                            if !card.firstMet.isEmpty {
                                Text("·")
                                Text("\(card.firstMet) – \(retirement.formattedRetiredDate)")
                            } else {
                                Text("·")
                                Text("Vaulted \(retirement.formattedRetiredDate)")
                            }
                        } else if !card.firstMet.isEmpty {
                            Text("·")
                            Text("since \(card.firstMet)")
                        }
                    }
                    .font(.system(size: 11.5, weight: .semibold))
                    .opacity(0.76)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: tilt.width * 2.5, y: tilt.height * 1.8)

                ZStack {
                    StudioHeadphoneLift(diameter: 120)
                    HeadphoneArtwork(card: card, colorOption: colorOption, showsChargingCase: false)
                }
                .frame(width: 120, height: 120)
                .offset(x: -tilt.width * 7, y: -tilt.height * 5)
            }
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 188)
        .background(FoilSurface(rarity: card.rarity, tilt: tilt, proFoil: foil))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            CardSpecularBorder(
                cornerRadius: 24,
                rarity: card.rarity,
                ink: ink,
                tilt: tilt,
                usesPrismRim: foil == nil,
                glow: foil?.glow
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
    var showsFirstMet = true
    var surfaceRarityOverride: Rarity? = nil
    var badgeOverride: LocalizedStringKey? = nil
    var catalogDetail: String? = nil
    var proFoil: ProFoilStyle? = nil
    var retirement: DeviceRetirement? = nil

    @Environment(\.proAccess) private var proAccess
    @Environment(SlabCustomizationStore.self) private var customizationStore: SlabCustomizationStore?

    var body: some View {
        let surfaceRarity = surfaceRarityOverride ?? card.rarity
        let foil = proFoil ?? (surfaceRarityOverride == nil && proAccess.isUnlocked(.foilShaders)
            ? (customizationStore ?? .shared).customization(for: card.id).proFoil : nil)
        let ink = foil?.ink ?? surfaceRarity.ink
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                TierBadgePill(
                    title: badgeOverride ?? LocalizedStringKey(surfaceRarity.title),
                    ink: ink,
                    isHolo: foil == nil && surfaceRarity == .holo && badgeOverride == nil,
                    fontSize: 11,
                    tracking: 1.5
                )
                Spacer()
                if let retirement {
                    VaultedCardBadge(ink: ink, reason: retirement.reason)
                } else if isCurrentlyWorn {
                    ActiveWearDot()
                }
            }

            Spacer()

            ZStack {
                if showSymbol {
                    StudioHeadphoneLift(diameter: showsChargingCase ? 172 : 152)
                }
                HeadphoneArtwork(card: card, colorOption: colorOption, showsChargingCase: showsChargingCase,
                                 usesProductArtwork: usesProductArtwork)
            }
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
                    if showsFirstMet {
                        if let retirement {
                            Text("\(card.firstMet) – \(retirement.formattedRetiredDate)")
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        } else {
                            Text("since \(card.firstMet)")
                        }
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .opacity(0.76)
                .padding(.top, 6)
            } else {
                Text(card.model)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                if let catalogDetail, !catalogDetail.isEmpty {
                    Text(catalogDetail)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .opacity(0.74)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.top, 5)
                }
            }
        }
        .foregroundStyle(ink)
        .padding(22)
        .frame(width: CardMetrics.size.width, height: CardMetrics.size.height)
        .background(FoilSurface(rarity: surfaceRarity, tilt: tilt, proFoil: foil))
        .clipShape(RoundedRectangle(cornerRadius: CardMetrics.corner, style: .continuous))
        .overlay(
            CardSpecularBorder(
                cornerRadius: CardMetrics.corner,
                rarity: surfaceRarity,
                ink: ink,
                tilt: tilt,
                usesPrismRim: foil == nil,
                glow: foil?.glow
            )
        )
    }
}

struct CardBack: View {
    let card: HeadphoneCard
    var retirement: DeviceRetirement? = nil
    var openDossier: (() -> Void)? = nil
    var openTiers: (() -> Void)? = nil
    var flip: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isLight = colorScheme == .light
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
                            .background(Theme.surfaceFillStrong, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .foregroundStyle(Theme.primaryText)
        .padding(20)
        .frame(width: CardMetrics.size.width, height: CardMetrics.size.height)
        .background(
            ZStack {
                Theme.card
                RadialGradient(colors: [card.rarity.glow.opacity(isLight ? 0.16 : 0.35), .clear], center: .top, startRadius: 0, endRadius: 320)
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
                Text(card.model)
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            ZStack {
                EarprintGlyph(grid: card.grid, showHourLabels: false)
                    .equatable()
                VStack(spacing: 0) {
                    Text("4 weeks").font(.system(size: 10, weight: .semibold)).opacity(0.65)
                    Text("listening").font(.system(size: 10)).opacity(0.55)
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
            Text(title).font(.system(size: 11)).opacity(0.58)
            Group {
                switch unit {
                case .minutes: Text(value.minutesText)
                case .count: Text("\(Int(value))")
                case .decibels: value > 0 ? Text("\(Int(value)) dB") : Text(verbatim: "—")
                }
            }
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.70)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.surfaceFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder private var tierProgress: some View {
        let content = tierProgressBody
        if let openTiers {
            Button(action: openTiers) {
                content
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("View all card tiers")
        } else {
            content
        }
    }

    @ViewBuilder private var tierProgressBody: some View {
        if let retirement {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(card.rarity.accent)
                    Text("Vaulted · \(Text(LocalizedStringKey(retirement.reason.title)))")
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Text(retirement.formattedRetiredDate)
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .opacity(0.65)
            }
        } else {
            let hours = card.lifetimeMinutes / 60
            if let next = card.rarity.nextTierHours {
                let remaining = max(1, Int(ceil(next - hours)))
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text("\(remaining)h to next tier")
                            .font(.system(size: 11, weight: .semibold))
                            .opacity(0.75)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if openTiers != nil {
                            Image(systemName: "info.circle")
                                .font(.system(size: 10))
                                .opacity(0.55)
                        }
                    }
                    ProgressView(value: card.rarity.progressToNextTier(minutes: card.lifetimeMinutes))
                        .tint(card.rarity.accent)
                }
            } else {
                HStack(spacing: 5) {
                    Text("Max tier reached ✦")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(card.rarity.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if openTiers != nil {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(card.rarity.accent.opacity(0.7))
                    }
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
