import Foundation

/// Plain copy of the `HKDevice` fields we care about, so identity and naming are testable without HealthKit.
///
/// What iOS writes for headphones (from the iLEAPP `healthdb.sqlite` `source_devices` parser and a competitor screenshot):
/// - `name`: the user's Bluetooth nickname, e.g. "🧸's AirPods Pro" (can change when the user renames the AirPods).
/// - `manufacturer`: "Apple Inc." for Apple / Beats; often nil or a vendor string for third-party headphones.
/// - `model`: the Apple Bluetooth product ID as hex text, e.g. "0x2024".
/// - `localIdentifier`: a per-accessory Bluetooth identifier, often with a "-tacl" suffix. Stable across renames.
struct DeviceDescriptor: Codable, Hashable, Sendable {
    var name: String?
    var manufacturer: String?
    var model: String?
    var hardwareVersion: String?
    var firmwareVersion: String?
    var softwareVersion: String?
    var localIdentifier: String?
    var udiDeviceIdentifier: String?

    init(name: String? = nil, manufacturer: String? = nil, model: String? = nil, hardwareVersion: String? = nil,
         firmwareVersion: String? = nil, softwareVersion: String? = nil, localIdentifier: String? = nil,
         udiDeviceIdentifier: String? = nil) {
        self.name = name
        self.manufacturer = manufacturer
        self.model = model
        self.hardwareVersion = hardwareVersion
        self.firmwareVersion = firmwareVersion
        self.softwareVersion = softwareVersion
        self.localIdentifier = localIdentifier
        self.udiDeviceIdentifier = udiDeviceIdentifier
    }

    /// Key for "same physical device". The local identifier survives nickname changes; the name-based
    /// fallback is only used when HealthKit gives no identifier (then a rename makes a new card).
    var identityKey: String {
        if let id = Self.clean(localIdentifier) {
            let lower = id.lowercased()
            return "lid:" + (lower.hasSuffix("-tacl") ? String(lower.dropLast(5)) : lower)
        }
        if let udi = Self.clean(udiDeviceIdentifier) {
            return "udi:" + udi
        }
        return "nm:" + [name, manufacturer, model].map { Self.clean($0) ?? "-" }.joined(separator: "|")
    }

    /// True when the "device" is the phone, watch, iPad or Mac itself rather than a headphone.
    /// This happens when another app writes samples with `HKDevice.local()` or with no headphone info.
    var isHostDevice: Bool {
        let fields = [model, hardwareVersion, name].compactMap { $0?.lowercased() }
        let hostPrefixes = ["iphone", "ipad", "ipod", "watch", "apple watch", "mac"]
        for field in fields {
            // "iPhone15,2", "Watch6,1", "iPhone" — but not "MacBook's AirPods".
            if hostPrefixes.contains(where: { field == $0 || field.hasPrefix($0 + " ") || Self.isHardwareCode(field, prefix: $0) }) {
                return true
            }
        }
        return false
    }

    /// HealthKit may omit the vendor or use Apple's Bluetooth company identifier.
    var hasCompatibleAppleManufacturer: Bool {
        guard let manufacturer = Self.clean(manufacturer)?.lowercased() else { return true }
        return manufacturer == "apple" || manufacturer == "apple inc." || manufacturer == "apple inc"
            || (manufacturer.hasPrefix("0x") && Int(manufacturer.dropFirst(2), radix: 16) == 0x004c)
    }

    var displayName: String {
        Self.clean(name) ?? HeadphoneModelCatalog.resolve(self).marketingName
    }

    static func clean(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty,
              trimmed != "__NONE__" else { return nil }
        return trimmed
    }

    /// "iphone15,2" / "watch6,1" style hardware codes.
    private static func isHardwareCode(_ field: String, prefix: String) -> Bool {
        guard field.hasPrefix(prefix) else { return false }
        let rest = field.dropFirst(prefix.count)
        return !rest.isEmpty && rest.allSatisfy { $0.isNumber || $0 == "," }
    }
}
