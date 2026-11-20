import SwiftUI

/// Card achievement tier from lifetime listening hours (10 tiers: 0h Bronze up to 2,000h Holo Legendary).
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

    /// Intensity of prismatic color-dodge foil shimmer (0 for matte entry tiers, up to 0.9 for Holo).
    var sheenOpacity: Double {
        switch self {
        case .holo: 0.90
        case .obsidian: 0.68
        case .diamond: 0.62
        case .platinum: 0.42
        case .amethyst: 0.45
        case .sapphire: 0.40
        case .emerald: 0.36
        case .gold: 0.34
        case .silver, .bronze: 0
        }
    }

    var title: String {
        switch self {
        case .holo: "HOLO · LEGENDARY"
        case .obsidian: "OBSIDIAN · PRESTIGE"
        case .diamond: "DIAMOND · PRISM"
        case .platinum: "PLATINUM · MASTER"
        case .amethyst: "AMETHYST · MYSTIC"
        case .sapphire: "SAPPHIRE · COBALT"
        case .emerald: "EMERALD · VIVID"
        case .gold: "GOLD · RARE"
        case .silver: "SILVER · UNCOMMON"
        case .bronze: "BRONZE"
        }
    }

    var shortName: String {
        switch self {
        case .holo: "Holo"
        case .obsidian: "Obsidian"
        case .diamond: "Diamond"
        case .platinum: "Platinum"
        case .amethyst: "Amethyst"
        case .sapphire: "Sapphire"
        case .emerald: "Emerald"
        case .gold: "Gold"
        case .silver: "Silver"
        case .bronze: "Bronze"
        }
    }

    var tagline: String {
        switch self {
        case .bronze: "Minted on your very first listen"
        case .silver: "Warmed up and entering your rotation"
        case .gold: "Trusted daily pick with warm 24k sheen"
        case .emerald: "Vivid jewel finish for steady listeners"
        case .sapphire: "Deep cobalt luster for long-haul commutes"
        case .amethyst: "Velvet ultraviolet glow at 300+ hours"
        case .platinum: "Brushed ice-titanium master finish"
        case .diamond: "Crystalline prism cut near the thousand-hour mark"
        case .obsidian: "Stealth carbon-aurora prestige finish"
        case .holo: "The 2,000-hour full-spectrum holographic crown"
        }
    }

    var baseColors: [Color] {
        switch self {
        case .holo:
            [Color(red: 0.48, green: 0.96, blue: 0.88), Color(red: 0.65, green: 0.55, blue: 0.98),
             Color(red: 0.98, green: 0.66, blue: 0.83), Color(red: 0.99, green: 0.90, blue: 0.54),
             Color(red: 0.48, green: 0.96, blue: 0.88)]
        case .obsidian:
            [Color(red: 0.13, green: 0.15, blue: 0.23), Color(red: 0.27, green: 0.17, blue: 0.38),
             Color(red: 0.11, green: 0.28, blue: 0.35), Color(red: 0.17, green: 0.13, blue: 0.25),
             Color(red: 0.13, green: 0.15, blue: 0.23)]
        case .diamond:
            [Color(red: 0.84, green: 0.96, blue: 1.00), Color(red: 0.68, green: 0.86, blue: 1.00),
             Color(red: 0.96, green: 0.92, blue: 1.00), Color(red: 0.72, green: 0.95, blue: 0.96),
             Color(red: 0.84, green: 0.96, blue: 1.00)]
        case .platinum:
            [Color(red: 0.76, green: 0.85, blue: 0.94), Color(red: 0.50, green: 0.62, blue: 0.78),
             Color(red: 0.86, green: 0.92, blue: 0.98), Color(red: 0.42, green: 0.54, blue: 0.70),
             Color(red: 0.76, green: 0.85, blue: 0.94)]
        case .amethyst:
            [Color(red: 0.58, green: 0.36, blue: 0.88), Color(red: 0.34, green: 0.18, blue: 0.62),
             Color(red: 0.74, green: 0.48, blue: 0.96), Color(red: 0.26, green: 0.14, blue: 0.48),
             Color(red: 0.58, green: 0.36, blue: 0.88)]
        case .sapphire:
            [Color(red: 0.20, green: 0.52, blue: 0.94), Color(red: 0.11, green: 0.28, blue: 0.68),
             Color(red: 0.36, green: 0.68, blue: 0.98), Color(red: 0.08, green: 0.22, blue: 0.54),
             Color(red: 0.20, green: 0.52, blue: 0.94)]
        case .emerald:
            [Color(red: 0.18, green: 0.72, blue: 0.52), Color(red: 0.09, green: 0.44, blue: 0.32),
             Color(red: 0.34, green: 0.84, blue: 0.62), Color(red: 0.07, green: 0.36, blue: 0.26),
             Color(red: 0.18, green: 0.72, blue: 0.52)]
        case .gold:
            [Color(red: 0.98, green: 0.84, blue: 0.45), Color(red: 0.80, green: 0.56, blue: 0.20),
             Color(red: 0.99, green: 0.88, blue: 0.60), Color(red: 0.72, green: 0.48, blue: 0.16),
             Color(red: 0.98, green: 0.84, blue: 0.45)]
        case .silver:
            [Color(red: 0.86, green: 0.88, blue: 0.93), Color(red: 0.52, green: 0.56, blue: 0.64),
             Color(red: 0.93, green: 0.94, blue: 0.97), Color(red: 0.45, green: 0.49, blue: 0.57),
             Color(red: 0.86, green: 0.88, blue: 0.93)]
        case .bronze:
            [Color(red: 0.80, green: 0.55, blue: 0.38), Color(red: 0.45, green: 0.28, blue: 0.18),
             Color(red: 0.85, green: 0.62, blue: 0.45), Color(red: 0.38, green: 0.23, blue: 0.15),
             Color(red: 0.80, green: 0.55, blue: 0.38)]
        }
    }

    var ink: Color {
        switch self {
        case .bronze, .emerald, .sapphire, .amethyst, .obsidian:
            .white
        case .silver, .gold, .platinum, .diamond, .holo:
            Color(red: 0.08, green: 0.08, blue: 0.10)
        }
    }

    var glow: Color {
        switch self {
        case .obsidian: Color(red: 0.56, green: 0.48, blue: 0.96)
        case .diamond: Color(red: 0.72, green: 0.92, blue: 1.00)
        case .platinum: Color(red: 0.60, green: 0.82, blue: 1.00)
        case .amethyst: Color(red: 0.72, green: 0.46, blue: 0.98)
        case .sapphire: Color(red: 0.32, green: 0.64, blue: 1.00)
        case .emerald: Color(red: 0.26, green: 0.86, blue: 0.62)
        default: baseColors[1]
        }
    }
}
