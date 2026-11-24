import Foundation

/// Display-ready stats for a headphone and its matching accessory records.
struct DeviceSummary: Identifiable, Sendable {
    var id: String
    var aliasIDs: [String]
    var nickname: String
    /// Earlier nicknames of the same physical device.
    var otherNames: [String]
    var model: HeadphoneModelInfo
    var descriptor: DeviceDescriptor?
    var isUnattributed: Bool

    var sampleCount: Int
    var lifetimeSeconds: Double
    var averageDecibels: Double?
    var sessionCount: Int
    var longestSession: TimeInterval
    var averageSession: TimeInterval
    var first: Date?
    var last: Date?
    var activeDays: Int
    var sources: [String]

    /// Last 28 local days × 24 hours, oldest day first, today last.
    var grid: ListeningGrid
    var weekSeconds: Double
    var weekDecibels: Double?
    /// Share of the WHO weekly budget used in the last 7 local days (today + 6), 1.0 = 100 %.
    var weeklyBudget: Double
    var tierAchievedDates: [Rarity: Date] = [:]
    var wearSessions: [WearSession] = []
    var dailySeconds: [Int: Double] = [:]
}

struct LibrarySnapshot: Sendable {
    var generatedAt: Date
    /// Sorted by lifetime listening, most first.
    var devices: [DeviceSummary]
    var totalSamples: Int
    var hostSamples: Int
    var invalidSamples: Int
    private var sourceSerials: [String: Int]

    var isEmpty: Bool { devices.isEmpty }
    var lifetimeSeconds: Double { devices.reduce(0) { $0 + $1.lifetimeSeconds } }

    /// The headphone to feature on the home screen: most listening this week, else most lifetime.
    var primary: DeviceSummary? {
        devices.max { a, b in
            (a.weekSeconds, a.lifetimeSeconds) < (b.weekSeconds, b.lifetimeSeconds)
        }
    }

    static let gridDays = 28

    init(aggregate: ListeningAggregate, now: Date = Date(), calendar: Calendar = .current) {
        generatedAt = now
        totalSamples = aggregate.totalSamples
        hostSamples = aggregate.hostSamples
        invalidSamples = aggregate.invalidSamples
        let sources = aggregate.devices.values
            .filter { $0.sampleCount > 0 }
            .sorted { ($0.first ?? .distantFuture, $0.key) < ($1.first ?? .distantFuture, $1.key) }
        sourceSerials = Dictionary(uniqueKeysWithValues: sources.enumerated().map { ($1.key, $0 + 1) })
        devices = Dictionary(grouping: sources, by: DeviceGroup.init)
            .values
            .map { group in
                Self.summary(for: DeviceAccumulator.combining(group), aliasIDs: group.dropFirst().map(\.key),
                             now: now, calendar: calendar)
            }
            .sorted { ($0.lifetimeSeconds, $0.id) > ($1.lifetimeSeconds, $1.id) }
    }

    private enum DeviceGroup: Hashable {
        case accessory(String)
        case airPods(product: String, nickname: String)

        init(_ device: DeviceAccumulator) {
            let model = HeadphoneModelCatalog.resolve(device.descriptor)
            guard let productID = model.productID,
                  let product = HeadphoneModelCatalog.byProductID[productID],
                  product.key.collectibleArtwork != nil,
                  let name = DeviceDescriptor.clean(device.descriptor?.name) else {
                self = .accessory(device.key)
                return
            }
            let nickname = name.lowercased()
                .replacingOccurrences(of: "\u{2019}", with: "'")
                .replacingOccurrences(of: "\u{2018}", with: "'")
            self = .airPods(product: product.marketingName, nickname: nickname)
        }
    }

