import SwiftUI

/// Routes `earprint://` URLs (from widgets and the Live Activity) to a tab and, for cards, a card id.
@Observable
final class DeepLinkRouter {
    enum Tab: Hashable { case collection, rings, probe }

    var tab: Tab = .collection
    /// Card to open in the Collection tab. The Collection view clears it after opening.
    var pendingCardID: String?

    func handle(_ url: URL) {
        guard let route = EarprintLink.route(for: url) else { return }
        switch route {
        case .card(let id):
            tab = .collection
            pendingCardID = id
        case .collection: tab = .collection
        case .rings: tab = .rings
        case .probe: tab = .probe
        }
    }
}
