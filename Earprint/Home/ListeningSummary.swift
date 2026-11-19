import Foundation

/// Everything the home screen shows. Built from sample data now, from HealthKit later.
struct ListeningSummary {
    var deviceName: String
    var deviceModel: String
    var periodLabel: String
    var grid: ListeningGrid
    var lifetimeMinutes: Double
    var sessions: Int
    var averageSessionMinutes: Double
    var longestSessionMinutes: Double
    var firstUse: String

    var weekMinutes: Double { grid.totalMinutes(lastDays: 7) }
    var weekDecibels: Double { grid.averageDecibels(lastDays: 7) }

    /// Share of the WHO weekly safe-listening budget (80 dB(A) for 40 h) used this week.
    /// Every +3 dB halves the allowed time.
    var weeklyBudgetUsed: Double {
        var used = 0.0
        for (m, db) in zip(grid.minutes.suffix(7), grid.decibels.suffix(7)) {
            for h in 0..<24 where m[h] > 0 {
                let allowedMinutes = 40 * 60 * pow(2, (80 - db[h]) / 3)
                used += m[h] / allowedMinutes
            }
        }
        return used
    }

    var persona: Persona {
        let night = grid.share(hours: [22, 23, 0, 1, 2, 3], lastDays: 28)
        let commute = grid.share(hours: [7, 8, 17, 18], lastDays: 28)
        let morning = grid.share(hours: [5, 6, 7], lastDays: 28)
        if night >= 0.3 { return .nightOwl(night) }
        if commute >= 0.3 { return .commuter(commute) }
        if morning >= 0.2 { return .earlyBird(morning) }
        return .allDay
    }

    enum Persona {
        case nightOwl(Double), commuter(Double), earlyBird(Double), allDay

        var emoji: String {
            switch self {
            case .nightOwl: "🦉"
            case .commuter: "🚇"
            case .earlyBird: "🐦"
            case .allDay: "🎧"
            }
        }
        var title: String {
            switch self {
            case .nightOwl: "Night Owl"
            case .commuter: "Commute Soundtracker"
            case .earlyBird: "Early Bird"
            case .allDay: "All-Day Listener"
            }
        }
        var detail: String {
            switch self {
            case .nightOwl(let s): "\(Int(s * 100))% of your listening happens after 10 pm."
            case .commuter(let s): "\(Int(s * 100))% of your listening is on the way to and from work."
            case .earlyBird(let s): "\(Int(s * 100))% of your listening is before 8 am."
            case .allDay: "Your headphones keep you company all day long."
            }
        }
    }
}

enum SampleData {
    /// Deterministic, realistic-looking four weeks of listening.
    static let summary: ListeningSummary = {
        var rng = SplitMix64(seed: 7)
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
                add(9, 5...20, db: 60...66, chance: 0.6)
                add(13, 10...30, db: 54...60, chance: 0.5)
                add(18, 25...50, db: 63...72)
                add(19, 10...25, db: 60...66, chance: 0.7)
            } else {
                for hour in 14...17 { add(hour, 10...45, db: 55...64, chance: 0.55) }
            }
            for hour in 21...23 { add(hour, 15...55, db: 58...70, chance: 0.75) }
            add(0, 10...45, db: 66...80, chance: 0.5)
            add(1, 5...30, db: 70...82, chance: 0.25)
        }

        return ListeningSummary(
            deviceName: "🧸's AirPods Pro",
            deviceModel: "AirPods Pro 2 · USB-C",
            periodLabel: "Nov 12 – 18",
            grid: ListeningGrid(minutes: minutes, decibels: decibels),
            lifetimeMinutes: 188 * 60 + 22,
            sessions: 269,
            averageSessionMinutes: 42,
            longestSessionMinutes: 220,
            firstUse: "Oct 30"
        )
    }()
}

struct SplitMix64 {
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

extension Double {
    /// 2820 minutes -> "47h 0m"
    var minutesText: String {
        let total = Int(self.rounded())
        return total >= 60 ? "\(total / 60)h \(total % 60)m" : "\(total)m"
    }
}
