import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Global appearance preference controlled in Settings (`System`, `Light`, or `Dark`).
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "app.appearance"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

extension Color {
    /// Dynamic Light/Dark color resolved cleanly against SwiftUI's environment trait collection.
    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

enum Theme {
    static let canvas = Color.adaptive(
        light: UIColor(red: 0.938, green: 0.944, blue: 0.960, alpha: 1),
        dark: UIColor(red: 0.035, green: 0.035, blue: 0.055, alpha: 1)
    )
    static let canvasElevated = Color.adaptive(
        light: UIColor(red: 0.952, green: 0.957, blue: 0.970, alpha: 1),
        dark: UIColor(red: 0.050, green: 0.050, blue: 0.070, alpha: 1)
    )
    static let background = LinearGradient(
        colors: [canvas, canvasElevated],
        startPoint: .top,
        endPoint: .bottom
    )
    static let card = Color.adaptive(
        light: .white,
        dark: UIColor(red: 0.102, green: 0.106, blue: 0.140, alpha: 1)
    )
    static let cardStroke = Color.adaptive(
        light: UIColor.black.withAlphaComponent(0.085),
        dark: UIColor.white.withAlphaComponent(0.105)
    )
    static let cardShadow = Color.adaptive(
        light: UIColor.black.withAlphaComponent(0.085),
        dark: UIColor.black.withAlphaComponent(0.36)
    )
    static let artworkWellLightTop = Color(red: 0.34, green: 0.38, blue: 0.45)
    static let artworkWellLightBottom = Color(red: 0.24, green: 0.27, blue: 0.34)
    static let primaryText = Color.adaptive(
        light: UIColor(red: 0.075, green: 0.080, blue: 0.110, alpha: 1),
        dark: .white
    )
    static let secondaryText = Color.adaptive(
        light: UIColor(red: 0.075, green: 0.080, blue: 0.110, alpha: 0.68),
        dark: UIColor.white.withAlphaComponent(0.68)
    )
    static let tertiaryText = Color.adaptive(
        light: UIColor(red: 0.075, green: 0.080, blue: 0.110, alpha: 0.63),
        dark: UIColor.white.withAlphaComponent(0.54)
    )
    static let surfaceFill = Color.adaptive(
        light: UIColor.black.withAlphaComponent(0.05),
        dark: UIColor.white.withAlphaComponent(0.07)
    )
    static let surfaceFillStrong = Color.adaptive(
        light: UIColor.black.withAlphaComponent(0.09),
        dark: UIColor.white.withAlphaComponent(0.12)
    )
    static let hairline = Color.adaptive(
        light: UIColor.black.withAlphaComponent(0.085),
        dark: UIColor.white.withAlphaComponent(0.10)
    )
    static let controlStroke = Color.adaptive(
        light: UIColor.black.withAlphaComponent(0.13),
        dark: UIColor.white.withAlphaComponent(0.16)
    )
    static let detailBackdrop = Color.adaptive(
        light: UIColor(red: 0.945, green: 0.950, blue: 0.965, alpha: 0.96),
        dark: UIColor(red: 0.030, green: 0.030, blue: 0.050, alpha: 0.94)
    )
    static let invertedFill = Color.adaptive(
        light: UIColor(red: 0.090, green: 0.095, blue: 0.125, alpha: 1),
        dark: .white
    )
    static let invertedText = Color.adaptive(
        light: .white,
        dark: .black
    )

    static let quiet = RGB(0.22, 0.86, 0.58)
    static let moderate = RGB(0.98, 0.78, 0.36)
    static let loud = RGB(0.99, 0.34, 0.46)

    static let quietLight = RGB(0.04, 0.52, 0.33)
    static let moderateLight = RGB(0.79, 0.44, 0.02)
    static let loudLight = RGB(0.78, 0.13, 0.24)

    // Deeper Light-mode dial tokens for crisp thin-arc contrast on bright surfaces.
    static let quietDialLight = RGB(0.02, 0.43, 0.27)
    static let moderateDialLight = RGB(0.76, 0.42, 0.02)
    static let loudDialLight = RGB(0.72, 0.10, 0.20)

    static let quietColor = Color.adaptive(
        light: UIColor(red: 0.04, green: 0.52, blue: 0.33, alpha: 1),
        dark: UIColor(red: 0.22, green: 0.86, blue: 0.58, alpha: 1)
    )
    static let moderateColor = Color.adaptive(
        light: UIColor(red: 0.79, green: 0.44, blue: 0.02, alpha: 1),
        dark: UIColor(red: 0.98, green: 0.78, blue: 0.36, alpha: 1)
    )
    static let loudColor = Color.adaptive(
        light: UIColor(red: 0.78, green: 0.13, blue: 0.24, alpha: 1),
        dark: UIColor(red: 0.99, green: 0.34, blue: 0.46, alpha: 1)
    )

