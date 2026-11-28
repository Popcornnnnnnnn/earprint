import SwiftUI

enum SlabMetrics {
    static let width: CGFloat = 290
    static let labelHeight: CGFloat = 96
    static let footerHeight: CGFloat = 28
    static let cardScale: CGFloat = (width - 28) / CardMetrics.size.width
    static let cardSize = CGSize(width: CardMetrics.size.width * cardScale, height: CardMetrics.size.height * cardScale)
    static let height: CGFloat = 14 + labelHeight + 8 + cardSize.height + 8 + footerHeight + 10
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
    var colorOption: DeviceColorOption? = nil
    var onInspectGrade: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.proAccess) private var proAccess
    @Environment(SlabCustomizationStore.self) private var customizationStore: SlabCustomizationStore?
    @Environment(DeviceColorStore.self) private var colorStore: DeviceColorStore?

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
        let rarity = dossier.rarity
        let displayCard = dossier.cardSnapshot(from: card)
        let customization = customization
        let tierName = AppLanguage.current.text(rarity.displayName)
        let longestPhrase = displayCard.longestMinutes > 0
            ? ", \(AppLanguage.current.text("longest wear %@", displayCard.longestMinutes.minutesText))"
            : ""
        let avgDBPhrase = displayCard.averageDecibels > 0
            ? ", \(AppLanguage.current.text("average %lld decibels", Int(displayCard.averageDecibels.rounded())))"
            : ""
        let slab = VStack(spacing: 8) {
            label(grade: grade, rarity: rarity, customization: customization)
                .frame(height: SlabMetrics.labelHeight)
            cardWell(card: displayCard, foil: customization.proFoil)
            footer(rarity: rarity)
                .frame(height: SlabMetrics.footerHeight)
        }
        .padding(.top, 14)
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
        .frame(width: SlabMetrics.width, height: SlabMetrics.height)
        .background { acrylic(rarity: rarity, proFoil: customization.proFoil) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            flipped
                ? AppLanguage.current.text("%@, %@, back face, %@ in last 28 days, lifetime %@, %lld wears%@%@, graded %@", card.model, tierName, displayCard.grid.totalMinutes(lastDays: 28).minutesText, displayCard.lifetimeMinutes.minutesText, displayCard.sessions, longestPhrase, avgDBPhrase, grade.scoreText)
                : AppLanguage.current.text("%@, %@, 30-day Ear Grade %@ out of 10, %@, %@, %lld wears, since %@", card.model, tierName, grade.scoreText, AppLanguage.current.text(grade.label), displayCard.lifetimeMinutes.minutesText, displayCard.sessions, displayCard.firstMet)
        )
        .accessibilityValue(Text([customization.engravedTitle, customization.customSerial]
            .filter { !$0.isEmpty }.joined(separator: " · ")))

        if let onInspectGrade {
            slab.accessibilityAction(named: Text("Inspect Ear Grade"), onInspectGrade)
        } else {
            slab
        }
    }

    private func label(grade: EarGrade, rarity: Rarity, customization: CardCustomization) -> some View {
        let accent = DossierContrast.accentColor(rarity: rarity, proFoil: customization.proFoil, colorScheme: colorScheme)
        let scoreStyle = DossierContrast.gradeScoreGradient(rarity: rarity, proFoil: customization.proFoil, colorScheme: colorScheme)
        let borderColors = DossierContrast.borderColors(rarity: rarity, proFoil: customization.proFoil, colorScheme: colorScheme)
        let labelBorderColors: [Color] = if colorScheme == .light && customization.proFoil == nil && rarity != .holo {
            [accent.opacity(0.50), accent.opacity(0.24), accent.opacity(0.42)]
        } else if colorScheme == .dark && customization.proFoil == nil && rarity != .holo {
            [accent.opacity(0.90), accent.opacity(0.48), Color.white.opacity(0.28)]
        } else {
            borderColors
        }
        return HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 0) {
                Text(dossier.isRetired ? "EARPRINT VAULT" : "EARPRINT ARCHIVE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 1)
                VStack(alignment: .leading, spacing: 1.5) {
                    Text(verbatim: AppLanguage.current.text(rarity.displayName).uppercased())
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    if !customization.engravedTitle.isEmpty {
                        Text(customization.engravedTitle)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(DossierPalette.dim)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
                if showsHardwareID || !customization.customSerial.isEmpty {
                    Spacer(minLength: 1)
                    HStack(spacing: 4) {
                        DossierBarcode(
                            seed: card.serial * 13 + 1,
                            color: DossierPalette.primaryText.opacity(colorScheme == .light ? 0.80 : 0.75)
                        )
                        .equatable()
                        .frame(width: 24, height: 11)
                        Text(customization.customSerial.isEmpty ? certNumber : customization.customSerial)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(DossierPalette.dim)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                } else {
                    Spacer(minLength: 1)
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsGrade {
                Rectangle().fill(DossierPalette.hairline).frame(width: 1).padding(.vertical, 6)
                let gradeBadge = VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 3) {
                        Text("30D EAR GRADE")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .tracking(0.35)
                            .foregroundStyle(DossierPalette.dim)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        if onInspectGrade != nil {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10.5, weight: .heavy))
                                .foregroundStyle(accent)
                                .accessibilityHidden(true)
                        }
                    }
                    Spacer(minLength: 1)
                    HStack(alignment: .firstTextBaseline, spacing: 1.5) {
                        Text(grade.scoreText)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(scoreStyle)
                        if grade.hasRecentData {
                            Text(verbatim: "/10")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(DossierPalette.dim)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
                    Spacer(minLength: 1)
                    Text(LocalizedStringKey(grade.label))
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .tracking(0.35)
                        .foregroundStyle(grade.hasRecentData ? accent : DossierPalette.dim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(.vertical, 6)
                .padding(.leading, 6)
                .padding(.trailing, 4)
                .frame(width: 112, alignment: .leading)

                if let onInspectGrade {
                    Button(action: onInspectGrade) {
                        gradeBadge
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(DossierIconPressStyle())
                } else {
                    gradeBadge
                }
            }
        }
        .foregroundStyle(DossierPalette.primaryText)
        .padding(.horizontal, 10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    colorScheme == .light
                        ? LinearGradient(colors: [.white, Color(red: 0.96, green: 0.965, blue: 0.98)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color(red: 0.135, green: 0.140, blue: 0.185), Color(red: 0.085, green: 0.088, blue: 0.125)], startPoint: .top, endPoint: .bottom)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(LinearGradient(colors: labelBorderColors, startPoint: UnitPoint(x: tilt.width * 0.5, y: 0), endPoint: UnitPoint(x: 1 + tilt.width * 0.5, y: 1)), lineWidth: 1.5)
        }
    }

    private func cardWell(card displayCard: HeadphoneCard, foil: ProFoilStyle?) -> some View {
        let frontTilt = flipped ? .zero : tilt
        let backTilt = flipped ? tilt : .zero
        return ZStack {
            if reduceMotion {
                CardFront(card: displayCard, tilt: frontTilt, colorOption: colorOption ?? colorStore?.selectedColor(for: displayCard),
                          showsFirstMet: showsFirstWear, proFoil: foil, retirement: dossier.retirement, isEmbeddedInSlab: true)
                    .dynamicTypeSize(.medium)
                    .environment(\.proAccess, .free)
                    .opacity(flipped ? 0 : 1)
                CardBack(card: displayCard, tilt: backTilt, proFoil: foil, retirement: dossier.retirement)
                    .dynamicTypeSize(.medium)
                    .environment(\.proAccess, .free)
                    .opacity(flipped ? 1 : 0)
            } else {
                CardFront(card: displayCard, tilt: frontTilt, colorOption: colorOption ?? colorStore?.selectedColor(for: displayCard),
                          showsFirstMet: showsFirstWear, proFoil: foil, retirement: dossier.retirement, isEmbeddedInSlab: true)
                    .dynamicTypeSize(.medium)
                    .environment(\.proAccess, .free)
                    .modifier(CardFaceRotation(angle: flipped ? 180 : 0))
                CardBack(card: displayCard, tilt: backTilt, proFoil: foil, retirement: dossier.retirement)
                    .dynamicTypeSize(.medium)
                    .environment(\.proAccess, .free)
                    .modifier(CardFaceRotation(angle: flipped ? 180 : 0, isBack: true))
            }
        }
        .scaleEffect(SlabMetrics.cardScale)
        .frame(width: SlabMetrics.cardSize.width, height: SlabMetrics.cardSize.height)
        .overlay {
            if colorScheme == .light {
                RoundedRectangle(cornerRadius: CardMetrics.corner * SlabMetrics.cardScale, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: CardMetrics.corner * SlabMetrics.cardScale, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.55), lineWidth: 1.5)
                    RoundedRectangle(cornerRadius: CardMetrics.corner * SlabMetrics.cardScale, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.75)
                }
            }
        }
        .shadow(color: colorScheme == .light ? Theme.cardShadow : .black.opacity(0.45), radius: 8, y: 4)
    }

    private func footer(rarity: Rarity) -> some View {
        HStack(spacing: 6) {
            Text("EARPRINT")
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .tracking(0.8)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let retirement = dossier.retirement {
                Text(retirement.formattedRetiredDate)
                    .font(.system(size: 11.5, weight: .medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            HoloSeal(
                tilt: tilt,
                size: 26,
                isAnimated: animateSeal
            )
        }
        .foregroundStyle(colorScheme == .light ? DossierPalette.dim : DossierPalette.dim.opacity(0.84))
        .padding(.horizontal, 6)
    }

    /// Clear plastic case: subtle depth, double rim, moving reflection.
    private func acrylic(rarity: Rarity, proFoil: ProFoilStyle?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        let isLight = colorScheme == .light
        let glowColor = proFoil?.glow ?? rarity.glow
        return ZStack {
            if isLight {
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.96),
                            Color(red: 0.89, green: 0.925, blue: 0.968).opacity(0.88),
                            Color(red: 0.955, green: 0.968, blue: 0.990).opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.14), radius: 18, y: 10)
                .shadow(color: glowColor.opacity(0.14), radius: 14, y: 4)
                shape.fill(LinearGradient(
                    colors: [Color.white.opacity(0.82), Color.white.opacity(0.20), Color(red: 0.84, green: 0.885, blue: 0.955).opacity(0.32)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                shape.fill(
                    LinearGradient(colors: [.clear, .white.opacity(0.76), .clear],
                                   startPoint: UnitPoint(x: -0.2 + tilt.width * 0.6, y: 0.0 + tilt.height * 0.4),
                                   endPoint: UnitPoint(x: 0.45 + tilt.width * 0.6, y: 0.55 + tilt.height * 0.4))
                )
                shape.strokeBorder(
                    LinearGradient(
                        colors: [Color(red: 0.66, green: 0.72, blue: 0.82).opacity(0.76), Color(red: 0.52, green: 0.58, blue: 0.68).opacity(0.36), .white.opacity(0.90), Color(red: 0.52, green: 0.58, blue: 0.68).opacity(0.36)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                shape.inset(by: 5).strokeBorder(
                    LinearGradient(
                        colors: [Color.black.opacity(0.11), .clear, .white.opacity(0.92), Color(red: 0.72, green: 0.78, blue: 0.88).opacity(0.32)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.15
                )
            } else {
                shape.fill(Color(red: 0.055, green: 0.06, blue: 0.08).opacity(0.88))
                    .shadow(color: glowColor.opacity(0.24), radius: 22, y: 10)
                shape.fill(LinearGradient(
                    colors: [Color.white.opacity(0.14), Color.white.opacity(0.035), Color.white.opacity(0.09)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                shape.fill(.ultraThinMaterial.opacity(0.35))
                shape.fill(LinearGradient(
                    colors: [Color.white.opacity(0.14), Color.white.opacity(0.04), .clear],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.22)
                ))
                shape.fill(
                    LinearGradient(colors: [.clear, .white.opacity(0.20), .clear],
                                   startPoint: UnitPoint(x: -0.2 + tilt.width * 0.6, y: 0.0 + tilt.height * 0.4),
                                   endPoint: UnitPoint(x: 0.45 + tilt.width * 0.6, y: 0.55 + tilt.height * 0.4))
                )
                .blendMode(.screen)
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.36), .white.opacity(0.11), .white.opacity(0.26)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.25
                )
                shape.inset(by: 5).strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.16), .white.opacity(0.05), .white.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
        }
    }

    private var certNumber: String {
        String(format: "#%04d · %@", card.serial, dossier.hardware.productID)
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
    var isInteractive = false
    var liveTiltActive = false
    var demoOverrideTilt: CGSize? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var certificateGradeSize: CGFloat = 38

    var body: some View {
        let hw = dossier.hardware
        let grade = dossier.grade
        let rarity = dossier.rarity
        let isLight = colorScheme == .light
        let accentColor = DossierContrast.accentColor(rarity: rarity, proFoil: nil, colorScheme: colorScheme)
        let scoreStyle = DossierContrast.gradeScoreGradient(rarity: rarity, proFoil: nil, colorScheme: colorScheme)
        let borderColors = DossierContrast.borderColors(rarity: rarity, proFoil: nil, colorScheme: colorScheme)
        let certBorderColor = accentColor.opacity(isLight ? 0.44 : 0.60)
        let leadingNotchBorderColor = certBorderColor
        let trailingNotchBorderColor = certBorderColor
        let hasMiddleGrid = showsHardwareDetails || showsSourceMetadata || showsFirstWear || dossier.isRetired
        let cardPadding: CGFloat = compact ? 11 : 18
        let perfPadding: CGFloat = compact ? 3 : 6
        let notchInset: CGFloat = compact ? 17 : 24
        let interactiveCertificate = isInteractive && !compact
        let topEyebrow: LocalizedStringKey = dossier.isRetired ? "EARPRINT VAULT" : "EARPRINT ARCHIVE"
        VStack(alignment: .leading, spacing: 0) {
            let isCertAX = !compact && dynamicTypeSize.isAccessibilitySize
            let topRowLayout = isCertAX
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(spacing: 8))

            topRowLayout {
                Text(topEyebrow)
                    .font(compact ? .system(size: 8, weight: .bold, design: .rounded) : .system(.caption2, design: .rounded, weight: .bold))
                    .tracking(compact ? 1.2 : 0.8)
                    .foregroundStyle(accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if !isCertAX {
                    Spacer()
                }
                if showsHardwareDetails {
                    let shortPID = hw.productID.hasPrefix("0x") ? String(hw.productID.dropFirst(2)) : hw.productID
                    Text(String(format: interactiveCertificate ? "#%04d · %@" : "CERT %04d-%@", card.serial, interactiveCertificate ? hw.productID : shortPID))
                        .font(compact ? .system(size: 8, weight: .semibold, design: .monospaced) : .system(.caption2, design: .monospaced, weight: .semibold))
                        .foregroundStyle(DossierPalette.dim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .padding(.bottom, compact ? 6 : 12)

            let titleRowLayout = (interactiveCertificate && isCertAX)
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(alignment: interactiveCertificate ? .center : .top, spacing: compact ? 10 : 12))

            titleRowLayout {
                VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                    Text(card.model)
                        .font(.system(compact ? .headline : .title3, design: .rounded, weight: .bold))
                        .lineLimit(!compact && dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        .minimumScaleFactor(0.75)
                        .accessibilityAddTraits(.isHeader)
                    if interactiveCertificate {
                        let statusOrTier = dossier.isRetired
                            ? AppLanguage.current.text("Vaulted")
                            : AppLanguage.current.text(rarity.displayName)
                        Text(verbatim: statusOrTier)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .lineLimit(isCertAX ? 2 : 1)
                            .minimumScaleFactor(0.8)
                    } else if showsHardwareDetails {
                        Text("\(hw.manufacturer) · \(hw.productID)")
                            .font(.system(compact ? .caption2 : .footnote, design: .monospaced, weight: .semibold))
                            .foregroundStyle(DossierPalette.dim)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                if !(interactiveCertificate && isCertAX) {
                    Spacer(minLength: 0)
                }
                if interactiveCertificate {
                    certificateSeal(size: isCertAX ? 48 : 54)
                } else if showsGrade {
                    VStack(spacing: compact ? 1 : 2) {
                        Text("EAR GRADE")
                            .font(.system(size: compact ? 7 : 10.5, weight: .bold, design: .rounded))
                            .tracking(compact ? 1.0 : 0.7)
                            .foregroundStyle(DossierPalette.dim)
                            .lineLimit(1)
                        Text(grade.scoreText)
                            .font(.system(size: compact ? 24 : min(certificateGradeSize, 46), weight: .black, design: .rounded))
                            .foregroundStyle(scoreStyle)
                            .shadow(color: rarity.glow.opacity(isLight ? 0.08 : 0.22), radius: compact ? 2 : 4)
                        Text(LocalizedStringKey(grade.label))
                            .font(.system(size: compact ? 7.5 : 11, weight: .bold, design: .rounded))
                            .tracking(0.6)
                            .foregroundStyle(accentColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .padding(.vertical, compact ? 4 : 8)
                    .frame(width: compact ? 80 : 96)
                    .background(DossierPalette.surfaceFill, in: RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous).strokeBorder(LinearGradient(colors: borderColors, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                }
            }
            .padding(.bottom, interactiveCertificate ? 4 : 0)

            if hasMiddleGrid {
                Perforation(
                    notchInset: notchInset,
                    notchPadding: cardPadding,
                    notchRadius: compact ? 4.5 : 7,
                    leadingNotchBorderColor: leadingNotchBorderColor,
                    trailingNotchBorderColor: trailingNotchBorderColor
                )
                .padding(.vertical, perfPadding)

                if compact {
                    Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
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
                                    engraved("MINTED", dossier.firstWear.map { DateText.dotted($0, calendar: dossier.calendar) } ?? "—")
                                } else {
                                    engraved("FIRMWARE", hw.firmwareVersion ?? "Not reported")
                                        .gridCellColumns(2)
                                }
                            }
                        } else if showsFirstWear {
                            GridRow {
                                engraved("MINTED", dossier.firstWear.map { DateText.dotted($0, calendar: dossier.calendar) } ?? "—")
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
                        if let retirement = dossier.retirement {
                            GridRow {
                                engraved("STATUS", AppLanguage.current.text("Vaulted · %@", AppLanguage.current.text(retirement.reason.title)))
                                engraved("RETIRED", retirement.formattedRetiredDate)
                            }
                        }
                    }
                } else if interactiveCertificate {
                    let secondaryHW = interactiveHardwareCell(hw: hw)
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 10) {
                            if showsHardwareDetails {
                                engraved("MANUFACTURER", hw.manufacturer)
                                engraved(secondaryHW.0, secondaryHW.1)
                            }
                            if showsSourceMetadata {
                                engraved("RECORDED BY", hw.sourceName)
                                engraved("SAMPLES READ", DossierFormat.grouped(dossier.sampleCount))
                            }
                            if let retirement = dossier.retirement {
                                engraved("STATUS", AppLanguage.current.text("Vaulted · %@", AppLanguage.current.text(retirement.reason.title)))
                                if !retirement.farewellNote.isEmpty {
                                    engraved("FAREWELL NOTE", "“\(retirement.farewellNote)”")
                                } else {
                                    engraved("RETIRED", retirement.formattedRetiredDate)
                                }
                            }
                        }
                    } else {
                        Grid(alignment: .topLeading, horizontalSpacing: 14, verticalSpacing: 10) {
                            if showsHardwareDetails || showsSourceMetadata {
                                GridRow {
                                    if showsHardwareDetails {
                                        engraved("MANUFACTURER", hw.manufacturer)
                                    }
                                    if showsSourceMetadata {
                                        engraved("RECORDED BY", hw.sourceName)
                                    }
                                }
                                GridRow {
                                    if showsHardwareDetails {
                                        engraved(secondaryHW.0, secondaryHW.1)
                                    }
                                    if showsSourceMetadata {
                                        engraved("SAMPLES READ", DossierFormat.grouped(dossier.sampleCount))
                                    }
                                }
                            }
                            if let retirement = dossier.retirement {
                                GridRow {
                                    engraved("STATUS", AppLanguage.current.text("Vaulted · %@", AppLanguage.current.text(retirement.reason.title)))
                                    if !retirement.farewellNote.isEmpty {
                                        engraved("FAREWELL NOTE", "“\(retirement.farewellNote)”")
                                    } else {
                                        engraved("RETIRED", retirement.formattedRetiredDate)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Grid(alignment: .topLeading, horizontalSpacing: 14, verticalSpacing: 10) {
                        if showsHardwareDetails {
                            GridRow {
                                engraved("MANUFACTURER", hw.manufacturer)
                                engraved("PRODUCT ID", hw.productID)
                            }
                            GridRow {
                                engraved("MODEL", hw.modelName)
                                if showsFirstWear {
                                    engraved("MINTED", dossier.firstWear.map { DateText.dotted($0, calendar: dossier.calendar) } ?? "—")
                                } else if showsSourceMetadata {
                                    engraved("RECORDED BY", hw.sourceName)
                                }
                            }
                        } else if showsFirstWear {
                            GridRow {
                                engraved("MINTED", dossier.firstWear.map { DateText.dotted($0, calendar: dossier.calendar) } ?? "—")
                                if showsSourceMetadata {
                                    engraved("COLLECTION NUMBER", String(format: "#%04d", card.serial))
                                }
                            }
                        }

                        if showsSourceMetadata && showsHardwareDetails {
                            GridRow {
                                engraved("COLLECTION NUMBER", String(format: "#%04d", card.serial))
                                if let retirement = dossier.retirement {
                                    engraved("RETIRED", retirement.formattedRetiredDate)
                                } else if showsFirstWear {
                                    engraved("RECORDED BY", hw.sourceName)
                                }
                            }
                        }

                        if showsHardwareDetails && (hw.hardwareVersion != nil || hw.firmwareVersion != nil) {
                            GridRow {
                                if let hv = hw.hardwareVersion {
                                    engraved("HARDWARE", hv)
                                }
                                if let fw = hw.firmwareVersion {
                                    engraved("FIRMWARE", fw)
                                }
                            }
                        }

                        if showsSourceMetadata {
                            GridRow {
                                engraved("SAMPLES READ", DossierFormat.grouped(dossier.sampleCount))
                                if !showsHardwareDetails {
                                    engraved("RECORDED BY", hw.sourceName)
                                }
                            }
                            GridRow {
                                engraved("SOURCE BUNDLE", hw.sourceBundleID)
                                    .gridCellColumns(2)
                            }
                        }

                        if let retirement = dossier.retirement {
                            GridRow {
                                engraved("STATUS", AppLanguage.current.text("Vaulted · %@", AppLanguage.current.text(retirement.reason.title)))
                                if !retirement.farewellNote.isEmpty {
                                    engraved("FAREWELL NOTE", "“\(retirement.farewellNote)”")
                                }
                            }
                        }
                    }
                }
            }

            Perforation(
                notchInset: notchInset,
                notchPadding: cardPadding,
                notchRadius: compact ? 4.5 : 7,
                leadingNotchBorderColor: leadingNotchBorderColor,
                trailingNotchBorderColor: trailingNotchBorderColor
            )
            .padding(.vertical, perfPadding)

            let spanFooterLayout = (!compact && dynamicTypeSize.isAccessibilitySize)
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(alignment: .center, spacing: compact ? 10 : 16))

            spanFooterLayout {
                VStack(alignment: .leading, spacing: compact ? 2 : 5) {
                    if showsSourceMetadata {
                        Eyebrow(interactiveCertificate ? "Apple Health span" : "History read")
                        let startText = showsFirstWear ? (dossier.days.first.map { DateText.dotted($0.date, calendar: dossier.calendar) } ?? "—") : "—"
                        Text("\(startText) – \(DateText.dotted(dossier.now, calendar: dossier.calendar))")
                            .font(compact ? .system(.caption2, design: .monospaced, weight: .semibold) : .system(.subheadline, design: .monospaced, weight: .semibold))
                            .monospacedDigit()
                            .lineLimit(!compact && dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                            .minimumScaleFactor(0.8)
                        let syncStamp = "\(DateText.dotted(dossier.lastSynced, calendar: dossier.calendar)) \(dossier.lastSynced.dossierTime(calendar: dossier.calendar))"
                        Group {
                            if showsFirstWear {
                                if dossier.recordDays == dossier.historyDays {
                                    Text("All \(dossier.recordDays) recorded days · synced \(syncStamp)")
                                } else {
                                    Text("\(dossier.recordDays) of \(dossier.historyDays) recorded days · synced \(syncStamp)")
                                }
                            } else {
                                Text("\(dossier.recordDays) record days · synced \(syncStamp)")
                            }
                        }
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(DossierPalette.dim)
                        .lineLimit(compact ? 1 : 2)
                        .minimumScaleFactor(0.85)
                    }
                    if compact {
                        DossierBarcode(seed: card.serial * 13 + 1, color: DossierPalette.primaryText.opacity(0.78))
                            .equatable()
                            .frame(height: 10)
                            .padding(.top, showsSourceMetadata ? 2 : 0)
                    }
                }
                .accessibilityElement(children: .combine)
                if !interactiveCertificate {
                    if (!showsSourceMetadata || !compact) && !(!compact && dynamicTypeSize.isAccessibilitySize) {
                        Spacer(minLength: 14)
                    }
                    certificateSeal(size: compact ? 40 : 56)
                }
            }
            if !compact {
                DossierBarcode(
                    seed: card.serial * 13 + 1,
                    color: DossierPalette.primaryText.opacity(isLight ? 0.42 : 0.36)
                )
                .equatable()
                .frame(maxWidth: .infinity)
                .frame(height: 10)
                .padding(.top, 10)
                .accessibilityHidden(true)
            }
        }
        .foregroundStyle(DossierPalette.primaryText)
        .padding(cardPadding)
        .background {
            RoundedRectangle(cornerRadius: compact ? 18 : 22, style: .continuous)
                .fill(
                    isLight
                        ? LinearGradient(colors: [.white, Color(red: 0.975, green: 0.976, blue: 0.988)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color(red: 0.135, green: 0.138, blue: 0.175), Color(red: 0.095, green: 0.098, blue: 0.130)], startPoint: .top, endPoint: .bottom)
                )
                .overlay {
                    GuillochePattern(lineColor: isLight ? Color.black.opacity(0.048) : Color.white.opacity(0.036))
                        .equatable()
                        .clipShape(RoundedRectangle(cornerRadius: compact ? 18 : 22, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: compact ? 18 : 22, style: .continuous)
                        .strokeBorder(certBorderColor, lineWidth: 1)
                }
        }
        .compositingGroup()
        .shadow(color: Theme.cardShadow, radius: 10, y: 4)
    }

    @ViewBuilder
    private func certificateSeal(size: CGFloat) -> some View {
        if liveTiltActive {
            LiveTiltView(isActive: true, overrideTilt: demoOverrideTilt) { sealTilt in
                HoloSeal(tilt: sealTilt, size: size, isAnimated: false)
            }
        } else {
            HoloSeal(tilt: tilt, size: size, isAnimated: animateSeal)
        }
    }

    private func interactiveHardwareCell(hw: DossierHardware) -> (LocalizedStringKey, String) {
        if let fw = hw.firmwareVersion, !fw.isEmpty {
            return ("FIRMWARE", fw)
        } else if let hv = hw.hardwareVersion, !hv.isEmpty {
            return ("HARDWARE", hv)
        } else {
            return ("COLLECTION NUMBER", String(format: "#%04d", card.serial))
        }
    }

    private func engraved(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: compact ? 1 : 3) {
            Text(title)
                .font(compact ? .system(size: 7, weight: .bold, design: .rounded) : .system(.caption2, design: .rounded, weight: .bold))
                .tracking(compact ? 1.0 : 0.7)
                .foregroundStyle(DossierPalette.dim)
            Text(value)
                .font(compact ? .system(size: 9.5, weight: .semibold, design: .monospaced) : .system(.footnote, design: .monospaced, weight: .semibold))
                .foregroundStyle(DossierPalette.primaryText.opacity(0.92))
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

/// Apple Wallet–style dashed perforation with punched concave side notches.
struct Perforation: View {
    var notchInset: CGFloat = 24
    var notchPadding: CGFloat = 18
    var notchRadius: CGFloat = 7
    var leadingNotchBorderColor: Color = DossierPalette.hairline
    var trailingNotchBorderColor: Color = DossierPalette.hairline

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let diameter = notchRadius * 2
        let horizontalBleed = notchPadding > 0 ? notchPadding : max(0, notchInset - 6)
        let dashColor = colorScheme == .light ? Color.black.opacity(0.13) : Color.white.opacity(0.14)
        ZStack {
            Line()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(dashColor)
                .frame(height: 1)
                .padding(.horizontal, -(horizontalBleed - notchRadius - 4))

            HStack {
                notch(trailing: false, radius: notchRadius)
                Spacer()
                notch(trailing: true, radius: notchRadius)
            }
            .padding(.horizontal, -horizontalBleed)
        }
        .frame(height: diameter)
        .accessibilityHidden(true)
    }

    private func notch(trailing: Bool, radius: CGFloat) -> some View {
        let diameter = radius * 2
        return ZStack {
            EdgeNotchShape(trailing: trailing)
                .fill(.black)
                .blendMode(.destinationOut)
            EdgeNotchArc(trailing: trailing)
                .stroke(
                    trailing ? trailingNotchBorderColor : leadingNotchBorderColor,
                    style: StrokeStyle(lineWidth: 1.0, lineCap: .butt)
                )
        }
        .frame(width: diameter, height: diameter)
        .offset(x: trailing ? radius - 0.5 : -radius + 0.5)
    }

    private struct EdgeNotchShape: Shape {
        let trailing: Bool
        func path(in rect: CGRect) -> Path {
            let r = min(rect.width, rect.height) / 2
            let c = CGPoint(x: rect.midX, y: rect.midY)
            return Path { p in
                if trailing {
                    p.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
                    p.addLine(to: CGPoint(x: c.x, y: rect.maxY))
                    p.addArc(center: c, radius: r, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
                    p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                } else {
                    p.move(to: CGPoint(x: rect.minX, y: rect.minY))
                    p.addLine(to: CGPoint(x: c.x, y: rect.minY))
                    p.addArc(center: c, radius: r, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
                    p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                }
                p.closeSubpath()
            }
        }
    }

    private struct EdgeNotchArc: Shape {
        let trailing: Bool
        func path(in rect: CGRect) -> Path {
            let r = max(0, min(rect.width, rect.height) / 2 - 0.5)
            let c = CGPoint(x: rect.midX, y: rect.midY)
            return Path { p in
                if trailing {
                    p.addArc(center: c, radius: r, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
                } else {
                    p.addArc(center: c, radius: r, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
                }
            }
        }
    }

    struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { $0.move(to: CGPoint(x: 0, y: rect.midY)); $0.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)) }
        }
    }
}

/// How the grade was computed: clean score summary + factor table.
struct GradeBreakdown: View {
    let grade: EarGrade
    let accent: Color
    var rarity: Rarity? = nil
    var showsScoreHeader = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title) private var scoreFontSize: CGFloat = 28
    @ScaledMetric(relativeTo: .caption2) private var impactBaseWidth: CGFloat = 64

    var body: some View {
        let resolvedAccent = rarity.map { DossierContrast.accentColor(rarity: $0, proFoil: nil, colorScheme: colorScheme) } ?? accent
        let scoreGradient = DossierContrast.gradeScoreGradient(rarity: rarity ?? .sapphire, proFoil: nil, colorScheme: colorScheme)
        let scoreStyle: AnyShapeStyle = if grade.hasRecentData {
            if rarity != nil {
                AnyShapeStyle(scoreGradient)
            } else {
                AnyShapeStyle(resolvedAccent)
            }
        } else {
            AnyShapeStyle(DossierPalette.dim)
        }
        let impactColWidth: CGFloat = min(88, max(60, impactBaseWidth))
        let impactAlignment: Alignment = .trailing

        VStack(alignment: .leading, spacing: 14) {
            if showsScoreHeader {
                let isHeaderAX = dynamicTypeSize.isAccessibilitySize
                let scoreHeaderLayout = isHeaderAX
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: 12))

                VStack(alignment: .leading, spacing: 4) {
                    scoreHeaderLayout {
                        Text("Ear Grade")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(DossierPalette.primaryText)
                            .accessibilityAddTraits(.isHeader)
                        if !isHeaderAX {
                            Spacer(minLength: 8)
                        }
                        VStack(alignment: isHeaderAX ? .leading : .trailing, spacing: 1) {
                            HStack(alignment: .firstTextBaseline, spacing: 1.5) {
                                Text(grade.scoreText)
                                    .font(.system(size: isHeaderAX ? scoreFontSize : min(scoreFontSize, 34), weight: .heavy, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(scoreStyle)
                                if grade.hasRecentData {
                                    Text(verbatim: "/10")
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .monospacedDigit()
                                        .foregroundStyle(DossierPalette.dim)
                                }
                            }
                            .lineLimit(1)
                            Text(LocalizedStringKey(grade.label))
                                .font(.system(.caption2, design: .rounded, weight: .bold))
                                .tracking(0.5)
                                .foregroundStyle(grade.hasRecentData ? resolvedAccent : DossierPalette.dim)
                                .lineLimit(1)
                        }
                    }

                    Text("30-day habit score · Not a hearing test")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DossierPalette.dim)
                        .lineLimit(isHeaderAX ? 3 : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)

                if grade.hasRecentData {
                    Rectangle()
                        .fill(DossierPalette.hairline)
                        .frame(height: 1)
                        .accessibilityHidden(true)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("How it’s graded")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(DossierPalette.primaryText)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 4)
                    Text("Last 30 Days · Start at 10.0")
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(DossierPalette.dim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }

            if !grade.hasRecentData {
                Text("Not enough listening in the last 30 days to compute a grade.")
                    .font(.subheadline)
                    .foregroundStyle(DossierPalette.dim)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                let isAX = dynamicTypeSize.isAccessibilitySize
                let hasAnyPenalty = grade.factors.contains { $0.penalty >= 0.05 }
                VStack(alignment: .leading, spacing: 4) {
                    if !isAX {
                        HStack(spacing: 8) {
                            Text("Factor")
                            Spacer(minLength: 4)
                            Text("Value")
                                .padding(.trailing, 6)
                            Text("Deduction")
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                                .frame(width: impactColWidth, alignment: impactAlignment)
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DossierPalette.dim)
                        .accessibilityHidden(true)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(grade.factors.enumerated()), id: \.element.id) { index, factor in
                            let isPerfect = factor.penalty < 0.05
                            let textColor = isPerfect
                                ? Theme.quietText
                                : (factor.penalty < 0.5 ? Theme.moderateText : Theme.loudText)
                            let factorLabel = AppLanguage.current.text(factor.name)
                            let spokenValue = factor.value.replacingOccurrences(of: "dB(A)", with: AppLanguage.current.text("decibels"))
                            let impactSpoken = isPerfect
                                ? AppLanguage.current.text("No deduction")
                                : String(format: AppLanguage.current.text("Minus %.1f points"), factor.penalty)

                            Group {
                                if isAX {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(LocalizedStringKey(factor.name))
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(DossierPalette.primaryText)
                                            .lineLimit(2)
                                        HStack(spacing: 10) {
                                            Text(factor.value)
                                                .font(.subheadline)
                                                .monospacedDigit()
                                                .foregroundStyle(DossierPalette.dim)
                                            Spacer(minLength: 8)
                                            if isPerfect {
                                                Label("No deduction", systemImage: "checkmark")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(Theme.quietText)
                                            } else {
                                                Text(String(format: "−%.1f", factor.penalty))
                                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                                    .monospacedDigit()
                                                    .foregroundStyle(textColor)
                                            }
                                        }
                                    }
                                } else {
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text(LocalizedStringKey(factor.name))
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(DossierPalette.primaryText)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.84)
                                        Spacer(minLength: 4)
                                        Text(factor.value)
                                            .font(.subheadline)
                                            .monospacedDigit()
                                            .foregroundStyle(DossierPalette.dim)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.85)
                                            .layoutPriority(1)
                                            .padding(.trailing, 6)
                                        Group {
                                            if isPerfect {
                                                Text("0.0")
                                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                                    .monospacedDigit()
                                                    .foregroundStyle(DossierPalette.dim)
                                            } else {
                                                Text(String(format: "−%.1f", factor.penalty))
                                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                                    .monospacedDigit()
                                                    .foregroundStyle(textColor)
                                            }
                                        }
                                        .frame(width: impactColWidth, alignment: impactAlignment)
                                    }
                                }
                            }
                            .padding(.vertical, 10)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(factorLabel), \(spokenValue), \(impactSpoken)")

                            if index < grade.factors.count - 1 {
                                Rectangle()
                                    .fill(DossierPalette.hairline)
                                    .frame(height: 1)
                            }
                        }

                        if !hasAnyPenalty {
                            Rectangle()
                                .fill(DossierPalette.hairline)
                                .frame(height: 1)
                                .accessibilityHidden(true)
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption.weight(.semibold))
                                    .accessibilityHidden(true)
                                Text("No deductions across \(grade.factors.count) factors")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(Theme.quietText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 10)
                            .padding(.bottom, 2)
                        }
                    }
                }

                Text("Earprint habit score starting at 10.0 · Deductions round to 0.1; dose uses the WHO 40h @ 80 dB(A) weekly reference.")
                    .font(.caption)
                    .foregroundStyle(DossierPalette.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Contrast-safe gradient & border helpers for slabs, dials, and certificates across Light and Dark themes.
enum DossierContrast {
    static func accentColor(rarity: Rarity, proFoil: ProFoilStyle?, colorScheme: ColorScheme) -> Color {
        guard let proFoil else {
            return rarity.accent(for: colorScheme)
        }
        switch proFoil {
        case .goldBullion:
            return colorScheme == .light ? Color(red: 0.58, green: 0.36, blue: 0.05) : proFoil.accent
        case .obsidianPrism:
            return colorScheme == .light ? Color(red: 0.34, green: 0.27, blue: 0.66) : Color(red: 0.66, green: 0.60, blue: 0.96)
        case .sakuraPearl:
            return colorScheme == .light ? Color(red: 0.62, green: 0.21, blue: 0.44) : proFoil.accent
        case .rawTitanium:
            return colorScheme == .light ? Color(red: 0.28, green: 0.36, blue: 0.43) : Color(red: 0.62, green: 0.72, blue: 0.79)
        }
    }

    static func gradeScoreGradient(rarity: Rarity, proFoil: ProFoilStyle?, colorScheme: ColorScheme) -> LinearGradient {
        let accent = accentColor(rarity: rarity, proFoil: proFoil, colorScheme: colorScheme)
        let darkInk = Color(red: 0.08, green: 0.09, blue: 0.14)
        let colors: [Color]
        if colorScheme == .light {
            // Ensure strong contrast against the near-white grading label across all tiers & light foils.
            if let proFoil {
                colors = [accent, proFoil == .obsidianPrism ? darkInk : accent.opacity(0.85), darkInk]
            } else if rarity == .holo {
                colors = [
                    Color(red: 0.05, green: 0.54, blue: 0.58),
                    Color(red: 0.22, green: 0.34, blue: 0.84),
                    Color(red: 0.76, green: 0.16, blue: 0.52)
                ]
            } else {
                let anchor = rarity.baseColors.indices.contains(2) ? rarity.baseColors[2] : darkInk
                colors = [accent, anchor]
            }
        } else {
            // Ensure dark-label scores always stay bright & crisp against #0D0D14 in Dark mode.
            if let proFoil {
                switch proFoil {
                case .obsidianPrism, .rawTitanium:
                    colors = [.white, accent]
                case .goldBullion, .sakuraPearl:
                    colors = Array(proFoil.baseColors.prefix(3))
                }
            } else if rarity == .holo {
                colors = Array(rarity.baseColors.prefix(5))
            } else {
                colors = [Color(white: 0.96), accent]
            }
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func borderColors(rarity: Rarity, proFoil: ProFoilStyle?, colorScheme: ColorScheme) -> [Color] {
        if colorScheme == .light && proFoil == .sakuraPearl {
            return [Color.black.opacity(0.20), rarity.accent.opacity(0.40), Color.black.opacity(0.16)]
        }
        if colorScheme == .dark && (proFoil == .obsidianPrism || (proFoil == nil && rarity == .obsidian)) {
            let accent = accentColor(rarity: rarity, proFoil: proFoil, colorScheme: colorScheme)
            return [.white.opacity(0.32), accent.opacity(0.55), .white.opacity(0.16)]
        }
        if let proFoil {
            return proFoil.baseColors
        }
        return rarity == .holo ? rarity.prismRimColors : rarity.baseColors
    }
}
