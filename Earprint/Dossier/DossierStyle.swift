import SwiftUI

// MARK: - Formatting

extension Date {
    /// 2026.10.30
    var dossierDot: String { formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)).replacingOccurrences(of: "/", with: ".") }
    /// Nov 9
    var dossierShort: String { formatted(.dateTime.month(.abbreviated).day()) }
    /// 21:10
    var dossierTime: String { formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)) }

    func dossierRelative(to now: Date, calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: self), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case 0: return AppLanguage.current.text("Today")
        case 1: return AppLanguage.current.text("Yesterday")
        case 2..<60: return AppLanguage.current.text("%lld days ago", days)
        case 60..<730: return AppLanguage.current.text("%lld months ago", days / 30)
        default: return AppLanguage.current.text("%lld years ago", days / 365)
        }
    }
}

enum DossierFormat {
    static func dot(_ date: Date) -> String {
        DateText.dotted(date, calendar: .current)
    }

    static func range(_ start: Date, _ end: Date) -> String {
        let cal = Calendar.current
        if cal.isDate(start, equalTo: end, toGranularity: .month) {
            return "\(start.dossierShort) – \(cal.component(.day, from: end))"
        }
        if cal.isDate(start, equalTo: end, toGranularity: .year) {
            return "\(start.dossierShort) – \(end.dossierShort)"
        }
        return "\(start.formatted(.dateTime.month(.abbreviated).year())) – \(end.formatted(.dateTime.month(.abbreviated).year()))"
    }

    static func hours(_ minutes: Double) -> String {
        let h = minutes / 60
        return h >= 10 ? "\(Int(h.rounded()))h" : String(format: "%.1fh", h)
    }

    static func hourLabel(_ hour: Int) -> String { String(format: "%02d:00", hour) }

    static func grouped(_ n: Int) -> String { n.formatted(.number.grouping(.automatic)) }
}

// MARK: - Shared pieces

