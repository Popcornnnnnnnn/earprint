import SwiftUI

enum Theme {
    static let background = LinearGradient(
        colors: [Color(red: 0.05, green: 0.06, blue: 0.12), Color(red: 0.02, green: 0.02, blue: 0.04)],
        startPoint: .top,
        endPoint: .bottom
    )
    static let card = Color.white.opacity(0.06)
    static let cardStroke = Color.white.opacity(0.08)
    static let secondaryText = Color.white.opacity(0.55)

    static let quiet = RGB(0.36, 0.90, 0.80)
    static let moderate = RGB(1.00, 0.76, 0.33)
    static let loud = RGB(1.00, 0.38, 0.40)

    /// Teal when quiet, amber around 70 dB(A), coral when loud.
    static func levelColor(db: Double) -> Color {
        switch db {
        case ..<60: return quiet.color
        case 60..<72: return quiet.mix(moderate, (db - 60) / 12).color
        case 72..<82: return moderate.mix(loud, (db - 72) / 10).color
        default: return loud.color
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
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

/// Compact badge shown when the app is displaying fallback sample data instead of Apple Health records.
struct SampleDataBanner: View {
    var badgeText: String = "Sample data"
    var detail: String?
    var isLoading: Bool = false
    var onConnect: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.caption2.weight(.bold))
                    Text(badgeText)
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(Theme.moderate.color)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Theme.moderate.color.opacity(0.14), in: Capsule())
                .overlay(Capsule().stroke(Theme.moderate.color.opacity(0.32), lineWidth: 1))

                Spacer()

                if let onConnect {
                    Button(action: onConnect) {
                        HStack(spacing: 5) {
                            if isLoading {
                                ProgressView().controlSize(.mini).tint(.white)
                            } else {
                                Image(systemName: "heart.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.loud.color)
                            }
                            Text(isLoading ? "Syncing…" : "Connect Health")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                }
            }

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
