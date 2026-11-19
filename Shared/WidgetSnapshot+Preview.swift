import Foundation

/// Built-in sample snapshot for widget placeholders, the widget gallery, previews and PNG renders.
/// The app publishes its own snapshot (see `WidgetSnapshot+App.swift`); this one is only a fallback.
extension WidgetSnapshot {
    static let preview: WidgetSnapshot = {
        var rng = PreviewRNG(seed: 7)
        var minutes = Array(repeating: Array(repeating: 0.0, count: 24), count: 28)
        var decibels = Array(repeating: Array(repeating: 0.0, count: 24), count: 28)
        for day in 0..<28 {
            let weekday = day % 7 < 5
            func add(_ hour: Int, _ range: ClosedRange<Double>, db: ClosedRange<Double>, chance: Double = 1) {
                guard rng.unit() < chance else { return }
                minutes[day][hour] = min(60, minutes[day][hour] + rng.in(range))
                decibels[day][hour] = rng.in(db)
            }
            if weekday {
                add(8, 25...50, db: 62...70)
                add(13, 10...30, db: 54...60, chance: 0.5)
                add(18, 25...50, db: 63...72)
            } else {
                for hour in 14...17 { add(hour, 10...45, db: 55...64, chance: 0.55) }
            }
            for hour in 21...23 { add(hour, 15...55, db: 58...70, chance: 0.75) }
            add(0, 10...45, db: 66...80, chance: 0.5)
        }
        let heatmap = Heatmap(minutes: minutes, decibels: decibels)
        let grid = heatmap.grid
        return WidgetSnapshot(
            generatedAt: Date(),
            isSample: true,
            day: Calendar.current.startOfDay(for: Date()),
            today: Today(minutes: 72, decibels: 63, deviceName: "🧸's AirPods Pro", deviceSymbol: "airpodspro"),
            week: Week(minutes: grid.totalMinutes(lastDays: 7), budgetUsed: 0.38,
                       decibels: grid.averageDecibels(lastDays: 7), label: "Nov 12 – 18"),
            cards: [
                Card(id: "pro2", nickname: "🧸's AirPods Pro", model: "AirPods Pro 2 · USB-C", symbol: "airpodspro",
                     lifetimeMinutes: 188 * 60 + 22, weekMinutes: 9 * 60 + 12, sessions: 269, serial: 1),
                Card(id: "max", nickname: "Studio Max", model: "AirPods Max", symbol: "airpodsmax",
                     lifetimeMinutes: 64 * 60 + 10, weekMinutes: 3 * 60 + 5, sessions: 88, serial: 2),
                Card(id: "fit", nickname: "Gym buds", model: "Beats Fit Pro", symbol: "beats.earphones",
                     lifetimeMinutes: 9 * 60 + 40, weekMinutes: 50, sessions: 21, serial: 3),
            ],
            heatmap: heatmap
        )
    }()

    /// A quiet first-run state: no cards, nothing played.
    static let empty = WidgetSnapshot(
        generatedAt: Date(), isSample: true, day: Calendar.current.startOfDay(for: Date()),
        today: Today(minutes: 0, decibels: nil, deviceName: nil, deviceSymbol: "airpodspro"),
        week: Week(minutes: 0, budgetUsed: 0, decibels: nil, label: "This week"),
        cards: [],
        heatmap: Heatmap(minutes: Array(repeating: Array(repeating: 0, count: 24), count: 28),
                         decibels: Array(repeating: Array(repeating: 0, count: 24), count: 28))
    )
}

private struct PreviewRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func `in`(_ range: ClosedRange<Double>) -> Double { range.lowerBound + unit() * (range.upperBound - range.lowerBound) }
}
