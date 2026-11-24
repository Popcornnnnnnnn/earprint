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
        case .bronze: "Anodized Matte"
        case .silver: "Beaded Alloy"
        case .sapphire: "Brushed Slate"
        case .platinum: "Frosted Plum"
        case .obsidian: "DLC Coating"
        case .holo: "Prism Oxide"
        }
    }

    /// Intensity of prismatic color-dodge foil shimmer (0 for matte entry tiers, up to 0.9 for Holo).
    var sheenOpacity: Double {
        switch self {
        case .holo: 0.90
        case .obsidian: 0.62
        case .platinum: 0.42
        case .sapphire: 0.26
        case .silver, .bronze: 0
        }
    }

    var title: String {
        switch self {
        case .holo: "LIQUID HOLO · LEGENDARY"
        case .obsidian: "MIDNIGHT CARBON"
        case .platinum: "DEEP PURPLE"
        case .sapphire: "FJORD TEAL"
        case .silver: "SILVER ALUMINUM"
        case .bronze: "BRONZE SLATE"
        }
    }

    var shortName: String {
        switch self {
        case .holo: "Holo"
        case .obsidian: "Carbon"
        case .platinum: "Deep Purple"
        case .sapphire: "Fjord"
        case .silver: "Silver"
        case .bronze: "Bronze"
        }
    }

    var tagline: String {
        switch self {
        case .bronze: "Starter anodized slate cast on your first listen"
        case .silver: "Brushed silver aluminum unibody at 25+ hours"
        case .sapphire: "Coastal brushed fjord teal at 120+ hours"
        case .platinum: "Frosted velvet deep purple at 400+ hours"
        case .obsidian: "Forged midnight carbon at 1,000+ hours"
        case .holo: "Full-spectrum liquid holographic crown at 2,000+ hours"
        }
    }

    var baseColors: [Color] {
        switch self {
        case .holo:
            // #6 Liquid Holo
            [Color(red: 0.424, green: 0.961, blue: 0.910), Color(red: 0.604, green: 0.518, blue: 1.000),
             Color(red: 1.000, green: 0.518, blue: 0.808), Color(red: 1.000, green: 0.941, blue: 0.549),
             Color(red: 0.424, green: 0.961, blue: 0.910)]
        case .obsidian:
            // #5 Midnight Carbon
            [Color(red: 0.059, green: 0.078, blue: 0.125), Color(red: 0.145, green: 0.180, blue: 0.259),
             Color(red: 0.086, green: 0.118, blue: 0.180), Color(red: 0.031, green: 0.043, blue: 0.071),
             Color(red: 0.059, green: 0.078, blue: 0.125)]
        case .platinum:
            // #4 Deep Purple
            [Color(red: 0.294, green: 0.204, blue: 0.427), Color(red: 0.522, green: 0.388, blue: 0.710),
             Color(red: 0.212, green: 0.137, blue: 0.322), Color(red: 0.141, green: 0.086, blue: 0.227),
             Color(red: 0.294, green: 0.204, blue: 0.427)]
        case .sapphire:
            // #3 Fjord Teal
            [Color(red: 0.322, green: 0.482, blue: 0.525), Color(red: 0.525, green: 0.682, blue: 0.722),
             Color(red: 0.227, green: 0.376, blue: 0.420), Color(red: 0.149, green: 0.271, blue: 0.306),
             Color(red: 0.322, green: 0.482, blue: 0.525)]
        case .silver:
            // #2 Silver Aluminum
            [Color(red: 0.725, green: 0.753, blue: 0.800), Color(red: 0.933, green: 0.945, blue: 0.965),
             Color(red: 0.604, green: 0.635, blue: 0.690), Color(red: 0.482, green: 0.514, blue: 0.569),
             Color(red: 0.725, green: 0.753, blue: 0.800)]
        case .bronze:
            // #1 Bronze Slate
            [Color(red: 0.455, green: 0.314, blue: 0.231), Color(red: 0.710, green: 0.510, blue: 0.388),
             Color(red: 0.353, green: 0.231, blue: 0.165), Color(red: 0.263, green: 0.169, blue: 0.118),
             Color(red: 0.455, green: 0.314, blue: 0.231)]
        }
    }

    var ink: Color {
        switch self {
        case .bronze, .sapphire, .platinum, .obsidian:
            .white
        case .silver, .holo:
            Color(red: 0.08, green: 0.08, blue: 0.10)
        }
    }

    var glow: Color {
        switch self {
        case .obsidian: Color(red: 0.302, green: 0.565, blue: 0.769)
        case .platinum: Color(red: 0.522, green: 0.388, blue: 0.710)
        case .sapphire: Color(red: 0.427, green: 0.612, blue: 0.659)
        case .silver: Color(red: 0.725, green: 0.753, blue: 0.800)
        case .bronze: Color(red: 0.710, green: 0.510, blue: 0.388)
        case .holo: Color(red: 0.604, green: 0.518, blue: 1.000)
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
