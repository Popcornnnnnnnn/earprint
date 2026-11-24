import SwiftUI

enum SlabMetrics {
    static let width: CGFloat = 280
    static let labelHeight: CGFloat = 84
    static let cardScale: CGFloat = (width - 28) / CardMetrics.size.width
    static let cardSize = CGSize(width: CardMetrics.size.width * cardScale, height: CardMetrics.size.height * cardScale)
    static let height: CGFloat = 12 + labelHeight + 10 + cardSize.height + 10 + 26 + 8
    static let size = CGSize(width: width, height: height)
}

/// The card sealed in a graded acrylic slab, PSA-style. Rendered at design size; scale it from outside.
struct GradingSlab: View {
    let card: HeadphoneCard
    let dossier: DeviceDossier
    var tilt: CGSize = .zero
    var flipped = false
    var animateSeal = true
    var showsGrade = true
    var showsHardwareID = true
    var showsFirstWear = true
    var proFoil: ProFoilStyle? = nil
    var engravedSubtitle: String? = nil
    var customSerialTag: String? = nil
    var usesSavedCustomization = true
    var usesOriginalArtwork = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.proAccess) private var proAccess
    @Environment(SlabCustomizationStore.self) private var customizationStore: SlabCustomizationStore?

    private var customization: CardCustomization {
        let foilUnlocked = usesSavedCustomization && proAccess.isUnlocked(.foilShaders)
        let engravingUnlocked = usesSavedCustomization && proAccess.isUnlocked(.slabEngraving)
        let saved = foilUnlocked || engravingUnlocked
            ? (customizationStore ?? .shared).customization(for: card.id) : CardCustomization()
        return CardCustomization(
            proFoil: proFoil ?? (foilUnlocked ? saved.proFoil : nil),
            engravedTitle: engravedSubtitle ?? (engravingUnlocked ? saved.engravedTitle : ""),
            customSerial: customSerialTag ?? (engravingUnlocked ? saved.customSerial : "")
        ).sanitized
    }

    var body: some View {
        let grade = dossier.grade
        let rarity = card.rarity
        let customization = customization
        VStack(spacing: 10) {
            label(grade: grade, rarity: rarity, customization: customization)
                .frame(height: SlabMetrics.labelHeight)
            cardWell(foil: customization.proFoil)
            footer(rarity: rarity)
                .frame(height: 26)
        }
        .padding(.top, 12)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .frame(width: SlabMetrics.width, height: SlabMetrics.height)
        .background { acrylic(rarity: rarity) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(card.model), graded \(grade.scoreText), \(grade.label). \(dossier.hardware.manufacturer), product ID \(dossier.hardware.productID).")
        .accessibilityValue(Text([customization.engravedTitle, customization.customSerial]
            .filter { !$0.isEmpty }.joined(separator: " · ")))
    }

    private func label(grade: EarGrade, rarity: Rarity, customization: CardCustomization) -> some View {
        let accent = customization.proFoil?.accent ?? rarity.accent
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("EARPRINT · AUTHENTICATED")
                    .font(.system(size: 7.5, weight: .heavy, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(card.model)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !customization.engravedTitle.isEmpty {
                    Text(customization.engravedTitle)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(DossierPalette.dim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
                if showsHardwareID || !customization.customSerial.isEmpty {
                    HStack(spacing: 5) {
                        DossierBarcode(seed: card.serial * 7 + 3, color: DossierPalette.primaryText.opacity(0.75))
                            .frame(width: 44, height: 11)
                        Text(customization.customSerial.isEmpty ? certNumber : customization.customSerial)
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .foregroundStyle(DossierPalette.dim)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .padding(.top, 3)
                }
            }
            Spacer(minLength: 0)
            if showsGrade {
                Rectangle().fill(DossierPalette.hairline).frame(width: 1).padding(.vertical, 6)
                VStack(spacing: 0) {
                    Text("EAR GRADE")
                        .font(.system(size: 7.5, weight: .heavy, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(DossierPalette.dim)
                    Text(grade.scoreText)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(rarity.foil)
                        .shadow(color: rarity.glow.opacity(colorScheme == .light ? 0.28 : 0.5), radius: 6)
                    Text(LocalizedStringKey(grade.label))
                        .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(accent)
                }
                .frame(width: 74)
            }
        }
        .foregroundStyle(DossierPalette.primaryText)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    colorScheme == .light
                        ? LinearGradient(colors: [.white, Color(red: 0.96, green: 0.965, blue: 0.98)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color(red: 0.10, green: 0.10, blue: 0.14), Color(red: 0.05, green: 0.05, blue: 0.08)], startPoint: .top, endPoint: .bottom)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(LinearGradient(colors: customization.proFoil?.baseColors ?? rarity.baseColors, startPoint: UnitPoint(x: tilt.width * 0.5, y: 0), endPoint: UnitPoint(x: 1 + tilt.width * 0.5, y: 1)), lineWidth: 1.5)
        }
    }

    private func cardWell(foil: ProFoilStyle?) -> some View {
        ZStack {
            CardFront(card: card, tilt: tilt, showsFirstMet: showsFirstWear,
                      proFoil: foil, usesOriginalArtwork: usesOriginalArtwork)
                .environment(\.proAccess, .free)
                .modifier(CardFaceRotation(angle: flipped ? 180 : 0))
            CardBack(card: card)
                .modifier(CardFaceRotation(angle: flipped ? 180 : 0, isBack: true))
        }
        .scaleEffect(SlabMetrics.cardScale)
        .frame(width: SlabMetrics.cardSize.width, height: SlabMetrics.cardSize.height)
        .shadow(color: colorScheme == .light ? Theme.cardShadow : .black.opacity(0.55), radius: 8, y: 4)
        .padding(1)
    }

    private func footer(rarity: Rarity) -> some View {
        HStack(spacing: 6) {
            Text("EARPRINT GRADING")
                .font(.system(size: 7.5, weight: .heavy, design: .rounded))
                .tracking(1.4)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            if showsFirstWear {
                Text("MINTED \(dossier.firstWear.map(DossierFormat.dot) ?? "—")")
                    .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            HoloSeal(tilt: tilt, size: 30, isAnimated: animateSeal)
                .offset(y: -4)
        }
        .foregroundStyle(DossierPalette.faint)
        .padding(.horizontal, 6)
    }

    /// Clear plastic case: faint fill, double rim, moving reflection.
    private func acrylic(rarity: Rarity) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        let isLight = colorScheme == .light
        return ZStack {
            shape.fill(isLight ? Color.white.opacity(0.82) : Color.black.opacity(0.65))
                .shadow(color: isLight ? Theme.cardShadow : rarity.glow.opacity(0.35), radius: isLight ? 18 : 26, y: isLight ? 8 : 14)
            shape.fill(LinearGradient(
                colors: [Color.white.opacity(isLight ? 0.55 : 0.13), Color.white.opacity(0.04), Color.white.opacity(isLight ? 0.35 : 0.09)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            shape.fill(.ultraThinMaterial.opacity(isLight ? 0.5 : 0.35))
            shape.fill(
                LinearGradient(colors: [.clear, .white.opacity(isLight ? 0.45 : 0.22), .clear],
                               startPoint: UnitPoint(x: -0.2 + tilt.width * 0.6, y: 0.0 + tilt.height * 0.4),
                               endPoint: UnitPoint(x: 0.45 + tilt.width * 0.6, y: 0.55 + tilt.height * 0.4))
            )
            .blendMode(.screen)
            shape.strokeBorder(
                LinearGradient(
                    colors: isLight
                        ? [Color.black.opacity(0.14), Color.black.opacity(0.05), Color.black.opacity(0.12)]
                        : [.white.opacity(0.65), .white.opacity(0.15), .white.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
            shape.inset(by: 5).strokeBorder(DossierPalette.hairline, lineWidth: 1)
        }
    }

    private var certNumber: String {
        let prefix = String(format: "#%04d·", card.serial) + dossier.hardware.productID.dropFirst(2)
        guard showsFirstWear else { return prefix }
        let date = dossier.firstWear.map { DossierFormat.dot($0).replacingOccurrences(of: ".", with: "").suffix(4) } ?? "0000"
        return prefix + "·" + date
    }
}

/// Big grading label: the device's hardware identity, engraved, plus provenance.
struct CertificateLabel: View {
    let card: HeadphoneCard
    let dossier: DeviceDossier
    var tilt: CGSize = .zero
    var animateSeal = true
    var showsGrade = true
    var showsHardwareDetails = true
    var showsSourceMetadata = true
    var showsFirstWear = true
    var compact = false
    var showsHealthProvenance = true

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let hw = dossier.hardware
        let grade = dossier.grade
        let rarity = card.rarity
        let isLight = colorScheme == .light
        let hasMiddleGrid = showsHardwareDetails || showsSourceMetadata || showsFirstWear
        let cardPadding: CGFloat = compact ? 11 : 18
        let perfPadding: CGFloat = compact ? 5 : 14
        let notchInset: CGFloat = compact ? 17 : 24
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("EARPRINT GRADING AUTHORITY")
                    .font(.system(size: compact ? 8 : 9, weight: .heavy, design: .rounded))
                    .tracking(compact ? 1.4 : 1.8)
                    .foregroundStyle(rarity.accent)
                Spacer()
                if showsHardwareDetails {
                    Text(String(format: "CERT %04d-%@", card.serial, String(hw.productID.dropFirst(2))))
                        .font(.system(size: compact ? 8 : 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DossierPalette.dim)
                }
            }
            .padding(.bottom, compact ? 6 : 12)

            HStack(alignment: .top, spacing: compact ? 10 : 14) {
                VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                    Text(card.model)
                        .font(.system(compact ? .headline : .title3, design: .rounded, weight: .bold))
                        .lineLimit(compact ? 1 : 2)
                        .minimumScaleFactor(0.8)
                    if showsHardwareDetails {
                        Text("\(hw.manufacturer) · \(hw.productID)")
                            .font(.system(compact ? .caption2 : .footnote, design: .monospaced, weight: .semibold))
                            .foregroundStyle(DossierPalette.dim)
                    }
                }
                Spacer(minLength: 0)
                if showsGrade {
                    VStack(spacing: compact ? 1 : 2) {
                        Text("EAR GRADE")
                            .font(.system(size: compact ? 7 : 8, weight: .heavy, design: .rounded)).tracking(1.1)
                            .foregroundStyle(DossierPalette.dim)
                        Text(grade.scoreText)
                            .font(.system(size: compact ? 24 : 44, weight: .black, design: .rounded))
                            .foregroundStyle(rarity.foil)
                            .shadow(color: rarity.glow.opacity(isLight ? 0.25 : 0.45), radius: compact ? 4 : 8)
                        Text(LocalizedStringKey(grade.label))
                            .font(.system(size: compact ? 7.5 : 9, weight: .heavy, design: .rounded)).tracking(0.8)
                            .foregroundStyle(rarity.accent)
                    }
                    .padding(.vertical, compact ? 4 : 8)
                    .frame(width: compact ? 80 : 104)
                    .background(DossierPalette.surfaceFill, in: RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous).strokeBorder(rarity.foil, lineWidth: 1))
                }
            }

            if hasMiddleGrid {
                Perforation(notchInset: notchInset).padding(.vertical, perfPadding)

                Grid(alignment: .leading, horizontalSpacing: compact ? 10 : 14, verticalSpacing: compact ? 4 : 10) {
                    if showsHardwareDetails {
                        GridRow {
                            engraved("MANUFACTURER", hw.manufacturer)
                            engraved("PRODUCT ID", hw.productID)
                        }
                        GridRow {
                            engraved("MODEL", hw.modelName)
                            engraved("HARDWARE", hw.hardwareVersion ?? "Not reported")
                        }
                        GridRow {
                            if showsFirstWear {
                                engraved("FIRMWARE", hw.firmwareVersion ?? "Not reported")
                                engraved("MINTED", dossier.firstWear.map(DossierFormat.dot) ?? "—")
                            } else {
                                engraved("FIRMWARE", hw.firmwareVersion ?? "Not reported")
                                    .gridCellColumns(2)
                            }
                        }
                    } else if showsFirstWear {
                        GridRow {
                            engraved("MINTED", dossier.firstWear.map(DossierFormat.dot) ?? "—")
                                .gridCellColumns(2)
                        }
                    }
                    if showsSourceMetadata {
                        GridRow {
                            engraved("RECORDED BY", hw.sourceName)
                            engraved("SAMPLES READ", DossierFormat.grouped(dossier.sampleCount))
                        }
                        GridRow {
                            engraved("COLLECTION NUMBER", String(format: "#%04d", card.serial))
                                .gridCellColumns(2)
                        }
                        GridRow {
                            engraved("SOURCE BUNDLE", hw.sourceBundleID)
                                .gridCellColumns(2)
                        }
                    }
                }

                if showsSourceMetadata && !compact && showsHealthProvenance {
                    Text("Collection numbers follow the order of first listening dates in Apple Health.")
                        .font(.caption2)
                        .foregroundStyle(DossierPalette.dim)
                        .padding(.top, 10)
                }
            }

            Perforation(notchInset: notchInset).padding(.vertical, perfPadding)

            HStack(alignment: .center, spacing: compact ? 10 : 12) {
                VStack(alignment: .leading, spacing: compact ? 2 : 5) {
                    if showsSourceMetadata {
                        Eyebrow("History read")
                        let startText = showsFirstWear ? (dossier.days.first.map { DossierFormat.dot($0.date) } ?? "—") : "—"
                        Text("\(startText) – \(DossierFormat.dot(dossier.now))")
                            .font(.system(compact ? .caption2 : .subheadline, design: .monospaced, weight: .semibold))
                        Text("\(dossier.recordDays) of \(dossier.historyDays) days · synced \(dossier.lastSynced.formatted(.relative(presentation: .named)))")
                            .font(compact ? .caption2 : .caption)
                            .foregroundStyle(DossierPalette.dim)
                            .lineLimit(compact ? 1 : 2)
                            .minimumScaleFactor(0.85)
                    }
                    DossierBarcode(seed: card.serial * 13 + 1, color: DossierPalette.primaryText.opacity(0.6))
                        .frame(height: compact ? 10 : 18)
                        .padding(.top, showsSourceMetadata ? (compact ? 2 : 4) : 0)
                }
                if !showsSourceMetadata {
                    Spacer(minLength: 12)
                }
                HoloSeal(tilt: tilt, size: compact ? 40 : 64, isAnimated: animateSeal)
            }
        }
        .foregroundStyle(DossierPalette.primaryText)
        .padding(cardPadding)
        .background {
            RoundedRectangle(cornerRadius: compact ? 18 : 22, style: .continuous)
                .fill(
                    isLight
                        ? LinearGradient(colors: [.white, Color(red: 0.965, green: 0.968, blue: 0.982)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color(red: 0.11, green: 0.11, blue: 0.15), Color(red: 0.06, green: 0.06, blue: 0.09)], startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: Theme.cardShadow, radius: 12, y: 5)
                .overlay {
                    GuillochePattern(lineColor: isLight ? Color.black.opacity(0.03) : Color.white.opacity(0.025))
                        .equatable()
                        .clipShape(RoundedRectangle(cornerRadius: compact ? 18 : 22, style: .continuous))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: compact ? 18 : 22, style: .continuous)
                .strokeBorder(LinearGradient(colors: rarity.baseColors, startPoint: UnitPoint(x: tilt.width * 0.5, y: 0), endPoint: UnitPoint(x: 1 + tilt.width * 0.5, y: 1)), lineWidth: 1.5)
        }
    }

    private func engraved(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: compact ? 1 : 3) {
            Text(title)
                .font(.system(size: compact ? 7 : 8.5, weight: .heavy, design: .rounded))
                .tracking(compact ? 1.0 : 1.3)
                .foregroundStyle(DossierPalette.faint)
            Text(value)
                .font(.system(size: compact ? 9.5 : 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(DossierPalette.primaryText.opacity(0.88))
                .lineLimit(compact ? 1 : 2)
                .minimumScaleFactor(compact ? 0.7 : 0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Static guilloché security line pattern, isolated as `Equatable` so tilt updates never redraw 26 sine paths.
private struct GuillochePattern: View, Equatable {
    var lineColor: Color = Color.white.opacity(0.025)

    var body: some View {
        Canvas { context, size in
            var combined = Path()
            for i in 0..<26 {
                let y0 = CGFloat(i) * size.height / 22
                combined.move(to: CGPoint(x: 0, y: y0))
                for x in stride(from: 0, through: size.width, by: 6) {
                    combined.addLine(to: CGPoint(x: x, y: y0 + sin(x / 26 + CGFloat(i)) * 9))
                }
            }
            context.stroke(combined, with: .color(lineColor), lineWidth: 0.8)
        }
    }
}

/// Dashed tear line with punched notches on both sides.
struct Perforation: View {
    var notchInset: CGFloat = 24

    var body: some View {
        HStack(spacing: 0) {
            Circle().fill(DossierPalette.ink).frame(width: 12, height: 12).offset(x: -notchInset)
            Line().stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 4])).foregroundStyle(DossierPalette.hairline).frame(height: 1)
            Circle().fill(DossierPalette.ink).frame(width: 12, height: 12).offset(x: notchInset)
        }
        .accessibilityHidden(true)
    }

    struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { $0.move(to: CGPoint(x: 0, y: rect.midY)); $0.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)) }
        }
    }
}

/// How the grade was computed: one row per penalty.
struct GradeBreakdown: View {
    let grade: EarGrade
    let accent: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow("How it’s graded")
                Spacer()
                Text("Start at 10.0")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(DossierPalette.dim)
            }
            ForEach(grade.factors) { factor in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(LocalizedStringKey(factor.name)).font(.footnote.weight(.semibold))
                            Spacer()
                            Text(factor.value).font(.system(.footnote, design: .monospaced)).foregroundStyle(DossierPalette.dim)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(DossierPalette.surfaceFill)
                                Capsule()
                                    .fill(LinearGradient(colors: [Theme.quietColor, Theme.moderateColor, Theme.loudColor], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(6, geo.size.width * factor.severity))
                            }
                        }
                        .frame(height: 4)
                    }
                    Text(factor.penalty < 0.05 ? "0.0" : String(format: "−%.1f", factor.penalty))
                        .font(.system(.footnote, design: .monospaced, weight: .bold))
                        .foregroundStyle(factor.penalty < 0.05 ? Theme.quietColor : (factor.penalty < 0.5 ? Theme.moderateColor : Theme.loudColor))
                        .frame(width: 44, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
            }
            Text("Lower volume, a lighter weekly dose and fewer loud or late sessions keep the grade high. Based on the WHO safe-listening guide (80 dB(A) for 40 h a week).")
                .font(.caption)
                .foregroundStyle(DossierPalette.faint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