    // WCAG AA >= 4.8:1 text-safe adaptive loudness inks for small colored labels in Light mode.
    static let quietText = Color.adaptive(
        light: UIColor(red: 0.03, green: 0.44, blue: 0.27, alpha: 1),
        dark: UIColor(red: 0.22, green: 0.86, blue: 0.58, alpha: 1)
    )
    static let moderateText = Color.adaptive(
        light: UIColor(red: 0.60, green: 0.33, blue: 0.01, alpha: 1),
        dark: UIColor(red: 0.98, green: 0.78, blue: 0.36, alpha: 1)
    )
    static let loudText = Color.adaptive(
        light: UIColor(red: 0.75, green: 0.12, blue: 0.23, alpha: 1),
        dark: UIColor(red: 0.99, green: 0.34, blue: 0.46, alpha: 1)
    )
    static let trophyGold = Color.adaptive(
        light: UIColor(red: 0.60, green: 0.39, blue: 0.02, alpha: 1),
        dark: UIColor(red: 0.96, green: 0.78, blue: 0.28, alpha: 1)
    )

    static func levelTextColor(db: Double) -> Color {
        let rounded = Int(db.rounded())
        switch rounded {
        case ..<66: return quietText
        case 66..<76: return moderateText
        default: return loudText
        }
    }

    static func levelZoneName(db: Double) -> String {
        let rounded = Int(db.rounded())
        switch rounded {
        case ..<66: return "Quiet"
        case 66..<76: return "Moderate"
        default: return "Loud"
        }
    }

    private static func levelRGB(db: Double, isLight: Bool, useDialTokens: Bool = false) -> RGB {
        let q = isLight ? (useDialTokens ? quietDialLight : quietLight) : quiet
        let m = isLight ? (useDialTokens ? moderateDialLight : moderateLight) : moderate
        let l = isLight ? (useDialTokens ? loudDialLight : loudLight) : loud
        let rounded = Int(db.rounded())
        switch rounded {
        case ..<66:
            return q
        case 66..<76:
            return m
        default:
            return l
        }
    }

    /// Perceptual three-zone loudness palette aligned with Quiet / Moderate / Loud keys.
    /// When `colorScheme` is nil, resolves dynamically for Light and Dark appearance.
    static func levelColor(db: Double, colorScheme: ColorScheme? = nil) -> Color {
        if let colorScheme {
            return levelRGB(db: db, isLight: colorScheme == .light).color
        }
        return Color.adaptive(
            light: levelRGB(db: db, isLight: true).uiColor,
            dark: levelRGB(db: db, isLight: false).uiColor
        )
    }

    static func dialLevelColor(db: Double, colorScheme: ColorScheme) -> Color {
        levelRGB(db: db, isLight: colorScheme == .light, useDialTokens: true).color
    }

    struct RGB {
        let r, g, b: Double
        init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
        var color: Color { Color(red: r, green: g, blue: b) }
        var uiColor: UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }
        func mix(_ other: RGB, _ t: Double) -> RGB {
            let t = min(max(t, 0), 1)
            return RGB(r + (other.r - r) * t, g + (other.g - g) * t, b + (other.b - b) * t)
        }
    }
}

/// Authoritative elevated panel surface shared across Rings, Dossier, and utility cards.
struct ElevatedCardSurface: ViewModifier {
    var cornerRadius: CGFloat = 22
    var padding: CGFloat? = nil
    var stretchHeight: Bool = false
    var strokeColor: Color? = nil
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let isLight = colorScheme == .light
        content
            .padding(padding ?? 0)
            .frame(maxWidth: .infinity, maxHeight: stretchHeight ? .infinity : nil, alignment: stretchHeight ? .topLeading : .leading)
            .background(
                shape.fill(Theme.card)
                    .shadow(
                        color: isLight ? Theme.cardShadow : .black.opacity(0.24),
                        radius: isLight ? 10 : 12,
                        y: isLight ? 3.5 : 6
                    )
                    .shadow(
                        color: isLight ? Color.black.opacity(0.035) : .clear,
                        radius: 1.5,
                        y: 1
                    )
            )
            .overlay(shape.strokeBorder(strokeColor ?? Theme.cardStroke, lineWidth: 1))
    }
}

extension View {
    func elevatedCard(
        cornerRadius: CGFloat = 22,
        padding: CGFloat? = nil,
        stretchHeight: Bool = false,
        strokeColor: Color? = nil
    ) -> some View {
        modifier(ElevatedCardSurface(
            cornerRadius: cornerRadius,
            padding: padding,
            stretchHeight: stretchHeight,
            strokeColor: strokeColor
        ))
    }

    func card() -> some View {
        elevatedCard(cornerRadius: 22, padding: 16)
    }
}

