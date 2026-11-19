import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Which 3D model / illustration a card should use. Raw values are stable (used in the cache and by the 3D card).
enum HeadphoneModelKey: String, Codable, CaseIterable, Sendable {
    case airpods            // AirPods 1, 2 (stem)
    case airpods3           // Shared open-ear artwork for AirPods 3 and 5
    case airpods4           // AirPods 4 and AirPods 4 (ANC), with charging case
    case airpodsPro         // AirPods Pro 1, 2, 3 (tips)
    case airpodsMax         // AirPods Max (all)
    case beatsEarbuds       // Beats in-ear: Studio Buds, Fit Pro, Solo Buds, Flex, X
    case beatsEarhook       // Powerbeats / Powerbeats Pro (ear hook)
    case beatsOverEar       // Beats Solo / Studio headphones
    case earbudsGeneric     // unknown in-ear headphones
    case overEarGeneric     // unknown over-ear headphones, also the final fallback

    /// Artwork used for collectible cards. Unknown and third-party models stay in Health totals.
    var collectibleArtwork: String? {
        switch self {
        case .airpods, .airpods3: "CardRenderAirPodsOpen"
        case .airpods4: "CardRenderAirPods4"
        case .airpodsPro: "CardRenderAirPodsPro"
        case .airpodsMax: "CardRenderAirPodsMax"
        default: nil
        }
    }

    var collectibleModel: String? {
        switch self {
        case .airpodsPro: "AirPodsPro"
        case .airpodsMax: "AirPodsMax"
        default: nil
        }
    }

    /// The 3D model family used by `HeadphoneModelView`.
    var kind: HeadphoneKind {
        switch self {
        case .airpodsMax, .beatsOverEar, .overEarGeneric: .overEar
        case .airpods, .airpods3, .airpods4, .airpodsPro, .earbudsGeneric: .earbuds
        case .beatsEarbuds, .beatsEarhook: .sportBuds
        }
    }

    /// Closest of the five base shapes, for a 3D renderer that only has the basic set.
    var baseShape: HeadphoneModelKey {
        switch self {
        case .airpods, .airpods3, .airpods4: .airpods
        case .airpodsPro: .airpodsPro
        case .airpodsMax: .airpodsMax
        case .beatsEarbuds, .beatsEarhook: .beatsEarbuds
        case .beatsOverEar, .overEarGeneric: .overEarGeneric
        case .earbudsGeneric: .airpods
        }
    }
}

struct HeadphoneModelInfo: Equatable, Sendable {
    /// Apple Bluetooth product ID, e.g. 0x2024. nil when unknown.
    var productID: Int?
    var marketingName: String
    var shortName: String
    var key: HeadphoneModelKey
    /// Preferred SF Symbol; some need iOS 18+.
    var symbol: String
    /// iOS 17-safe fallback symbol.
    var fallbackSymbol: String
    var isApple: Bool

    var productIDText: String? { productID.map { String(format: "0x%04X", $0) } }

    /// The symbol that exists on this OS version.
    var resolvedSymbol: String {
        #if canImport(UIKit)
        UIImage(systemName: symbol) != nil ? symbol : fallbackSymbol
        #else
        fallbackSymbol
        #endif
    }
}

/// Maps HealthKit `HKDevice` fields to a product.
///
/// HealthKit stores the Apple Bluetooth product ID (vendor 0x004C) in `HKDevice.model` as hex text such as
/// "0x2024" — confirmed by the iLEAPP Health parser, which maps the `model` column of `healthdb.sqlite`
/// `source_devices` with this same table, and by a competitor screenshot ("Apple Inc. · 0x2024").
///
/// Sources for the product-ID table (fetched 2026-11-19). Each entry lists the sources that agree:
/// - [I] iLEAPP `scripts/artifacts/health.py` `bluetooth_pid` (cites theapplewiki.com/wiki/Bluetooth_PIDs)
///       https://github.com/abrignoni/iLEAPP/blob/main/scripts/artifacts/health.py
/// - [M] MagicPodsCore `src/sdk/aap/enums/AapModelIds.h`
///       https://github.com/steam3d/MagicPodsCore/blob/master/src/sdk/aap/enums/AapModelIds.h
/// - [O] open-pods `src/devices/apple_models.cpp`
///       https://github.com/JossueE/open-pods/blob/main/src/devices/apple_models.cpp
/// - [T] MacTools `Plugins/DeviceBattery/Sources/AppleHeadphoneSupport.swift`
///       https://github.com/mactools-app/MacTools/blob/main/Plugins/DeviceBattery/Sources/AppleHeadphoneSupport.swift
/// - [S] status-trio `Sources/StatusTrioCore/Audio/AirPodsModel.swift`
///       https://github.com/lingyired/status-trio/blob/main/Sources/StatusTrioCore/Audio/AirPodsModel.swift
/// Entries with only one source are marked "single source" and should be checked against a real device report.
enum HeadphoneModelCatalog {
    private static func entry(_ id: Int, _ name: String, _ short: String, _ key: HeadphoneModelKey,
                              _ symbol: String, _ fallback: String) -> HeadphoneModelInfo {
        HeadphoneModelInfo(productID: id, marketingName: name, shortName: short, key: key,
                           symbol: symbol, fallbackSymbol: fallback, isApple: true)
    }

