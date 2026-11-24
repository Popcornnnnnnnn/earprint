import Foundation
import Observation

struct CardCustomization: Codable, Equatable, Hashable, Sendable {
    var proFoil: ProFoilStyle? = nil
    var engravedTitle = ""
    var customSerial = ""

    var sanitized: Self {
        Self(proFoil: proFoil,
             engravedTitle: Self.clean(engravedTitle, limit: 24),
             customSerial: Self.clean(customSerial, limit: 16))
    }

    private static func clean(_ value: String, limit: Int) -> String {
        let singleLine = value.components(separatedBy: .newlines).joined(separator: " ")
        return String(singleLine.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor @Observable
final class SlabCustomizationStore {
    static let shared = SlabCustomizationStore()

    private static let storageKey = "earprint.slabCustomizations"
    private let defaults: UserDefaults
    private var entries: [String: CardCustomization]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let stored = try? JSONDecoder().decode([String: CardCustomization].self, from: data) {
            entries = stored.mapValues(\.sanitized)
        } else {
            entries = [:]
        }
    }

    func customization(for cardID: String) -> CardCustomization {
        entries[cardID] ?? CardCustomization()
    }

    func update(cardID: String, customization: CardCustomization) {
        let value = customization.sanitized
        if value == CardCustomization() {
            reset(cardID: cardID)
        } else {
            entries[cardID] = value
            persist()
        }
    }

    func reset(cardID: String) {
        guard entries.removeValue(forKey: cardID) != nil else { return }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
