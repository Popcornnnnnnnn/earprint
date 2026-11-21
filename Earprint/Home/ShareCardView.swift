import SwiftUI

enum ShareCardAspect: String, CaseIterable, Identifiable, Hashable {
    case portrait3x4
    case story9x16

    var id: Self { self }

    var size: CGSize {
        switch self {
        case .portrait3x4: CGSize(width: 360, height: 480)
        case .story9x16: CGSize(width: 360, height: 640)
        }
    }

    var title: String {
        switch self {
        case .portrait3x4: "3:4"
        case .story9x16: "9:16"
        }
    }
}

/// Share card sized for 3:4 (RedNote / Douyin feed) or 9:16 (Stories).
struct ShareCardView: View {
    let summary: ListeningSummary
    var primaryCard: HeadphoneCard? = nil
    var colorOption: DeviceColorOption? = nil
    var aspect: ShareCardAspect = .portrait3x4
    var colorScheme: ColorScheme = .dark

    private var rarity: Rarity {
        primaryCard?.rarity ?? Rarity(minutes: summary.lifetimeMinutes)
    }

    private var resolvedColor: DeviceColorOption? {
        guard let primaryCard else { return nil }
        return colorOption ?? DeviceColorOption.defaultOption(for: primaryCard.modelKey)
    }

    var body: some View {
        let isLight = colorScheme == .light
        let isCompact = aspect == .portrait3x4
        let hasWeekListening = summary.weekMinutes > 0
        let avgDBColor = hasWeekListening ? Theme.levelColor(db: summary.weekDecibels, colorScheme: colorScheme) : DossierPalette.dim
        let fg: Color = isLight ? Color(red: 0.075, green: 0.080, blue: 0.110) : .white

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: isCompact ? 2 : 4) {
                    Text("MY EARPRINT")
                        .font(.caption.weight(.bold))
                        .tracking(2)
                        .foregroundStyle(rarity.accent)
                    Text(summary.periodLabel)
                        .font(isCompact ? .caption : .subheadline)
                        .foregroundStyle(DossierPalette.dim)
                }

                Spacer(minLength: 8)

