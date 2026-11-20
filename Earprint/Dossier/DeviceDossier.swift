import Foundation

// MARK: - Raw inputs (filled by the HealthKit pipeline)

/// One continuous wear of the device, merged from Health audio-exposure samples.
struct WearSession: Hashable, Identifiable {
    var id: Date { start }
    var start: Date
    var minutes: Double
    /// Time-weighted energy average, dB(A).
    var averageDecibels: Double
    var peakDecibels: Double
    /// True when the session edges were inferred from gaps between samples.
    var isEstimated: Bool

    var end: Date { start.addingTimeInterval(minutes * 60) }
}

/// Hardware identity as reported by `HKDevice` / `HKSource` on the samples.
struct DossierHardware: Hashable {
    /// `HKDevice.name`, e.g. "🧸's AirPods Pro".
    var deviceName: String
    /// `HKDevice.manufacturer`, e.g. "Apple Inc.".
    var manufacturer: String
    /// `HKDevice.model` (Bluetooth product ID), e.g. "0x2024".
    var productID: String
    /// Marketing name mapped from `productID`, e.g. "AirPods Pro 2 (USB-C)".
    var modelName: String
    /// `HKDevice.hardwareVersion`, nil when Health does not report it.
    var hardwareVersion: String?
    /// `HKDevice.firmwareVersion`, nil when Health does not report it.
    var firmwareVersion: String?
    /// `HKSource.name` of the samples (usually the iPhone).
    var sourceName: String
    /// `HKSource.bundleIdentifier`, e.g. "com.apple.health.81A3F9C2-…".
    var sourceBundleID: String
}

// MARK: - Periods and derived stats

enum DossierPeriod: String, CaseIterable, Identifiable {
    case week, month, year, all

    var id: String { rawValue }
    var title: String {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        case .all: "All"
        }
    }
    /// Rolling window length in days; nil means since first wear.
    var days: Int? {
        switch self {
        case .week: 7
        case .month: 30
        case .year: 365
        case .all: nil
        }
    }
    var previousLabel: String {
        switch self {
        case .week: "vs prev 7 days"
        case .month: "vs prev 30 days"
        case .year: "vs prev year"
        case .all: "since minted"
        }
    }
    var wornLabel: String {
        switch self {
        case .week: "WORN · LAST 7 DAYS"
        case .month: "WORN · LAST 30 DAYS"
        case .year: "WORN · LAST 12 MONTHS"
        case .all: "WORN · ALL TIME"
        }
    }
}

struct DayStat: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    var minutes: Double = 0
    var sessions = 0
    /// Sum of 10^(dB/10) × minutes, for energy-averaged loudness.
    var energy = 0.0
    var hourMinutes = [Double](repeating: 0, count: 24)
    var hourEnergy = [Double](repeating: 0, count: 24)
    /// Minutes across every headphone that day (this one included), for wear share.
    var allDevicesMinutes = 0.0

    var averageDecibels: Double { minutes > 0 ? 10 * log10(energy / minutes) : 0 }
}

struct TrendBucket: Identifiable, Hashable {
    let id: Int
    let start: Date
    let end: Date
    let minutes: Double
    let averageDecibels: Double
    let sessions: Int
    let isFuture: Bool
}

struct HourStat: Identifiable, Hashable {
    var id: Int { hour }
    let hour: Int
    let minutes: Double
    let averageDecibels: Double
}

struct PeriodStats {
    let period: DossierPeriod
    let start: Date
    let end: Date
    let totalMinutes: Double
    let allDevicesMinutes: Double
    let previousMinutes: Double?
    let sessions: [WearSession]
    let averageDecibels: Double
    let peakDecibels: Double
    let activeDays: Int
    /// Calendar days covered (clipped to the device's history).
    let spanDays: Int
    let buckets: [TrendBucket]
    let bucketUnit: Calendar.Component
    let hours: [HourStat]
    /// Average share of the WHO weekly budget (80 dB(A) × 40 h, −3 dB halves it).
    let weeklyDose: Double
    /// Share of listening time in sessions averaging 80 dB(A) or more.
    let loudShare: Double