    static let byProductID: [Int: HeadphoneModelInfo] = {
        let list: [HeadphoneModelInfo] = [
            // AirPods
            entry(0x2002, "AirPods (1st generation)", "AirPods", .airpods, "airpods", "airpods"),            // I M O T S
            entry(0x200F, "AirPods (2nd generation)", "AirPods 2", .airpods, "airpods", "airpods"),          // M O T S
            entry(0x2013, "AirPods (3rd generation)", "AirPods 3", .airpods3, "airpods.gen3", "airpods"),    // I M O T S
            entry(0x2019, "AirPods 4", "AirPods 4", .airpods4, "airpods.gen4", "airpods.gen3"),              // M O T S
            entry(0x201B, "AirPods 4 (ANC)", "AirPods 4 ANC", .airpods4, "airpods.gen4", "airpods.gen3"),   // I M O T S
            entry(0x201C, "AirPods 4", "AirPods 4", .airpods4, "airpods.gen4", "airpods.gen3"),              // T S (variant)
            entry(0x201E, "AirPods 4", "AirPods 4", .airpods4, "airpods.gen4", "airpods.gen3"),              // T S (variant)
            entry(0x2020, "AirPods 4", "AirPods 4", .airpods4, "airpods.gen4", "airpods.gen3"),              // T S (variant)
            entry(0x2030, "AirPods 5", "AirPods 5", .airpods3, "airpods.gen4", "airpods.gen3"),              // M S ("airpods5wcc")
            entry(0x2036, "AirPods 5", "AirPods 5", .airpods3, "airpods.gen4", "airpods.gen3"),              // M S
            // AirPods Pro
            entry(0x200E, "AirPods Pro (1st generation)", "AirPods Pro", .airpodsPro, "airpods.pro", "airpodspro"),         // I M O T S
            entry(0x2014, "AirPods Pro 2 · Lightning", "AirPods Pro 2", .airpodsPro, "airpods.pro", "airpodspro"),          // I M O T S
            entry(0x2024, "AirPods Pro 2 · USB-C", "AirPods Pro 2", .airpodsPro, "airpods.pro", "airpodspro"),              // I M O T S
            entry(0x2027, "AirPods Pro 3", "AirPods Pro 3", .airpodsPro, "airpods.pro", "airpodspro"),                      // M O T S
            entry(0x2028, "AirPods Pro 3", "AirPods Pro 3", .airpodsPro, "airpods.pro", "airpodspro"),                      // S (single source)
            // AirPods Max
            entry(0x200A, "AirPods Max · Lightning", "AirPods Max", .airpodsMax, "airpods.max", "airpodsmax"),              // I M O T S
            entry(0x201F, "AirPods Max · USB-C", "AirPods Max", .airpodsMax, "airpods.max", "airpodsmax"),                  // M O T S
            entry(0x202D, "AirPods Max 2", "AirPods Max 2", .airpodsMax, "airpods.max", "airpodsmax"),                      // M O T S
            // Beats in-ear
            entry(0x2005, "BeatsX", "BeatsX", .beatsEarbuds, "beats.earphones", "beats.earphones"),                         // M O T
            entry(0x2010, "Beats Flex", "Beats Flex", .beatsEarbuds, "beats.earphones", "beats.earphones"),                 // M O T
            entry(0x2011, "Beats Studio Buds", "Studio Buds", .beatsEarbuds, "beats.studiobuds", "beats.earphones"),        // M O T
            entry(0x2012, "Beats Fit Pro", "Fit Pro", .beatsEarbuds, "beats.fitpro", "beats.earphones"),                    // M O T
            entry(0x2016, "Beats Studio Buds +", "Studio Buds +", .beatsEarbuds, "beats.studiobudsplus", "beats.studiobuds"), // I M O T
            entry(0x2026, "Beats Solo Buds", "Solo Buds", .beatsEarbuds, "beats.solobuds", "beats.earphones"),              // M O T
            // Beats ear-hook
            entry(0x2003, "Powerbeats3", "Powerbeats3", .beatsEarhook, "beats.powerbeats3", "beats.powerbeats3"),           // M O T
            entry(0x200D, "Powerbeats (2020)", "Powerbeats", .beatsEarhook, "beats.powerbeats", "beats.powerbeats"),        // M O T ("Powerbeats4")
            entry(0x200B, "Powerbeats Pro", "Powerbeats Pro", .beatsEarhook, "beats.powerbeats.pro", "beats.powerbeatspro"), // M O T
            entry(0x201D, "Powerbeats Pro 2", "Powerbeats Pro 2", .beatsEarhook, "beats.powerbeats.pro.2", "beats.powerbeatspro"), // M O T
            entry(0x202F, "Powerbeats Fit", "Powerbeats Fit", .beatsEarbuds, "beats.fitpro", "beats.earphones"),            // M O
            // Beats over-ear / on-ear
            entry(0x2006, "Beats Solo3", "Solo3", .beatsOverEar, "beats.headphones", "beats.headphones"),                   // M O T
            entry(0x200C, "Beats Solo Pro", "Solo Pro", .beatsOverEar, "beats.headphones", "beats.headphones"),             // M O T
            entry(0x2009, "Beats Studio3", "Studio3", .beatsOverEar, "beats.headphones", "beats.headphones"),               // M O T
            entry(0x2017, "Beats Studio Pro", "Studio Pro", .beatsOverEar, "beats.studio.pro", "beats.headphones"),         // M O T
            entry(0x2025, "Beats Solo 4", "Solo 4", .beatsOverEar, "beats.headphones", "beats.headphones"),                 // M O T
        ]
        return Dictionary(uniqueKeysWithValues: list.map { ($0.productID!, $0) })
    }()