    private static func summary(for acc: DeviceAccumulator, aliasIDs: [String], now: Date, calendar: Calendar) -> DeviceSummary {
        let unattributed = acc.key == ListeningAggregate.unattributedKey
        let model = unattributed ? HeadphoneModelCatalog.unknownHeadphones : HeadphoneModelCatalog.resolve(acc.descriptor)
        let nickname = unattributed ? "Unknown headphones"
            : DeviceDescriptor.clean(acc.descriptor?.name) ?? model.shortName
        let window = gridWindow(slots: acc.slots, now: now, calendar: calendar, days: gridDays)
        let sessions = acc.sessions
        let tierDates = achievedTierDates(for: acc, now: now, calendar: calendar)
        let fallbackDB = acc.averageDecibels ?? 62
        let wearSessions: [WearSession] = sessions.spans.compactMap { span in
            let activeSeconds = span.effectiveSeconds
            guard activeSeconds > 0 else { return nil }
            let avgDB = span.averageDecibels ?? fallbackDB
            let peakDB = span.peakDecibels > 0 ? max(span.peakDecibels, avgDB) : avgDB
            return WearSession(
                start: Date(timeIntervalSince1970: span.start),
                minutes: activeSeconds / 60,
                averageDecibels: avgDB,
                peakDecibels: peakDB,
                isEstimated: false
            )
        }
        return DeviceSummary(
            id: acc.key,
            aliasIDs: aliasIDs,
            nickname: nickname,
            otherNames: acc.names.filter { $0 != nickname },
            model: model,
            descriptor: acc.descriptor,
            isUnattributed: unattributed,
            sampleCount: acc.sampleCount,
            lifetimeSeconds: acc.seconds,
            averageDecibels: acc.averageDecibels,
            sessionCount: sessions.count,
            longestSession: sessions.longest,
            averageSession: sessions.count > 0 ? sessions.totalSpan / Double(sessions.count) : 0,
            first: acc.first,
            last: acc.last,
            activeDays: acc.activeDays,
            sources: acc.sources.sorted(),
            grid: window.grid,
            weekSeconds: window.weekSeconds,
            weekDecibels: HearingBudget.averageDecibels(energy: window.weekEnergy, seconds: window.weekSeconds),
            weeklyBudget: HearingBudget.dose(energy: window.weekEnergy),
            tierAchievedDates: tierDates,
            wearSessions: wearSessions,
            dailySeconds: acc.daily
        )
    }

    private static func achievedTierDates(for acc: DeviceAccumulator, now: Date, calendar: Calendar) -> [Rarity: Date] {
        var dates: [Rarity: Date] = [:]
        if let first = acc.first {
            dates[.bronze] = first
        }
        var cumulativeSeconds = 0.0
        for (dayKey, seconds) in acc.daily.sorted(by: { $0.key < $1.key }) where seconds > 0 {
            cumulativeSeconds += seconds
            let year = dayKey / 10_000
            let month = (dayKey / 100) % 100
            let day = dayKey % 100
            let dayDate = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? now
            if dates[.bronze] == nil {
                dates[.bronze] = dayDate
            }
            for tier in Rarity.allAscending.dropFirst() where dates[tier] == nil {
                if cumulativeSeconds >= tier.minimumHours * 3600 {
                    dates[tier] = dayDate
                }
            }
        }
        for tier in Rarity.allAscending.dropFirst() where dates[tier] == nil && acc.seconds >= tier.minimumHours * 3600 {
            dates[tier] = acc.last ?? now
        }
        return dates
    }

    struct GridWindow {
        var grid: ListeningGrid
        var weekSeconds: Double
        var weekEnergy: Double
    }

