import Foundation

extension WidgetSnapshot {
    /// Collectible cards feed the shelf. Today uses the full listening library when available.
    init(summary: ListeningSummary, cards: [HeadphoneCard], isSample: Bool,
         listening: LibrarySnapshot? = nil, now: Date = Date(), calendar: Calendar = .current) {
        let grid = summary.grid
        let sorted = cards.sorted { $0.lifetimeMinutes > $1.lifetimeMinutes }
        let devices: [(name: String, symbol: String, grid: ListeningGrid)] =
            listening?.devices.map { ($0.nickname, $0.model.resolvedSymbol, $0.grid) }
            ?? sorted.map { ($0.nickname, $0.symbol, $0.grid) }
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
            cards: sorted.map { card in
                Card(id: card.id, nickname: card.nickname, model: card.model, symbol: card.symbol,
                     lifetimeMinutes: card.lifetimeMinutes, weekMinutes: card.grid.totalMinutes(lastDays: 7),
                     sessions: card.sessions, serial: card.serial)
            },
            heatmap: Heatmap(minutes: grid.minutes, decibels: grid.decibels)
        )
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
