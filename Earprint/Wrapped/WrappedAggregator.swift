import Foundation

// Both types contain only value data. Their declarations are shared with the v1.0 views.
extension HeadphoneCard: @unchecked Sendable {}
extension ListeningSummary.Persona: @unchecked Sendable {}

typealias ListeningPersona = ListeningSummary.Persona

struct WrappedSummary: Equatable, Sendable {
    let year: Int
    let totalMinutes: Double
    let totalSessions: Int
    let activeDays: Int
    let topDeviceName: String
    let topDeviceModel: String
    let topDeviceKey: HeadphoneModelKey
    let topDeviceSymbol: String
    let topDeviceMinutes: Double
    let topCard: HeadphoneCard?
    let peakMonth: Int?
    let peakMonthMinutes: Double
    let longestStreakDays: Int
    let averageDecibels: Double
    let persona: ListeningPersona
    let whoSafeWeeksCount: Int

    var isThinData: Bool { totalMinutes < 300 || activeDays < 3 }

    static func sample(year: Int = 2026) -> WrappedSummary {
        WrappedAggregator.sample(year: year)
    }
}

enum WrappedAggregator {
    static func summarize(
        aggregate: ListeningAggregate,
        cards: [HeadphoneCard],
        year: Int = 2026,
        calendar inputCalendar: Calendar = .current
    ) -> WrappedSummary {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = inputCalendar.timeZone
        calendar.firstWeekday = inputCalendar.firstWeekday
        calendar.minimumDaysInFirstWeek = inputCalendar.minimumDaysInFirstWeek
        let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1))
        let end = start.flatMap { calendar.date(byAdding: .year, value: 1, to: $0) }

        let cardsByID = cards.sorted { $0.id < $1.id }
        let groupedDevices = Dictionary(grouping: aggregate.devices.values.sorted { $0.key < $1.key }) { device in
            cardsByID.first { $0.matches(id: device.key) }?.id ?? device.key
        }
        var topDevice: DeviceAccumulator?
        var topCard: HeadphoneCard?
        var topSeconds = 0.0
        var daily: [Int: Double] = [:]
        var sessionCount = 0
        var energy = 0.0
        var measuredSeconds = 0.0
        var hours = Array(repeating: 0.0, count: 24)
        var weekEnergy: [Date: Double] = [:]
        if let start, let end {
            for device in aggregate.devices.values {
                for span in device.sessions.spans where span.duration > 0 && span.energy > 0 {
                    var cursor = Date(timeIntervalSince1970: span.start)
                    let stop = Date(timeIntervalSince1970: span.end)
                    while cursor < stop, let week = calendar.dateInterval(of: .weekOfYear, for: cursor) {
                        let next = min(stop, week.end)
                        let fraction = next.timeIntervalSince(cursor) / span.duration
                        if week.start >= start && week.end <= end {
                            weekEnergy[week.start, default: 0] += span.energy * fraction
                        }
                        cursor = next
                    }
                }
            }
        }

        for key in groupedDevices.keys.sorted() {
            guard let devices = groupedDevices[key], let firstDevice = devices.first else { continue }
            var groupSeconds = 0.0
            var spans: [SessionSet.Span] = []
            var groupHasSpans = false
            for device in devices {
                if !device.sessions.spans.isEmpty { groupHasSpans = true }
                spans.append(contentsOf: device.sessions.spans)
            }
            if !groupHasSpans {
                for device in devices {
                    for (day, seconds) in device.daily.sorted(by: { $0.key < $1.key })
                    where day / 10_000 == year && seconds > 0 && seconds.isFinite {
                        daily[day, default: 0] += seconds
                        groupSeconds += seconds
                    }
                }
            }
            if groupSeconds > topSeconds, !groupHasSpans {
                topCard = cardsByID.first { $0.id == key }
                topDevice = devices.max { $0.descriptorDate < $1.descriptorDate } ?? firstDevice
                topSeconds = groupSeconds
            }
            guard let start, let end else { continue }
            var sessions = SessionSet()
            for span in spans.sorted(by: { $0.start < $1.start }) where span.duration > 0 {
                let lower = max(start.timeIntervalSince1970, span.start)
                let upper = min(end.timeIntervalSince1970, span.end)
                guard lower < upper else { continue }
                let share = (upper - lower) / span.duration
                sessions.insert(start: lower, end: upper, gap: ListeningAggregate.sessionGap,
                                listeningSeconds: span.effectiveSeconds * share, energy: span.energy * share)
                // Derive Gregorian daily buckets from session timestamps so non-Gregorian
                // system calendars never lose year keys.
                var dayCursor = Date(timeIntervalSince1970: lower)
                let stop = Date(timeIntervalSince1970: upper)
                while dayCursor < stop, let dayInterval = calendar.dateInterval(of: .day, for: dayCursor) {
                    let next = min(stop, dayInterval.end)
                    let fraction = next.timeIntervalSince(dayCursor) / span.duration
                    let pieceSeconds = span.effectiveSeconds * fraction
                    let comps = calendar.dateComponents([.year, .month, .day], from: dayInterval.start)
                    let dayKey = (comps.year ?? 0) * 10_000 + (comps.month ?? 0) * 100 + (comps.day ?? 0)
                    daily[dayKey, default: 0] += pieceSeconds
                    groupSeconds += pieceSeconds
                    dayCursor = next
                }
                var cursor = Date(timeIntervalSince1970: lower)
                while cursor < stop, let hour = calendar.dateInterval(of: .hour, for: cursor) {
                    let next = min(stop, hour.end)
                    let fraction = next.timeIntervalSince(cursor) / span.duration
                    hours[calendar.component(.hour, from: cursor)] += span.effectiveSeconds * fraction
                    cursor = next
                }
                if span.energy > 0 {
                    energy += span.energy * share
                    measuredSeconds += span.effectiveSeconds * share
                }
            }
            if groupHasSpans, groupSeconds > topSeconds {
                topCard = cardsByID.first { $0.id == key }
                topDevice = devices.max { $0.descriptorDate < $1.descriptorDate } ?? firstDevice
                topSeconds = groupSeconds
            }
            sessionCount += sessions.count
        }

        var months: [Int: Double] = [:]
        var previous: Date?
        var streak = 0
        var longest = 0
        var totalSeconds = 0.0
        for (key, seconds) in daily.sorted(by: { $0.key < $1.key }) {
            let month = key / 100 % 100
            months[month, default: 0] += seconds
            totalSeconds += seconds
            guard let day = calendar.date(from: DateComponents(year: year, month: month, day: key % 100)) else { continue }
            let nextDay = previous.flatMap { calendar.date(byAdding: .day, value: 1, to: $0) }
            streak = day == nextDay ? streak + 1 : 1
            longest = max(longest, streak)
            previous = day
        }
        let peak = months.sorted { ($0.value, -$0.key) > ($1.value, -$1.key) }.first
        let model = HeadphoneModelCatalog.resolve(topDevice?.descriptor)
        let persona = ListeningSummary(
            deviceName: "", deviceModel: "", periodLabel: "",
            grid: ListeningGrid(minutes: [hours.map { $0 / 60 }], decibels: []),
            lifetimeMinutes: 0, sessions: 0, averageSessionMinutes: 0, longestSessionMinutes: 0, firstUse: ""
        ).persona
        return WrappedSummary(
            year: year, totalMinutes: totalSeconds / 60, totalSessions: sessionCount, activeDays: daily.count,
            topDeviceName: topCard?.nickname ?? DeviceDescriptor.clean(topDevice?.descriptor?.name) ?? model.shortName,
            topDeviceModel: topCard?.model ?? model.marketingName, topDeviceKey: topCard?.modelKey ?? model.key,
            topDeviceSymbol: topCard?.symbol ?? model.resolvedSymbol, topDeviceMinutes: topSeconds / 60, topCard: topCard,
            peakMonth: peak?.key, peakMonthMinutes: (peak?.value ?? 0) / 60, longestStreakDays: longest,
            averageDecibels: HearingBudget.averageDecibels(energy: energy, seconds: measuredSeconds) ?? 0,
            persona: persona, whoSafeWeeksCount: weekEnergy.values.filter { HearingBudget.dose(energy: $0) <= 1 }.count
        )
    }

    static func sample(year: Int = 2026) -> WrappedSummary {
        var card = SampleCards.all[0]
        card.nickname = "Studio Headphones"
        card.model = "Over-ear headphones"
        card.symbol = "headphones"
        card.modelKey = .overEarGeneric
        card.kind = .overEar
        return WrappedSummary(
            year: year, totalMinutes: 14_870, totalSessions: 351, activeDays: 186,
            topDeviceName: card.nickname, topDeviceModel: card.model, topDeviceKey: card.modelKey,
            topDeviceSymbol: card.symbol, topDeviceMinutes: 11_302, topCard: card,
            peakMonth: 10, peakMonthMinutes: 1_860, longestStreakDays: 17, averageDecibels: 64,
            persona: .commuter(0.38), whoSafeWeeksCount: 35
        )
    }
}
