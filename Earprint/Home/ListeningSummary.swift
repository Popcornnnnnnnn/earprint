import Foundation

/// Everything the home screen shows. Built from HealthKit via `LibrarySnapshot`, or `SampleData` as fallback.
struct ListeningSummary: Equatable {
    struct DayMetrics: Equatable {
        let dayIndex: Int
        let minutes: Double
        let decibels: Double?
    }

    var deviceName: String
    var deviceModel: String
    var deviceSymbol: String = "airpodspro"
    var periodLabel: String
    var periodEndDate: Date? = nil
    var grid: ListeningGrid {
        didSet {
            if grid != oldValue {
                recomputeGridMetrics()
            }
        }
    }
    var lifetimeMinutes: Double
    var sessions: Int
    var averageSessionMinutes: Double
    var longestSessionMinutes: Double
    var firstUse: String
    /// Exact WHO weekly dose computed directly from raw 15-min slot energy when available.
    var weeklyBudgetOverride: Double? = nil

    // Precomputed grid-derived metrics so SwiftUI body passes stay O(1) with zero per-frame pow/log10 scans.
    private(set) var has28DayData: Bool = false
    private(set) var monthMinutes: Double = 0
    private(set) var monthDecibels: Double = 0
    private(set) var weekMinutes: Double = 0
    private(set) var weekDecibels: Double = 0
    private(set) var computedWeeklyBudget: Double = 0
    private(set) var persona: Persona = .allDay
    private(set) var last7Days: [DayMetrics] = []

    init(
        deviceName: String,
        deviceModel: String,
        deviceSymbol: String = "airpodspro",
        periodLabel: String,
        periodEndDate: Date? = nil,
        grid: ListeningGrid,
        lifetimeMinutes: Double,
        sessions: Int,
        averageSessionMinutes: Double,
        longestSessionMinutes: Double,
        firstUse: String,
        weeklyBudgetOverride: Double? = nil
    ) {
        self.deviceName = deviceName
        self.deviceModel = deviceModel
        self.deviceSymbol = deviceSymbol
        self.periodLabel = periodLabel
        self.periodEndDate = periodEndDate
        self.grid = grid
        self.lifetimeMinutes = lifetimeMinutes
        self.sessions = sessions
        self.averageSessionMinutes = averageSessionMinutes
        self.longestSessionMinutes = longestSessionMinutes
        self.firstUse = firstUse
        self.weeklyBudgetOverride = weeklyBudgetOverride
        recomputeGridMetrics()
    }

    /// Share of the WHO weekly safe-listening budget (80 dB(A) for 40 h) used this week.
    /// Every +3 dB halves the allowed time.
    var weeklyBudgetUsed: Double {
        weeklyBudgetOverride ?? computedWeeklyBudget
    }

    /// Authentic zero-data summary used in Release builds before Apple Health data is connected or available.
    static func empty(now: Date = Date(), calendar: Calendar = .current) -> ListeningSummary {
        ListeningSummary(
            deviceName: AppLanguage.current.text("No headphones yet"),
            deviceModel: AppLanguage.current.text("Apple Health"),
            deviceSymbol: "headphones",
            periodLabel: DateText.weekRange(endingAt: now, calendar: calendar),
            periodEndDate: now,
            grid: ListeningGrid(
                minutes: Array(repeating: Array(repeating: 0.0, count: 24), count: 28),
                decibels: Array(repeating: Array(repeating: 0.0, count: 24), count: 28)
            ),
            lifetimeMinutes: 0,
            sessions: 0,
            averageSessionMinutes: 0,
            longestSessionMinutes: 0,
            firstUse: "—"
        )
    }