    var share: Double { allDevicesMinutes > 0 ? min(1, totalMinutes / allDevicesMinutes) : 0 }
    var sessionCount: Int { sessions.count }
    var longest: WearSession? { sessions.max { $0.minutes < $1.minutes } }
    var averagePerWear: Double { sessions.isEmpty ? 0 : totalMinutes / Double(sessions.count) }
    var sessionsPerDay: Double { spanDays > 0 ? Double(sessions.count) / Double(spanDays) : 0 }
    var dailyAverage: Double { spanDays > 0 ? totalMinutes / Double(spanDays) : 0 }
    var change: Double? {
        guard let previousMinutes, previousMinutes > 0 else { return nil }
        return totalMinutes / previousMinutes - 1
    }
    var bestBucket: TrendBucket? { buckets.filter { $0.minutes > 0 }.max { $0.minutes < $1.minutes } }
    var peakHour: HourStat? { hours.filter { $0.minutes > 0 }.max { $0.minutes < $1.minutes } }
}

struct DossierMilestone: Identifiable, Hashable {
    enum Kind: Hashable { case minted, hours, tier, longest, bestDay, upcoming }
    let id: String
    let kind: Kind
    let date: Date
    let title: String
    let detail: String
    var tier: Rarity?
    var isFuture = false
}

struct EarGrade {
    struct Factor: Identifiable {
        var id: String { name }
        let name: String
        let value: String
        let penalty: Double
        /// 0 = perfect, 1 = at the cap.
        let severity: Double
    }

    let score: Double
    let factors: [Factor]

    var label: String {
        switch score {
        case 9.95...: "PRISTINE"
        case 9..<9.95: "GEM MINT"
        case 8..<9: "MINT"
        case 7..<8: "NEAR MINT"
        case 6..<7: "EXCELLENT"
        case 5..<6: "VERY GOOD"
        default: "WELL WORN"
        }
    }
    var scoreText: String { String(format: "%.1f", score) }
}

struct CareerRow: Identifiable, Hashable {
    let id: Date
    let label: String
    let minutes: Double
    let sessions: Int
    let longest: Double
    let averageDecibels: Double
}

// MARK: - Dossier

/// Everything the Device Dossier shows for one headphone. See docs/DOSSIER.md.
struct DeviceDossier: Identifiable {
    let id: String
    var nickname: String
    var symbol: String
    var serial: Int
    var hardware: DossierHardware
    /// All wear sessions, sorted by start.
    let sessions: [WearSession]
    /// Health samples read for this device.
    var sampleCount: Int
    var lastSynced: Date
    /// Reference "now" so stats are reproducible.
    let now: Date
    let calendar: Calendar

    /// One entry per calendar day from the first wear to `now`.
    let days: [DayStat]
    let periods: [DossierPeriod: PeriodStats]

    /// - Parameter otherDevicesDailyMinutes: minutes on *other* headphones keyed by start of day.
    init(id: String, nickname: String, symbol: String, serial: Int, hardware: DossierHardware,
         sessions: [WearSession], otherDevicesDailyMinutes: [Date: Double], sampleCount: Int,
         lastSynced: Date, now: Date, calendar: Calendar = .current) {
        self.id = id
        self.nickname = nickname
        self.symbol = symbol
        self.serial = serial
        self.hardware = hardware
        self.sessions = sessions.sorted { $0.start < $1.start }
        self.sampleCount = sampleCount
        self.lastSynced = lastSynced
        self.now = now
        self.calendar = calendar
        let days = Self.buildDays(sessions: self.sessions, others: otherDevicesDailyMinutes, now: now, calendar: calendar)
        self.days = days
        var periods: [DossierPeriod: PeriodStats] = [:]
        for period in DossierPeriod.allCases {
            periods[period] = Self.stats(period, days: days, sessions: self.sessions, now: now, calendar: calendar)
        }
        self.periods = periods
    }

