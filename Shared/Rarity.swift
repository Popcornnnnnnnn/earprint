import SwiftUI

/// Material craft texture rendered across `FoilSurface`.
/// Shared by both the main app and widget extension.
enum FoilMaterial: String, Codable, Hashable {
    case matteGrain
    case brushed
    case satin
    case carbon
    case holo
}

/// Card achievement tier from lifetime listening hours (6 tiers: 0h Bronze Slate up to 2,000h Liquid Holo).
/// Shared by the app and the widget extension.
enum Rarity: String, Codable, CaseIterable, Identifiable {
    case holo = "HOLO"
    case obsidian = "OBSIDIAN"
    case platinum = "PLATINUM"
    case sapphire = "SAPPHIRE"
    case silver = "SILVER"
    case bronze = "BRONZE"

    var id: String { rawValue }

    /// Tiers ordered from entry level (0h) to top tier (2,000h).
    static let allAscending: [Rarity] = [
        .bronze, .silver, .sapphire, .platinum, .obsidian, .holo
    ]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? ""
        switch raw {
        case "GOLD": self = .silver
        case "EMERALD": self = .sapphire
        case "AMETHYST": self = .platinum
        case "DIAMOND": self = .obsidian
        default: self = Self(rawValue: raw) ?? .bronze
        }
    }

    init(minutes: Double) {
        switch minutes / 60 {
        case 2000...: self = .holo
        case 1000..<2000: self = .obsidian
        case 400..<1000: self = .platinum
        case 120..<400: self = .sapphire
        case 25..<120: self = .silver
        default: self = .bronze
        }
    }

    /// Minimum lifetime hours required to reach this tier.
    var minimumHours: Double {
        switch self {
        case .bronze: 0
        case .silver: 25
        case .sapphire: 120
        case .platinum: 400
        case .obsidian: 1000
        case .holo: 2000
        }
    }

    var nextTier: Rarity? {
        switch self {
        case .bronze: .silver
        case .silver: .sapphire
        case .sapphire: .platinum
        case .platinum: .obsidian
        case .obsidian: .holo
        case .holo: nil
        }
    }

    /// Hours needed for the next tier, nil at the top (2,000h+).
    var nextTierHours: Double? { nextTier?.minimumHours }

    func progressToNextTier(minutes: Double) -> Double {
        guard let next = nextTierHours else { return 1 }
        let hours = minutes / 60
        let span = max(1, next - minimumHours)
        return min(max((hours - minimumHours) / span, 0), 1)
    }

    /// Material craft texture applied on `FoilSurface`.
    var material: FoilMaterial {
        switch self {
        case .bronze: .matteGrain
        case .silver: .brushed
        case .sapphire: .brushed
        case .platinum: .satin
        case .obsidian: .carbon
        case .holo: .holo
        }
    }

    /// Short finish descriptor shown in tier badges and the collector binder.
    var finishLabel: String {
        switch self {
        case .bronze: "Liquid Satin"
        case .silver: "Frosted Glass"
        case .sapphire: "Aqua Enamel"
        case .platinum: "Sapphire Silk"
        case .obsidian: "Forged Carbon"
        case .holo: "Chromatic Prism"
        }
    }

    /// Intensity of glass foil refraction sheen (from subtle satin on Mist up to 0.92 on Prism Aurora).
    var sheenOpacity: Double {
        switch self {
        case .holo: 0.92
        case .obsidian: 0.62
        case .platinum: 0.46
        case .sapphire: 0.34
        case .silver: 0.26
        case .bronze: 0.18
        }
    }

    var title: String {
        switch self {
        case .holo: "PRISM AURORA · LEGENDARY"
        case .obsidian: "SMOKED TITANIUM"
        case .platinum: "DEEP COBALT"
        case .sapphire: "GLACIER TEAL"
        case .silver: "ARCTIC ICE"
        case .bronze: "BRUSHED MIST"
        }
    }

    var shortName: String {
        switch self {
        case .holo: "Prism"
        case .obsidian: "Titanium"
        case .platinum: "Cobalt"
        case .sapphire: "Glacier"
        case .silver: "Arctic"
        case .bronze: "Mist"
        }
    }

    var tagline: String {
        switch self {
        case .bronze: "Cool brushed mist glass cast on your first listen"
        case .silver: "Luminous frost-blue silk glass at 25+ hours"
        case .sapphire: "Mint-aqua to deep ocean glass at 120+ hours"
        case .platinum: "Electric indigo to royal sapphire silk at 400+ hours"
        case .obsidian: "Carbon obsidian lit with violet-steel silk at 1,000+ hours"
        case .holo: "Full-spectrum liquid prism aurora at 2,000+ hours"
        }
    }

    var baseColors: [Color] {
        switch self {
        case .holo:
            // #6 Prism Aurora — full-spectrum vivid crown
            [Color(red: 0.125, green: 0.910, blue: 0.863), Color(red: 0.259, green: 0.596, blue: 1.000),
             Color(red: 0.604, green: 0.302, blue: 1.000), Color(red: 1.000, green: 0.278, blue: 0.620),
             Color(red: 1.000, green: 0.820, blue: 0.302)]
        case .obsidian:
            // #5 Smoked Titanium
            [Color(red: 0.078, green: 0.094, blue: 0.149), Color(red: 0.275, green: 0.337, blue: 0.502),
             Color(red: 0.365, green: 0.306, blue: 0.651), Color(red: 0.031, green: 0.039, blue: 0.071),
             Color(red: 0.078, green: 0.094, blue: 0.149)]
        case .platinum:
            // #4 Deep Cobalt
            [Color(red: 0.118, green: 0.208, blue: 0.600), Color(red: 0.388, green: 0.510, blue: 1.000),
             Color(red: 0.078, green: 0.129, blue: 0.420), Color(red: 0.043, green: 0.071, blue: 0.259),
             Color(red: 0.118, green: 0.208, blue: 0.600)]
        case .sapphire:
            // #3 Glacier Teal
            [Color(red: 0.063, green: 0.471, blue: 0.522), Color(red: 0.322, green: 0.859, blue: 0.808),
             Color(red: 0.051, green: 0.275, blue: 0.388), Color(red: 0.031, green: 0.153, blue: 0.239),
             Color(red: 0.063, green: 0.471, blue: 0.522)]
        case .silver:
            // #2 Arctic Ice
            [Color(red: 0.169, green: 0.431, blue: 0.627), Color(red: 0.580, green: 0.831, blue: 0.969),
             Color(red: 0.106, green: 0.286, blue: 0.451), Color(red: 0.059, green: 0.165, blue: 0.278),
             Color(red: 0.169, green: 0.431, blue: 0.627)]
        case .bronze:
            // #1 Brushed Mist
            [Color(red: 0.314, green: 0.349, blue: 0.408), Color(red: 0.659, green: 0.702, blue: 0.769),
             Color(red: 0.208, green: 0.235, blue: 0.290), Color(red: 0.129, green: 0.149, blue: 0.188),
             Color(red: 0.314, green: 0.349, blue: 0.408)]
        }
    }

    /// 3x3 sculptural `MeshGradient` stop colors for iOS 18 liquid-silk cards & widgets.
    var meshColors: [Color] {
        let mid = baseColors[0]
        let hi = baseColors[1]
        let sh = baseColors[2]
        let deep = baseColors[3]
        switch self {
        case .holo:
            let gold = baseColors[4]
            let jewelTeal = Color(red: 0.047, green: 0.486, blue: 0.588)
            let vividAzure = Color(red: 0.145, green: 0.388, blue: 0.922)
            let deepCobalt = Color(red: 0.078, green: 0.251, blue: 0.600)
            let irisViolet = Color(red: 0.486, green: 0.227, blue: 0.929)
            let hotMagenta = Color(red: 0.902, green: 0.180, blue: 0.541)
            let royalIndigo = Color(red: 0.075, green: 0.090, blue: 0.369)
            let deepAmethyst = Color(red: 0.357, green: 0.129, blue: 0.714)
            let coralRose = Color(red: 0.878, green: 0.282, blue: 0.459)
            return [
                jewelTeal, vividAzure, gold,
                deepCobalt, irisViolet, hotMagenta,
                royalIndigo, deepAmethyst, coralRose,
            ]
        case .obsidian:
            return [
                mid, hi, sh,
                deep, mid, sh,
                deep, deep, mid,
            ]
        case .bronze, .silver, .sapphire, .platinum:
            return [
                mid, hi, mid,
                mid, hi, sh,
                deep, sh, deep,
            ]
        }
    }

    /// Closed full-spectrum color ring for exclusive `.holo` prismatic borders.
    var prismRimColors: [Color] {
        let emerald = Color(red: 0.169, green: 0.910, blue: 0.690)
        return [
            baseColors[0], baseColors[1], baseColors[2],
            baseColors[3], baseColors[4], emerald, baseColors[0],
        ]
    }

    /// Tilt-shifted 3x3 control points for `MeshGradient` surfaces.
    static func meshPoints(tilt: CGSize = .zero) -> [SIMD2<Float>] {
        let ox = Float(max(-0.14, min(0.14, tilt.width * 0.14)))
        let oy = Float(max(-0.12, min(0.12, tilt.height * 0.12)))
        return [
            [0, 0], [0.5 + ox * 0.4, 0], [1, 0],
            [0, 0.5 + oy * 0.4], [0.5 + ox, 0.46 + oy], [1, 0.5 - oy * 0.4],
            [0, 1], [0.5 - ox * 0.4, 1], [1, 1],
        ]
    }

    var ink: Color {
        .white
    }

    var glow: Color {
        switch self {
        case .holo: Color(red: 0.659, green: 0.333, blue: 1.000)
        case .obsidian: Color(red: 0.478, green: 0.447, blue: 0.851)
        case .platinum: Color(red: 0.400, green: 0.522, blue: 1.000)
        case .sapphire: Color(red: 0.275, green: 0.824, blue: 0.784)
        case .silver: Color(red: 0.471, green: 0.769, blue: 0.941)
        case .bronze: Color(red: 0.596, green: 0.639, blue: 0.710)
        }
    }
}

