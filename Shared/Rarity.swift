import SwiftUI

/// Card achievement tier from lifetime listening hours (0h Bronze up to 2,000h Holo Legendary).
/// Shared by the app and the widget extension.
enum Rarity: String, Codable, CaseIterable, Identifiable {
    case holo = "HOLO"
    case obsidian = "OBSIDIAN"
    case platinum = "PLATINUM"
    case gold = "GOLD"
    case silver = "SILVER"
    case bronze = "BRONZE"

    var id: String { rawValue }

    /// Tiers ordered from entry level (0h) to top tier (2,000h).
    static let allAscending: [Rarity] = [.bronze, .silver, .gold, .platinum, .obsidian, .holo]

    init(minutes: Double) {
        switch minutes / 60 {
        case 2000...: self = .holo
        case 900..<2000: self = .obsidian
        case 350..<900: self = .platinum
        case 100..<350: self = .gold
        case 25..<100: self = .silver
        default: self = .bronze
        }
    }

    /// Minimum lifetime hours required to reach this tier.
    var minimumHours: Double {
        switch self {
        case .bronze: 0
        case .silver: 25
        case .gold: 100
        case .platinum: 350
        case .obsidian: 900
        case .holo: 2000
        }
    }

    var nextTier: Rarity? {
        switch self {
        case .bronze: .silver
        case .silver: .gold
        case .gold: .platinum
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

    var title: String {
        switch self {
        case .holo: "HOLO · LEGENDARY"
        case .obsidian: "OBSIDIAN · PRESTIGE"
        case .platinum: "PLATINUM · MASTER"
        case .gold: "GOLD · EPIC"
        case .silver: "SILVER · RARE"
        case .bronze: "BRONZE"
        }
    }

    var shortName: String {
        switch self {
        case .holo: "Holo"
        case .obsidian: "Obsidian"
        case .platinum: "Platinum"
        case .gold: "Gold"
        case .silver: "Silver"
        case .bronze: "Bronze"
        }
    }

    var tagline: String {
        switch self {
        case .bronze: "Minted on your very first listen"
        case .silver: "A regular companion in your rotation"
        case .gold: "100+ hours of shared playlists and calls"
        case .platinum: "Deep daily driver with brushed ice-titanium sheen"
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
            [Color(red: 0.14, green: 0.16, blue: 0.24), Color(red: 0.26, green: 0.18, blue: 0.36),
             Color(red: 0.12, green: 0.28, blue: 0.34), Color(red: 0.18, green: 0.14, blue: 0.26),
             Color(red: 0.14, green: 0.16, blue: 0.24)]
        case .platinum:
            [Color(red: 0.78, green: 0.88, blue: 0.98), Color(red: 0.54, green: 0.68, blue: 0.86),
             Color(red: 0.88, green: 0.94, blue: 1.00), Color(red: 0.46, green: 0.60, blue: 0.78),
             Color(red: 0.78, green: 0.88, blue: 0.98)]
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

    var ink: Color { (self == .bronze || self == .obsidian) ? .white : Color(red: 0.08, green: 0.08, blue: 0.10) }

    var glow: Color {
        switch self {
        case .obsidian: Color(red: 0.56, green: 0.48, blue: 0.96)
        case .platinum: Color(red: 0.60, green: 0.82, blue: 1.00)
        default: baseColors[1]
        }
    }
}
