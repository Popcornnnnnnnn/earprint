import AppIntents
import Foundation

/// Interactive widget button (iOS 17+): shows the next headphone card in the small "Today" widget.
/// WidgetKit reloads the widget's timeline after `perform()` returns.
struct NextCardIntent: AppIntent {
    static var title: LocalizedStringResource = "Show next card"
    static var description = IntentDescription("Shows the next headphone card in the Earprint widget.")
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        FeaturedCard.index += 1
        return .result()
    }
}