/// Optional collector finishes. The earned rarity stays independent of the selected finish.
enum ProFoilStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case goldBullion, obsidianPrism, sakuraPearl, rawTitanium

    var id: String { rawValue }

    var title: String {
        switch self {
        case .goldBullion: "GOLD BULLION"
        case .obsidianPrism: "OBSIDIAN PRISM"
        case .sakuraPearl: "SAKURA PEARL"
        case .rawTitanium: "RAW TITANIUM"
        }
    }

    var shortName: String {
        switch self {
        case .goldBullion: "Gold Bullion"
        case .obsidianPrism: "Obsidian Prism"
        case .sakuraPearl: "Sakura Pearl"
        case .rawTitanium: "Raw Titanium"
        }
    }

    var subtitle: String {
        switch self {
        case .goldBullion: "Brushed metallic gold"
        case .obsidianPrism: "Dark carbon with a prism flare"
        case .sakuraPearl: "Warm rose-pearl satin"
        case .rawTitanium: "Aerospace matte titanium"
        }
    }

    var material: FoilMaterial {
        switch self {
        case .goldBullion: .brushed
        case .obsidianPrism: .carbon
        case .sakuraPearl: .satin
        case .rawTitanium: .matteGrain
        }
    }

    var baseColors: [Color] {
        switch self {
        case .goldBullion:
            [Self.color(0x9A621F), Self.color(0xFFE29B), Self.color(0xBF8634), Self.color(0x714617)]
        case .obsidianPrism:
            [Self.color(0x0C101C), Self.color(0x35354E), Self.color(0x141B30), Self.color(0x060810)]
        case .sakuraPearl:
            [Self.color(0xEAA9BA), Self.color(0xFFF4E9), Self.color(0xE1ADCB), Self.color(0xB981A9)]
        case .rawTitanium:
            [Self.color(0x545D65), Self.color(0x888F94), Self.color(0x48545D), Self.color(0x29323B)]
        }
    }

    var ink: Color {
        switch self {
        case .goldBullion: Self.color(0x241204)
        case .sakuraPearl: Self.color(0x351C30)
        case .obsidianPrism, .rawTitanium: .white
        }
    }

    var glow: Color {
        switch self {
        case .goldBullion: Self.color(0xE8A539)
        case .obsidianPrism: Self.color(0x958CFF)
        case .sakuraPearl: Self.color(0xF3A1BD)
        case .rawTitanium: Self.color(0x91A8B7)
        }
    }

    var accent: Color {
        switch self {
        case .goldBullion: Self.color(0xBD8229)
        case .obsidianPrism: Self.color(0x8B79CF)
        case .sakuraPearl: Self.color(0xC56E9A)
        case .rawTitanium: Self.color(0x758998)
        }
    }

    var sheenOpacity: Double {
        switch self {
        case .goldBullion: 0.85
        case .obsidianPrism: 0.72
        case .sakuraPearl: 0.66
        case .rawTitanium: 0.24
        }
    }

    private static func color(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 255) / 255,
              green: Double((hex >> 8) & 255) / 255,
              blue: Double(hex & 255) / 255)
    }
}
