import SwiftUI

/// Routes `earprint://` URLs (from widgets and the Live Activity) to a tab and, for cards, a card id.
@Observable
final class DeepLinkRouter {
    enum Tab: Hashable { case collection, rings }

    #if DEBUG
    enum DeveloperScreen: Hashable, Identifiable {
        case tools, probe

        var id: Self { self }
    }

    var developerScreen: DeveloperScreen?
    #endif

    var tab: Tab = .collection
    /// Card to open in the Collection tab. The Collection view clears it after opening.
    var pendingCardID: String?
    /// Opens the 2026 Wrapped story when requested by `earprint://wrapped`.
    var pendingWrapped = false

    func handle(_ url: URL) {
        guard let route = EarprintLink.route(for: url) else { return }
        switch route {
        case .card(let id):
            tab = .collection
            pendingCardID = id
        case .collection: tab = .collection
        case .rings: tab = .rings
        case .wrapped:
            tab = .rings
            pendingWrapped = true
        case .probe:
            #if DEBUG
            developerScreen = .probe
            #else
            break
            #endif
        }
    }
}