    func stats(_ period: DossierPeriod) -> PeriodStats { periods[period]! }

    // MARK: Lifetime

    var lifetimeMinutes: Double { sessions.reduce(0) { $0 + $1.minutes } }
    var rarity: Rarity { Rarity(minutes: lifetimeMinutes) }
    var firstWear: Date? { sessions.first?.start }
    var lastWear: WearSession? { sessions.last }
    var recordDays: Int { days.filter { $0.minutes > 0 }.count }
    var historyDays: Int { days.count }
    var longestSession: WearSession? { sessions.max { $0.minutes < $1.minutes } }
    var bestDay: DayStat? { days.max { $0.minutes < $1.minutes } }
    var averageDecibels: Double { Self.energyAverage(sessions) }

    var grade: EarGrade {
        let recent = stats(.month)
        let db = recent.totalMinutes > 0 ? recent.averageDecibels : averageDecibels
        let volume = max(0, db - 55) * 0.12
        let dose = min(3, recent.weeklyDose * 2.5)
        let loud = min(2, recent.loudShare * 8)
        let night = min(0.6, nightShare * 0.8)
        let score = max(1, min(10, ((10 - volume - dose - loud - night) * 10).rounded() / 10))
        return EarGrade(score: score, factors: [
            .init(name: "Average volume", value: "\(Int(db.rounded())) dB(A)", penalty: volume, severity: min(1, volume / 3)),
            .init(name: "Weekly WHO dose", value: "\(Int((recent.weeklyDose * 100).rounded()))%", penalty: dose, severity: min(1, dose / 3)),
            .init(name: "Loud sessions ≥80 dB", value: "\(Int((recent.loudShare * 100).rounded()))%", penalty: loud, severity: min(1, loud / 2)),
            .init(name: "Late-night share", value: "\(Int((nightShare * 100).rounded()))%", penalty: night, severity: min(1, night / 0.6)),
        ])
    }

    /// Share of last-30-day listening between midnight and 5 am.
    var nightShare: Double {
        let s = stats(.month)
        let total = s.hours.reduce(0) { $0 + $1.minutes }
        guard total > 0 else { return 0 }
        return s.hours.filter { $0.hour < 5 }.reduce(0) { $0 + $1.minutes } / total
    }

    var milestones: [DossierMilestone] {
        guard let first = sessions.first else { return [] }
        var result: [DossierMilestone] = [
            .init(id: "minted", kind: .minted, date: first.start, title: "Minted",
                  detail: "First wear · \(first.minutes.minutesText)", tier: .bronze),
        ]
        let hourMarks: [Double] = [50, 100, 250, 500, 1000, 2000]
        let tiers: [(Double, Rarity)] = [
            (10, .silver), (35, .gold), (80, .emerald), (160, .sapphire),
            (300, .amethyst), (550, .platinum), (900, .diamond), (1400, .obsidian), (2000, .holo)
        ]
        var cumulative = 0.0
        for session in sessions {
            let before = cumulative
            cumulative += session.minutes
            for mark in hourMarks where before < mark * 60 && cumulative >= mark * 60 {
                let date = session.start.addingTimeInterval((mark * 60 - before) * 60)
                let delta = daysBetween(first.start, date)
                let dayDetail = delta == 0 ? "Same day as minting" : (delta == 1 ? "1 day after minting" : "\(delta) days after minting")
                result.append(.init(id: "h\(Int(mark))", kind: .hours, date: date, title: "\(Int(mark)) hours",
                                    detail: dayDetail))
            }
            for (mark, tier) in tiers where before < mark * 60 && cumulative >= mark * 60 {
                let date = session.start.addingTimeInterval((mark * 60 - before) * 60)
                result.append(.init(id: "t\(tier.rawValue)", kind: .tier, date: date, title: "\(tier.rawValue.capitalized) tier",
                                    detail: "Card upgraded at \(Int(mark))h", tier: tier))
            }
        }
        if let longest = longestSession {
            result.append(.init(id: "longest", kind: .longest, date: longest.start, title: "Longest wear",
                                detail: "\(longest.minutes.minutesText) in one go\(longest.isEstimated ? " · est." : "")"))
        }
        if let best = bestDay, best.minutes > 0 {
            result.append(.init(id: "bestDay", kind: .bestDay, date: best.date.addingTimeInterval(20 * 3600), title: "Biggest day",
                                detail: "\(best.minutes.minutesText) across \(best.sessions) wears"))
        }
        // Next goal with an ETA from the last 30 days' pace.
        let pace = stats(.month).dailyAverage
        if let next = (hourMarks.map { $0 * 60 } + tiers.map { $0.0 * 60 }).sorted().first(where: { $0 > lifetimeMinutes }), pace > 0 {
            let daysLeft = (next - lifetimeMinutes) / pace
            let eta = now.addingTimeInterval(daysLeft * 86400)
            let tier = tiers.first { $0.0 * 60 == next }?.1
            result.append(.init(id: "next", kind: .upcoming, date: eta,
                                title: tier.map { "\($0.rawValue.capitalized) tier" } ?? "\(Int(next / 60)) hours",
                                detail: "\((next - lifetimeMinutes).minutesText) to go · at your pace", tier: tier, isFuture: true))
        }
        return result.sorted { $0.date < $1.date }
    }

