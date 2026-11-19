import SwiftUI
import WidgetKit

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    /// Card shown in the small widget (cycled by `NextCardIntent`).
    let featured: WidgetSnapshot.Card?
    /// True when the app has not written a snapshot yet and we show built-in sample data.
    let isFallback: Bool
}

/// Reads `WidgetSnapshot` from the App Group. The app reloads timelines whenever it writes a new one;
/// we also refresh hourly and at midnight so "today" resets even if the app is not opened.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        entry(at: Date(), snapshot: .preview, isFallback: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        if context.isPreview {
            completion(entry(at: Date(), snapshot: WidgetSnapshotStore.load() ?? .preview, isFallback: true))
        } else {
            completion(currentEntry(at: Date()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let now = Date()
        var entries = [currentEntry(at: now)]
        let calendar = Calendar.current
        if let midnight = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) {
            entries.append(currentEntry(at: midnight))
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(60 * 60))))
    }

    private func currentEntry(at date: Date) -> SnapshotEntry {
        if let stored = WidgetSnapshotStore.load() {
            return entry(at: date, snapshot: stored, isFallback: false)
        }
        return entry(at: date, snapshot: .preview, isFallback: true)
    }

    private func entry(at date: Date, snapshot: WidgetSnapshot, isFallback: Bool) -> SnapshotEntry {
        SnapshotEntry(date: date, snapshot: snapshot, featured: FeaturedCard.card(in: snapshot), isFallback: isFallback)
    }
}
