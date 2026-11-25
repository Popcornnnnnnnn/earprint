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
        light: UIColor(red: 0.953, green: 0.957, blue: 0.969, alpha: 1),
        dark: UIColor(red: 0.035, green: 0.035, blue: 0.055, alpha: 1)
    )
    static let canvasElevated = Color.adaptive(
        light: UIColor(red: 0.965, green: 0.969, blue: 0.978, alpha: 1),
        dark: UIColor(red: 0.050, green: 0.050, blue: 0.070, alpha: 1)
    )
    static let background = LinearGradient(
        colors: [canvas, canvasElevated],
        startPoint: .top,
        endPoint: .bottom
    )
    static let card = Color.adaptive(
        light: .white,
        dark: UIColor(red: 0.075, green: 0.075, blue: 0.105, alpha: 1)
    )
    static let cardStroke = Color.adaptive(
        light: UIColor.black.withAlphaComponent(0.08),
        dark: UIColor.white.withAlphaComponent(0.09)
    )
    static let cardShadow = Color.adaptive(
        light: UIColor.black.withAlphaComponent(0.08),
        dark: UIColor.black.withAlphaComponent(0.36)
    )
    static let primaryText = Color.adaptive(
        light: UIColor(red: 0.075, green: 0.080, blue: 0.110, alpha: 1),
        dark: .white
    )
    static let secondaryText = Color.adaptive(
        light: UIColor(red: 0.075, green: 0.080, blue: 0.110, alpha: 0.64),
        dark: UIColor.white.withAlphaComponent(0.58)
    )
    static let tertiaryText = Color.adaptive(
        light: UIColor(red: 0.075, green: 0.080, blue: 0.110, alpha: 0.52),
        dark: UIColor.white.withAlphaComponent(0.46)
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

    static let quiet = RGB(0.32, 0.90, 0.86)
    static let moderate = RGB(0.98, 0.78, 0.36)
    static let loud = RGB(0.99, 0.34, 0.46)

    static let quietLight = RGB(0.05, 0.60, 0.55)
    static let moderateLight = RGB(0.80, 0.50, 0.04)
    static let loudLight = RGB(0.86, 0.16, 0.28)

    static let quietColor = Color.adaptive(
        light: UIColor(red: 0.05, green: 0.60, blue: 0.55, alpha: 1),
        dark: UIColor(red: 0.32, green: 0.90, blue: 0.86, alpha: 1)
    )
    static let moderateColor = Color.adaptive(
        light: UIColor(red: 0.80, green: 0.50, blue: 0.04, alpha: 1),
        dark: UIColor(red: 0.98, green: 0.78, blue: 0.36, alpha: 1)
    )
    static let loudColor = Color.adaptive(
        light: UIColor(red: 0.86, green: 0.16, blue: 0.28, alpha: 1),
        dark: UIColor(red: 0.99, green: 0.34, blue: 0.46, alpha: 1)
    )

    /// Glacier mint when quiet, champagne gold around 70 dB(A), rose-crimson when loud.
    static func levelColor(db: Double, colorScheme: ColorScheme = .dark) -> Color {
        let q = colorScheme == .light ? quietLight : quiet
        let m = colorScheme == .light ? moderateLight : moderate
        let l = colorScheme == .light ? loudLight : loud
        switch db {
        case ..<60: return q.color
        case 60..<72: return q.mix(m, (db - 60) / 12).color
        case 72..<82: return m.mix(l, (db - 72) / 10).color
        default: return l.color
        }
    }

    struct RGB {
        let r, g, b: Double
        init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
        var color: Color { Color(red: r, green: g, blue: b) }
        func mix(_ other: RGB, _ t: Double) -> RGB {
            let t = min(max(t, 0), 1)
            return RGB(r + (other.r - r) * t, g + (other.g - g) * t, b + (other.b - b) * t)
        }
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.cardStroke, lineWidth: 1))
            .shadow(color: Theme.cardShadow, radius: 10, y: 4)
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
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
                .foregroundStyle(Theme.moderateColor)
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
                        .padding(.vertical, 8)
                        .background(Theme.surfaceFillStrong, in: Capsule())
                        .contentShape(Capsule())
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
