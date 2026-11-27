import Foundation

extension WidgetSnapshot {
    /// Active cards feed the Card Shelf while `allCards` and `listening` keep lifetime & weekly breakdown totals intact.
    init(summary: ListeningSummary, cards: [HeadphoneCard], allCards: [HeadphoneCard]? = nil,
         isSample: Bool, listening: LibrarySnapshot? = nil, now: Date = Date(), calendar: Calendar = .current) {
        let grid = summary.grid
        let shelfSorted = cards.sorted { $0.lifetimeMinutes > $1.lifetimeMinutes }
        let fullCards = allCards ?? cards
        let breakdownCards = Self.buildWeeklyBreakdown(fullCards: fullCards, listening: listening)
        let totalLifetime = listening.map { $0.lifetimeSeconds / 60 }
            ?? fullCards.reduce(0) { $0 + $1.lifetimeMinutes }
        let devices: [(name: String, symbol: String, grid: ListeningGrid)] =
            listening?.devices.map { ($0.nickname, $0.model.resolvedSymbol, $0.grid) }
            ?? fullCards.map { ($0.nickname, $0.symbol, $0.grid) }
        let todayDevices = devices.compactMap { device -> (name: String, symbol: String, minutes: Double, energy: Double)? in
            let minutes = device.grid.totalMinutes(lastDays: 1)
            guard minutes > 0 else { return nil }
            let decibels = device.grid.averageDecibels(lastDays: 1)
            return (device.name, device.symbol, minutes, pow(10, decibels / 10) * minutes)
        }
        let combinedMinutes = todayDevices.reduce(0) { $0 + $1.minutes }
        let todayMinutes = combinedMinutes > 0 ? combinedMinutes : grid.totalMinutes(lastDays: 1)
        let todayDB: Double? = if combinedMinutes > 0 {
            10 * log10(todayDevices.reduce(0) { $0 + $1.energy } / combinedMinutes)
        } else {
            todayMinutes > 0 ? grid.averageDecibels(lastDays: 1) : nil
        }
        let activeTodayDevice = todayDevices.max { $0.minutes < $1.minutes }
        let weekDB = summary.weekMinutes > 0 ? summary.weekDecibels : nil

        self.init(
            generatedAt: now,
            isSample: isSample,
            day: calendar.startOfDay(for: now),
            today: Today(minutes: todayMinutes,
                         decibels: todayDB,
                         deviceName: todayMinutes > 0 ? (activeTodayDevice?.name ?? summary.deviceName) : nil,
                         deviceSymbol: activeTodayDevice?.symbol ?? summary.deviceSymbol),
            week: Week(minutes: summary.weekMinutes, budgetUsed: summary.weeklyBudgetUsed,
                       decibels: weekDB, label: summary.periodLabel),
            cards: shelfSorted.map(Self.widgetCard(from:)),
            heatmap: Heatmap(minutes: grid.minutes, decibels: grid.decibels),
            totalLifetimeMinutes: totalLifetime,
            weeklyBreakdown: breakdownCards
        )
    }

    @MainActor
    static func forApp(
        summary: ListeningSummary,
        allCards: [HeadphoneCard],
        lifecycleStore: DeviceLifecycleStore,
        isSample: Bool,
        listening: LibrarySnapshot? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> WidgetSnapshot {
        let shelfCards = allCards.filter { !lifecycleStore.isRetired($0) }
        return WidgetSnapshot(
            summary: summary,
            cards: shelfCards,
            allCards: allCards,
            isSample: isSample,
            listening: listening,
            now: now,
            calendar: calendar
        )
    }

    private static func widgetCard(from card: HeadphoneCard) -> Card {
        Card(
            id: card.id,
            nickname: card.nickname,
            model: card.model,
            symbol: card.symbol,
            lifetimeMinutes: card.lifetimeMinutes,
            weekMinutes: card.grid.totalMinutes(lastDays: 7),
            sessions: card.sessions,
            serial: card.serial
        )
    }

    private static func buildWeeklyBreakdown(fullCards: [HeadphoneCard], listening: LibrarySnapshot?) -> [Card] {
        var result = fullCards.map(widgetCard(from:))
        if let listening {
            for device in listening.devices where device.weekSeconds > 0 {
                let alreadyIncluded = fullCards.contains { card in
                    card.matches(id: device.id) || device.aliasIDs.contains(where: { card.matches(id: $0) })
                }
                if !alreadyIncluded {
                    result.append(
                        Card(
                            id: device.id,
                            nickname: device.nickname,
                            model: device.model.marketingName,
                            symbol: device.model.resolvedSymbol,
                            lifetimeMinutes: device.lifetimeSeconds / 60,
                            weekMinutes: device.weekSeconds / 60,
                            sessions: device.sessionCount,
                            serial: listening.sourceSerials[device.id] ?? 0
                        )
                    )
                }
            }
        }
        return result.sorted {
            if $0.weekMinutes != $1.weekMinutes { return $0.weekMinutes > $1.weekMinutes }
            return $0.lifetimeMinutes > $1.lifetimeMinutes
        }
    }

    static func sample(now: Date = Date()) -> WidgetSnapshot {
        WidgetSnapshot(summary: SampleData.summary, cards: SampleCards.all, isSample: true, now: now)
    }
}

enum WidgetPublisher {
    /// Writes the snapshot to the App Group and reloads widgets if it changed.
    static func publish(_ snapshot: WidgetSnapshot) {
        do {
            let changed = try WidgetSnapshotStore.save(snapshot)
            #if DEBUG
            print("[Widgets] snapshot \(changed ? "written" : "unchanged") at \(WidgetSnapshotStore.fileURL?.path ?? "-")")
            #endif
        } catch {
            print("[Widgets] could not write snapshot: \(error)")
        }
    }

    /// Placeholder until real HealthKit data is wired in.
    static func publishSample() { publish(.sample()) }
}
