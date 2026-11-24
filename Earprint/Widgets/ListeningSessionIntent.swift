import AppIntents
import Foundation

@available(iOS 18.0, *)
struct StartListeningSessionIntent: LiveActivityIntent {
    enum SessionError: LocalizedError {
        case proRequired
        case startFailed(String)

        var errorDescription: String? {
            switch self {
            case .proRequired:
                return String(localized: "Earprint Pro is required to start a Live Listening Session.")
            case .startFailed(let message):
                return message
            }
        }
    }

    static var title: LocalizedStringResource = "Start Listening Session"
    static var description = IntentDescription("Starts an Earprint listening session on the Lock Screen and Dynamic Island.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let store = ProEntitlementStore(autoStart: false)
        await store.refreshEntitlements()
        guard store.isUnlocked(.liveActivity) else {
            throw SessionError.proRequired
        }

        let snapshot = WidgetSnapshotStore.load()
        let monitor = ActiveAudioRouteMonitor()
        let activeName = monitor.activeOutputNames.first

        let matchedCard: WidgetSnapshot.Card? = if let activeName, let cards = snapshot?.cards {
            cards.first {
                ActiveAudioRouteMonitor.matches(
                    cardNickname: $0.nickname,
                    cardModel: $0.model,
                    activeOutputNames: [activeName]
                )
            }
        } else {
            nil
        }

        let deviceName = matchedCard?.nickname ?? activeName ?? String(localized: "Headphones")
        let symbol = matchedCard?.symbol ?? "headphones"
        let cardID = matchedCard?.id ?? "headphones"

        let started = LiveActivityController.shared.start(
            deviceName: deviceName,
            symbol: symbol,
            cardID: cardID,
            decibels: 0
        )
        if !started {
            let reason = LiveActivityController.shared.lastError ?? String(localized: "Unable to start Live Activity.")
            throw SessionError.startFailed(reason)
        }
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
        await LiveActivityController.shared.stopAndWait(manual: true)
        return .result()
    }
}
