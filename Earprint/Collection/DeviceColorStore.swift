import SwiftUI
import UIKit

/// Selectable hardware finish for an Apple/Beats headphone model that ships in multiple retail colors.
struct DeviceColorOption: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let swatchTop: Color
    let swatchBottom: Color
    /// Optional asset name in `Assets.xcassets` used on the outside of cards.
    let cardAssetName: String?
    /// Material colors applied to the live 3D model inside `CardDetail`.
    let shellRGB: (Double, Double, Double)
    let accentRGB: (Double, Double, Double)
    let cushionRGB: (Double, Double, Double)
    let metallic: Float
    let roughness: Float

    var modelFinish: HeadphoneFinish {
        HeadphoneFinish(
            shell: UIColor(red: shellRGB.0, green: shellRGB.1, blue: shellRGB.2, alpha: 1),
            accent: UIColor(red: accentRGB.0, green: accentRGB.1, blue: accentRGB.2, alpha: 1),
            cushion: UIColor(red: cushionRGB.0, green: cushionRGB.1, blue: cushionRGB.2, alpha: 1),
            metallic: metallic,
            roughness: roughness
        )
    }

    static func == (lhs: DeviceColorOption, rhs: DeviceColorOption) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // MARK: - AirPods Max (All 10 official Apple finishes)

    static let airPodsMaxFinishes: [DeviceColorOption] = [
        // 2024 USB-C
        DeviceColorOption(
            id: "apm.midnight", title: "Midnight",
            swatchTop: Color(red: 0.16, green: 0.19, blue: 0.25), swatchBottom: Color(red: 0.08, green: 0.10, blue: 0.14),
            cardAssetName: "IconCutoutMidnight",
            shellRGB: (0.11, 0.13, 0.18), accentRGB: (0.15, 0.17, 0.22), cushionRGB: (0.09, 0.10, 0.13),
            metallic: 0.88, roughness: 0.32
        ),
        DeviceColorOption(
            id: "apm.starlight", title: "Starlight",
            swatchTop: Color(red: 0.90, green: 0.86, blue: 0.78), swatchBottom: Color(red: 0.78, green: 0.74, blue: 0.65),
            cardAssetName: "IconCutoutStarlight",
            shellRGB: (0.86, 0.82, 0.74), accentRGB: (0.90, 0.87, 0.80), cushionRGB: (0.80, 0.76, 0.68),
            metallic: 0.84, roughness: 0.30
        ),
        DeviceColorOption(
            id: "apm.blue", title: "Blue",
            swatchTop: Color(red: 0.34, green: 0.47, blue: 0.62), swatchBottom: Color(red: 0.22, green: 0.32, blue: 0.45),
            cardAssetName: "IconCutoutBlue",
            shellRGB: (0.28, 0.41, 0.56), accentRGB: (0.34, 0.46, 0.60), cushionRGB: (0.22, 0.31, 0.44),
            metallic: 0.86, roughness: 0.32
        ),
        DeviceColorOption(
            id: "apm.purple", title: "Purple",
            swatchTop: Color(red: 0.76, green: 0.66, blue: 0.80), swatchBottom: Color(red: 0.56, green: 0.46, blue: 0.60),
            cardAssetName: "IconCutoutPurple",
            shellRGB: (0.70, 0.60, 0.75), accentRGB: (0.76, 0.68, 0.80), cushionRGB: (0.52, 0.43, 0.57),
            metallic: 0.84, roughness: 0.32
        ),
        DeviceColorOption(
            id: "apm.orange", title: "Orange",
            swatchTop: Color(red: 0.94, green: 0.54, blue: 0.36), swatchBottom: Color(red: 0.82, green: 0.38, blue: 0.22),
            cardAssetName: "IconCutoutOrange",
            shellRGB: (0.90, 0.48, 0.30), accentRGB: (0.94, 0.58, 0.40), cushionRGB: (0.78, 0.38, 0.22),
            metallic: 0.84, roughness: 0.32
        ),
        // 2020 Lightning
        DeviceColorOption(
            id: "apm.spaceGray", title: "Space Gray",
            swatchTop: Color(red: 0.46, green: 0.47, blue: 0.50), swatchBottom: Color(red: 0.27, green: 0.28, blue: 0.30),
            cardAssetName: "IconCutoutSpaceGray",
            shellRGB: (0.36, 0.37, 0.40), accentRGB: (0.26, 0.27, 0.29), cushionRGB: (0.16, 0.16, 0.18),
            metallic: 0.88, roughness: 0.32
        ),
        DeviceColorOption(
            id: "apm.silver", title: "Silver",
            swatchTop: Color(red: 0.92, green: 0.93, blue: 0.95), swatchBottom: Color(red: 0.75, green: 0.77, blue: 0.80),
            cardAssetName: "IconCutoutSilver",
            shellRGB: (0.88, 0.89, 0.91), accentRGB: (0.94, 0.94, 0.96), cushionRGB: (0.86, 0.87, 0.89),
            metallic: 0.88, roughness: 0.28
        ),
        DeviceColorOption(
            id: "apm.skyBlue", title: "Sky Blue",
            swatchTop: Color(red: 0.66, green: 0.79, blue: 0.88), swatchBottom: Color(red: 0.48, green: 0.62, blue: 0.74),
            cardAssetName: "IconCutoutSkyBlue",
            shellRGB: (0.58, 0.73, 0.85), accentRGB: (0.74, 0.84, 0.91), cushionRGB: (0.48, 0.61, 0.73),
            metallic: 0.86, roughness: 0.30
        ),
        DeviceColorOption(
            id: "apm.green", title: "Green",
            swatchTop: Color(red: 0.73, green: 0.82, blue: 0.70), swatchBottom: Color(red: 0.55, green: 0.65, blue: 0.53),
            cardAssetName: "IconCutoutGreen",
            shellRGB: (0.67, 0.77, 0.64), accentRGB: (0.77, 0.84, 0.74), cushionRGB: (0.55, 0.65, 0.53),
            metallic: 0.84, roughness: 0.32
        ),
        DeviceColorOption(
            id: "apm.pink", title: "Pink",
            swatchTop: Color(red: 0.92, green: 0.51, blue: 0.48), swatchBottom: Color(red: 0.78, green: 0.36, blue: 0.34),
            cardAssetName: "IconCutoutPink",
            shellRGB: (0.89, 0.44, 0.42), accentRGB: (0.93, 0.56, 0.53), cushionRGB: (0.76, 0.36, 0.35),
            metallic: 0.84, roughness: 0.32
        ),
    ]

    // MARK: - Beats In-Ear (Beats Fit Pro / Studio Buds / Powerbeats)

    static let beatsEarbudFinishes: [DeviceColorOption] = [
        DeviceColorOption(
            id: "beats.black", title: "Beats Black",
            swatchTop: Color(red: 0.22, green: 0.22, blue: 0.24), swatchBottom: Color(red: 0.08, green: 0.08, blue: 0.10),
            cardAssetName: "CardRenderBeatsFitBlack",
            shellRGB: (0.11, 0.11, 0.13), accentRGB: (0.28, 0.28, 0.30), cushionRGB: (0.16, 0.16, 0.18),
            metallic: 0.18, roughness: 0.48
        ),
        DeviceColorOption(
            id: "beats.white", title: "Beats White",
            swatchTop: Color(red: 0.96, green: 0.96, blue: 0.98), swatchBottom: Color(red: 0.82, green: 0.83, blue: 0.86),
            cardAssetName: "CardRenderBeatsFitWhite",
            shellRGB: (0.93, 0.94, 0.95), accentRGB: (0.82, 0.83, 0.86), cushionRGB: (0.88, 0.89, 0.91),
            metallic: 0.08, roughness: 0.28
        ),
        DeviceColorOption(
            id: "beats.sageGray", title: "Sage Gray",
            swatchTop: Color(red: 0.72, green: 0.76, blue: 0.72), swatchBottom: Color(red: 0.52, green: 0.56, blue: 0.53),
            cardAssetName: "CardRenderBeatsFitSageGray",
            shellRGB: (0.64, 0.68, 0.64), accentRGB: (0.50, 0.54, 0.51), cushionRGB: (0.56, 0.60, 0.57),
            metallic: 0.14, roughness: 0.46
        ),
        DeviceColorOption(
            id: "beats.stonePurple", title: "Stone Purple",
            swatchTop: Color(red: 0.74, green: 0.68, blue: 0.82), swatchBottom: Color(red: 0.54, green: 0.48, blue: 0.64),
            cardAssetName: "CardRenderBeatsFitStonePurple",
            shellRGB: (0.67, 0.61, 0.76), accentRGB: (0.52, 0.46, 0.62), cushionRGB: (0.58, 0.52, 0.67),
            metallic: 0.14, roughness: 0.46
        ),
        DeviceColorOption(
            id: "beats.tidalBlue", title: "Tidal Blue",
            swatchTop: Color(red: 0.28, green: 0.52, blue: 0.78), swatchBottom: Color(red: 0.14, green: 0.30, blue: 0.52),
            cardAssetName: "CardRenderBeatsFitTidalBlue",
            shellRGB: (0.20, 0.42, 0.68), accentRGB: (0.14, 0.30, 0.52), cushionRGB: (0.16, 0.35, 0.58),
            metallic: 0.18, roughness: 0.42
        ),
        DeviceColorOption(
            id: "beats.coralPink", title: "Coral Pink",
            swatchTop: Color(red: 0.94, green: 0.54, blue: 0.55), swatchBottom: Color(red: 0.78, green: 0.34, blue: 0.36),
            cardAssetName: "CardRenderBeatsFitCoralPink",
            shellRGB: (0.89, 0.45, 0.46), accentRGB: (0.74, 0.32, 0.34), cushionRGB: (0.80, 0.38, 0.39),
            metallic: 0.14, roughness: 0.44
        ),
    ]

    // MARK: - Beats Over-Ear (Studio Pro / Solo 4)

    static let beatsOverEarFinishes: [DeviceColorOption] = [
        DeviceColorOption(
            id: "beatsOE.black", title: "Black",
            swatchTop: Color(red: 0.22, green: 0.22, blue: 0.24), swatchBottom: Color(red: 0.08, green: 0.08, blue: 0.10),
            cardAssetName: "IconCutoutMidnight",
            shellRGB: (0.11, 0.11, 0.13), accentRGB: (0.18, 0.18, 0.20), cushionRGB: (0.10, 0.10, 0.12),
            metallic: 0.35, roughness: 0.45
        ),
        DeviceColorOption(
            id: "beatsOE.sandstone", title: "Sandstone",
            swatchTop: Color(red: 0.86, green: 0.82, blue: 0.76), swatchBottom: Color(red: 0.70, green: 0.65, blue: 0.59),
            cardAssetName: "IconCutoutStarlight",
            shellRGB: (0.80, 0.76, 0.70), accentRGB: (0.85, 0.81, 0.76), cushionRGB: (0.72, 0.68, 0.62),
            metallic: 0.25, roughness: 0.48
        ),
        DeviceColorOption(
            id: "beatsOE.navy", title: "Navy",
            swatchTop: Color(red: 0.26, green: 0.36, blue: 0.52), swatchBottom: Color(red: 0.14, green: 0.22, blue: 0.36),
            cardAssetName: "IconCutoutBlue",
            shellRGB: (0.18, 0.28, 0.44), accentRGB: (0.24, 0.34, 0.50), cushionRGB: (0.14, 0.22, 0.36),
            metallic: 0.30, roughness: 0.46
        ),
        DeviceColorOption(
            id: "beatsOE.cloudPink", title: "Cloud Pink",
            swatchTop: Color(red: 0.90, green: 0.68, blue: 0.72), swatchBottom: Color(red: 0.76, green: 0.50, blue: 0.55),
            cardAssetName: "IconCutoutPink",
            shellRGB: (0.86, 0.62, 0.66), accentRGB: (0.90, 0.68, 0.72), cushionRGB: (0.74, 0.52, 0.56),
            metallic: 0.25, roughness: 0.46
        ),
    ]

    /// Available retail color choices for a device model. Empty when the hardware only comes in one color (e.g. AirPods / AirPods Pro).
    static func options(for modelKey: HeadphoneModelKey) -> [DeviceColorOption] {
        switch modelKey {
        case .airpodsMax:
            return airPodsMaxFinishes
        case .beatsEarbuds, .beatsEarhook:
            return beatsEarbudFinishes
        case .beatsOverEar:
            return beatsOverEarFinishes
        case .airpods, .airpods3, .airpods4, .airpodsPro, .earbudsGeneric, .overEarGeneric:
            return []
        }
    }

    static func defaultOption(for modelKey: HeadphoneModelKey) -> DeviceColorOption? {
        switch modelKey {
        case .airpodsMax:
            return airPodsMaxFinishes.first { $0.id == "apm.spaceGray" } ?? airPodsMaxFinishes.first
        case .beatsEarbuds, .beatsEarhook:
            return beatsEarbudFinishes.first
        case .beatsOverEar:
            return beatsOverEarFinishes.first
        default:
            return nil
        }
    }
}

/// Persists each headphone card's user-chosen hardware color (synced across Collection cards and 3D detail).
@MainActor
@Observable
final class DeviceColorStore {
    private static let storageKey = "earprint.deviceColors.v1"

    private let defaults: UserDefaults
    private(set) var selections: [String: String]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.selections = defaults.dictionary(forKey: Self.storageKey) as? [String: String] ?? [:]
    }

    func availableColors(for card: HeadphoneCard) -> [DeviceColorOption] {
        DeviceColorOption.options(for: card.modelKey)
    }

    func selectedColor(for card: HeadphoneCard) -> DeviceColorOption? {
        let options = availableColors(for: card)
        guard !options.isEmpty else { return nil }
        for id in [card.id] + card.aliasIDs {
            if let savedID = selections[id], let match = options.first(where: { $0.id == savedID }) {
                return match
            }
        }
        return DeviceColorOption.defaultOption(for: card.modelKey) ?? options.first
    }

    func select(_ color: DeviceColorOption, for card: HeadphoneCard) {
        selections[card.id] = color.id
        defaults.set(selections, forKey: Self.storageKey)
    }
}