    /// Buckets 15-minute slots into local day × hour cells using the calendar's *current* time zone.
    /// DST: the repeated autumn hour adds into the same hour cell; the skipped spring hour stays empty.
    /// Precomputes the `days` local day intervals once so normal 24-hour days resolve in O(1) arithmetic
    /// without invoking `Calendar` on every 15-minute slot.
    static func gridWindow(slots: [Int: SlotTotals], now: Date, calendar: Calendar, days: Int) -> GridWindow {
        var seconds = Array(repeating: Array(repeating: 0.0, count: 24), count: days)
        var energy = seconds
        guard days > 0 else {
            return GridWindow(grid: ListeningGrid(minutes: [], decibels: []), weekSeconds: 0, weekEnergy: 0)
        }

        let today = calendar.startOfDay(for: now)
        let firstDay = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today

        var dayStarts = [Double](repeating: 0, count: days)
        var dayEnds = [Double](repeating: 0, count: days)
        var uniformDay = [Bool](repeating: false, count: days)
        let tz = calendar.timeZone

        for d in 0..<days {
            let startDate = calendar.date(byAdding: .day, value: d, to: firstDay) ?? firstDay
            let endDate = calendar.date(byAdding: .day, value: d + 1, to: firstDay) ?? startDate.addingTimeInterval(86_400)
            let s = startDate.timeIntervalSince1970
            let e = endDate.timeIntervalSince1970
            dayStarts[d] = s
            dayEnds[d] = e
            uniformDay[d] = (e - s == 86_400)
                && tz.secondsFromGMT(for: startDate) == tz.secondsFromGMT(for: Date(timeIntervalSince1970: e - 1))
        }

        let firstStart = dayStarts[0]
        let nowEpoch = now.timeIntervalSince1970
        let lastDayEnd = dayEnds[days - 1]
        var weekSeconds = 0.0, weekEnergy = 0.0

        for (index, slot) in slots where slot.seconds > 0 {
            let t = Double(index) * ListeningAggregate.slotLength
            guard t >= firstStart, t <= nowEpoch, t < lastDayEnd else { continue }

            var day = min(days - 1, max(0, Int((t - firstStart) / 86_400)))
            while day + 1 < days && t >= dayStarts[day + 1] { day += 1 }
            while day > 0 && t < dayStarts[day] { day -= 1 }
            guard t >= dayStarts[day] && t < dayEnds[day] else { continue }

            let hour: Int
            if uniformDay[day] {
                hour = min(23, max(0, Int((t - dayStarts[day]) / 3600)))
            } else {
                hour = calendar.component(.hour, from: Date(timeIntervalSince1970: t))
            }
            guard hour >= 0 && hour < 24 else { continue }

            seconds[day][hour] += slot.seconds
            energy[day][hour] += slot.energy
            if day >= days - 7 {
                weekSeconds += slot.seconds
                weekEnergy += slot.energy
            }
        }

        var minutes = seconds
        var decibels = seconds
        for d in 0..<days {
            for h in 0..<24 {
                minutes[d][h] = seconds[d][h] / 60
                decibels[d][h] = HearingBudget.averageDecibels(energy: energy[d][h], seconds: seconds[d][h]) ?? 0
            }
        }
        return GridWindow(grid: ListeningGrid(minutes: minutes, decibels: decibels), weekSeconds: weekSeconds, weekEnergy: weekEnergy)
    }
}

private extension DeviceAccumulator {
    /// The first accessory keeps its key. Only the snapshot combines records; the cache retains each source.
    static func combining(_ devices: [Self]) -> Self {
        var combined = devices[0]
        guard devices.count > 1 else { return combined }

        for device in devices.dropFirst() {
            combined.sampleCount += device.sampleCount
            combined.seconds += device.seconds
            combined.energy += device.energy
            if device.descriptorDate >= combined.descriptorDate {
                combined.descriptor = device.descriptor
                combined.descriptorDate = device.descriptorDate
            }
            if let last = device.last {
                combined.last = max(combined.last ?? last, last)
            }
            for name in device.names where !combined.names.contains(name) {
                combined.names.append(name)
            }
            combined.sources.formUnion(device.sources)
            combined.daily.merge(device.daily, uniquingKeysWith: +)
            for (index, totals) in device.slots {
                combined.slots[index, default: SlotTotals()].seconds += totals.seconds
                combined.slots[index, default: SlotTotals()].energy += totals.energy
            }
        }

        let spans = devices.flatMap { $0.sessions.spans }.sorted { $0.start < $1.start }
        combined.sessions = SessionSet()
        for span in spans {
            combined.sessions.insert(
                start: span.start,
                end: span.end,
                gap: ListeningAggregate.sessionGap,
                listeningSeconds: span.effectiveSeconds,
                energy: span.energy,
                peakDecibels: span.peakDecibels
            )
        }
        return combined
    }
}

