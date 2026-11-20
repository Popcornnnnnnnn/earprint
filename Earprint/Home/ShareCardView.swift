import SwiftUI

/// 9:16 card sized for Xiaohongshu, TikTok and Instagram stories.
struct ShareCardView: View {
    let summary: ListeningSummary
    var primaryCard: HeadphoneCard? = nil
    var colorOption: DeviceColorOption? = nil

    private var rarity: Rarity {
        primaryCard?.rarity ?? Rarity(minutes: summary.lifetimeMinutes)
    }

    private var resolvedColor: DeviceColorOption? {
        guard let primaryCard else { return nil }
        return colorOption ?? DeviceColorOption.defaultOption(for: primaryCard.modelKey)
    }

    var body: some View {
        let hasWeekListening = summary.weekMinutes > 0
        let avgDBColor = hasWeekListening ? Theme.levelColor(db: summary.weekDecibels) : DossierPalette.dim

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MY EARPRINT")
                        .font(.caption.weight(.bold))
                        .tracking(2)
                        .foregroundStyle(rarity.accent)
                    Text(summary.periodLabel)
                        .font(.subheadline)
                        .foregroundStyle(DossierPalette.dim)
                }

                Spacer(minLength: 8)

                Text(LocalizedStringKey(rarity.title))
                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                    .tracking(1.0)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(rarity.accent.opacity(0.16), in: Capsule())
                    .overlay(Capsule().strokeBorder(rarity.accent.opacity(0.45), lineWidth: 0.9))
                    .foregroundStyle(rarity.accent)
            }

            Spacer(minLength: 10)

            EarprintGlyph(grid: summary.grid, showHourLabels: true)
                .frame(width: 224, height: 224)
                .frame(maxWidth: .infinity)

            Spacer(minLength: 10)

            Text(summary.weekMinutes.minutesText)
                .font(.system(size: 50, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text("in my headphones this week")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)

            HStack(spacing: 8) {
                Text(summary.persona.emoji)
                Text(LocalizedStringKey(summary.persona.title))
                    .fontWeight(.semibold)
            }
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.white.opacity(0.07), in: Capsule())
            .overlay(Capsule().strokeBorder(DossierPalette.hairline, lineWidth: 1))
            .padding(.top, 14)

            HStack(spacing: 0) {
                mini("\(summary.sessions)", "sessions")
                Rectangle().fill(DossierPalette.hairline).frame(width: 1, height: 26)
                mini(summary.longestSessionMinutes.minutesText, "longest")
                Rectangle().fill(DossierPalette.hairline).frame(width: 1, height: 26)
                if hasWeekListening {
                    mini("\(Int(summary.weekDecibels.rounded())) dB",
                         "avg level",
                         valueColor: avgDBColor)
                } else {
                    mini("—", "avg level", valueColor: avgDBColor)
                }
            }
            .padding(.vertical, 12)
            .background(DossierPalette.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(DossierPalette.hairline, lineWidth: 1))
            .padding(.top, 16)

            Spacer(minLength: 14)

            HStack(spacing: 10) {
                if let primaryCard {
                    HeadphoneArtwork(card: primaryCard, colorOption: resolvedColor, showsChargingCase: false)
                        .frame(width: 28, height: 28)
                        .padding(3)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(DossierPalette.hairline, lineWidth: 0.75))
                } else {
                    Image(systemName: summary.deviceSymbol)
                        .font(.caption)
                        .foregroundStyle(rarity.accent)
                }

                Text(summary.deviceModel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)

                Spacer(minLength: 8)

                HStack(spacing: 5) {
                    Image(systemName: "ear.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(rarity.accent)
                    Text("Earprint")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
        }
        .padding(26)
        .frame(width: 360, height: 640)
        .background(
            ZStack {
                DossierPalette.ink
                RadialGradient(
                    colors: [rarity.glow.opacity(0.24), rarity.accent.opacity(0.06), .clear],
                    center: .topTrailing,
                    startRadius: 10,
                    endRadius: 340
                )
                RadialGradient(
                    colors: [rarity.accent.opacity(0.12), .clear],
                    center: UnitPoint(x: 0.45, y: 0.36),
                    startRadius: 10,
                    endRadius: 240
                )
            }
        )
        .foregroundStyle(.white)
    }

    private func mini(_ value: String, _ label: LocalizedStringKey, valueColor: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ShareSheet: View {
    let summary: ListeningSummary
    var primaryCard: HeadphoneCard? = nil
    var colorOption: DeviceColorOption? = nil

    @Environment(\.displayScale) private var displayScale
    @Environment(\.locale) private var locale

    var body: some View {
        // The share card keeps its 360×640 design size (it is also the exported image);
        // the preview only scales it to fit the sheet, which can be short (landscape) or wide (iPhone Duo).
        GeometryReader { geo in
            let wide = geo.size.width >= 600
            Group {
                if geo.size.width > geo.size.height * 1.1 {
                    HStack(spacing: 28) {
                        preview(maxScale: wide ? 1 : 0.82)
                        shareButton
                            .frame(width: min(280, geo.size.width * 0.4))
                    }
                    .padding(24)
                } else {
                    VStack(spacing: 20) {
                        preview(maxScale: wide ? 1 : 0.82)
                        shareButton
                            .frame(maxWidth: 420)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(DossierPalette.ink.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }

    private func preview(maxScale: CGFloat) -> some View {
        FittedDesign(designSize: CGSize(width: 360, height: 640), maxScale: maxScale) {
            ShareCardView(summary: summary, primaryCard: primaryCard, colorOption: colorOption)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
        }
    }

    @ViewBuilder private var shareButton: some View {
        if let image = renderImage() {
            ShareLink(item: image, preview: SharePreview(Text("My Earprint"), image: image)) {
                Label("Share image", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white, in: Capsule())
                    .foregroundStyle(.black)
            }
        }
    }

    @MainActor private func renderImage() -> Image? {
        let renderer = ImageRenderer(
            content: ShareCardView(summary: summary, primaryCard: primaryCard, colorOption: colorOption)
                .environment(\.locale, locale)
        )
        renderer.scale = max(displayScale, 3)
        guard let ui = renderer.uiImage else { return nil }
        return Image(uiImage: ui)
    }
}