extension Rarity {
    var foil: LinearGradient {
        LinearGradient(colors: Array(baseColors.prefix(4)), startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    /// Adaptive tier accent tuned for crisp contrast in both Light and Dark mode.
    var accent: Color {
        switch self {
        case .holo:
            Color.adaptive(
                light: UIColor(red: 0.659, green: 0.141, blue: 0.541, alpha: 1),
                dark: UIColor(red: 1.000, green: 0.471, blue: 0.784, alpha: 1)
            )
        case .obsidian:
            Color.adaptive(
                light: UIColor(red: 0.247, green: 0.212, blue: 0.478, alpha: 1),
                dark: UIColor(red: 0.608, green: 0.573, blue: 0.941, alpha: 1)
            )
        case .platinum:
            Color.adaptive(
                light: UIColor(red: 0.145, green: 0.247, blue: 0.659, alpha: 1),
                dark: UIColor(red: 0.490, green: 0.600, blue: 1.000, alpha: 1)
            )
        case .sapphire:
            Color.adaptive(
                light: UIColor(red: 0.055, green: 0.420, blue: 0.459, alpha: 1),
                dark: UIColor(red: 0.322, green: 0.859, blue: 0.808, alpha: 1)
            )
        case .silver:
            Color.adaptive(
                light: UIColor(red: 0.114, green: 0.373, blue: 0.580, alpha: 1),
                dark: UIColor(red: 0.486, green: 0.784, blue: 0.961, alpha: 1)
            )
        case .bronze:
            Color.adaptive(
                light: UIColor(red: 0.294, green: 0.333, blue: 0.400, alpha: 1),
                dark: UIColor(red: 0.659, green: 0.702, blue: 0.769, alpha: 1)
            )
        }
    }
}

enum DossierPalette {
    static let ink = Theme.canvas
    static let panel = Theme.card
    static let surfaceFill = Theme.surfaceFill
    static let hairline = Theme.hairline
    static let primaryText = Theme.primaryText
    static let dim = Theme.secondaryText
    static let faint = Theme.tertiaryText
}

/// "01  AIRTIME ———" numbered section header, like the tabs of a case file.
struct DossierSectionHeader: View {
    let index: Int
    let title: String
    var trailing: String?
    var accent: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(String(format: "%02d", index))
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(accent)
                .fixedSize()
            Text(AppLanguage.current.text(title).uppercased())
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .tracking(2.0)
                .foregroundStyle(DossierPalette.primaryText.opacity(0.88))
                .lineLimit(1)
                .fixedSize()
            Rectangle().fill(DossierPalette.hairline).frame(height: 1).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 4 }
            if let trailing {
                Text(trailing)
                    .font(.system(.caption2, design: .monospaced, weight: .medium))
                    .foregroundStyle(DossierPalette.dim)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Small rounded "object" surface used by tiles; crisp white ceramic card in Light mode, obsidian glass in Dark mode.
struct DossierTile: ViewModifier {
    var tint: Color = Theme.primaryText
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        content
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                if colorScheme == .light {
                    shape.fill(Theme.card)
                        .overlay {
                            shape.fill(
                                LinearGradient(
                                    colors: [tint.opacity(0.06), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        }
                        .shadow(color: Theme.cardShadow, radius: 10, y: 4)
                } else {
                    shape.fill(
                        LinearGradient(
                            colors: [tint.opacity(0.10), Color.white.opacity(0.025)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
            }
            .overlay {
                if colorScheme == .light {
                    shape.strokeBorder(Theme.cardStroke, lineWidth: 1)
                } else {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.16), .white.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                }
            }
    }
}

extension View {
    func dossierTile(tint: Color = Theme.primaryText) -> some View { modifier(DossierTile(tint: tint)) }

    /// Fade, lift and sharpen as the view scrolls into place.
    func dossierAppear() -> some View {
        scrollTransition(.interactive(timingCurve: .easeOut), axis: .vertical) { content, phase in
            content
                .opacity(phase == .bottomTrailing ? 0.0 : 1)
                .scaleEffect(phase == .bottomTrailing ? 0.94 : 1, anchor: .top)
                .offset(y: phase == .bottomTrailing ? 40 : 0)
                .blur(radius: phase == .bottomTrailing ? 6 : 0)
        }
    }
}

/// Tiny caption above a value.
struct Eyebrow: View {
    let text: String
    var color: Color = DossierPalette.dim
    init(_ text: String, color: Color = DossierPalette.dim) { self.text = text; self.color = color }
    var body: some View {
        Text(AppLanguage.current.text(text).uppercased())
            .font(.system(.caption2, design: .rounded, weight: .heavy))
            .tracking(1.4)
            .foregroundStyle(color)
    }
}

/// Deterministic barcode, like the strip on a grading label.
struct DossierBarcode: View, Equatable {
    let seed: Int
    var color: Color = DossierPalette.primaryText

    var body: some View {
        Canvas { context, size in
            var rng = SplitMix64(seed: UInt64(seed) &* 2_654_435_761 &+ 97)
            var x: CGFloat = 0
            var bars = Path()
            while x < size.width {
                let w = CGFloat([1, 1, 2, 3][Int(rng.unit() * 4)])
                if rng.unit() > 0.42 {
                    bars.addRect(CGRect(x: x, y: 0, width: w, height: size.height))
                }
                x += w + 1
            }
            context.fill(bars, with: .color(color))
        }
        .accessibilityHidden(true)
    }
}

/// Hologram seal that reacts to tilt; static ring & circular lettering stay isolated outside the animated sheen.
struct HoloSeal: View {
    var tilt: CGSize = .zero
    var size: CGFloat = 44
    var text = "EARPRINT · AUTHENTIC · GRADED · "
    var isAnimated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if reduceMotion || !isAnimated {
                shimmerLayer(angle: Angle.degrees(tilt.width * 140 + tilt.height * 60))
            } else {
                TimelineView(.animation(minimumInterval: 1 / 15)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    shimmerLayer(angle: Angle.degrees(t * 36 + tilt.width * 140 + tilt.height * 60))
                }
            }

            // Static foreground seal details (rings, lettering, ear mark) never rebuild per frame.
            HoloSealStaticOverlay(size: size, text: text)
                .equatable()
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
        .accessibilityLabel("Earprint hologram seal")
    }

    private func shimmerLayer(angle: Angle) -> some View {
        ZStack {
            Circle()
                .fill(AngularGradient(colors: [.pink, .yellow, .mint, .cyan, .purple, .pink], center: .center, angle: angle))
            Circle()
                .fill(RadialGradient(
                    colors: [.white.opacity(0.75), .clear],
                    center: UnitPoint(x: 0.5 + tilt.width * 0.3, y: 0.35 + tilt.height * 0.3),
                    startRadius: 0,
                    endRadius: size * 0.6
                ))
                .blendMode(.overlay)
            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let halfLen = size * 0.25
                var rays = Path()
                let baseRad = angle.radians * 0.5
                for i in 0..<12 {
                    let a = Double(i) * (.pi / 12) + baseRad
                    let dx = cos(a) * halfLen
                    let dy = sin(a) * halfLen
                    rays.move(to: CGPoint(x: center.x - dx, y: center.y - dy))
                    rays.addLine(to: CGPoint(x: center.x + dx, y: center.y + dy))
                }
                context.stroke(rays, with: .color(.white.opacity(0.35)), lineWidth: 0.8)
            }
        }
    }
}

private struct HoloSealStaticOverlay: View, Equatable {
    let size: CGFloat
    let text: String

    var body: some View {
        ZStack {
            Circle().strokeBorder(.white.opacity(0.7), lineWidth: 1)
            Circle().inset(by: size * 0.17).strokeBorder(.white.opacity(0.55), lineWidth: 0.7)
            CircularText(text: text, radius: size * 0.41, fontSize: max(4, size * 0.095))
            Image(systemName: "ear.fill")
                .font(.system(size: size * 0.26, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 1)
        }
    }
}

struct CircularText: View {
    let text: String
    let radius: CGFloat
    let fontSize: CGFloat

    var body: some View {
        let chars = Array(text)
        ZStack {
            ForEach(chars.indices, id: \.self) { i in
                Text(String(chars[i]))
                    .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                    .offset(y: -radius)
                    .rotationEffect(.degrees(Double(i) / Double(chars.count) * 360))
            }
        }
    }
}
