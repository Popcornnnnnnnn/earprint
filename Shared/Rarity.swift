import SwiftUI

/// Material craft texture rendered across `FoilSurface`.
/// Shared by both the main app and widget extension.
enum FoilMaterial: String, Codable, Hashable {
    case matteGrain
    case brushed
    case satin
    case frosted
    case faceted
    case carbon
    case holo
}

/// Card achievement tier from lifetime listening hours (10 tiers: 0h Bronze Slate up to 2,000h Liquid Holo).
/// Shared by the app and the widget extension.
enum Rarity: String, Codable, CaseIterable, Identifiable {
    case holo = "HOLO"
    case obsidian = "OBSIDIAN"
    case diamond = "DIAMOND"
    case platinum = "PLATINUM"
    case amethyst = "AMETHYST"
    case sapphire = "SAPPHIRE"
    case emerald = "EMERALD"
    case gold = "GOLD"
    case silver = "SILVER"
    case bronze = "BRONZE"

    var id: String { rawValue }

    /// Tiers ordered from entry level (0h) to top tier (2,000h).
    static let allAscending: [Rarity] = [
        .bronze, .silver, .gold, .emerald, .sapphire,
        .amethyst, .platinum, .diamond, .obsidian, .holo
    ]

    init(minutes: Double) {
        switch minutes / 60 {
        case 2000...: self = .holo
        case 1400..<2000: self = .obsidian
        case 900..<1400: self = .diamond
        case 550..<900: self = .platinum
        case 300..<550: self = .amethyst
        case 160..<300: self = .sapphire
        case 80..<160: self = .emerald
        case 35..<80: self = .gold
        case 10..<35: self = .silver
        default: self = .bronze
        }
    }

    /// Minimum lifetime hours required to reach this tier.
    var minimumHours: Double {
        switch self {
        case .bronze: 0
        case .silver: 10
        case .gold: 35
        case .emerald: 80
        case .sapphire: 160
        case .amethyst: 300
        case .platinum: 550
        case .diamond: 900
        case .obsidian: 1400
        case .holo: 2000
        }
    }

    var nextTier: Rarity? {
        switch self {
        case .bronze: .silver
        case .silver: .gold
        case .gold: .emerald
        case .emerald: .sapphire
        case .sapphire: .amethyst
        case .amethyst: .platinum
        case .platinum: .diamond
        case .diamond: .obsidian
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
        case .gold: .satin
        case .emerald: .frosted
        case .sapphire: .brushed
        case .amethyst: .faceted
        case .platinum: .satin
        case .diamond: .faceted
        case .obsidian: .carbon
        case .holo: .holo
        }
    }

    /// Short finish descriptor shown in tier badges and the collector binder.
    var finishLabel: String {
        switch self {
        case .bronze: "Anodized Matte"
        case .silver: "Beaded Alloy"
        case .gold: "Satin Titanium"
        case .emerald: "Frosted Mineral"
        case .sapphire: "Brushed Slate"
        case .amethyst: "Anodized Indigo"
        case .platinum: "Frosted Plum"
        case .diamond: "Smoked Dusk"
        case .obsidian: "DLC Coating"
        case .holo: "Prism Oxide"
        }
    }

    /// Intensity of prismatic color-dodge foil shimmer (0 for matte entry tiers, up to 0.9 for Holo).
    var sheenOpacity: Double {
        switch self {
        case .holo: 0.90
        case .obsidian: 0.62
        case .diamond: 0.50
        case .platinum: 0.42
        case .amethyst: 0.34
        case .sapphire: 0.26
        case .emerald: 0.20
        case .gold: 0.18
        case .silver, .bronze: 0
        }
    }

    var title: String {
        switch self {
        case .holo: "LIQUID HOLO · LEGENDARY"
        case .obsidian: "MIDNIGHT CARBON"
        case .diamond: "TWILIGHT SLATE"
        case .platinum: "DEEP PURPLE"
        case .amethyst: "SLATE INDIGO"
        case .sapphire: "FJORD TEAL"
        case .emerald: "SAGE MIST"
        case .gold: "MIST CHAMPAGNE"
        case .silver: "SILVER ALUMINUM"
        case .bronze: "BRONZE SLATE"
        }
    }

    var shortName: String {
        switch self {
        case .holo: "Holo"
        case .obsidian: "Carbon"
        case .diamond: "Twilight"
        case .platinum: "Deep Purple"
        case .amethyst: "Indigo"
        case .sapphire: "Fjord"
        case .emerald: "Sage"
        case .gold: "Champagne"
        case .silver: "Silver"
        case .bronze: "Bronze"
        }
    }

    var tagline: String {
        switch self {
        case .bronze: "Natural bronze slate starter cast on your first listen"
        case .silver: "Classic bead-blasted silver aluminum unibody"
        case .gold: "Muted champagne titanium with warm satin sheen"
        case .emerald: "Low-key frosted mineral sage at 80+ hours"
        case .sapphire: "Cool brushed coastal slate-teal at 160+ hours"
        case .amethyst: "Muted anodized indigo with subtle bevel highlights"
        case .platinum: "Architectural frosted plum finish at 550+ hours"
        case .diamond: "Smoked twilight dusk slate near the thousand-hour mark"
        case .obsidian: "Diamond-like forged carbon midnight prestige finish"
        case .holo: "The 2,000-hour full-spectrum liquid holographic crown"
        }
    }