// MARK: - Mapping to the existing view models

extension LibrarySnapshot {
    func cards(now: Date = Date(), calendar: Calendar = .current) -> [HeadphoneCard] {
        // Keep the first accessory's existing serial after merging its aliases.
        devices.map { d in
            HeadphoneCard(
                id: d.id,
                nickname: d.nickname,
                model: d.model.marketingName,
                symbol: d.model.resolvedSymbol,
                lifetimeMinutes: d.lifetimeSeconds / 60,
                sessions: d.sessionCount,
                longestMinutes: d.longestSession / 60,
                averageDecibels: (d.averageDecibels ?? 0).rounded(),
                firstMet: d.first.map { DateText.dotted($0, calendar: calendar) } ?? "—",
                lastUsed: d.last.map { DateText.relativeDay($0, now: now, calendar: calendar) } ?? "—",
                serial: sourceSerials[d.id] ?? 0,
                grid: d.grid,
                modelKey: d.model.key,
                kind: d.model.key.kind,
                aliasIDs: d.aliasIDs,
                tierAchievedDates: d.tierAchievedDates
            )
        }
    }

    func homeSummary(now: Date = Date(), calendar: Calendar = .current) -> ListeningSummary? {
        guard let d = primary else { return nil }
        return Self.listeningSummary(for: d, now: now, calendar: calendar)
    }

    func summary(for deviceID: String, now: Date = Date(), calendar: Calendar = .current) -> ListeningSummary? {
        guard let d = devices.first(where: { $0.id == deviceID || $0.aliasIDs.contains(deviceID) }) else { return nil }
        return Self.listeningSummary(for: d, now: now, calendar: calendar)
    }

    /// Combines every discovered headphone pair into an all-devices weekly Earprint & WHO exposure summary.
    func combinedHomeSummary(now: Date = Date(), calendar: Calendar = .current) -> ListeningSummary? {
        guard !devices.isEmpty else { return nil }
        if devices.count == 1, let only = devices.first {
            return Self.listeningSummary(for: only, now: now, calendar: calendar)
        }

        let dayCount = devices.map(\.grid.days).max() ?? Self.gridDays
        var combinedMinutes = Array(repeating: Array(repeating: 0.0, count: 24), count: dayCount)
        var combinedEnergy = combinedMinutes

        for d in devices {
            let dayOffset = max(0, dayCount - d.grid.days)
            for day in 0..<d.grid.days {
                let targetDay = dayOffset + day
                for hour in 0..<24 {
                    let mins = d.grid.minutes[day][hour]
                    guard mins > 0 else { continue }
                    let db = d.grid.decibels[day][hour]
                    combinedMinutes[targetDay][hour] += mins
                    combinedEnergy[targetDay][hour] += pow(10, db / 10) * mins
                }
            }
        }

        var combinedDecibels = Array(repeating: Array(repeating: 0.0, count: 24), count: dayCount)
        for day in 0..<dayCount {
            for hour in 0..<24 where combinedMinutes[day][hour] > 0 {
                combinedDecibels[day][hour] = 10 * log10(combinedEnergy[day][hour] / combinedMinutes[day][hour])
            }
        }

        let totalLifetimeSeconds = devices.reduce(0) { $0 + $1.lifetimeSeconds }
        let totalSessions = devices.reduce(0) { $0 + $1.sessionCount }
        let longest = devices.map(\.longestSession).max() ?? 0
        let avgSession = totalSessions > 0 ? totalLifetimeSeconds / Double(totalSessions) : 0
        let earliestFirst = devices.compactMap(\.first).min()
        let totalBudget = devices.reduce(0) { $0 + $1.weeklyBudget }

        return ListeningSummary(
            deviceName: AppLanguage.current.text("All Headphones"),
            deviceModel: AppLanguage.current.text("%lld pairs", devices.count),
            deviceSymbol: "headphones",
            periodLabel: DateText.weekRange(endingAt: now, calendar: calendar),
            grid: ListeningGrid(minutes: combinedMinutes, decibels: combinedDecibels),
            lifetimeMinutes: totalLifetimeSeconds / 60,
            sessions: totalSessions,
            averageSessionMinutes: avgSession / 60,
            longestSessionMinutes: longest / 60,
            firstUse: earliestFirst.map { DateText.monthDay($0, calendar: calendar) } ?? "—",
            weeklyBudgetOverride: totalBudget
        )
    }

