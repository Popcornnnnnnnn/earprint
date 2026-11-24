import AVFoundation
import Foundation

/// Watches the active iOS audio output route to detect whether one of the user's headphones
/// is currently connected/worn — using public `AVAudioSession` APIs with zero extra permissions.
@MainActor
@Observable
final class ActiveAudioRouteMonitor {
    private(set) var activeOutputNames: [String] = []
    @ObservationIgnored var onRouteChange: (([String]) -> Void)?
    @ObservationIgnored nonisolated(unsafe) private var observer: NSObjectProtocol?
    private let readOutputNames: () -> [String]

    /// Debug-only override (`-activeCard <id>`) so Simulator previews can demonstrate the active indicator.
    private let debugActiveCardID: String?

    convenience init() {
        self.init(readOutputNames: Self.currentHeadphoneOutputNames)
    }

    init(readOutputNames: @escaping () -> [String]) {
        self.readOutputNames = readOutputNames
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-activeCard"), idx + 1 < args.count {
            self.debugActiveCardID = args[idx + 1]
        } else {
            self.debugActiveCardID = nil
        }
        #else
        self.debugActiveCardID = nil
        #endif

        refresh()
        observer = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func refresh() {
        let names = readOutputNames()
        guard activeOutputNames != names else { return }
        activeOutputNames = names
        onRouteChange?(names)
    }

    private static func currentHeadphoneOutputNames() -> [String] {
        let headphonePorts: Set<AVAudioSession.Port> = [
            .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .headphones, .usbAudio
        ]
        return AVAudioSession.sharedInstance().currentRoute.outputs
            .filter { headphonePorts.contains($0.portType) }
            .map(\.portName)
    }

    func activeMatchedCard(in cards: [HeadphoneCard]) -> HeadphoneCard? {
        if let debugActiveCardID, let debugCard = cards.first(where: { $0.id == debugActiveCardID }) {
            return debugCard
        }
        guard !activeOutputNames.isEmpty else { return nil }
        let outputs = activeOutputNames.map(Self.normalize).filter { !$0.isEmpty }
        guard !outputs.isEmpty else { return nil }

        // 1. Prefer exact normalized nickname or model match before any substring heuristic.
        if let exact = cards.first(where: { card in
            let nick = Self.normalize(card.nickname)
            let model = Self.normalize(card.model)
            return outputs.contains { output in
                (!nick.isEmpty && output == nick) || (!model.isEmpty && output == model)
            }
        }) {
            return exact
        }

        // 2. Use substring matching only when a single card matches unambiguously.
        let partial = cards.filter { card in
            let nick = Self.normalize(card.nickname)
            guard !nick.isEmpty else { return false }
            return outputs.contains { $0.contains(nick) || nick.contains($0) }
        }
        return partial.count == 1 ? partial.first : nil
    }

    func isCurrentlyWorn(_ card: HeadphoneCard) -> Bool {
        if let debugActiveCardID, card.id == debugActiveCardID {
            return true
        }
        return Self.matches(cardNickname: card.nickname, cardModel: card.model, activeOutputNames: activeOutputNames)
    }

    nonisolated static func matches(cardNickname: String, cardModel: String, activeOutputNames: [String]) -> Bool {
        guard !activeOutputNames.isEmpty else { return false }
        let nick = normalize(cardNickname)
        let model = normalize(cardModel)
        for rawOutput in activeOutputNames {
            let output = normalize(rawOutput)
            guard !output.isEmpty else { continue }
            if !nick.isEmpty && (output == nick || output.contains(nick) || nick.contains(output)) {
                return true
            }
            if !model.isEmpty && output == model {
                return true
            }
        }
        return false
    }

    nonisolated private static func normalize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