    var baseColors: [Color] {
        switch self {
        case .holo:
            // Kept Option B #10: Liquid Holo
            [Color(red: 0.424, green: 0.961, blue: 0.910), Color(red: 0.604, green: 0.518, blue: 1.000),
             Color(red: 1.000, green: 0.518, blue: 0.808), Color(red: 1.000, green: 0.941, blue: 0.549),
             Color(red: 0.424, green: 0.961, blue: 0.910)]
        case .obsidian:
            // Kept Option B #9: Midnight Carbon (#0F1420, #252E42, #161E2E, #080B12)
            [Color(red: 0.059, green: 0.078, blue: 0.125), Color(red: 0.145, green: 0.180, blue: 0.259),
             Color(red: 0.086, green: 0.118, blue: 0.180), Color(red: 0.031, green: 0.043, blue: 0.071),
             Color(red: 0.059, green: 0.078, blue: 0.125)]
        case .diamond:
            // #8 Twilight Slate (#2A2342, #534678, #1D1830, #131022)
            [Color(red: 0.165, green: 0.137, blue: 0.259), Color(red: 0.325, green: 0.275, blue: 0.471),
             Color(red: 0.114, green: 0.094, blue: 0.188), Color(red: 0.075, green: 0.063, blue: 0.133),
             Color(red: 0.165, green: 0.137, blue: 0.259)]
        case .platinum:
            // Kept Option B #7: Deep Purple (#4B346D, #8563B5, #362352, #24163A)
            [Color(red: 0.294, green: 0.204, blue: 0.427), Color(red: 0.522, green: 0.388, blue: 0.710),
             Color(red: 0.212, green: 0.137, blue: 0.322), Color(red: 0.141, green: 0.086, blue: 0.227),
             Color(red: 0.294, green: 0.204, blue: 0.427)]
        case .amethyst:
            // #6 Slate Indigo (#465A8C, #7A91C4, #334570, #223054)
            [Color(red: 0.275, green: 0.353, blue: 0.549), Color(red: 0.478, green: 0.569, blue: 0.769),
             Color(red: 0.200, green: 0.271, blue: 0.439), Color(red: 0.133, green: 0.188, blue: 0.329),
             Color(red: 0.275, green: 0.353, blue: 0.549)]
        case .sapphire:
            // #5 Fjord Teal (#527B86, #86AEB8, #3A606B, #26454E)
            [Color(red: 0.322, green: 0.482, blue: 0.525), Color(red: 0.525, green: 0.682, blue: 0.722),
             Color(red: 0.227, green: 0.376, blue: 0.420), Color(red: 0.149, green: 0.271, blue: 0.306),
             Color(red: 0.322, green: 0.482, blue: 0.525)]
        case .emerald:
            // #4 Sage Mist (#8FA89C, #C2D6CC, #6C867A, #51685E)
            [Color(red: 0.561, green: 0.659, blue: 0.612), Color(red: 0.761, green: 0.839, blue: 0.800),
             Color(red: 0.424, green: 0.525, blue: 0.478), Color(red: 0.318, green: 0.408, blue: 0.369),
             Color(red: 0.561, green: 0.659, blue: 0.612)]
        case .gold:
            // #3 Mist Champagne (#CBBFA6, #EDE4D2, #A89C84, #877C66)
            [Color(red: 0.796, green: 0.749, blue: 0.651), Color(red: 0.929, green: 0.894, blue: 0.824),
             Color(red: 0.659, green: 0.612, blue: 0.518), Color(red: 0.529, green: 0.486, blue: 0.400),
             Color(red: 0.796, green: 0.749, blue: 0.651)]
        case .silver:
            // Kept Option B #2: Silver Aluminum (#B9C0CC, #EEF1F6, #9AA2B0, #7B8391)
            [Color(red: 0.725, green: 0.753, blue: 0.800), Color(red: 0.933, green: 0.945, blue: 0.965),
             Color(red: 0.604, green: 0.635, blue: 0.690), Color(red: 0.482, green: 0.514, blue: 0.569),
             Color(red: 0.725, green: 0.753, blue: 0.800)]
        case .bronze:
            // Kept Option B #1: Bronze Slate (#74503B, #B58263, #5A3B2A, #432B1E)
            [Color(red: 0.455, green: 0.314, blue: 0.231), Color(red: 0.710, green: 0.510, blue: 0.388),
             Color(red: 0.353, green: 0.231, blue: 0.165), Color(red: 0.263, green: 0.169, blue: 0.118),
             Color(red: 0.455, green: 0.314, blue: 0.231)]
        }
    }

    var ink: Color {
        switch self {
        case .bronze, .sapphire, .amethyst, .platinum, .diamond, .obsidian:
            .white
        case .silver, .gold, .emerald, .holo:
            Color(red: 0.08, green: 0.08, blue: 0.10)
        }
    }

    var glow: Color {
        switch self {
        case .obsidian: Color(red: 0.302, green: 0.565, blue: 0.769)
        case .diamond: Color(red: 0.427, green: 0.369, blue: 0.620)
        case .platinum: Color(red: 0.522, green: 0.388, blue: 0.710)
        case .amethyst: Color(red: 0.424, green: 0.518, blue: 0.749)
        case .sapphire: Color(red: 0.427, green: 0.612, blue: 0.659)
        case .emerald: Color(red: 0.561, green: 0.659, blue: 0.612)
        case .gold: Color(red: 0.835, green: 0.784, blue: 0.678)
        case .silver: Color(red: 0.725, green: 0.753, blue: 0.800)
        case .bronze: Color(red: 0.710, green: 0.510, blue: 0.388)
        case .holo: Color(red: 0.604, green: 0.518, blue: 1.000)
        }
    }
}
