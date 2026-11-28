import SwiftUI
import UIKit

/// Design size of a card. Thumbnails render at this size and scale down, so every card looks identical at any size.
enum CardMetrics {
    static let size = CGSize(width: 300, height: 440)
    static let corner: CGFloat = 26
}

/// Keep each face visible only while it faces the viewer, using the angle of the current frame.
struct CardFaceRotation: ViewModifier, Animatable {
    var angle: Double
    var isBack = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        if reduceMotion {
            let normalized = abs(angle).truncatingRemainder(dividingBy: 360) / 180.0
            let t = min(max(normalized > 1 ? 2 - normalized : normalized, 0), 1)
            content.opacity(isBack ? t : (1 - t))
        } else {
            let showsFront = cos(angle * .pi / 180) > 0
            content
                .opacity(showsFront == isBack ? 0 : 1)
                .rotation3DEffect(.degrees(angle + (isBack ? 180 : 0)), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        }
    }
}

/// Static micro-texture for `FoilSurface`, isolated as `Equatable` so tilt changes never redraw the Canvas.
private struct FoilTexturePattern: View, Equatable {
    let material: FoilMaterial
    var inkColor: Color = .white
    var carbonOpacity: Double = 0.062
    var carbonPitch: CGFloat = 7.5
    var carbonLineWidth: CGFloat = 1.0
    var holoOpacity: Double = 0.055

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
                stride(from: -size.height, to: size.width + size.height, by: carbonPitch).forEach { x in
                    weave.move(to: CGPoint(x: x, y: size.height))
                    weave.addLine(to: CGPoint(x: x + size.height, y: 0))
                    weave.move(to: CGPoint(x: x, y: 0))
                    weave.addLine(to: CGPoint(x: x + size.height, y: size.height))
                }
                context.stroke(weave, with: .color(inkColor.opacity(carbonOpacity)), lineWidth: carbonLineWidth)

            case .holo:
                // Delicate pearlescent cross-shimmer mesh.
                var shimmer = Path()
                stride(from: -size.height, to: size.width, by: 5.5).forEach { x in
                    shimmer.move(to: CGPoint(x: x, y: size.height))
                    shimmer.addLine(to: CGPoint(x: x + size.height, y: 0))
                }
                context.stroke(shimmer, with: .color(inkColor.opacity(holoOpacity)), lineWidth: 0.8)
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
                FoilTexturePattern(material: .carbon, carbonOpacity: 0.036, carbonPitch: 8.0, carbonLineWidth: 0.85)
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
                    .init(color: .clear, location: 0.30),
                    .init(color: Color(red: 0.03, green: 0.04, blue: 0.09).opacity(0.38), location: 1.0)
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
                .minimumScaleFactor(0.72)
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

/// Knife-edge specular glass rim for collector cards; full rainbow prism ring on 2,000h `.holo`.
struct CardSpecularBorder: View {
    var cornerRadius: CGFloat
    var rarity: Rarity
    var ink: Color
    var tilt: CGSize = .zero
    var usesPrismRim: Bool = true
    var glow: Color? = nil
    var isBackFace: Bool = false
    var isRetired: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let isHoloRim = usesPrismRim && rarity == .holo
        let accentGlow = glow ?? rarity.glow
        ZStack {
            if isHoloRim {
                let isLightPlate = ink != .white
                let backLightPrism: [Color] = [
                    Color(red: 0.05, green: 0.56, blue: 0.62),
                    Color(red: 0.18, green: 0.36, blue: 0.82),
                    Color(red: 0.48, green: 0.20, blue: 0.78),
                    Color(red: 0.76, green: 0.14, blue: 0.48),
                    Color(red: 0.36, green: 0.58, blue: 0.78),
                    Color(red: 0.05, green: 0.56, blue: 0.62)
                ]
                let rimColors = (isBackFace && colorScheme == .light) ? backLightPrism : rarity.prismRimColors
                let rimWidth: CGFloat = isBackFace ? (isLightPlate ? 1.3 : 1.15) : (isLightPlate ? 1.5 : 1.75)
                let rimOpacity: Double = isBackFace
                    ? (isRetired ? 0.58 : (isLightPlate ? 0.68 : 0.60))
                    : (isLightPlate ? 0.76 : 0.92)
                shape.strokeBorder(
                    AngularGradient(
                        colors: rimColors,
                        center: .center,
                        angle: .degrees(Double(tilt.width) * 75 + Double(tilt.height) * 40)
                    ),
                    lineWidth: rimWidth
                )
                .opacity(rimOpacity)
                if isBackFace && isLightPlate {
                    shape.strokeBorder(Color.black.opacity(0.08), lineWidth: 0.75)
                } else {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(isLightPlate ? 0.35 : 0.55), .clear, .white.opacity(isLightPlate ? 0.18 : 0.28)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
                }
            } else {
                ZStack {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [
                                ink == .white ? Color.white.opacity(0.50) : accentGlow.opacity(0.42),
                                ink == .white ? Color.white.opacity(0.14) : accentGlow.opacity(0.18),
                                ink == .white ? accentGlow.opacity(0.36) : accentGlow.opacity(0.48),
                                ink == .white ? Color.white.opacity(0.24) : accentGlow.opacity(0.28)
                            ],
                            startPoint: UnitPoint(x: 0.15 + tilt.width * 0.45, y: 0.0 + tilt.height * 0.35),
                            endPoint: UnitPoint(x: 0.85 + tilt.width * 0.45, y: 1.0 + tilt.height * 0.35)
                        ),
                        lineWidth: 1.35
                    )
                    if isBackFace && ink != .white {
                        shape.strokeBorder(Color.black.opacity(0.08), lineWidth: 0.75)
                    }
                }
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
                        Text("\(card.sessions) wears")
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
    var isEmbeddedInSlab: Bool = false

