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
                // Authentic 2×2 carbon-fiber twill weave.
                var weave = Path()
                stride(from: -size.height, to: size.width + size.height, by: 7.5).forEach { x in
                    weave.move(to: CGPoint(x: x, y: size.height))
                    weave.addLine(to: CGPoint(x: x + size.height, y: 0))
                    weave.move(to: CGPoint(x: x, y: 0))
                    weave.addLine(to: CGPoint(x: x + size.height, y: size.height))
                }
                context.stroke(weave, with: .color(.white.opacity(0.062)), lineWidth: 1.0)

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

/// Foil surface: distinct per-material lighting architecture + finish micro-texture that responds naturally to tilt.
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
            // 1. Pinch-free base coat tailored to each tier's material physics.
            baseLayer(mid: mid, hi: hi, sh: sh, deep: deep, tx: tx, ty: ty)

            // 2. Static finish micro-texture (Equatable -> zero CPU cost during tilt).
            FoilTexturePattern(material: rarity.material)
                .equatable()

            // 3. Per-material natural light shape & specular behavior (no shared template!).
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

    @ViewBuilder
    private func baseLayer(mid: Color, hi: Color, sh: Color, deep: Color, tx: CGFloat, ty: CGFloat) -> some View {
        switch rarity.material {
        case .matteGrain:
            LinearGradient(
                colors: [hi, mid, sh, deep],
                startPoint: UnitPoint(x: 0.08 + tx * 0.06, y: 0.02 + ty * 0.05),
                endPoint: UnitPoint(x: 0.92 + tx * 0.06, y: 0.98 + ty * 0.05)
            )
        case .brushed:
            if rarity == .silver {
                LinearGradient(
                    colors: [mid, hi, mid, sh],
                    startPoint: UnitPoint(x: 0.12 + tx * 0.08, y: 0.0),
                    endPoint: UnitPoint(x: 0.88 + tx * 0.08, y: 1.0)
                )
            } else {
                // Fjord Teal: horizontal coastal gradient flow
                LinearGradient(
                    colors: [sh, mid, hi, sh, deep],
                    startPoint: UnitPoint(x: 0.0, y: 0.14 + ty * 0.06),
                    endPoint: UnitPoint(x: 1.0, y: 0.88 + ty * 0.06)
                )
            }
        case .satin:
            // Deep Purple: rich velvet plum base with upper-right lift
            LinearGradient(
                colors: [deep, sh, mid, deep],
                startPoint: UnitPoint(x: 0.05, y: 0.95),
                endPoint: UnitPoint(x: 0.95, y: 0.05)
            )
        case .carbon:
            // Midnight Carbon stays authentically dark forged composite across its body.
            LinearGradient(
                colors: [mid, deep, sh, Color(red: 0.025, green: 0.032, blue: 0.055)],
                startPoint: UnitPoint(x: 0.15, y: 0.0),
                endPoint: UnitPoint(x: 0.85, y: 1.0)
            )
        case .holo:
            LinearGradient(
                colors: [
                    rarity.baseColors[0].opacity(0.92),
                    rarity.baseColors[1].opacity(0.88),
                    rarity.baseColors[2].opacity(0.86),
                    rarity.baseColors[3].opacity(0.92),
                ],
                startPoint: UnitPoint(x: 0.02 + tx * 0.08, y: 0.04 + ty * 0.06),
                endPoint: UnitPoint(x: 0.98 + tx * 0.08, y: 0.96 + ty * 0.06)
            )
        }
    }

    @ViewBuilder
    private func lightingOverlay(mid: Color, hi: Color, sh: Color, deep: Color, tx: CGFloat, ty: CGFloat) -> some View {
        switch rarity.material {
        case .matteGrain:
            // Broad diffused top-left overhead dome + gentle matte roll-off
            RadialGradient(
                colors: [hi.opacity(0.45), mid.opacity(0.14), .clear],
                center: UnitPoint(x: 0.20 + tx * 0.28, y: 0.14 + ty * 0.22),
                startRadius: 8,
                endRadius: 310
            )
            LinearGradient(
                colors: [.white.opacity(0.16), .clear, .black.opacity(0.18)],
                startPoint: UnitPoint(x: 0.1 + tx * 0.25, y: 0.0),
                endPoint: UnitPoint(x: 0.9, y: 1.0)
            )
            .blendMode(.softLight)

        case .brushed:
            if rarity == .silver {
                // Vertical-traveling anisotropic brushed aluminum sheen ribbon
                LinearGradient(
                    colors: [.clear, hi.opacity(0.46), .white.opacity(0.32), hi.opacity(0.28), .clear],
                    startPoint: UnitPoint(x: 0.0, y: 0.10 + ty * 0.35),
                    endPoint: UnitPoint(x: 0.95, y: 0.72 + ty * 0.35)
                )
                .blendMode(.screen)
                LinearGradient(
                    colors: [.clear, .white.opacity(0.22), .clear],
                    startPoint: UnitPoint(x: -0.1 + tx * 0.5, y: 0.25),
                    endPoint: UnitPoint(x: 0.75 + tx * 0.5, y: 0.85)
                )
                .blendMode(.softLight)
            } else {
                // Fjord Teal: soft upper-right horizon light + horizontal brushed shimmer band
                RadialGradient(
                    colors: [hi.opacity(0.36), .clear],
                    center: UnitPoint(x: 0.84 + tx * 0.25, y: 0.16 + ty * 0.20),
                    startRadius: 6,
                    endRadius: 240
                )
                LinearGradient(
                    colors: [.clear, hi.opacity(0.30), .white.opacity(0.20), .clear],
                    startPoint: UnitPoint(x: -0.1 + tx * 0.45, y: 0.35),
                    endPoint: UnitPoint(x: 1.05 + tx * 0.45, y: 0.65)
                )
                .blendMode(.overlay)
            }

        case .satin:
            // Deep Purple: dramatic curved off-axis silk rim + warm violet bounce
            RadialGradient(
                colors: [hi.opacity(0.48), mid.opacity(0.20), .clear],
                center: UnitPoint(x: 0.82 + tx * 0.28, y: 0.18 + ty * 0.22),
                startRadius: 8,
                endRadius: 270
            )
            LinearGradient(
                colors: [.clear, hi.opacity(0.26), .white.opacity(0.14), .clear],
                startPoint: UnitPoint(x: 0.05 + tx * 0.35, y: 0.0),
                endPoint: UnitPoint(x: 0.85 + tx * 0.35, y: 0.95)
            )
            .blendMode(.softLight)

        case .carbon:
            // Midnight Carbon: directional DLC edge catchlight from upper-right + tight cyan-steel shimmer
            RadialGradient(
                colors: [hi.opacity(0.62), rarity.glow.opacity(0.24), .clear],
                center: UnitPoint(x: 0.86 + tx * 0.32, y: 0.12 + ty * 0.22),
                startRadius: 4,
                endRadius: 235
            )
            LinearGradient(
                colors: [.clear, rarity.glow.opacity(0.22), .white.opacity(0.14), .clear],
                startPoint: UnitPoint(x: 0.25 + tx * 0.55, y: 0.0),
                endPoint: UnitPoint(x: 0.95 + tx * 0.55, y: 0.85)
            )
            .blendMode(.screen)
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.32)],
                startPoint: UnitPoint(x: 0.5, y: 0.35),
                endPoint: .bottomLeading
            )

        case .holo:
            // Liquid Holo: flowing multi-pool iridescent aurora + prism sweep (zero pinch!).
            RadialGradient(
                colors: [rarity.baseColors[0].opacity(0.56), .clear],
                center: UnitPoint(x: 0.18 + tx * 0.32, y: 0.18 + ty * 0.26),
                startRadius: 8,
                endRadius: 250
            )
            RadialGradient(
                colors: [rarity.baseColors[2].opacity(0.46), .clear],
                center: UnitPoint(x: 0.84 - tx * 0.28, y: 0.36 + ty * 0.24),
                startRadius: 8,
                endRadius: 245
            )
            RadialGradient(
                colors: [rarity.baseColors[3].opacity(0.44), .clear],
                center: UnitPoint(x: 0.30 + tx * 0.26, y: 0.86 - ty * 0.22),
                startRadius: 8,
                endRadius: 230
            )
            LinearGradient(
                colors: [
                    .clear,
                    .pink.opacity(0.26),
                    .yellow.opacity(0.20),
                    .cyan.opacity(0.28),
                    .purple.opacity(0.22),
                    .clear
                ],
                startPoint: UnitPoint(x: -0.15 + tx * 0.55, y: 0.0),
                endPoint: UnitPoint(x: 1.10 + tx * 0.55, y: 1.0)
            )
            .blendMode(.colorDodge)
            .opacity(0.48)
            LinearGradient(
                colors: [.clear, .white.opacity(0.36), .clear],
                startPoint: UnitPoint(x: 0.0 + tx * 0.65, y: 0.05 + ty * 0.4),
                endPoint: UnitPoint(x: 0.65 + tx * 0.65, y: 0.72 + ty * 0.4)
            )
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
    var proFoil: ProFoilStyle? = nil

    @Environment(\.proAccess) private var proAccess
    @Environment(SlabCustomizationStore.self) private var customizationStore: SlabCustomizationStore?

    var body: some View {
        let foil = proFoil ?? (proAccess.isUnlocked(.foilShaders)
            ? (customizationStore ?? .shared).customization(for: card.id).proFoil : nil)
        let ink = foil?.ink ?? card.rarity.ink
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(LocalizedStringKey(card.rarity.title))
                    .font(.system(size: 10.5, weight: .heavy))
                    .tracking(1.4)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Color.black.opacity(ink == .white ? 0.34 : 0.74), in: Capsule())
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
                        if !card.firstMet.isEmpty {
                            Text("·")
                            Text("since \(card.firstMet)")
                        }
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
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            ink == .white ? Color.white.opacity(0.45) : Color.black.opacity(0.14),
                            ink == .white ? Color.white.opacity(0.14) : Color.black.opacity(0.05),
                            (foil?.glow ?? card.rarity.glow).opacity(0.45),
                            ink == .white ? Color.white.opacity(0.32) : Color.black.opacity(0.14)
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
    var showsFirstMet = true
    var surfaceRarityOverride: Rarity? = nil
    var badgeOverride: LocalizedStringKey? = nil
    var catalogDetail: String? = nil
    var proFoil: ProFoilStyle? = nil

    @Environment(\.proAccess) private var proAccess
    @Environment(SlabCustomizationStore.self) private var customizationStore: SlabCustomizationStore?

    var body: some View {
        let surfaceRarity = surfaceRarityOverride ?? card.rarity
        let foil = proFoil ?? (surfaceRarityOverride == nil && proAccess.isUnlocked(.foilShaders)
            ? (customizationStore ?? .shared).customization(for: card.id).proFoil : nil)
        let ink = foil?.ink ?? surfaceRarity.ink
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(badgeOverride ?? LocalizedStringKey(surfaceRarity.title))
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Color.black.opacity(ink == .white ? 0.34 : 0.74), in: Capsule())
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
                    if showsFirstMet {
                        Text("since \(card.firstMet)")
                    }
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
        .background(FoilSurface(rarity: surfaceRarity, tilt: tilt, proFoil: foil))
        .clipShape(RoundedRectangle(cornerRadius: CardMetrics.corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CardMetrics.corner, style: .continuous)
            .strokeBorder(ink == .white ? Color.white.opacity(0.32) : Color.black.opacity(0.14), lineWidth: 1.5))
    }
}

struct CardBack: View {
    let card: HeadphoneCard
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
