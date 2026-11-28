import SwiftUI

// MARK: - Formatting

extension Date {
    /// 2026.10.30
    var dossierDot: String { DateText.dotted(self, calendar: .current) }
    /// Nov 9
    var dossierShort: String { dossierShort(calendar: .current) }
    /// 21:10
    var dossierTime: String { dossierTime(calendar: .current) }

    func dossierShort(calendar: Calendar, locale: Locale = AppLanguage.current.locale) -> String {
        DateText.formatTemplate(self, template: "MMM d", calendar: calendar, locale: locale)
    }

    func dossierWeekdayShort(calendar: Calendar, locale: Locale = AppLanguage.current.locale) -> String {
        DateText.formatTemplate(self, template: "EEEMMMd", calendar: calendar, locale: locale)
    }

    func dossierFullDay(calendar: Calendar, locale: Locale = AppLanguage.current.locale) -> String {
        DateText.formatTemplate(self, template: "EEEEMMMd", calendar: calendar, locale: locale)
    }

    func dossierTime(calendar: Calendar) -> String {
        DateText.format(self, dateFormat: "HH:mm", calendar: calendar)
    }

    func dossierRelative(to now: Date, calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: self), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case 0: return AppLanguage.current.text("today")
        case 1: return AppLanguage.current.text("yesterday")
        case 2..<60: return AppLanguage.current.text("%lld days ago", days)
        case 60..<730: return AppLanguage.current.text("%lld months ago", days / 30)
        default: return AppLanguage.current.text("%lld years ago", days / 365)
        }
    }
}

enum DossierFormat {
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

    static func hourLabel(_ hour: Int) -> String { String(format: "%02d:00", hour) }

    static func grouped(_ n: Int) -> String { n.formatted(.number.grouping(.automatic)) }
}

// MARK: - Shared pieces

extension Rarity {
    /// Contrast-safe rich foil gradient for compact pills and segmented controls with white ink.
    var foil: LinearGradient {
        let colors: [Color] = switch self {
        case .holo:
            [
                Color(red: 0.031, green: 0.400, blue: 0.459),
                Color(red: 0.122, green: 0.278, blue: 0.722),
                Color(red: 0.420, green: 0.137, blue: 0.769),
                Color(red: 0.659, green: 0.102, blue: 0.420),
            ]
        case .obsidian:
            [
                Color(red: 0.078, green: 0.094, blue: 0.149),
                Color(red: 0.196, green: 0.192, blue: 0.388),
                Color(red: 0.051, green: 0.063, blue: 0.110),
            ]
        case .platinum:
            [
                Color(red: 0.102, green: 0.188, blue: 0.541),
                Color(red: 0.173, green: 0.282, blue: 0.741),
                Color(red: 0.071, green: 0.118, blue: 0.361),
            ]
        case .sapphire:
            [
                Color(red: 0.039, green: 0.337, blue: 0.380),
                Color(red: 0.063, green: 0.435, blue: 0.478),
                Color(red: 0.035, green: 0.231, blue: 0.322),
            ]
        case .silver:
            [
                Color(red: 0.094, green: 0.294, blue: 0.471),
                Color(red: 0.141, green: 0.408, blue: 0.620),
                Color(red: 0.071, green: 0.212, blue: 0.349),
            ]
        case .bronze:
            [
                Color(red: 0.231, green: 0.263, blue: 0.322),
                Color(red: 0.322, green: 0.365, blue: 0.439),
                Color(red: 0.169, green: 0.192, blue: 0.239),
            ]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    private func accentRGB(isLight: Bool) -> Theme.RGB {
        switch self {
        case .holo:
            isLight ? Theme.RGB(0.580, 0.150, 0.480) : Theme.RGB(1.000, 0.471, 0.784)
        case .obsidian:
            isLight ? Theme.RGB(0.280, 0.240, 0.560) : Theme.RGB(0.608, 0.573, 0.941)
        case .platinum:
            isLight ? Theme.RGB(0.145, 0.247, 0.680) : Theme.RGB(0.490, 0.600, 1.000)
        case .sapphire:
            isLight ? Theme.RGB(0.045, 0.410, 0.475) : Theme.RGB(0.322, 0.859, 0.808)
        case .silver:
            isLight ? Theme.RGB(0.114, 0.373, 0.580) : Theme.RGB(0.486, 0.784, 0.961)
        case .bronze:
            isLight ? Theme.RGB(0.200, 0.240, 0.320) : Theme.RGB(0.659, 0.702, 0.769)
        }
    }

    /// Adaptive tier accent tuned for crisp WCAG AA contrast in both Light and Dark mode.
    var accent: Color {
        Color.adaptive(
            light: accentRGB(isLight: true).uiColor,
            dark: accentRGB(isLight: false).uiColor
        )
    }

    func accent(for colorScheme: ColorScheme) -> Color {
        accentRGB(isLight: colorScheme == .light).color
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

/// Calm elevated card surface used across Dossier tiles in Light and Dark mode.
struct DossierTile: ViewModifier {
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        content.elevatedCard(cornerRadius: 22, padding: padding, stretchHeight: true)
    }
}

extension View {
    func dossierTile(padding: CGFloat = 18) -> some View {
        modifier(DossierTile(padding: padding))
    }
}

/// Crisp caption above a metric or chart.
struct Eyebrow: View {
    let text: String
    var color: Color = DossierPalette.dim
    init(_ text: String, color: Color = DossierPalette.dim) { self.text = text; self.color = color }
    var body: some View {
        Text(LocalizedStringKey(text))
            .textCase(.uppercase)
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .tracking(0.8)
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
            var bars = Path()
            let isMini = size.width <= 36
            if isMini {
                let widths: [CGFloat] = [0.8, 1.1, 1.5]
                let edgeW: CGFloat = 1.2
                let rightEdge = max(2.0, size.width - edgeW)
                bars.addRect(CGRect(x: 0, y: 0, width: edgeW, height: size.height))
                var x: CGFloat = edgeW + 0.8
                var skippedLast = false
                while x < rightEdge - 0.8 {
                    let w = min(widths[Int(rng.unit() * Double(widths.count))], rightEdge - 0.8 - x)
                    let shouldDraw = skippedLast || rng.unit() > 0.22
                    if w >= 0.75, shouldDraw {
                        bars.addRect(CGRect(x: x, y: 0, width: w, height: size.height))
                        skippedLast = false
                    } else {
                        skippedLast = true
                    }
                    x += max(w, 0.75) + 0.8
                }
                if size.width > 6 {
                    bars.addRect(CGRect(x: size.width - edgeW, y: 0, width: edgeW, height: size.height))
                }
            } else {
                let widths: [CGFloat] = [1.0, 1.0, 1.5, 2.5]
                let rightEdge = max(2.5, size.width - 1.5)
                bars.addRect(CGRect(x: 0, y: 0, width: 1.5, height: size.height))
                var x: CGFloat = 2.5
                while x < rightEdge - 1.5 {
                    let w = min(widths[Int(rng.unit() * Double(widths.count))], rightEdge - 1.0 - x)
                    if w >= 0.75, rng.unit() > 0.24 {
                        bars.addRect(CGRect(x: x, y: 0, width: w, height: size.height))
                    }
                    x += max(w, 0.75) + 0.85
                }
                if size.width > 6 {
                    bars.addRect(CGRect(x: size.width - 1.5, y: 0, width: 1.5, height: size.height))
                }
            }
            context.fill(bars, with: .color(color))
        }
        .accessibilityHidden(true)
    }
}

/// Shared button press style for Dossier header and sheet icon controls.
struct DossierIconPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.94 : 1))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Hologram seal that reacts to tilt; static ring & circular lettering stay isolated outside the animated sheen.
struct HoloSeal: View {
    var tilt: CGSize = .zero
    var size: CGFloat = 44
    var isAnimated = true

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerSettled = false