    private static func listeningSummary(for d: DeviceSummary, now: Date, calendar: Calendar) -> ListeningSummary {
        ListeningSummary(
            deviceName: d.nickname,
            deviceModel: d.model.marketingName,
            deviceSymbol: d.model.resolvedSymbol,
            periodLabel: DateText.weekRange(endingAt: now, calendar: calendar),
            grid: d.grid,
            lifetimeMinutes: d.lifetimeSeconds / 60,
            sessions: d.sessionCount,
            averageSessionMinutes: d.averageSession / 60,
            longestSessionMinutes: d.longestSession / 60,
            firstUse: d.first.map { DateText.monthDay($0, calendar: calendar) } ?? "—",
            weeklyBudgetOverride: d.weeklyBudget
        )
    }

    func dossier(forCardID id: String, now: Date = Date(), calendar: Calendar = .current) -> DeviceDossier? {
        guard let d = devices.first(where: { $0.id == id || $0.aliasIDs.contains(id) }) else { return nil }
        var others: [Date: Double] = [:]
        for other in devices where other.id != d.id {
            for (dayKey, secs) in other.dailySeconds where secs > 0 {
                let year = dayKey / 10_000
                let month = (dayKey / 100) % 100
                let day = dayKey % 100
                if let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) {
                    others[date, default: 0] += secs / 60
                }
            }
        }
        let desc = d.descriptor
        let productID = d.model.productID.map { String(format: "0x%04X", $0) }
            ?? desc?.model?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "—"
        let hardware = DossierHardware(
            deviceName: d.nickname,
            manufacturer: desc?.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Apple Inc.",
            productID: productID,
            modelName: d.model.marketingName,
            hardwareVersion: desc?.hardwareVersion?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
            firmwareVersion: desc?.firmwareVersion?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
            sourceName: Self.friendlySourceName(bundleIDs: d.sources),
            sourceBundleID: d.sources.first ?? "com.apple.Health"
        )
        return DeviceDossier(
            id: d.id,
            nickname: d.nickname,
            symbol: d.model.resolvedSymbol,
            serial: sourceSerials[d.id] ?? 0,
            hardware: hardware,
            sessions: d.wearSessions,
            otherDevicesDailyMinutes: others,
            sampleCount: d.sampleCount,
            lastSynced: generatedAt,
            now: now,
            calendar: calendar
        )
    }

    private static func friendlySourceName(bundleIDs: [String]) -> String {
        if bundleIDs.contains(where: { $0.hasPrefix("com.apple.health") }) {
            return "Apple Health"
        }
        return bundleIDs.first?.nonEmpty ?? "Apple Health"
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

enum DateText {
    private struct FormatterKey: Hashable {
        let format: String
        let isTemplate: Bool
        let calendarID: Calendar.Identifier
        let timeZoneID: String
        let localeID: String
    }

    private final class FormatterPool: @unchecked Sendable {
        private let lock = NSLock()
        private var cache: [FormatterKey: DateFormatter] = [:]

        func string(from date: Date, format: String, isTemplate: Bool, calendar: Calendar, locale: Locale) -> String {
            let key = FormatterKey(
                format: format,
                isTemplate: isTemplate,
                calendarID: calendar.identifier,
                timeZoneID: calendar.timeZone.identifier,
                localeID: locale.identifier
            )
            lock.lock()
            defer { lock.unlock() }
            let formatter: DateFormatter
            if let existing = cache[key] {
                formatter = existing
            } else {
                let f = DateFormatter()
                f.calendar = calendar
                f.timeZone = calendar.timeZone
                f.locale = locale
                if isTemplate {
                    f.setLocalizedDateFormatFromTemplate(format)
                } else {
                    f.dateFormat = format
                }
                cache[key] = f
                formatter = f
            }
            return formatter.string(from: date)
        }
        func date(from text: String, format: String, calendar: Calendar, locale: Locale) -> Date? {
            let key = FormatterKey(
                format: format,
                isTemplate: false,
                calendarID: calendar.identifier,
                timeZoneID: calendar.timeZone.identifier,
                localeID: locale.identifier
            )
            lock.lock()
            defer { lock.unlock() }
            let formatter: DateFormatter
            if let existing = cache[key] {
                formatter = existing
            } else {
                let f = DateFormatter()
                f.calendar = calendar
                f.timeZone = calendar.timeZone
                f.locale = locale
                f.dateFormat = format
                cache[key] = f
                formatter = f
            }
            return formatter.date(from: text)
        }
    }

    private static let pool = FormatterPool()
    private static let posixLocale = Locale(identifier: "en_US_POSIX")

    static func parse(_ text: String, dateFormat: String, calendar: Calendar, locale: Locale = posixLocale) -> Date? {
        pool.date(from: text, format: dateFormat, calendar: calendar, locale: locale)
    }

    static func format(_ date: Date, dateFormat: String, calendar: Calendar, locale: Locale = posixLocale) -> String {
        pool.string(from: date, format: dateFormat, isTemplate: false, calendar: calendar, locale: locale)
    }

    static func formatTemplate(_ date: Date, template: String, calendar: Calendar, locale: Locale) -> String {
        pool.string(from: date, format: template, isTemplate: true, calendar: calendar, locale: locale)
    }

    /// "2026.10.30"
    static func dotted(_ date: Date, calendar: Calendar) -> String {
        format(date, dateFormat: "yyyy.MM.dd", calendar: calendar)
    }

    /// "Oct 30"
    static func monthDay(_ date: Date, calendar: Calendar) -> String {
        formatTemplate(date, template: "MMM d", calendar: calendar, locale: AppLanguage.current.locale)
    }

    /// Concise tier achievement date: "Oct '25" in English or "25年10月" in Chinese.
    static func shortMonthYear(_ date: Date, calendar: Calendar, locale: Locale = AppLanguage.current.locale) -> String {
        let comps = calendar.dateComponents([.year, .month], from: date)
        let yy = (comps.year ?? 0) % 100
        let m = comps.month ?? 1
        if locale.identifier.hasPrefix("zh") {
            return "\(yy)年\(m)月"
        }
        let month = format(date, dateFormat: "MMM", calendar: calendar, locale: AppLanguage.english.locale)
        let year = format(date, dateFormat: "yy", calendar: calendar, locale: AppLanguage.english.locale)
        return "\(month) '\(year)"
    }

    /// Stable date strings consumed by the sample dossier's parser.
    static func relativeDay(_ date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let y = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: y) { return "Yesterday" }
        if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            return format(date, dateFormat: "MMM d", calendar: calendar)
        }
        return dotted(date, calendar: calendar)
    }

    /// "Nov 12 – 18" or "Oct 29 – Nov 4" for the last 7 local days.
    static func weekRange(endingAt now: Date, calendar: Calendar) -> String {
        let end = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -6, to: end) ?? end
        let sameMonth = calendar.component(.month, from: start) == calendar.component(.month, from: end)
        let tail = sameMonth && AppLanguage.current == .english
            ? format(end, dateFormat: "d", calendar: calendar) : monthDay(end, calendar: calendar)
        return "\(monthDay(start, calendar: calendar)) – \(tail)"
    }
}
