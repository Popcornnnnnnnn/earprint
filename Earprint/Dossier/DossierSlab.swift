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

    var body: some View {
        let grade = dossier.grade
        let rarity = card.rarity
        VStack(spacing: 10) {
            label(grade: grade, rarity: rarity)
                .frame(height: SlabMetrics.labelHeight)
            cardWell
            footer(rarity: rarity)
                .frame(height: 26)
        }
        .padding(.top, 12)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .frame(width: SlabMetrics.width, height: SlabMetrics.height)
        .background { acrylic(rarity: rarity) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(card.nickname), graded \(grade.scoreText), \(grade.label). \(dossier.hardware.manufacturer), product ID \(dossier.hardware.productID).")
    }

    private func label(grade: EarGrade, rarity: Rarity) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("EARPRINT · AUTHENTICATED")
                    .font(.system(size: 7.5, weight: .heavy, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(rarity.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(card.nickname)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(dossier.hardware.modelName)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    DossierBarcode(seed: card.serial * 7 + 3, color: .white.opacity(0.75))
                        .frame(width: 44, height: 11)
                    Text(certNumber)
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(.top, 3)
            }
            Spacer(minLength: 0)
            Rectangle().fill(.white.opacity(0.12)).frame(width: 1).padding(.vertical, 6)
            VStack(spacing: 0) {
                Text("EAR GRADE")
                    .font(.system(size: 7.5, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.6))
                Text(grade.scoreText)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(rarity.foil)
                    .shadow(color: rarity.glow.opacity(0.5), radius: 6)
                Text(LocalizedStringKey(grade.label))
                    .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(rarity.accent)
            }
            .frame(width: 74)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.10, green: 0.10, blue: 0.14), Color(red: 0.05, green: 0.05, blue: 0.08)], startPoint: .top, endPoint: .bottom))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(LinearGradient(colors: rarity.baseColors, startPoint: UnitPoint(x: tilt.width * 0.5, y: 0), endPoint: UnitPoint(x: 1 + tilt.width * 0.5, y: 1)), lineWidth: 1.5)
        }
    }

    private var cardWell: some View {
        ZStack {
            CardFront(card: card, tilt: tilt)
                .opacity(flipped ? 0 : 1)
            CardBack(card: card, revealed: flipped)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(flipped ? 1 : 0)
        }
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .scaleEffect(SlabMetrics.cardScale)
        .frame(width: SlabMetrics.cardSize.width, height: SlabMetrics.cardSize.height)
        .shadow(color: .black.opacity(0.55), radius: 8, y: 4)
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
            Text("MINTED \(dossier.firstWear.map(DossierFormat.dot) ?? "—")")
                .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HoloSeal(tilt: tilt, size: 30)
                .offset(y: -4)
        }
        .foregroundStyle(.white.opacity(0.42))
        .padding(.horizontal, 6)
    }

    /// Clear plastic case: faint fill, double rim, moving reflection.
    private func acrylic(rarity: Rarity) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return ZStack {
            shape.fill(LinearGradient(colors: [Color.white.opacity(0.13), Color.white.opacity(0.04), Color.white.opacity(0.09)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
            shape.fill(.ultraThinMaterial.opacity(0.35))
            shape.fill(
                LinearGradient(colors: [.clear, .white.opacity(0.22), .clear],
                               startPoint: UnitPoint(x: -0.2 + tilt.width * 0.6, y: 0.0 + tilt.height * 0.4),
                               endPoint: UnitPoint(x: 0.45 + tilt.width * 0.6, y: 0.55 + tilt.height * 0.4))
            )
            .blendMode(.screen)
            shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.65), .white.opacity(0.15), .white.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
            shape.inset(by: 5).strokeBorder(.white.opacity(0.09), lineWidth: 1)
        }
        .shadow(color: rarity.glow.opacity(0.35), radius: 30, y: 14)
    }

    private var certNumber: String {
        let date = dossier.firstWear.map { DossierFormat.dot($0).replacingOccurrences(of: ".", with: "").suffix(4) } ?? "0000"
        return String(format: "#%04d·", card.serial) + dossier.hardware.productID.dropFirst(2) + "·" + date
    }
}

/// Big grading label: the device's hardware identity, engraved, plus provenance.
struct CertificateLabel: View {
    let card: HeadphoneCard
    let dossier: DeviceDossier
    var tilt: CGSize = .zero