    var body: some View {
        let isLight = colorScheme == .light
        ZStack {
            if reduceMotion || !isAnimated || size < 36 || shimmerSettled {
                shimmerLayer(angle: Angle.degrees(tilt.width * 140 + tilt.height * 60))
            } else {
                TimelineView(.animation(minimumInterval: 1 / 15)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    shimmerLayer(angle: Angle.degrees(t * 36 + tilt.width * 140 + tilt.height * 60))
                }
            }

            // Static foreground seal details (rings, bezel ticks, ear mark) never rebuild per frame.
            HoloSealStaticOverlay(size: size)
                .equatable()
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            if isLight {
                Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: 0.75)
            }
        }
        .shadow(color: .black.opacity(isLight ? 0.14 : 0.35), radius: isLight ? 2 : 3, y: 1)
        .task(id: isAnimated) {
            shimmerSettled = false
            guard isAnimated, !reduceMotion, size >= 36 else { return }
            try? await Task.sleep(for: .seconds(6))
            if !Task.isCancelled {
                shimmerSettled = true
            }
        }
        .accessibilityHidden(true)
    }

    private func shimmerLayer(angle: Angle) -> some View {
        let pearlescent: [Color] = [
            Color(red: 0.42, green: 0.58, blue: 0.68),
            Color(red: 0.55, green: 0.50, blue: 0.70),
            Color(red: 0.66, green: 0.48, blue: 0.56),
            Color(red: 0.45, green: 0.64, blue: 0.60),
            Color(red: 0.42, green: 0.58, blue: 0.68)
        ]
        return ZStack {
            Circle()
                .fill(AngularGradient(colors: pearlescent, center: .center, angle: angle))
            Circle()
                .fill(RadialGradient(
                    colors: [.white.opacity(0.62), .clear],
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
                context.stroke(rays, with: .color(.white.opacity(0.28)), lineWidth: 0.8)
            }
        }
    }
}

private struct HoloSealStaticOverlay: View, Equatable {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().strokeBorder(.white.opacity(0.78), lineWidth: 1)
            Circle().inset(by: size * 0.17).strokeBorder(.white.opacity(0.55), lineWidth: 0.7)
            if size >= 34 {
                Canvas { context, canvasSize in
                    let c = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                    let rInner = size * 0.34
                    let rOuter = size * 0.44
                    var ticks = Path()
                    for i in 0..<36 {
                        let a = Double(i) * (2 * .pi / 36)
                        let dx = CGFloat(cos(a)), dy = CGFloat(sin(a))
                        ticks.move(to: CGPoint(x: c.x + rInner * dx, y: c.y + rInner * dy))
                        ticks.addLine(to: CGPoint(x: c.x + rOuter * dx, y: c.y + rOuter * dy))
                    }
                    context.stroke(ticks, with: .color(.white.opacity(0.68)), lineWidth: max(0.6, size * 0.014))
                }
            }
            Circle()
                .fill(Color(red: 0.16, green: 0.21, blue: 0.28).opacity(size >= 34 ? 0.34 : 0.30))
                .frame(width: size * (size >= 34 ? 0.54 : 0.62), height: size * (size >= 34 ? 0.54 : 0.62))
            Image(systemName: "ear.fill")
                .font(.system(size: size >= 48 ? size * 0.28 : (size >= 34 ? size * 0.36 : size * 0.44), weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.38), radius: 1)
        }
    }
}
