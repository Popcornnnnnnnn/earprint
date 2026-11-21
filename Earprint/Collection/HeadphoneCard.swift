import SwiftUI

/// One collectible card per headphone in the listening library.
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
    var aliasIDs: [String] = []
    var tierAchievedDates: [Rarity: Date] = [:]

    var rarity: Rarity { Rarity(minutes: lifetimeMinutes) }

    func matches(id: String) -> Bool { self.id == id || aliasIDs.contains(id) }

    static func == (a: HeadphoneCard, b: HeadphoneCard) -> Bool { a.id == b.id }
}

enum SampleCards {
    static let all: [HeadphoneCard] = {
        let base = SampleData.summary
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) ?? Date()
        }
        return [
            HeadphoneCard(id: "pro2", nickname: "🧸's AirPods Pro", model: "AirPods Pro 2 · USB-C", symbol: "airpodspro",
                          lifetimeMinutes: 188 * 60 + 22, sessions: 269, longestMinutes: 220, averageDecibels: 58,
                          firstMet: "2026.10.30", lastUsed: "Today", serial: 1, grid: base.grid,
                          modelKey: .airpodsPro, kind: .earbuds,
                          tierAchievedDates: [
                              .bronze: day(2026, 10, 30),
                              .silver: day(2026, 11, 2),
                              .sapphire: day(2026, 11, 14)
                          ]),
            HeadphoneCard(id: "max", nickname: "Studio Max", model: "AirPods Max", symbol: "airpodsmax",
                          lifetimeMinutes: 64 * 60 + 10, sessions: 88, longestMinutes: 185, averageDecibels: 63,
                          firstMet: "2024.12.25", lastUsed: "Sep 2", serial: 2, grid: scaled(base.grid, 0.45),
                          modelKey: .airpodsMax, kind: .overEar,
                          tierAchievedDates: [
                              .bronze: day(2024, 12, 25),
                              .silver: day(2025, 4, 12)
                          ]),
            HeadphoneCard(id: "airpods4", nickname: "AirPods 4", model: "AirPods 4 (ANC)", symbol: "airpods.gen4",
                          lifetimeMinutes: 9 * 60 + 40, sessions: 21, longestMinutes: 64, averageDecibels: 71,
                          firstMet: "2025.03.08", lastUsed: "Nov 2", serial: 3, grid: scaled(base.grid, 0.15),
                          modelKey: .airpods4, kind: .earbuds,
                          tierAchievedDates: [
                              .bronze: day(2025, 3, 8)
                          ]),
        ]
    }()

    private static func scaled(_ grid: ListeningGrid, _ keep: Double) -> ListeningGrid {
        var rng = SplitMix64(seed: UInt64(keep * 1000))
        var g = grid
        for d in 0..<g.days { for h in 0..<24 where rng.unit() > keep { g.minutes[d][h] = 0 } }
        return g
    }
}