    var body: some View {
        let hw = dossier.hardware
        let grade = dossier.grade
        let rarity = card.rarity
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("EARPRINT GRADING AUTHORITY")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(rarity.accent)
                Spacer()
                Text(String(format: "CERT %04d-%@", card.serial, String(hw.productID.dropFirst(2))))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DossierPalette.dim)
            }
            .padding(.bottom, 12)

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.nickname)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text("\(hw.manufacturer) · \(hw.productID)")
                        .font(.system(.footnote, design: .monospaced, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(hw.modelName)
                        .font(.footnote)
                        .foregroundStyle(DossierPalette.dim)
                }
                Spacer(minLength: 0)
                VStack(spacing: 2) {
                    Text("EAR GRADE")
                        .font(.system(size: 8, weight: .heavy, design: .rounded)).tracking(1.2)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(grade.scoreText)
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(rarity.foil)
                        .shadow(color: rarity.glow.opacity(0.45), radius: 8)
                    Text(LocalizedStringKey(grade.label))
                        .font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(1)
                        .foregroundStyle(rarity.accent)
                }
                .padding(.vertical, 8)
                .frame(width: 104)
                .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(rarity.foil, lineWidth: 1))
            }

            Perforation().padding(.vertical, 14)

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                GridRow {
                    engraved("MANUFACTURER", hw.manufacturer)
                    engraved("PRODUCT ID", hw.productID)
                }
                GridRow {
                    engraved("MODEL", hw.modelName)
                    engraved("HARDWARE", hw.hardwareVersion ?? "Not reported")
                }
                GridRow {
                    engraved("FIRMWARE", hw.firmwareVersion ?? "Not reported")
                    engraved("MINTED", dossier.firstWear.map(DossierFormat.dot) ?? "—")
                }
                GridRow {
                    engraved("RECORDED BY", hw.sourceName)
                    engraved("SAMPLES READ", DossierFormat.grouped(dossier.sampleCount))
                }
                GridRow {
                    engraved("SOURCE BUNDLE", hw.sourceBundleID)
                        .gridCellColumns(2)
                }
            }

            Perforation().padding(.vertical, 14)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Eyebrow("History read")
                    Text("\(dossier.days.first.map { DossierFormat.dot($0.date) } ?? "—") – \(DossierFormat.dot(dossier.now))")
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    Text("\(dossier.recordDays) of \(dossier.historyDays) days · synced \(dossier.lastSynced.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(DossierPalette.dim)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                    DossierBarcode(seed: card.serial * 13 + 1, color: .white.opacity(0.6))
                        .frame(height: 18)
                        .padding(.top, 4)
                }
                HoloSeal(tilt: tilt, size: 64)
            }
        }
        .foregroundStyle(.white)
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.11, green: 0.11, blue: 0.15), Color(red: 0.06, green: 0.06, blue: 0.09)], startPoint: .top, endPoint: .bottom))
                .overlay {
                    // Guilloché lines, like security printing.
                    Canvas { context, size in
                        for i in 0..<26 {
                            var path = Path()
                            let y0 = CGFloat(i) * size.height / 22
                            path.move(to: CGPoint(x: 0, y: y0))
                            for x in stride(from: 0, through: size.width, by: 6) {
                                path.addLine(to: CGPoint(x: x, y: y0 + sin(x / 26 + CGFloat(i)) * 9))
                            }
                            context.stroke(path, with: .color(.white.opacity(0.025)), lineWidth: 0.8)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(LinearGradient(colors: rarity.baseColors, startPoint: UnitPoint(x: tilt.width * 0.5, y: 0), endPoint: UnitPoint(x: 1 + tilt.width * 0.5, y: 1)), lineWidth: 1.5)
        }
    }

    private func engraved(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                .tracking(1.3)
                .foregroundStyle(DossierPalette.faint)
            Text(value)
                .font(.system(.footnote, design: .monospaced, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .shadow(color: .black.opacity(0.9), radius: 0, x: 0, y: -0.6)
                .shadow(color: .white.opacity(0.12), radius: 0, x: 0, y: 0.6)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Dashed tear line with punched notches on both sides.
struct Perforation: View {
    var body: some View {
        HStack(spacing: 0) {
            Circle().fill(DossierPalette.ink).frame(width: 12, height: 12).offset(x: -24)
            Line().stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 4])).foregroundStyle(.white.opacity(0.18)).frame(height: 1)
            Circle().fill(DossierPalette.ink).frame(width: 12, height: 12).offset(x: 24)
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
                                Capsule().fill(.white.opacity(0.08))
                                Capsule()
                                    .fill(LinearGradient(colors: [Theme.quiet.color, Theme.moderate.color, Theme.loud.color], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(6, geo.size.width * factor.severity))
                            }
                        }
                        .frame(height: 4)
                    }
                    Text(factor.penalty < 0.05 ? "0.0" : String(format: "−%.1f", factor.penalty))
                        .font(.system(.footnote, design: .monospaced, weight: .bold))
                        .foregroundStyle(factor.penalty < 0.05 ? Theme.quiet.color : (factor.penalty < 0.5 ? Theme.moderate.color : Theme.loud.color))
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