/// Compact badge shown when the app is displaying fallback sample data instead of Apple Health records.
struct SampleDataBanner: View {
    var badgeText: LocalizedStringKey = "Sample data"
    var detail: LocalizedStringKey?
    var isLoading: Bool = false
    var onConnect: (() -> Void)?

    @ViewBuilder
    var body: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-hideSampleBanner") {
            EmptyView()
        } else {
            bannerContent
        }
        #else
        bannerContent
        #endif
    }

    private var bannerContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.caption2.weight(.bold))
                    Text(badgeText)
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(Theme.moderateText)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Theme.moderateColor.opacity(0.14), in: Capsule())
                .overlay(Capsule().stroke(Theme.moderateColor.opacity(0.32), lineWidth: 1))

                Spacer()

                if let onConnect {
                    Button(action: onConnect) {
                        HStack(spacing: 5) {
                            if isLoading {
                                ProgressView().controlSize(.mini).tint(Theme.primaryText)
                            } else {
                                Image(systemName: "heart.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.loudColor)
                            }
                            Text(isLoading ? "Syncing…" : "Connect Health")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Theme.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.surfaceFillStrong, in: Capsule())
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                }
            }

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Shared dashed reference-line glyph kept in sync with chart average rules.
struct DashRuleGlyph: View {
    var width: CGFloat = 18
    var color: Color = Theme.secondaryText
    var lineWidth: CGFloat = 1.2
    var dash: [CGFloat] = [4, 3]

    var body: some View {
        Canvas { context, size in
            var line = Path()
            line.move(to: CGPoint(x: 0, y: size.height / 2))
            line.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            context.stroke(
                line,
                with: .color(color),
                style: StrokeStyle(lineWidth: lineWidth, dash: dash)
            )
        }
        .frame(width: width, height: 6)
        .accessibilityHidden(true)
    }
}

/// Shared canonical 3-band loudness legend reused across Rings, Card Back, and Activity charts.
struct LoudnessLegendRow: View {
    var showsAverageDash = false
    var compact = false
    var compactLabels = false
    var allowsStacking = true
    var showsUnit = true
    var averageLabel: LocalizedStringKey = "Avg"

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption2) private var compactFontSize: CGFloat = 11.5
    @ScaledMetric(relativeTo: .caption2) private var regularDotSize: CGFloat = 7.5
    @ScaledMetric(relativeTo: .caption2) private var compactDotSize: CGFloat = 5.5

    var body: some View {
        let dotSize = min(11, compact ? compactDotSize : regularDotSize)
        let itemSpacing: CGFloat = compact ? 6.0 : 10
        let quietLabel: LocalizedStringKey = "Quiet <66"
        let moderateLabel: LocalizedStringKey = compactLabels ? "Mod 66–75" : "Moderate 66–75"
        let highLabel: LocalizedStringKey = showsUnit ? "Loud 76+ dB(A)" : "Loud 76+"
        let isAX = dynamicTypeSize.isAccessibilitySize
        let shouldStack = allowsStacking && (isAX || (compact && dynamicTypeSize >= .xLarge))
        let layout = shouldStack
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: itemSpacing))
        let voLabel: LocalizedStringKey = showsAverageDash
            ? "Daily average dashed line. Loudness key: quiet under 66, moderate 66 to 75, loud 76 plus decibels"
            : "Loudness key: quiet under 66, moderate 66 to 75, loud 76 plus decibels"

        layout {
            if showsAverageDash {
                HStack(spacing: 4) {
                    DashRuleGlyph(width: 12, color: Theme.secondaryText, lineWidth: 1.15, dash: [3.5, 2.5])
                    Text(averageLabel)
                        .lineLimit(shouldStack ? 2 : 1)
                }
            }

            dotItem(Theme.quietColor, quietLabel, dotSize: dotSize, shouldStack: shouldStack)
            dotItem(Theme.moderateColor, moderateLabel, dotSize: dotSize, shouldStack: shouldStack)
            dotItem(Theme.loudColor, highLabel, dotSize: dotSize, shouldStack: shouldStack)
        }
        .font(compact && !shouldStack ? .system(size: min(compactFontSize, 15.0), weight: .medium) : .caption.weight(.medium))
        .foregroundStyle(Theme.secondaryText)
        .lineLimit(shouldStack ? 2 : 1)
        .minimumScaleFactor(shouldStack ? 1.0 : 0.88)
        .frame(maxWidth: .infinity, alignment: shouldStack ? .leading : .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(voLabel)
    }

    private func dotItem(_ color: Color, _ label: LocalizedStringKey, dotSize: CGFloat, shouldStack: Bool) -> some View {
        HStack(spacing: compact ? 3.0 : 5) {
            Circle()
                .fill(color)
                .frame(width: dotSize, height: dotSize)
                .accessibilityHidden(true)
            Text(label)
                .lineLimit(shouldStack ? 2 : 1)
        }
    }
}
