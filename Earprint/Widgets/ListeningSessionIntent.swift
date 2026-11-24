import AppIntents
import Foundation

@available(iOS 18.0, *)
struct StartListeningSessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Start Listening Session"
    static var description = IntentDescription("Starts an Earprint listening session on the Lock Screen and Dynamic Island.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let card = WidgetSnapshotStore.load()?.topCard
        LiveActivityController.shared.start(
            deviceName: card?.nickname ?? String(localized: "Headphones"),
            symbol: card?.symbol ?? "headphones",
            cardID: card?.id ?? "unknown"
        )
        return .result()
    }
}

@available(iOS 18.0, *)
struct ResetListeningRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Reset Listening Rest Timer"
    static var description = IntentDescription("Restarts the break countdown for the current Earprint listening session.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        await LiveActivityController.shared.resetRestAndWait()
        return .result()
    }
}

@available(iOS 18.0, *)
struct StopListeningSessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Listening Session"
    static var description = IntentDescription("Ends the current Earprint listening session.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        await LiveActivityController.shared.stopAndWait()
        return .result()
    }
}
