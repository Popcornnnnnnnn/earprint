import Foundation
import SwiftUI

enum EarprintReleasePolicy {
    /// All v1.1 capabilities ship 100% free while growing the initial user base.
    /// Flip to `true` in a future release to re-enable StoreKit Pro and Tip Jar paywall UI.
    static let monetizationEnabled = false
}

/// Original software-only Pro capabilities introduced in Earprint v1.1.0.
/// Strictly excludes third-party hardware trademarks or existing v1.0 core viewing.
enum ProFeature: String, CaseIterable, Identifiable, Sendable {
    case wrappedVideo
    case foilShaders
    case slabEngraving
    case export4K
    case archiveExport
    case liveActivity

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .wrappedVideo: "2026 Wrapped 3D Video"
        case .foilShaders: "4 Procedural Foil Finishes"
        case .slabEngraving: "Custom Slab Engraving"
        case .export4K: "Watermark-Free High-Res Posters"
        case .archiveExport: "Multi-Year CSV & JSON Archive"
        case .liveActivity: "Dynamic Island Session"
        }
    }

    var subtitleKey: LocalizedStringKey {
        switch self {
        case .wrappedVideo: "Export a 6-second 1080p spinning 3D card reel or animated GIF."
        case .foilShaders: "Gold Bullion, Obsidian Prism, Sakura Pearl, and Raw Titanium slabs."
        case .slabEngraving: "Personalize your collector slab title, serial tag, and accent rim."
        case .export4K: "Render ultra-crisp 2100×2800 Dossier posters without footer marks."
        case .archiveExport: "Back up your complete multi-year listening history locally."
        case .liveActivity: "Keep live loudness and rest countdowns on your Lock Screen."
        }
    }

    var systemImage: String {
        switch self {
        case .wrappedVideo: "film.stack"
        case .foilShaders: "sparkles"
        case .slabEngraving: "signature"
        case .export4K: "arrow.up.left.and.arrow.down.right.rectangle"
        case .archiveExport: "tray.and.arrow.up"
        case .liveActivity: "waveform.badge.magnifyingglass"
        }
    }
}

/// Shared contract implemented by `ProEntitlementStore` (WT2) and consumed across features (WT1/WT3).
@MainActor
protocol ProEntitlementProviding: AnyObject {
    var hasPro: Bool { get }
    var isGrandfathered: Bool { get }
    func isUnlocked(_ feature: ProFeature) -> Bool
}

extension ProEntitlementProviding {
    func isUnlocked(_ feature: ProFeature) -> Bool {
        hasPro || isGrandfathered
    }
}

/// Value snapshot propagated through SwiftUI `@Environment(\.proAccess)` so previews and
/// isolated worktree builds compile and react cleanly without cross-worktree coupling.
struct ProAccessSnapshot: Equatable, Sendable {
    var hasPro: Bool
    var isGrandfathered: Bool

    static let free = ProAccessSnapshot(hasPro: false, isGrandfathered: false)
    static let allUnlocked = ProAccessSnapshot(hasPro: true, isGrandfathered: true)

    func isUnlocked(_ feature: ProFeature) -> Bool {
        hasPro || isGrandfathered
    }
}

private struct ProAccessEnvironmentKey: EnvironmentKey {
    static let defaultValue = ProAccessSnapshot.free
}

extension EnvironmentValues {
    var proAccess: ProAccessSnapshot {
        get { self[ProAccessEnvironmentKey.self] }
        set { self[ProAccessEnvironmentKey.self] = newValue }
    }
}

extension Notification.Name {
    /// Posted when any feature asks to present `PaywallView`, optionally passing a `ProFeature` in
    /// `object` and `userInfo["feature"]`.
    static let earprintRequestPaywall = Notification.Name("com.popcornnn.earprint.requestPaywall")
}

enum ProPaywallRequester {
    @MainActor
    static func request(feature: ProFeature? = nil) {
        NotificationCenter.default.post(
            name: .earprintRequestPaywall,
            object: feature,
            userInfo: feature.map { ["feature": $0] }
        )
    }
}