    @Environment(\.proAccess) private var proAccess
    @Environment(SlabCustomizationStore.self) private var customizationStore: SlabCustomizationStore?

    var body: some View {
        let surfaceRarity = surfaceRarityOverride ?? card.rarity
        let foil = proFoil ?? (surfaceRarityOverride == nil && proAccess.isUnlocked(.foilShaders)
            ? (customizationStore ?? .shared).customization(for: card.id).proFoil : nil)
        let ink = foil?.ink ?? surfaceRarity.ink
        let pillTitle: LocalizedStringKey = badgeOverride ?? LocalizedStringKey(
            retirement != nil && surfaceRarity == .holo
                ? surfaceRarity.shortName.uppercased()
                : surfaceRarity.title
        )
        VStack(alignment: .leading, spacing: 0) {
            if isEmbeddedInSlab {
                HStack {
                    Spacer()
                    if let retirement {
                        VaultedCardBadge(ink: ink, reason: retirement.reason)
                    } else if isCurrentlyWorn {
                        ActiveWearDot()
                    }
                }
                .frame(minHeight: 8)
            } else {
                HStack {
                    TierBadgePill(
                        title: pillTitle,
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
                    .font(.system(size: isEmbeddedInSlab ? 16 : 17, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(card.lifetimeMinutes.minutesText)
                    .font(.system(size: isEmbeddedInSlab ? 30 : 42, weight: isEmbeddedInSlab ? .heavy : .black, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .padding(.top, 2)

                HStack {
                    Label(isEmbeddedInSlab ? "\(card.sessions) wears" : "\(card.sessions)", systemImage: "ear")
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
                .font(.system(size: isEmbeddedInSlab ? 13.5 : 12, weight: .semibold))
                .opacity(isEmbeddedInSlab ? 0.86 : 0.76)
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
    var tilt: CGSize = .zero
    var proFoil: ProFoilStyle? = nil
    var retirement: DeviceRetirement? = nil
    var openDossier: (() -> Void)? = nil
    var flip: (() -> Void)? = nil
    var onDialScrubChanged: ((Bool) -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.cardAllowsReflow) private var cardAllowsReflow
    @Environment(\.proAccess) private var proAccess
    @Environment(SlabCustomizationStore.self) private var customizationStore: SlabCustomizationStore?
    @ScaledMetric(relativeTo: .subheadline) private var titleSize: CGFloat = 16.5
    @ScaledMetric(relativeTo: .headline) private var dialValueSize: CGFloat = 18.5
    @ScaledMetric(relativeTo: .subheadline) private var specValueSize: CGFloat = 14.5
    @ScaledMetric(relativeTo: .caption) private var metaSize: CGFloat = 12.0
    @ScaledMetric(relativeTo: .caption2) private var microSize: CGFloat = 11.5
    @State private var selectedHour: Int? = nil
    @GestureState private var isDialDragActive = false

    var body: some View {
        let isLight = colorScheme == .light
        let foil = proFoil ?? (proAccess.isUnlocked(.foilShaders)
            ? (customizationStore ?? .shared).customization(for: card.id).proFoil : nil)
        let surfaceAccent = DossierContrast.accentColor(rarity: card.rarity, proFoil: foil, colorScheme: colorScheme)
        let allowsReflow = cardAllowsReflow && dynamicTypeSize >= .xLarge

        let cardContent = VStack(alignment: .leading, spacing: 0) {
            upperContent(foil: foil, surfaceAccent: surfaceAccent, isLight: isLight, allowsReflow: allowsReflow)

            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
                .padding(.top, 9)

            let footerLayout = allowsReflow
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 12))

            footerLayout {
                tierProgress(surfaceAccent: surfaceAccent, isLight: isLight, allowsReflow: allowsReflow)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let openDossier {
                    let dossierInk: Color = (!isLight && foil == nil && card.rarity == .holo)
                        ? Color(red: 1.0, green: 0.64, blue: 0.86)
                        : surfaceAccent
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        openDossier()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Dossier")
                            Image(systemName: "chevron.right")
                                .font(.system(size: allowsReflow ? microSize : min(microSize, 12), weight: .bold))
                                .accessibilityHidden(true)
                        }
                        .font(.system(size: allowsReflow ? metaSize : min(metaSize, 15), weight: .bold, design: .rounded))
                        .foregroundStyle(dossierInk)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background {
                            if isLight {
                                ZStack {
                                    Capsule().fill(Color.white.opacity(0.90))
                                    Capsule().fill(surfaceAccent.opacity(0.11))
                                }
                                .shadow(color: Color.black.opacity(0.05), radius: 3, y: 1)
                            } else {
                                Capsule().fill(surfaceAccent.opacity(0.14))
                            }
                        }
                        .overlay(
                            Capsule().strokeBorder(
                                isLight ? surfaceAccent.opacity(0.36) : surfaceAccent.opacity(0.34),
                                lineWidth: 0.9
                            )
                        )
                        .frame(maxWidth: allowsReflow ? .infinity : nil, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(CardControlPressStyle())
                    .fixedSize(horizontal: !allowsReflow, vertical: false)
                    .layoutPriority(1)
                    .accessibilityHint("Opens full device dossier")
                }
            }
            .frame(minHeight: 44)
            .frame(height: allowsReflow ? nil : 44)
            .padding(.top, 8)
        }
        .foregroundStyle(Theme.primaryText)
        .padding(.horizontal, 18)
        .padding(.top, 15)
        .padding(.bottom, 15)
        .frame(minWidth: CardMetrics.size.width, maxWidth: allowsReflow ? .infinity : CardMetrics.size.width)
        .frame(minHeight: CardMetrics.size.height, maxHeight: allowsReflow ? nil : CardMetrics.size.height)
        .background(reversePlateSurface(foil: foil, isLight: isLight))
        .clipShape(RoundedRectangle(cornerRadius: CardMetrics.corner, style: .continuous))
        .overlay(
            CardSpecularBorder(
                cornerRadius: CardMetrics.corner,
                rarity: card.rarity,
                ink: isLight ? .black : .white,
                tilt: tilt,
                usesPrismRim: foil == nil,
                glow: foil?.glow,
                isBackFace: true,
                isRetired: retirement != nil
            )
        )
        .onChange(of: card.id) { _, _ in
            selectedHour = nil
            onDialScrubChanged?(false)
        }
        .onChange(of: retirement) { _, _ in
            selectedHour = nil
            onDialScrubChanged?(false)
        }
        .onChange(of: isDialDragActive) { _, active in
            onDialScrubChanged?(active)
        }
        .onDisappear {
            onDialScrubChanged?(false)
        }

        if let flip {
            cardContent
                .accessibilityElement(children: .contain)
                .accessibilityAction(named: Text("Flip card"), flip)
        } else {
            cardContent
        }
    }

    private func upperContent(foil: ProFoilStyle?, surfaceAccent: Color, isLight: Bool, allowsReflow: Bool) -> some View {
        let tierLabel = foil != nil ? foil!.shortName : AppLanguage.current.text(card.rarity.displayName)
        let tierDisplay = tierLabel.uppercased()
        let monthMinutes = card.grid.last28Minutes
        let monthDB = card.grid.last28AverageDecibels
        let avgWearMinutes = card.sessions > 0 ? card.lifetimeMinutes / Double(card.sessions) : nil
        let dialSubtitle: LocalizedStringKey = retirement != nil ? "Final 28 days" : "Last 28 days"
        let dialWindowLabel = AppLanguage.current.text(retirement != nil ? "Final 28 days" : "Last 28 days")
        let canInspectDial = (openDossier != nil || flip != nil)

        let headerLayout = allowsReflow
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 8))

        let headerBlock = headerLayout {
            VStack(alignment: .leading, spacing: 3) {
                Text(card.model)
                    .font(.system(size: allowsReflow ? titleSize : min(titleSize, 20), weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(allowsReflow ? 2 : 1)
                    .minimumScaleFactor(0.8)
                    .accessibilityAddTraits(.isHeader)

                HStack(spacing: 5) {
                    Text(String(format: "#%04d", card.serial))
                        .foregroundStyle(Theme.secondaryText)
                    Text("·")
                        .foregroundStyle(Theme.tertiaryText)
                    Text(verbatim: tierDisplay)
                        .foregroundStyle(surfaceAccent)
                }
                .font(.system(size: allowsReflow ? metaSize : min(metaSize, 14.5), weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(String(format: "#%04d", card.serial)), \(tierLabel)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let flip {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    flip()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.2.swap")
                            .font(.system(size: allowsReflow ? metaSize : 12.5, weight: .semibold))
                        Text("Flip")
                            .font(.system(size: allowsReflow ? metaSize : 12.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Theme.primaryText.opacity(0.84))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5.5)
                    .background(
                        Capsule().fill(isLight ? Color.white.opacity(0.55) : Color.white.opacity(0.12))
                    )
                    .overlay(
                        Capsule().strokeBorder(
                            isLight ? Color.black.opacity(0.14) : Color.white.opacity(0.22),
                            lineWidth: 0.9
                        )
                    )
                    .frame(minWidth: 44, minHeight: 44, alignment: allowsReflow ? .leading : .trailing)
                    .contentShape(Rectangle())
                }
                .buttonStyle(CardControlPressStyle())
                .accessibilityLabel("Show card front")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)

        let dialSide: CGFloat = 178
        let dialView = ZStack {
            EarprintGlyph(
                grid: card.grid,
                showHourLabels: true,
                highlightedHour: selectedHour,
                forcedColorScheme: colorScheme,
                dynamicTypeSize: dynamicTypeSize
            )
            .equatable()
            .frame(width: dialSide, height: dialSide)

            VStack(spacing: 1.5) {
                if let hour = selectedHour {
                    let hStats = EarprintDialMath.hourSummary(grid: card.grid, hour: hour)
                    Text(String(format: "%02d:00", hour))
                        .font(.system(size: min(dialValueSize, 17.0), weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .contentTransition(reduceMotion ? .identity : .numericText())
                    Text("\(hStats.avgMinutesPerDay.minutesText) / day")
                        .font(.system(size: min(microSize, 11.5), weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                    if hStats.avgDB > 0 {
                        HStack(spacing: 3.5) {
                            Circle()
                                .fill(Theme.levelColor(db: hStats.avgDB, colorScheme: colorScheme))
                                .frame(width: 5.5, height: 5.5)
                            Text("\(Int(hStats.avgDB.rounded())) dB(A)")
                                .font(.system(size: min(microSize, 11.5), weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Theme.primaryText)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.80)
                    }
                } else {
                    Text(monthMinutes.minutesText)
                        .font(.system(size: min(dialValueSize, 17.0), weight: .heavy, design: .rounded))
                        .tracking(-0.5)
                        .monospacedDigit()
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .contentTransition(reduceMotion ? .identity : .numericText())
                    Text(dialSubtitle)
                        .font(.system(size: min(microSize, 11.5), weight: .medium, design: .rounded))
                        .tracking(-0.2)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .frame(maxWidth: EarprintDialMath.innerWellWidth(side: dialSide, showHourLabels: true, dayCount: card.grid.days))
        }
        .frame(width: dialSide, height: dialSide)

        return VStack(alignment: .leading, spacing: 0) {
            headerBlock

            Spacer(minLength: 8)

            VStack(spacing: 8) {
                if canInspectDial {
                    dialView
                        .contentShape(Circle())
                        .onTapGesture { location in
                            selectedHour = EarprintDialMath.selectHour(
                                at: location,
                                size: dialSide,
                                current: selectedHour,
                                toggle: true,
                                dayCount: card.grid.days
                            )
                        }
                        .gesture(
                            LongPressGesture(minimumDuration: 0.25)
                                .sequenced(before: DragGesture(minimumDistance: 0))
                                .updating($isDialDragActive) { value, state, _ in
                                    if case .second(true, _) = value {
                                        state = true
                                    }
                                }
                                .onChanged { value in
                                    if case .second(true, let drag?) = value {
                                        selectedHour = EarprintDialMath.selectHour(
                                            at: drag.location,
                                            size: dialSide,
                                            current: selectedHour,
                                            toggle: false,
                                            dayCount: card.grid.days
                                        )
                                    }
                                }
                        )
                        .sensoryFeedback(.selection, trigger: selectedHour)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(dialWindowLabel) Earprint dial, oldest ring inside to newest outside")
                        .accessibilityValue(
                            EarprintDialMath.accessibilityValue(
                                grid: card.grid,
                                selectedHour: selectedHour,
                                totalMinutes: monthMinutes,
                                averageDB: monthDB > 0 ? monthDB : nil,
                                formatMinutes: { $0.minutesText }
                            )
                        )
                        .accessibilityHint("Swipe up or down to inspect hours")
                        .accessibilityAdjustableAction { direction in
                            selectedHour = EarprintDialMath.adjustedHour(current: selectedHour, direction: direction)
                        }
                        .dialClearAccessibilityAction(isActive: selectedHour != nil) {
                            selectedHour = nil
                        }
                        .frame(maxWidth: .infinity)
                } else {
                    dialView
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(monthMinutes.minutesText), \(dialWindowLabel) Earprint dial")
                        .frame(maxWidth: .infinity)
                }

                VStack(spacing: 4) {
                    LoudnessLegendRow(compact: true, compactLabels: false, allowsStacking: allowsReflow, showsUnit: true)

                    if canInspectDial {
                        let dialCue: LocalizedStringKey = selectedHour != nil
                            ? "Tap center or hour to clear"
                            : "Tap or drag an hour"
                        Text(dialCue)
                            .font(.system(size: allowsReflow ? microSize : min(microSize, 11.5), weight: .medium))
                            .foregroundStyle(Theme.secondaryText)
                            .lineLimit(allowsReflow ? 2 : 1)
                            .minimumScaleFactor(0.90)
                            .frame(maxWidth: .infinity)
                            .accessibilityHidden(true)
                    }
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 7) {
                Text("ALL TIME")
                    .font(.system(size: allowsReflow ? microSize : 11.5, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(height: 1)
                    .accessibilityHidden(true)
            }
            .padding(.bottom, 5)

            Group {
                if allowsReflow {
                    VStack(alignment: .leading, spacing: 8) {
                        specColumn(
                            title: "Longest wear",
                            value: card.longestMinutes > 0 ? card.longestMinutes.minutesText : "—",
                            position: .leading,
                            allowsReflow: true
                        )
                        specColumn(
                            title: "Avg / wear",
                            value: avgWearMinutes?.minutesText ?? "—",
                            position: .middle,
                            allowsReflow: true
                        )
                        specColumn(
                            title: "Avg volume",
                            value: card.averageDecibels > 0 ? "\(Int(card.averageDecibels.rounded()))" : "—",
                            unit: card.averageDecibels > 0 ? "dB(A)" : nil,
                            spokenUnit: card.averageDecibels > 0 ? AppLanguage.current.text("decibels") : nil,
                            position: .trailing,
                            allowsReflow: true
                        )
                    }
                } else {
                    HStack(spacing: 0) {
                        specColumn(
                            title: "Longest wear",
                            value: card.longestMinutes > 0 ? card.longestMinutes.minutesText : "—",
                            position: .leading,
                            allowsReflow: false
                        )
                        specDivider
                        specColumn(
                            title: "Avg / wear",
                            value: avgWearMinutes?.minutesText ?? "—",
                            position: .middle,
                            allowsReflow: false
                        )
                        specDivider
                        specColumn(
                            title: "Avg volume",
                            value: card.averageDecibels > 0 ? "\(Int(card.averageDecibels.rounded()))" : "—",
                            unit: card.averageDecibels > 0 ? "dB(A)" : nil,
                            spokenUnit: card.averageDecibels > 0 ? AppLanguage.current.text("decibels") : nil,
                            position: .trailing,
                            allowsReflow: false
                        )
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private enum SpecColumnPosition {
        case leading
        case middle
        case trailing
    }

    private func specColumn(
        title: String,
        value: String,
        unit: String? = nil,
        spokenUnit: String? = nil,
        position: SpecColumnPosition = .leading,
        allowsReflow: Bool
    ) -> some View {
        let leadingPad: CGFloat = allowsReflow ? 0 : (position == .leading ? 0 : 8)
        let trailingPad: CGFloat = allowsReflow ? 0 : (position == .trailing ? 0 : 8)
        let spokenValue = spokenUnit.map { "\(value) \($0)" } ?? "\(value)\(unit.map { " \($0)" } ?? "")"
        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: allowsReflow ? specValueSize : min(specValueSize, 18), weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.primaryText)
                if let unit {
                    Text(unit)
                        .font(.system(size: allowsReflow ? microSize : min(microSize, 11.8), weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            Text(LocalizedStringKey(title))
                .font(.system(size: allowsReflow ? microSize : min(microSize, 11.8), weight: .medium))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.90)
        }
        .padding(.leading, leadingPad)
        .padding(.trailing, trailingPad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(AppLanguage.current.text(title)), \(spokenValue)"))
    }

    private var specDivider: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(width: 1)
            .padding(.vertical, 2)
    }

    @ViewBuilder
    private func reversePlateSurface(foil: ProFoilStyle?, isLight: Bool) -> some View {
        let colors = foil?.baseColors ?? card.rarity.baseColors
        let hi = colors.indices.contains(1) ? colors[1] : (foil?.glow ?? card.rarity.glow)
        let sh = colors.indices.contains(2) ? colors[2] : hi
        let material = foil?.material ?? card.rarity.material
        let sheen = foil?.sheenOpacity ?? card.rarity.sheenOpacity
        let surfaceAccent = DossierContrast.accentColor(rarity: card.rarity, proFoil: foil, colorScheme: colorScheme)
        let calmBackdrop = isLight ? Color(red: 0.96, green: 0.965, blue: 0.98) : Color(red: 0.055, green: 0.058, blue: 0.095)
        let isHoloPlate = foil == nil && card.rarity == .holo

        ZStack {
            LinearGradient(
                colors: isLight
                    ? [Color(red: 0.968, green: 0.978, blue: 0.986), Color(red: 0.916, green: 0.934, blue: 0.954)]
                    : [Color(red: 0.088, green: 0.092, blue: 0.138), Color(red: 0.068, green: 0.072, blue: 0.112)],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: isLight
                    ? (isHoloPlate ? [hi.opacity(0.18), .clear, sh.opacity(0.12)] : [hi.opacity(0.24), .clear, sh.opacity(0.17)])
                    : [hi.opacity(0.36), hi.opacity(0.06), sh.opacity(0.24)],
                startPoint: UnitPoint(x: 0.10 + tilt.width * 0.20, y: 0.0 + tilt.height * 0.15),
                endPoint: UnitPoint(x: 0.90 + tilt.width * 0.20, y: 1.0 + tilt.height * 0.15)
            )

            if material == .carbon && !isLight {
                FoilTexturePattern(material: .carbon, carbonOpacity: 0.025, carbonPitch: 8.0, carbonLineWidth: 0.85)
                    .equatable()
            } else if foil == nil && card.rarity == .holo {
                ZStack {
                    FoilTexturePattern(
                        material: .holo,
                        inkColor: isLight ? surfaceAccent : .white,
                        holoOpacity: isLight ? 0.020 : 0.024
                    )
                    .equatable()
                    LinearGradient(
                        colors: card.rarity.baseColors.map { $0.opacity(isLight ? 0.08 : 0.11) },
                        startPoint: UnitPoint(x: 0.05 + tilt.width * 0.35, y: 0.05),
                        endPoint: UnitPoint(x: 0.95 + tilt.width * 0.35, y: 0.95)
                    )
                }
                .mask(
                    RadialGradient(
                        colors: [.clear, .clear, .black.opacity(0.50), .black],
                        center: .center,
                        startRadius: 84,
                        endRadius: 175
                    )
                )
            }

            RadialGradient(
                colors: [calmBackdrop.opacity(isLight ? 0.56 : 0.58), .clear],
                center: UnitPoint(x: 0.5, y: 0.52),
                startRadius: 24,
                endRadius: isLight ? 205 : 145
            )

            if isHoloPlate {
                LinearGradient(
                    colors: [.clear, calmBackdrop.opacity(isLight ? 0.62 : 0.34)],
                    startPoint: UnitPoint(x: 0.5, y: 0.52),
                    endPoint: .bottom
                )
                if !isLight {
                    LinearGradient(
                        colors: [calmBackdrop.opacity(0.42), .clear],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.28)
                    )
                }
            }

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.28),
                    .init(color: Color.white.opacity((isLight ? 0.13 : 0.065) * (0.6 + sheen * 0.5)), location: 0.50),
                    .init(color: .clear, location: 0.72)
                ],
                startPoint: UnitPoint(x: -0.10 + tilt.width * 0.45, y: 0.0 + tilt.height * 0.30),
                endPoint: UnitPoint(x: 1.05 + tilt.width * 0.45, y: 0.95 + tilt.height * 0.30)
            )
            .blendMode(.softLight)
        }
    }

    @ViewBuilder private func tierProgress(surfaceAccent: Color, isLight: Bool, allowsReflow: Bool) -> some View {
        tierProgressBody(surfaceAccent: surfaceAccent, isLight: isLight, allowsReflow: allowsReflow)
    }

    @ViewBuilder private func tierProgressBody(surfaceAccent: Color, isLight: Bool, allowsReflow: Bool) -> some View {
            if let retirement {
                VStack(alignment: .leading, spacing: 2.5) {
                    HStack(spacing: 5) {
                        Text("VAULTED")
                            .font(.system(size: allowsReflow ? microSize : min(microSize, 11.5), weight: .bold, design: .rounded))
                            .tracking(0.35)
                            .foregroundStyle(Theme.primaryText.opacity(0.84))
                            .padding(.horizontal, 6.5)
                            .padding(.vertical, 2.5)
                            .background(isLight ? Color.black.opacity(0.085) : Color.white.opacity(0.14), in: Capsule())
                            .overlay(Capsule().strokeBorder(isLight ? Color.black.opacity(0.14) : Color.white.opacity(0.20), lineWidth: 0.65))
                        Text(retirement.formattedRetiredDate)
                            .font(.system(size: allowsReflow ? metaSize : min(metaSize, 12.0), weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.88)
                    }
                    Text("\(card.lifetimeMinutes.minutesText) preserved")
                        .font(.system(size: allowsReflow ? metaSize : min(metaSize, 12.5), weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.primaryText.opacity(0.88))
                        .lineLimit(allowsReflow ? 2 : 1)
                        .minimumScaleFactor(0.88)
                }
                .frame(minHeight: 34, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Vaulted · \(Text(LocalizedStringKey(retirement.reason.title))), \(retirement.formattedRetiredDate), \(card.lifetimeMinutes.minutesText) preserved")
            } else {
                let hours = card.lifetimeMinutes / 60
                let progress = card.rarity.progressToNextTier(minutes: card.lifetimeMinutes)
                if let nextTier = card.rarity.nextTier {
                    let displayedHours = min(Int(nextTier.minimumHours) - 1, Int(hours.rounded()))
                    let remaining = max(1, Int(nextTier.minimumHours) - displayedHours)
                    let tierPct = Int((progress * 100).rounded())
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4.5) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(surfaceAccent)
                                .accessibilityHidden(true)
                            Text("\(remaining)h to \(AppLanguage.current.text(nextTier.shortName))")
                                .foregroundStyle(Theme.primaryText.opacity(0.88))
                        }
                        .font(.system(size: allowsReflow ? metaSize : 12.0, weight: .semibold, design: .rounded))
                        .lineLimit(allowsReflow ? 2 : 1)
                        .minimumScaleFactor(0.85)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(verbatim: AppLanguage.current.text("%lld hours, %lld percent toward %@, %lld hours to go", displayedHours, tierPct, AppLanguage.current.text(nextTier.shortName), remaining)))

                        GeometryReader { geo in
                            let w = max(0, geo.size.width)
                            let fillW = (w > 0 && progress > 0) ? min(w, max(6.0, w * progress)) : 0
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(isLight ? Color.black.opacity(0.14) : Color.white.opacity(0.16))
                                    .overlay(
                                        Capsule().strokeBorder(
                                            isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.10),
                                            lineWidth: 0.5
                                        )
                                    )
                                if fillW > 0 {
                                    Capsule()
                                        .fill(surfaceAccent)
                                        .frame(width: fillW)
                                }
                            }
                            .clipShape(Capsule())
                            .frame(height: 6)
                        }
                        .frame(height: 6)
                        .accessibilityHidden(true)
                    }
                    .frame(minHeight: 34, alignment: .leading)
                } else {
                    Label("Max tier reached", systemImage: "sparkles")
                        .lineLimit(allowsReflow ? 2 : 1)
                        .minimumScaleFactor(0.85)
                        .font(.system(size: allowsReflow ? metaSize : min(metaSize, 15), weight: .bold, design: .rounded))
                        .foregroundStyle(surfaceAccent)
                }
            }
    }
}

private struct CardAllowsReflowKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var cardAllowsReflow: Bool {
        get { self[CardAllowsReflowKey.self] }
        set { self[CardAllowsReflowKey.self] = newValue }
    }
}

/// Renders a design-size card scaled to whatever frame it is given.
struct ScaledCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { geo in
            content
                .dynamicTypeSize(.medium)
                .environment(\.cardAllowsReflow, false)
                .scaleEffect(geo.size.width / CardMetrics.size.width, anchor: .topLeading)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .aspectRatio(CardMetrics.size.width / CardMetrics.size.height, contentMode: .fit)
    }
}

/// Tactile press-in 3D tilt/scale spring for collector cards in the Collection list.
struct CollectorCardPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.968 : 1.0))
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : (configuration.isPressed ? 3.2 : 0)),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.7
            )
            .brightness(configuration.isPressed ? 0.03 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

private struct CardControlPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.68 : 1.0)
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.95 : 1.0))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Scroll-driven diagonal specular glint that sweeps smoothly across a collector card as it moves through the viewport.
struct ScrollSheenSweep: View {
    var cornerRadius: CGFloat = 24
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if !reduceMotion {
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
}
