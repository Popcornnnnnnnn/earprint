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
    enum Kind: Hashable { case minted, hours, tier, longest, bestDay, upcoming, retired }
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
    /// All wear sessions (clamped at the retirement cutoff when vaulted), sorted by start.
    let sessions: [WearSession]
    /// Unclipped first and last sample timestamps across the full Health archive.
    let liveFirstWearDate: Date?
    let liveLastWearStartDate: Date?
    let liveLastWearDate: Date?
    /// Health samples read for this device.
    var sampleCount: Int
    var lastSynced: Date
    let retirement: DeviceRetirement?
    /// Reference "now" so stats are reproducible (frozen at retirement when vaulted).
    let now: Date
    let calendar: Calendar

    var isRetired: Bool { retirement != nil }

    /// One entry per calendar day from the first wear to `now`.
    let days: [DayStat]
    let periods: [DossierPeriod: PeriodStats]

    // Precomputed lifetime summaries so SwiftUI body passes read O(1) stored values.
    let lifetimeMinutes: Double
    let recordDays: Int
    let longestSession: WearSession?
    let bestDay: DayStat?
    let averageDecibels: Double
    let nightShare: Double
    let grade: EarGrade
    let milestones: [DossierMilestone]
    let careerRows: [CareerRow]

    /// - Parameter otherDevicesDailyMinutes: minutes on *other* headphones keyed by start of day.
    init(id: String, nickname: String, symbol: String, serial: Int, hardware: DossierHardware,
         sessions: [WearSession], otherDevicesDailyMinutes: [Date: Double], sampleCount: Int,
         lastSynced: Date, retirement: DeviceRetirement? = nil,
         liveLastSampleStart: Date? = nil, liveLastSampleEnd: Date? = nil,
         now: Date, calendar: Calendar = .current) {
        self.id = id
        self.nickname = nickname
        self.symbol = symbol
        self.serial = serial
        self.hardware = hardware
        self.retirement = retirement

        let allSortedSessions = sessions.sorted { $0.start < $1.start }
        self.liveFirstWearDate = allSortedSessions.first?.start
        self.liveLastWearStartDate = liveLastSampleStart ?? allSortedSessions.last?.start
        self.liveLastWearDate = liveLastSampleEnd ?? allSortedSessions.last?.end

        let effectiveCalendar = retirement?.retiredCalendar ?? calendar
        let sortedSessions: [WearSession]
        let effectiveNow: Date
        if let retirement {
            let cutoff = retirement.careerCutoffEnd
            let endMoment = retirement.careerEndMoment
            sortedSessions = allSortedSessions.compactMap { session in
                guard session.start < cutoff else { return nil }
                var clipped = session
                if clipped.end > endMoment {
                    clipped.minutes = max(0, endMoment.timeIntervalSince(clipped.start) / 60)
                }
                return clipped.minutes > 0 ? clipped : nil
            }
            effectiveNow = max(sortedSessions.first?.start ?? endMoment, endMoment)
        } else {
            sortedSessions = allSortedSessions
            effectiveNow = now
        }

        let normalizedOthers: [Date: Double]
        if let retirement {
            let cutoffDay = effectiveCalendar.startOfDay(for: effectiveNow)
            if effectiveCalendar.timeZone != calendar.timeZone {
                var remapped: [Date: Double] = [:]
                for (date, mins) in otherDevicesDailyMinutes where mins > 0 {
                    let comps = calendar.dateComponents([.year, .month, .day], from: date)
                    if let day = effectiveCalendar.date(from: comps), day <= cutoffDay {
                        remapped[day, default: 0] += mins
                    }
                }
                normalizedOthers = remapped
            } else {
                normalizedOthers = otherDevicesDailyMinutes.filter { $0.key <= cutoffDay }
            }
        } else {
            normalizedOthers = otherDevicesDailyMinutes
        }

        self.sessions = sortedSessions
        self.sampleCount = sampleCount
        self.lastSynced = lastSynced
        self.now = effectiveNow
        self.calendar = effectiveCalendar
        let days = Self.buildDays(sessions: sortedSessions, others: normalizedOthers, now: effectiveNow, calendar: effectiveCalendar)
        self.days = days
        var periods: [DossierPeriod: PeriodStats] = [:]
        for period in DossierPeriod.allCases {
            periods[period] = Self.stats(period, days: days, sessions: sortedSessions, now: effectiveNow, calendar: effectiveCalendar)
        }
        self.periods = periods

        let lifetime = sortedSessions.reduce(0) { $0 + $1.minutes }
        let recDays = days.reduce(0) { $0 + ($1.minutes > 0 ? 1 : 0) }
        let longest = sortedSessions.max { $0.minutes < $1.minutes }
        let best = days.max { $0.minutes < $1.minutes }
        let avgDB = Self.energyAverage(sortedSessions)
        let monthStats = periods[.month]!
        let monthHourTotal = monthStats.hours.reduce(0) { $0 + $1.minutes }
        let night = monthHourTotal > 0
            ? monthStats.hours.filter { $0.hour < 5 }.reduce(0) { $0 + $1.minutes } / monthHourTotal
            : 0

        self.lifetimeMinutes = lifetime
        self.recordDays = recDays
        self.longestSession = longest
        self.bestDay = best
        self.averageDecibels = avgDB
        self.nightShare = night
        self.grade = Self.buildGrade(recent: monthStats, fallbackDecibels: avgDB, nightShare: night)
        self.milestones = Self.buildMilestones(
            sessions: sortedSessions,
            lifetimeMinutes: lifetime,
            longestSession: longest,
            bestDay: best,
            pace: monthStats.dailyAverage,
            retirement: retirement,
            now: effectiveNow,
            calendar: effectiveCalendar
        )
        self.careerRows = Self.buildCareerRows(sessions: sortedSessions, calendar: effectiveCalendar)
    }

    func stats(_ period: DossierPeriod) -> PeriodStats { periods[period]! }

    // MARK: Lifetime

    var rarity: Rarity { Rarity(minutes: lifetimeMinutes) }
    var firstWear: Date? { sessions.first?.start }
    var lastWear: WearSession? { sessions.last }
    var historyDays: Int { days.count }

    /// 28-day × 24-hour listening grid ending on `calendar.startOfDay(for: now)` so vaulted glyphs reflect the archived cutoff.
    var recentFourWeekGrid: ListeningGrid {
        let dayCount = LibrarySnapshot.gridDays
        var minutes = Array(repeating: Array(repeating: 0.0, count: 24), count: dayCount)
        var decibels = minutes
        let endDay = calendar.dateInterval(of: .day, for: now)?.start ?? calendar.startOfDay(for: now)
        let firstGridDay = Self.addingCalendarDays(-(dayCount - 1), to: endDay, calendar: calendar)
        let byDate = Dictionary(uniqueKeysWithValues: days.map { ($0.date, $0) })
        var cursor = firstGridDay
        for offset in 0..<dayCount {
            if let stat = byDate[cursor] {
                for h in 0..<24 where stat.hourMinutes[h] > 0 {
                    minutes[offset][h] = stat.hourMinutes[h]
                    decibels[offset][h] = stat.hourEnergy[h] > 0 ? 10 * log10(stat.hourEnergy[h] / stat.hourMinutes[h]) : 0
                }
            }
            let nextCursor = calendar.dateInterval(of: .day, for: cursor)?.end
                ?? Self.addingCalendarDays(1, to: cursor, calendar: calendar)
            if nextCursor <= cursor { break }
            cursor = nextCursor
        }
        return ListeningGrid(minutes: minutes, decibels: decibels)
    }

    /// Returns a card whose career metrics and 4-week ring match this frozen dossier when retired.
    func cardSnapshot(from card: HeadphoneCard) -> HeadphoneCard {
        guard isRetired else { return card }
        var copy = card
        copy.lifetimeMinutes = lifetimeMinutes
        copy.sessions = sessions.count
        copy.longestMinutes = longestSession?.minutes ?? 0
        copy.averageDecibels = averageDecibels.rounded()
        copy.firstMet = firstWear.map { DateText.dotted($0, calendar: calendar) } ?? "—"
        copy.grid = recentFourWeekGrid
        return copy
    }

    private static func buildGrade(recent: PeriodStats, fallbackDecibels: Double, nightShare: Double) -> EarGrade {
        let db = recent.totalMinutes > 0 ? recent.averageDecibels : fallbackDecibels
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

    private static func buildMilestones(
        sessions: [WearSession],
        lifetimeMinutes: Double,
        longestSession: WearSession?,
        bestDay: DayStat?,
        pace: Double,
        retirement: DeviceRetirement?,
        now: Date,
        calendar: Calendar
    ) -> [DossierMilestone] {
        var result: [DossierMilestone] = []
        let hourMarks: [Double] = [50, 100, 250, 500, 1000, 2000]
        let tiers: [(Double, Rarity)] = Rarity.allAscending.dropFirst().map { ($0.minimumHours, $0) }
        if let first = sessions.first {
            let firstDayStart = calendar.startOfDay(for: first.start)
            result.append(
                .init(id: "minted", kind: .minted, date: first.start, title: "Minted",
                      detail: "First wear · \(first.minutes.minutesText)", tier: .bronze)
            )
            var cumulative = 0.0
            for session in sessions {
                let before = cumulative
                cumulative += session.minutes
                for mark in hourMarks where before < mark * 60 && cumulative >= mark * 60 {
                    let date = session.start.addingTimeInterval((mark * 60 - before) * 60)
                    let delta = Self.calendarDayDelta(from: firstDayStart, to: date, calendar: calendar)
                    let dayDetail = delta == 0 ? "Same day as minting" : (delta == 1 ? "1 day after minting" : "\(delta) days after minting")
                    result.append(.init(id: "h\(Int(mark))", kind: .hours, date: date, title: "\(Int(mark)) hours",
                                        detail: dayDetail))
                }
                for (mark, tier) in tiers where before < mark * 60 && cumulative >= mark * 60 {
                    let date = session.start.addingTimeInterval((mark * 60 - before) * 60)
                    result.append(.init(id: "t\(tier.rawValue)", kind: .tier, date: date, title: "\(tier.shortName) tier",
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
        }
        if let retirement {
            let finalTier = Rarity(minutes: lifetimeMinutes)
            let detail = AppLanguage.current.text(
                "%@ · %@ career",
                AppLanguage.current.text(retirement.reason.title),
                lifetimeMinutes.minutesText
            )
            result.append(.init(
                id: "retired",
                kind: .retired,
                date: retirement.careerEndMoment,
                title: "Retired to Vault",
                detail: detail,
                tier: finalTier
            ))
        } else if !sessions.isEmpty,
                  let next = (hourMarks.map { $0 * 60 } + tiers.map { $0.0 * 60 }).sorted().first(where: { $0 > lifetimeMinutes }),
                  pace > 0 {
            // Next goal with an ETA from the last 30 days' pace.
            let daysLeft = (next - lifetimeMinutes) / pace
            let eta = now.addingTimeInterval(daysLeft * 86400)
            let tier = tiers.first { $0.0 * 60 == next }?.1
            result.append(.init(id: "next", kind: .upcoming, date: eta,
                                title: tier.map { "\($0.shortName) tier" } ?? "\(Int(next / 60)) hours",
                                detail: "\((next - lifetimeMinutes).minutesText) to go · at your pace", tier: tier, isFuture: true))
        }
        return result.sorted { $0.date < $1.date }
    }

    /// Month-by-month "career" lines, newest first.
    private static func buildCareerRows(sessions: [WearSession], calendar: Calendar) -> [CareerRow] {
        var groups: [Date: [WearSession]] = [:]
        for s in sessions {
            let month = calendar.dateInterval(of: .month, for: s.start)!.start
            groups[month, default: []].append(s)
        }
        return groups.keys.sorted(by: >).map { month in
            let list = groups[month]!
            let label = DateText.format(month, dateFormat: "MMM ’yy", calendar: calendar, locale: Locale.current).uppercased()
            return CareerRow(id: month, label: label,
                             minutes: list.reduce(0) { $0 + $1.minutes }, sessions: list.count,
                             longest: list.map(\.minutes).max() ?? 0, averageDecibels: Self.energyAverage(list))
        }
    }

    func daysBetween(_ a: Date, _ b: Date) -> Int {
        Self.calendarDayDelta(from: a, to: b, calendar: calendar)
    }

    private static func addingCalendarDays(_ delta: Int, to dayStart: Date, calendar: Calendar) -> Date {
        let interval = calendar.dateInterval(of: .day, for: dayStart)
        let midpoint: Date
        if let interval {
            midpoint = interval.start.addingTimeInterval(interval.duration / 2)
        } else {
            midpoint = calendar.startOfDay(for: dayStart).addingTimeInterval(12 * 3600)
        }
        guard let shifted = calendar.date(byAdding: .day, value: delta, to: midpoint) else {
            return dayStart.addingTimeInterval(Double(delta) * 86_400)
        }
        return calendar.dateInterval(of: .day, for: shifted)?.start ?? calendar.startOfDay(for: shifted)
    }

    private static func calendarDayDelta(from a: Date, to b: Date, calendar: Calendar) -> Int {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let aComps = calendar.dateComponents([.year, .month, .day], from: a)
        let bComps = calendar.dateComponents([.year, .month, .day], from: b)
        guard let aUTC = utc.date(from: DateComponents(year: aComps.year, month: aComps.month, day: aComps.day)),
              let bUTC = utc.date(from: DateComponents(year: bComps.year, month: bComps.month, day: bComps.day)) else {
            return calendar.dateComponents([.day], from: calendar.startOfDay(for: a), to: calendar.startOfDay(for: b)).day ?? 0
        }
        return utc.dateComponents([.day], from: aUTC, to: bUTC).day ?? 0
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
        let start = calendar.dateInterval(of: .day, for: first.start)?.start ?? calendar.startOfDay(for: first.start)
        let lastSessionDay = sessions
            .map { calendar.dateInterval(of: .day, for: $0.end)?.start ?? calendar.startOfDay(for: $0.end) }
            .max() ?? start
        let nowDay = calendar.dateInterval(of: .day, for: now)?.start ?? calendar.startOfDay(for: now)
        let today = max(start, max(lastSessionDay, nowDay))

        var days: [DayStat] = []
        var dayStarts: [Double] = []
        var dayEnds: [Double] = []
        var uniformDay: [Bool] = []
        let tz = calendar.timeZone

        var cursor = start
        while cursor <= today {
            let interval = calendar.dateInterval(of: .day, for: cursor)
            let d = interval?.start ?? cursor
            let nextD = interval?.end ?? Self.addingCalendarDays(1, to: d, calendar: calendar)
            days.append(DayStat(date: d))
            let s = d.timeIntervalSince1970
            let e = nextD.timeIntervalSince1970
            dayStarts.append(s)
            dayEnds.append(e)
            uniformDay.append(
                (e - s == 86_400)
                && tz.secondsFromGMT(for: d) == tz.secondsFromGMT(for: Date(timeIntervalSince1970: e - 1))
            )
            if nextD <= cursor { break }
            cursor = nextD
        }
        let count = days.count
        guard count > 0 else { return [] }

        let firstStart = dayStarts[0]
        let lastEnd = dayEnds[count - 1]
        func dayIndex(for epoch: Double) -> Int? {
            guard epoch >= firstStart && epoch < lastEnd else { return nil }
            var i = min(count - 1, max(0, Int((epoch - firstStart) / 86_400)))
            while i + 1 < count && epoch >= dayStarts[i + 1] { i += 1 }
            while i > 0 && epoch < dayStarts[i] { i -= 1 }
            return (epoch >= dayStarts[i] && epoch < dayEnds[i]) ? i : nil
        }

        for s in sessions {
            let startEpoch = s.start.timeIntervalSince1970
            let endEpoch = s.end.timeIntervalSince1970
            if let i = dayIndex(for: startEpoch) { days[i].sessions += 1 }
            let level = pow(10, s.averageDecibels / 10)
            var t = startEpoch
            while t < endEpoch {
                guard let i = dayIndex(for: t) else { break }
                let h: Int
                let hourEndEpoch: Double
                if uniformDay[i] {
                    h = min(23, max(0, Int((t - dayStarts[i]) / 3600)))
                    hourEndEpoch = dayStarts[i] + Double(h + 1) * 3600
                } else {
                    let date = Date(timeIntervalSince1970: t)
                    h = calendar.component(.hour, from: date)
                    hourEndEpoch = calendar.dateInterval(of: .hour, for: date)?.end.timeIntervalSince1970 ?? (t + 3600)
                }
                let sliceEnd = min(hourEndEpoch, endEpoch)
                let minutes = (sliceEnd - t) / 60
                if minutes > 0 {
                    days[i].minutes += minutes
                    days[i].energy += level * minutes
                    days[i].hourMinutes[h] += minutes
                    days[i].hourEnergy[h] += level * minutes
                }
                t = max(sliceEnd, t + 1)
            }
        }
        for i in days.indices {
            days[i].allDevicesMinutes = days[i].minutes + (others[days[i].date] ?? 0)
        }
        return days
    }

    private static func stats(_ period: DossierPeriod, days: [DayStat], sessions: [WearSession], now: Date, calendar: Calendar) -> PeriodStats {
        let nowDay = calendar.dateInterval(of: .day, for: now)?.start ?? calendar.startOfDay(for: now)
        let firstDay = days.first?.date ?? nowDay
        let lastDay = days.last?.date ?? firstDay
        let today = max(lastDay, nowDay)
        let start = period.days.map { Self.addingCalendarDays(-($0 - 1), to: today, calendar: calendar) } ?? firstDay

        // Single linear pass over sorted `days` for range totals, previous period, active days, and 24h bins.
        let prevStart = period.days.map { Self.addingCalendarDays(-$0, to: start, calendar: calendar) }
        var total = 0.0
        var all = 0.0
        var energy = 0.0
        var activeDays = 0
        var spanDaysInRange = 0
        var prevTotal = 0.0
        var hourMinutes = [Double](repeating: 0, count: 24)
        var hourEnergy = [Double](repeating: 0, count: 24)

        for day in days {
            if day.date >= start {
                spanDaysInRange += 1
                total += day.minutes
                all += day.allDevicesMinutes
                energy += day.energy
                if day.minutes > 0 { activeDays += 1 }
                for h in 0..<24 {
                    hourMinutes[h] += day.hourMinutes[h]
                    hourEnergy[h] += day.hourEnergy[h]
                }
            } else if let prevStart, day.date >= prevStart {
                prevTotal += day.minutes
            }
        }
        let previous: Double? = prevStart != nil ? prevTotal : nil

        let periodSessions = sessions.filter { $0.start >= start }
        let span = max(1, spanDaysInRange)

        // Buckets for the trend chart via O(days) two-pointer scan over sorted `days`.
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
        var dayCursor = 0
        while dayCursor < days.count && days[dayCursor].date < cursor {
            dayCursor += 1
        }
        while cursor <= today {
            let next = calendar.dateInterval(of: unit, for: cursor)?.end
                ?? (unit == .day
                    ? Self.addingCalendarDays(1, to: cursor, calendar: calendar)
                    : calendar.date(byAdding: unit, value: 1, to: cursor)!)
            var m = 0.0
            var e = 0.0
            var sCount = 0
            while dayCursor < days.count && days[dayCursor].date < next {
                let d = days[dayCursor]
                m += d.minutes
                e += d.energy
                sCount += d.sessions
                dayCursor += 1
            }
            buckets.append(TrendBucket(id: buckets.count, start: cursor, end: next, minutes: m,
                                       averageDecibels: m > 0 ? 10 * log10(e / m) : 0,
                                       sessions: sCount, isFuture: false))
            if next <= cursor { break }
            cursor = next
        }

        let hours = (0..<24).map { h in
            let m = hourMinutes[h]
            let e = hourEnergy[h]
            return HourStat(hour: h, minutes: m, averageDecibels: m > 0 ? 10 * log10(e / m) : 0)
        }
        var doseSum = 0.0
        var loud = 0.0
        var peakDB = 0.0
        for s in periodSessions {
            doseSum += s.minutes / allowedWeeklyMinutes(db: s.averageDecibels)
            if s.averageDecibels >= 80 { loud += s.minutes }
            if s.peakDecibels > peakDB { peakDB = s.peakDecibels }
        }
        let dose = doseSum / max(1, Double(span) / 7)

        return PeriodStats(period: period, start: start, end: now, totalMinutes: total, allDevicesMinutes: all,
                           previousMinutes: previous, sessions: periodSessions,
                           averageDecibels: total > 0 ? 10 * log10(energy / total) : 0,
                           peakDecibels: peakDB,
                           activeDays: activeDays, spanDays: span,
                           buckets: buckets, bucketUnit: unit, hours: hours, weeklyDose: dose,
                           loudShare: total > 0 ? loud / total : 0)
    }
}