    private mutating func recomputeGridMetrics() {
        let totalDays = grid.days
        let start28 = max(0, totalDays - 28)
        let start7 = max(0, totalDays - 7)

        var total28 = 0.0
        var monthEnergy = 0.0
        var night = 0.0
        var commute = 0.0
        var morning = 0.0

        var weekMin = 0.0
        var weekEnergy = 0.0
        var weekDose = 0.0

        var sevenDays: [DayMetrics] = []
        sevenDays.reserveCapacity(max(0, totalDays - start7))

        for dayIndex in start28..<totalDays {
            let dayMinutes = grid.minutes[dayIndex]
            let dayDB = grid.decibels.indices.contains(dayIndex) ? grid.decibels[dayIndex] : []
            let count = min(dayMinutes.count, 24)
            let isInLast7 = dayIndex >= start7

            var thisDayMin = 0.0
            var thisDayEnergy = 0.0

            for h in 0..<count {
                let v = dayMinutes[h]
                guard v > 0 else { continue }
                total28 += v
                if h >= 22 || h <= 3 { night += v }
                if h == 7 || h == 8 || h == 17 || h == 18 { commute += v }
                if h >= 5 && h <= 7 { morning += v }

                let hasDB = h < dayDB.count && dayDB[h] > 0
                let hourEnergy = hasDB ? pow(10, dayDB[h] / 10) * v : 0
                monthEnergy += hourEnergy

                if isInLast7 {
                    thisDayMin += v
                    weekMin += v
                    if hasDB {
                        thisDayEnergy += hourEnergy
                        weekEnergy += hourEnergy
                        weekDose += HearingBudget.dose(decibels: dayDB[h], seconds: v * 60)
                    }
                }
            }

            if isInLast7 {
                let db: Double? = (thisDayMin > 0 && thisDayEnergy > 0)
                    ? 10 * log10(thisDayEnergy / thisDayMin)
                    : nil
                sevenDays.append(DayMetrics(dayIndex: dayIndex, minutes: thisDayMin, decibels: db))
            }
        }

        has28DayData = total28 > 0
        monthMinutes = total28
        monthDecibels = (total28 > 0 && monthEnergy > 0) ? 10 * log10(monthEnergy / total28) : 0
        weekMinutes = weekMin
        weekDecibels = (weekMin > 0 && weekEnergy > 0) ? 10 * log10(weekEnergy / weekMin) : 0
        computedWeeklyBudget = weekDose
        last7Days = sevenDays

        if total28 <= 0 {
            persona = .allDay
        } else {
            let nightShare = night / total28
            if nightShare >= 0.3 {
                persona = .nightOwl(nightShare)
            } else {
                let commuteShare = commute / total28
                if commuteShare >= 0.3 {
                    persona = .commuter(commuteShare)
                } else {
                    let morningShare = morning / total28
                    if morningShare >= 0.2 {
                        persona = .earlyBird(morningShare)
                    } else {
                        persona = .allDay
                    }
                }
            }
        }
    }

    enum Persona: Equatable {
        case nightOwl(Double), commuter(Double), earlyBird(Double), allDay

        var emoji: String {
            switch self {
            case .nightOwl: "🦉"
            case .commuter: "🚇"
            case .earlyBird: "🐦"
            case .allDay: "🎧"
            }
        }
        var symbol: String {
            switch self {
            case .nightOwl: "moon.stars.fill"
            case .commuter: "tram.fill"
            case .earlyBird: "sunrise.fill"
            case .allDay: "headphones"
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
            case .nightOwl(let s): AppLanguage.current.text("%lld%% of your listening happens after 10 pm.", Int((s * 100).rounded()))
            case .commuter(let s): AppLanguage.current.text("%lld%% of your listening is on the way to and from work.", Int((s * 100).rounded()))
            case .earlyBird(let s): AppLanguage.current.text("%lld%% of your listening is before 8 am.", Int((s * 100).rounded()))
            case .allDay: AppLanguage.current.text("Your headphones keep you company all day long.")
            }
        }
        var shortDetail: String {
            switch self {
            case .nightOwl(let s): AppLanguage.current.text("%lld%% late night (22:00–04:00)", Int((s * 100).rounded()))
            case .commuter(let s): AppLanguage.current.text("%lld%% during rush hours", Int((s * 100).rounded()))
            case .earlyBird(let s): AppLanguage.current.text("%lld%% before 8 am", Int((s * 100).rounded()))
            case .allDay: AppLanguage.current.text("Balanced across the day")
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
            deviceName: "AirPods Pro 2",
            deviceModel: "AirPods Pro 2 · USB-C",
            periodLabel: "Nov 12 – 18",
            periodEndDate: Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 23, minute: 40)),
            grid: ListeningGrid(minutes: minutes, decibels: decibels),
            lifetimeMinutes: 188 * 60 + 22,
            sessions: 269,
            averageSessionMinutes: 42,
            longestSessionMinutes: 220,
            firstUse: "2026.07.15"
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
    /// 2820 minutes -> "47h 0m", 149418 minutes -> "2,490h 18m"
    var minutesText: String {
        let total = Int(self.rounded())
        guard total >= 60 else { return AppLanguage.current.text("%lldm", total) }
        let hours = total / 60
        let mins = total % 60
        let hoursText = hours >= 1000 ? hours.formatted() : "\(hours)"
        return AppLanguage.current.text("%@h %lldm", hoursText, mins)
    }
}
