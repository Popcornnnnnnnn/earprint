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
            weeklyBudget: HearingBudget.dose(energy: window.weekEnergy)
        )
    }

    struct GridWindow {
        var grid: ListeningGrid
        var weekSeconds: Double
        var weekEnergy: Double
    }

    /// Buckets 15-minute slots into local day × hour cells using the calendar's *current* time zone.
    /// DST: the repeated autumn hour adds into the same hour cell; the skipped spring hour stays empty.
    static func gridWindow(slots: [Int: SlotTotals], now: Date, calendar: Calendar, days: Int) -> GridWindow {
        var seconds = Array(repeating: Array(repeating: 0.0, count: 24), count: days)
        var energy = seconds
        let today = calendar.startOfDay(for: now)
        let firstDay = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        var weekSeconds = 0.0, weekEnergy = 0.0
        var dayCache: [Date: Int] = [:]

        for (index, slot) in slots where slot.seconds > 0 {
            let start = Date(timeIntervalSince1970: Double(index) * ListeningAggregate.slotLength)
            guard start >= firstDay, start <= now else { continue }
            let dayStart = calendar.startOfDay(for: start)
            let day: Int
            if let cached = dayCache[dayStart] {
                day = cached
            } else {
                day = calendar.dateComponents([.day], from: firstDay, to: dayStart).day ?? -1
                dayCache[dayStart] = day
            }
            guard day >= 0, day < days else { continue }
            let hour = calendar.component(.hour, from: start)
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
            combined.sessions.insert(start: span.start, end: span.end, gap: ListeningAggregate.sessionGap)
        }
        return combined
    }
}

// MARK: - Mapping to the existing view models

extension LibrarySnapshot {
    func cards(now: Date = Date(), calendar: Calendar = .current) -> [HeadphoneCard] {
        // Keep the first accessory's existing serial after merging its aliases.
        return devices.compactMap { d in
            guard d.model.key.collectibleArtwork != nil else { return nil }
            return HeadphoneCard(
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
                aliasIDs: d.aliasIDs
            )
        }
    }

    func homeSummary(now: Date = Date(), calendar: Calendar = .current) -> ListeningSummary? {
        guard let d = primary else { return nil }
        return ListeningSummary(
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
}

enum DateText {
    static func formatter(_ template: String, calendar: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = template
        return f
    }

    /// "2026.10.30"
    static func dotted(_ date: Date, calendar: Calendar) -> String {
        formatter("yyyy.MM.dd", calendar: calendar).string(from: date)
    }

    /// "Oct 30"
    static func monthDay(_ date: Date, calendar: Calendar) -> String {
        let format = DateFormatter()
        format.calendar = calendar
        format.timeZone = calendar.timeZone
        format.locale = AppLanguage.current.locale
        format.setLocalizedDateFormatFromTemplate("MMM d")
        return format.string(from: date)
    }

    /// Stable date strings consumed by the sample dossier's parser.
    static func relativeDay(_ date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let y = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: y) { return "Yesterday" }
        if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            return formatter("MMM d", calendar: calendar).string(from: date)
        }
        return dotted(date, calendar: calendar)
    }

    /// "Nov 12 – 18" or "Oct 29 – Nov 4" for the last 7 local days.
    static func weekRange(endingAt now: Date, calendar: Calendar) -> String {
        let end = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -6, to: end) ?? end
        let sameMonth = calendar.component(.month, from: start) == calendar.component(.month, from: end)
        let tail = sameMonth && AppLanguage.current == .english
            ? formatter("d", calendar: calendar).string(from: end) : monthDay(end, calendar: calendar)
        return "\(monthDay(start, calendar: calendar)) – \(tail)"
    }
}
