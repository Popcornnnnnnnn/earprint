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
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        return f.string(from: date)
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
    /// Light accent that reads on the dark dossier background.
    var accent: Color {
        switch self {
        case .holo: Color(red: 0.55, green: 0.95, blue: 0.88)
        case .obsidian: Color(red: 0.72, green: 0.66, blue: 1.00)
        case .platinum: Color(red: 0.72, green: 0.88, blue: 1.00)
        case .gold: Color(red: 0.99, green: 0.82, blue: 0.45)
        case .silver: Color(red: 0.82, green: 0.86, blue: 0.94)
        case .bronze: Color(red: 0.92, green: 0.64, blue: 0.45)
        }
    }
}

enum DossierPalette {
    static let ink = Color(red: 0.035, green: 0.035, blue: 0.055)
    static let panel = Color(red: 0.075, green: 0.075, blue: 0.105)
    static let hairline = Color.white.opacity(0.09)
    static let dim = Color.white.opacity(0.5)
    static let faint = Color.white.opacity(0.32)
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
                .foregroundStyle(.white.opacity(0.88))
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

/// Small rounded "object" surface used by tiles. Darker and crisper than the generic frosted card.
struct DossierTile: ViewModifier {
    var tint: Color = .white
    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [tint.opacity(0.10), Color.white.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0.03)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
            }
    }
}

extension View {
    func dossierTile(tint: Color = .white) -> some View { modifier(DossierTile(tint: tint)) }

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
struct DossierBarcode: View {
    let seed: Int
    var color: Color = .white

    var body: some View {
        Canvas { context, size in
            var rng = SplitMix64(seed: UInt64(seed) &* 2_654_435_761 &+ 97)
            var x: CGFloat = 0
            while x < size.width {
                let w = CGFloat([1, 1, 2, 3][Int(rng.unit() * 4)])
                if rng.unit() > 0.42 {
                    context.fill(Path(CGRect(x: x, y: 0, width: w, height: size.height)), with: .color(color))
                }
                x += w + 1
            }
        }
        .accessibilityHidden(true)
    }
}

/// Spinning rainbow hologram seal that reacts to tilt.
struct HoloSeal: View {
    var tilt: CGSize = .zero
    var size: CGFloat = 44
    var text = "EARPRINT · AUTHENTIC · GRADED · "

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let angle = Angle.degrees(t * 40 + tilt.width * 140 + tilt.height * 60)
            ZStack {
                Circle()
                    .fill(AngularGradient(colors: [.pink, .yellow, .mint, .cyan, .purple, .pink], center: .center, angle: angle))
                Circle()
                    .fill(RadialGradient(colors: [.white.opacity(0.75), .clear], center: UnitPoint(x: 0.5 + tilt.width * 0.3, y: 0.35 + tilt.height * 0.3), startRadius: 0, endRadius: size * 0.6))
                    .blendMode(.overlay)
                ForEach(0..<12, id: \.self) { i in
                    Capsule().fill(.white.opacity(0.35)).frame(width: 0.8, height: size * 0.5)
                        .rotationEffect(.degrees(Double(i) * 15) + angle * 0.5)
                }
                .mask(Circle())
                Circle().strokeBorder(.white.opacity(0.7), lineWidth: 1)
                Circle().inset(by: size * 0.17).strokeBorder(.white.opacity(0.55), lineWidth: 0.7)
                CircularText(text: text, radius: size * 0.41, fontSize: max(4, size * 0.095))
                Image(systemName: "ear.fill")
                    .font(.system(size: size * 0.26, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 1)
            }
            .frame(width: size, height: size)
            .compositingGroup()
            .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
        }
        .accessibilityLabel("Earprint hologram seal")
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
