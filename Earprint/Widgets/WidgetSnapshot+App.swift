import Foundation

// App-side producer for `WidgetSnapshot`.
// Today the snapshot is built from sample data. The HealthKit pipeline should replace
// `WidgetSnapshot.sample()` with its own builder and call `WidgetPublisher.publish(_:)`
// after each refresh (see docs/WIDGETS.md).

extension WidgetSnapshot {
    /// Builds a snapshot from the app's models. Works for sample data and for real data alike.
    init(summary: ListeningSummary, cards: [HeadphoneCard], isSample: Bool, now: Date = Date(), calendar: Calendar = .current) {
        let grid = summary.grid
        let todayMinutes = grid.minutes.last?.reduce(0, +) ?? 0
        let todayDB = todayMinutes > 0 ? grid.averageDecibels(lastDays: 1) : nil
        let sorted = cards.sorted { $0.lifetimeMinutes > $1.lifetimeMinutes }
        let todayCard = sorted.max { $0.grid.totalMinutes(lastDays: 1) < $1.grid.totalMinutes(lastDays: 1) }
        let weekDB = summary.weekMinutes > 0 ? summary.weekDecibels : nil

        self.init(
            generatedAt: now,
            isSample: isSample,
            day: calendar.startOfDay(for: now),
            today: Today(minutes: todayMinutes,
                         decibels: todayDB,
                         deviceName: todayMinutes > 0 ? (todayCard?.nickname ?? summary.deviceName) : nil,
                         deviceSymbol: todayCard?.symbol ?? "airpodspro"),
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