                Text(LocalizedStringKey(rarity.title))
                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                    .tracking(1.0)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(rarity.accent.opacity(0.14), in: Capsule())
                    .overlay(Capsule().strokeBorder(rarity.accent.opacity(0.45), lineWidth: 0.9))
                    .foregroundStyle(rarity.accent)
            }

            Spacer(minLength: isCompact ? 6 : 10)

            EarprintGlyph(grid: summary.grid, showHourLabels: true, forcedColorScheme: colorScheme)
                .frame(width: isCompact ? 168 : 224, height: isCompact ? 168 : 224)
                .frame(maxWidth: .infinity)

            Spacer(minLength: isCompact ? 6 : 10)

            Text(summary.weekMinutes.minutesText)
                .font(.system(size: isCompact ? 38 : 50, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text("in my headphones this week")
                .font(isCompact ? .caption : .subheadline)
                .foregroundStyle(DossierPalette.dim)

            HStack(spacing: 7) {
                Text(summary.persona.emoji)
                Text(LocalizedStringKey(summary.persona.title))
                    .fontWeight(.semibold)
            }
            .font(isCompact ? .caption : .callout)
            .padding(.horizontal, isCompact ? 10 : 12)
            .padding(.vertical, isCompact ? 5 : 6)
            .background(DossierPalette.surfaceFill, in: Capsule())
            .overlay(Capsule().strokeBorder(DossierPalette.hairline, lineWidth: 1))
            .padding(.top, isCompact ? 8 : 14)

            HStack(spacing: 0) {
                mini("\(summary.sessions)", "sessions", valueColor: fg)
                Rectangle().fill(DossierPalette.hairline).frame(width: 1, height: 24)
                mini(summary.longestSessionMinutes.minutesText, "longest", valueColor: fg)
                Rectangle().fill(DossierPalette.hairline).frame(width: 1, height: 24)
                if hasWeekListening {
                    mini("\(Int(summary.weekDecibels.rounded())) dB",
                         "avg level",
                         valueColor: avgDBColor)
                } else {
                    mini("—", "avg level", valueColor: avgDBColor)
                }
            }
            .padding(.vertical, isCompact ? 9 : 12)
            .background(DossierPalette.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(DossierPalette.hairline, lineWidth: 1))
            .shadow(color: isLight ? Color.black.opacity(0.05) : .clear, radius: 6, y: 2)
            .padding(.top, isCompact ? 10 : 16)

            Spacer(minLength: isCompact ? 8 : 14)

            HStack(spacing: 10) {
                if let primaryCard {
                    HeadphoneArtwork(card: primaryCard, colorOption: resolvedColor, showsChargingCase: false)
                        .frame(width: 26, height: 26)
                        .padding(3)
                        .background(DossierPalette.surfaceFill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(DossierPalette.hairline, lineWidth: 0.75))
                } else {
                    Image(systemName: summary.deviceSymbol)
                        .font(.caption)
                        .foregroundStyle(rarity.accent)
                }

                Text(summary.deviceModel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(fg.opacity(0.82))
                    .lineLimit(1)

                Spacer(minLength: 8)

                HStack(spacing: 5) {
                    Image(systemName: "ear.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(rarity.accent)
                    Text("Earprint")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(fg.opacity(0.75))
                }
            }
        }
        .padding(isCompact ? 20 : 26)
        .frame(width: aspect.size.width, height: aspect.size.height)
        .background(
            ZStack {
                isLight
                    ? Color(red: 0.960, green: 0.964, blue: 0.976)
                    : Color(red: 0.035, green: 0.035, blue: 0.055)
                RadialGradient(
                    colors: [rarity.glow.opacity(isLight ? 0.16 : 0.24), rarity.accent.opacity(isLight ? 0.04 : 0.06), .clear],
                    center: .topTrailing,
                    startRadius: 10,
                    endRadius: 340
                )
                RadialGradient(
                    colors: [rarity.accent.opacity(isLight ? 0.08 : 0.12), .clear],
                    center: UnitPoint(x: 0.45, y: 0.36),
                    startRadius: 10,
                    endRadius: 240
                )
            }
        )
        .foregroundStyle(fg)
        .environment(\.colorScheme, colorScheme)
    }

    private func mini(_ value: String, _ label: LocalizedStringKey, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.caption2)
                .foregroundStyle(DossierPalette.dim)
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
    @Environment(\.colorScheme) private var envColorScheme
    @State private var aspect: ShareCardAspect = .portrait3x4
    @State private var posterScheme: ColorScheme? = nil
    @State private var renderedImage: Image?

    private var activeScheme: ColorScheme {
        posterScheme ?? envColorScheme
    }

    private struct RenderKey: Hashable {
        let cardID: String?
        let deviceName: String
        let periodLabel: String
        let weekMinutes: Int
        let lifetimeMinutes: Int
        let colorID: String?
        let localeID: String
        let aspect: ShareCardAspect
        let scheme: ColorScheme
    }

    private var renderKey: RenderKey {
        RenderKey(
            cardID: primaryCard?.id,
            deviceName: summary.deviceName,
            periodLabel: summary.periodLabel,
            weekMinutes: Int(summary.weekMinutes.rounded()),
            lifetimeMinutes: Int(summary.lifetimeMinutes.rounded()),
            colorID: colorOption?.id,
            localeID: locale.identifier,
            aspect: aspect,
            scheme: activeScheme
        )
    }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= 600
            Group {
                if geo.size.width > geo.size.height * 1.1 {
                    HStack(spacing: 28) {
                        preview(maxScale: wide ? 1 : 0.82)
                        VStack(spacing: 14) {
                            posterControls
                            shareButton
                        }
                        .frame(width: min(280, geo.size.width * 0.4))
                    }
                    .padding(24)
                } else {
                    VStack(spacing: 16) {
                        posterControls
                            .padding(.horizontal, 24)
                        preview(maxScale: wide ? 1 : 0.82)
                        shareButton
                            .frame(maxWidth: 420)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(DossierPalette.ink.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .task(id: renderKey) {
            await Task.yield()
            renderedImage = renderImage()
        }
    }

    private var posterControls: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(ShareCardAspect.allCases) { option in
                    let selected = aspect == option
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.snappy(duration: 0.22)) { aspect = option }
                    } label: {
                        Text(option.title)
                            .font(.caption.weight(.bold).monospacedDigit())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundStyle(selected ? Theme.invertedText : Theme.secondaryText)
                            .background(selected ? Theme.invertedFill : Color.clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Theme.surfaceFill, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.snappy(duration: 0.22)) {
                    posterScheme = activeScheme == .dark ? .light : .dark
                }
            } label: {
                Label(
                    activeScheme == .light ? LocalizedStringKey("Light") : LocalizedStringKey("Dark"),
                    systemImage: activeScheme == .light ? "sun.max.fill" : "moon.fill"
                )
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(Theme.primaryText)
                .background(Theme.surfaceFill, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private func preview(maxScale: CGFloat) -> some View {
        FittedDesign(designSize: aspect.size, maxScale: maxScale) {
            ShareCardView(
                summary: summary,
                primaryCard: primaryCard,
                colorOption: colorOption,
                aspect: aspect,
                colorScheme: activeScheme
            )
            .environment(\.colorScheme, activeScheme)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
            .shadow(color: Theme.cardShadow, radius: 18, y: 8)
        }
    }

    @ViewBuilder private var shareButton: some View {
        if let image = renderedImage {
            ShareLink(item: image, preview: SharePreview(Text("My Earprint"), image: image)) {
                Label("Share image", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.invertedFill, in: Capsule())
                    .foregroundStyle(Theme.invertedText)
            }
        } else {
            Label("Share image", systemImage: "square.and.arrow.up")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.surfaceFill, in: Capsule())
                .foregroundStyle(Theme.tertiaryText)
        }
    }

    @MainActor private func renderImage() -> Image? {
        let renderer = ImageRenderer(
            content: ShareCardView(
                summary: summary,
                primaryCard: primaryCard,
                colorOption: colorOption,
                aspect: aspect,
                colorScheme: activeScheme
            )
            .environment(\.locale, locale)
            .environment(\.colorScheme, activeScheme)
        )
        renderer.scale = max(displayScale, 3)
        guard let ui = renderer.uiImage else { return nil }
        return Image(uiImage: ui)
    }
}
