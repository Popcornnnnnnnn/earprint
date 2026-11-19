import SwiftUI

/// Card tier, from lifetime listening hours. Shared by the app and the widget extension.
enum Rarity: String, Codable {
    case holo = "HOLO"
    case gold = "GOLD"
    case silver = "SILVER"
    case bronze = "BRONZE"

    init(minutes: Double) {
        switch minutes / 60 {
        case 150...: self = .holo
        case 60..<150: self = .gold
        case 20..<60: self = .silver
        default: self = .bronze
        }
    }

    var title: String {
        switch self {
        case .holo: "HOLO · LEGENDARY"
        case .gold: "GOLD · EPIC"
        case .silver: "SILVER · RARE"
        case .bronze: "BRONZE"
        }
    }

    /// Hours needed for the next tier, nil at the top.
    var nextTierHours: Double? {
        switch self {
        case .bronze: 20
        case .silver: 60
        case .gold: 150
        case .holo: nil
        }
    }

    var baseColors: [Color] {
        switch self {
        case .holo: [Color(red: 0.48, green: 0.96, blue: 0.88), Color(red: 0.65, green: 0.55, blue: 0.98),
                     Color(red: 0.98, green: 0.66, blue: 0.83), Color(red: 0.99, green: 0.90, blue: 0.54),
                     Color(red: 0.48, green: 0.96, blue: 0.88)]
        case .gold: [Color(red: 0.98, green: 0.84, blue: 0.45), Color(red: 0.80, green: 0.56, blue: 0.20),
                     Color(red: 0.99, green: 0.88, blue: 0.60), Color(red: 0.72, green: 0.48, blue: 0.16),
                     Color(red: 0.98, green: 0.84, blue: 0.45)]
        case .silver: [Color(red: 0.86, green: 0.88, blue: 0.93), Color(red: 0.52, green: 0.56, blue: 0.64),
                       Color(red: 0.93, green: 0.94, blue: 0.97), Color(red: 0.45, green: 0.49, blue: 0.57),
                       Color(red: 0.86, green: 0.88, blue: 0.93)]
        case .bronze: [Color(red: 0.80, green: 0.55, blue: 0.38), Color(red: 0.45, green: 0.28, blue: 0.18),
                       Color(red: 0.85, green: 0.62, blue: 0.45), Color(red: 0.38, green: 0.23, blue: 0.15),
                       Color(red: 0.80, green: 0.55, blue: 0.38)]
        }
    }

    var ink: Color { self == .bronze ? .white : Color(red: 0.08, green: 0.08, blue: 0.10) }
    var glow: Color { baseColors[1] }
}