    /// Month-by-month "career" lines, newest first.
    var careerRows: [CareerRow] {
        var groups: [Date: [WearSession]] = [:]
        for s in sessions {
            let month = calendar.dateInterval(of: .month, for: s.start)!.start
            groups[month, default: []].append(s)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM ’yy"
        return groups.keys.sorted(by: >).map { month in
            let list = groups[month]!
            return CareerRow(id: month, label: formatter.string(from: month).uppercased(),
                             minutes: list.reduce(0) { $0 + $1.minutes }, sessions: list.count,
                             longest: list.map(\.minutes).max() ?? 0, averageDecibels: Self.energyAverage(list))
        }
    }

    func daysBetween(_ a: Date, _ b: Date) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: a), to: calendar.startOfDay(for: b)).day ?? 0
    }

    // MARK: Builders

    static func energyAverage(_ sessions: [WearSession]) -> Double {
        let minutes = sessions.reduce(0) { $0 + $1.minutes }
        guard minutes > 0 else { return 0 }
        let energy = sessions.reduce(0) { $0 + pow(10, $1.averageDecibels / 10) * $1.minutes }
        return 10 * log10(energy / minutes)
    }

    /// WHO: 40 h a week at 80 dB(A); every +3 dB halves the allowance.
    static func allowedWeeklyMinutes(db: Double) -> Double { 40 * 60 * pow(2, (80 - db) / 3) }

    private static func buildDays(sessions: [WearSession], others: [Date: Double], now: Date, calendar: Calendar) -> [DayStat] {
        guard let first = sessions.first else { return [] }
        let start = calendar.startOfDay(for: first.start)
        let lastSessionDay = sessions.map { calendar.startOfDay(for: $0.end) }.max() ?? start
        let today = max(start, max(lastSessionDay, calendar.startOfDay(for: now)))
        let count = max(1, (calendar.dateComponents([.day], from: start, to: today).day ?? 0) + 1)
        var days = (0..<count).map { DayStat(date: calendar.date(byAdding: .day, value: $0, to: start)!) }
        func index(_ date: Date) -> Int? {
            let i = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: date)).day ?? -1
            return days.indices.contains(i) ? i : nil
        }
        for s in sessions {
            if let i = index(s.start) { days[i].sessions += 1 }
            let level = pow(10, s.averageDecibels / 10)
            var t = s.start
            while t < s.end {
                let hourEnd = calendar.dateInterval(of: .hour, for: t)!.end
                let sliceEnd = min(hourEnd, s.end)
                let minutes = sliceEnd.timeIntervalSince(t) / 60
                if let i = index(t) {
                    let h = calendar.component(.hour, from: t)
                    days[i].minutes += minutes
                    days[i].energy += level * minutes
                    days[i].hourMinutes[h] += minutes
                    days[i].hourEnergy[h] += level * minutes
                }
                t = sliceEnd
            }
        }
        for i in days.indices {
            days[i].allDevicesMinutes = days[i].minutes + (others[days[i].date] ?? 0)
        }
        return days
    }

    private static func stats(_ period: DossierPeriod, days: [DayStat], sessions: [WearSession], now: Date, calendar: Calendar) -> PeriodStats {
        let firstDay = days.first?.date ?? calendar.startOfDay(for: now)
        let lastDay = days.last?.date ?? firstDay
        let today = max(lastDay, calendar.startOfDay(for: now))
        let start = period.days.map { calendar.date(byAdding: .day, value: -($0 - 1), to: today)! } ?? firstDay
        let inRange = days.filter { $0.date >= start }
        let total = inRange.reduce(0) { $0 + $1.minutes }
        let all = inRange.reduce(0) { $0 + $1.allDevicesMinutes }
        var previous: Double?
        if let n = period.days {
            let prevStart = calendar.date(byAdding: .day, value: -n, to: start)!
            previous = days.filter { $0.date >= prevStart && $0.date < start }.reduce(0) { $0 + $1.minutes }
        }
        let periodSessions = sessions.filter { $0.start >= start }
        let energy = inRange.reduce(0) { $0 + $1.energy }
        let clippedStart = max(start, firstDay)
        let span = max(1, (calendar.dateComponents([.day], from: clippedStart, to: today).day ?? 0) + 1)

        // Buckets for the trend chart.
        let unit: Calendar.Component
        switch period {
        case .week, .month: unit = .day
        case .year: unit = .month
        case .all: unit = span <= 62 ? .day : (span <= 400 ? .weekOfYear : .month)
        }
        var buckets: [TrendBucket] = []
        var cursor: Date = {
            switch period {
            case .year: return calendar.date(byAdding: .month, value: -11, to: calendar.dateInterval(of: .month, for: today)!.start)!
            default: return calendar.dateInterval(of: unit, for: start)!.start
            }
        }()
        while cursor <= today {
            let next = calendar.date(byAdding: unit, value: 1, to: cursor)!
            let slice = days.filter { $0.date >= cursor && $0.date < next }
            let m = slice.reduce(0) { $0 + $1.minutes }
            let e = slice.reduce(0) { $0 + $1.energy }
            buckets.append(TrendBucket(id: buckets.count, start: cursor, end: next, minutes: m,
                                       averageDecibels: m > 0 ? 10 * log10(e / m) : 0,
                                       sessions: slice.reduce(0) { $0 + $1.sessions }, isFuture: false))
            cursor = next
        }

        let hours = (0..<24).map { h in
            let m = inRange.reduce(0) { $0 + $1.hourMinutes[h] }
            let e = inRange.reduce(0) { $0 + $1.hourEnergy[h] }
            return HourStat(hour: h, minutes: m, averageDecibels: m > 0 ? 10 * log10(e / m) : 0)
        }
        let dose = periodSessions.reduce(0) { $0 + $1.minutes / allowedWeeklyMinutes(db: $1.averageDecibels) } / max(1, Double(span) / 7)
        let loud = periodSessions.filter { $0.averageDecibels >= 80 }.reduce(0) { $0 + $1.minutes }

        return PeriodStats(period: period, start: start, end: now, totalMinutes: total, allDevicesMinutes: all,
                           previousMinutes: previous, sessions: periodSessions,
                           averageDecibels: total > 0 ? 10 * log10(energy / total) : 0,
                           peakDecibels: periodSessions.map(\.peakDecibels).max() ?? 0,
                           activeDays: inRange.filter { $0.minutes > 0 }.count, spanDays: span,
                           buckets: buckets, bucketUnit: unit, hours: hours, weeklyDose: dose,
                           loudShare: total > 0 ? loud / total : 0)
    }
}
