import SwiftUI

/// One collectible card per headphone device found in Health.
struct HeadphoneCard: Identifiable, Equatable {
    let id: String
    var nickname: String
    var model: String
    var symbol: String
    var lifetimeMinutes: Double
    var sessions: Int
    var longestMinutes: Double
    var averageDecibels: Double
    var firstMet: String
    var lastUsed: String
    var serial: Int
    var grid: ListeningGrid
    /// Detailed product shape from the device-ID table (see `HeadphoneModelCatalog`).
    var modelKey: HeadphoneModelKey = .overEarGeneric
    /// Which 3D model the card shows.
    var kind: HeadphoneKind = .overEar

    var rarity: Rarity { Rarity(minutes: lifetimeMinutes) }

    static func == (a: HeadphoneCard, b: HeadphoneCard) -> Bool { a.id == b.id }
}

enum Rarity: String {
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

enum SampleCards {
    static let all: [HeadphoneCard] = {
        let base = SampleData.summary
        return [
            HeadphoneCard(id: "pro2", nickname: "🧸's AirPods Pro", model: "AirPods Pro 2 · USB-C", symbol: "airpodspro",
                          lifetimeMinutes: 188 * 60 + 22, sessions: 269, longestMinutes: 220, averageDecibels: 58,
                          firstMet: "2026.10.30", lastUsed: "Today", serial: 1, grid: base.grid,
                          modelKey: .airpodsPro, kind: .earbuds),
            HeadphoneCard(id: "max", nickname: "Studio Max", model: "AirPods Max", symbol: "airpodsmax",
                          lifetimeMinutes: 64 * 60 + 10, sessions: 88, longestMinutes: 185, averageDecibels: 63,
                          firstMet: "2024.12.25", lastUsed: "Sep 2", serial: 2, grid: scaled(base.grid, 0.45),
                          modelKey: .airpodsMax, kind: .overEar),
            HeadphoneCard(id: "fit", nickname: "Gym buds", model: "Beats Fit Pro", symbol: "beats.earphones",
                          lifetimeMinutes: 9 * 60 + 40, sessions: 21, longestMinutes: 64, averageDecibels: 71,
                          firstMet: "2025.03.08", lastUsed: "Nov 2", serial: 3, grid: scaled(base.grid, 0.15),
                          modelKey: .beatsEarbuds, kind: .sportBuds),
        ]
    }()

    private static func scaled(_ grid: ListeningGrid, _ keep: Double) -> ListeningGrid {
        var rng = SplitMix64(seed: UInt64(keep * 1000))
        var g = grid
        for d in 0..<g.days { for h in 0..<24 where rng.unit() > keep { g.minutes[d][h] = 0 } }
        return g
    }
}