    /// Reads a product ID from text such as "0x2024", "0X200e" or "2024"-style bare hex.
    /// Only accepts the Apple audio range 0x2000–0x20FF for bare hex, to avoid reading version numbers.
    static func productID(from text: String?) -> Int? {
        guard let raw = DeviceDescriptor.clean(text) else { return nil }
        let lower = raw.lowercased()
        if let range = lower.range(of: #"0x[0-9a-f]{1,4}\b"#, options: .regularExpression) {
            return Int(lower[range].dropFirst(2), radix: 16)
        }
        if lower.count == 4, lower.hasPrefix("20"), let value = Int(lower, radix: 16) {
            return value
        }
        return nil
    }

    static func resolve(_ device: DeviceDescriptor?) -> HeadphoneModelInfo {
        guard let device else { return unknownHeadphones }
        let text = [device.model, device.name].compactMap { $0?.lowercased() }.joined(separator: " ")
        let isApple = device.hasCompatibleAppleManufacturer && DeviceDescriptor.clean(device.manufacturer) != nil
        if device.hasCompatibleAppleManufacturer {
            // The model identifiers are vendor-scoped. Other vendors may use the same numbers.
            for field in [device.model, device.hardwareVersion] {
                if let id = productID(from: field) {
                    if let known = byProductID[id] { return known }
                    if isApple { return unknownApple(id: id, name: device.name) }
                }
            }
            if let guess = guess(from: text) { return guess }
        }
        // 3. Unknown: guess the shape from common over-ear words, else in-ear.
        let overEarWords = ["wh-", "headphone", "qc", "quietcomfort", "momentum", "studio", "solo", "max", "over-ear", "xm"]
        let overEar = overEarWords.contains { text.contains($0) } && !text.contains("wf-") && !text.contains("buds")
        return HeadphoneModelInfo(productID: nil,
                                  marketingName: DeviceDescriptor.clean(device.manufacturer).map { "\($0) headphones" } ?? "Headphones",
                                  shortName: "Headphones",
                                  key: overEar ? .overEarGeneric : .earbudsGeneric,
                                  symbol: overEar ? "headphones" : "earbuds",
                                  fallbackSymbol: "headphones",
                                  isApple: isApple)
    }

    static let unknownHeadphones = HeadphoneModelInfo(productID: nil, marketingName: "Headphones", shortName: "Headphones",
                                                      key: .overEarGeneric, symbol: "headphones",
                                                      fallbackSymbol: "headphones", isApple: false)

    private static func unknownApple(id: Int, name: String?) -> HeadphoneModelInfo {
        // A new Apple / Beats product we have not mapped yet: keep the ID visible, guess the shape from the name.
        var info = guess(from: name?.lowercased() ?? "") ?? HeadphoneModelInfo(
            productID: nil, marketingName: "Apple headphones", shortName: "Headphones", key: .earbudsGeneric,
            symbol: "earbuds", fallbackSymbol: "headphones", isApple: true)
        info.productID = id
        info.marketingName += String(format: " · 0x%04X", id)
        return info
    }

    private static func guess(from text: String) -> HeadphoneModelInfo? {
        func make(_ name: String, _ key: HeadphoneModelKey, _ symbol: String, _ fallback: String) -> HeadphoneModelInfo {
            HeadphoneModelInfo(productID: nil, marketingName: name, shortName: name, key: key,
                               symbol: symbol, fallbackSymbol: fallback, isApple: true)
        }
        if text.contains("airpods max") { return make("AirPods Max", .airpodsMax, "airpods.max", "airpodsmax") }
        if text.contains("airpods pro") { return make("AirPods Pro", .airpodsPro, "airpods.pro", "airpodspro") }
        if text.contains("airpods") { return make("AirPods", .airpods, "airpods", "airpods") }
        if text.contains("powerbeats") { return make("Powerbeats", .beatsEarhook, "beats.powerbeats", "beats.powerbeats") }
        if text.contains("beats") {
            if text.contains("solo") && !text.contains("buds") || text.contains("studio3") || text.contains("studio pro") {
                return make("Beats headphones", .beatsOverEar, "beats.headphones", "beats.headphones")
            }
            return make("Beats earbuds", .beatsEarbuds, "beats.earphones", "beats.earphones")
        }
        return nil
    }
}
