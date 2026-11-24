import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct ArchiveExportFile: Identifiable, Transferable, Sendable {
    let url: URL

    var id: URL { url }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { file in
            SentTransferredFile(file.url)
        }
        .exportingCondition { $0.url.pathExtension == "csv" }
        FileRepresentation(exportedContentType: .json) { file in
            SentTransferredFile(file.url)
        }
        .exportingCondition { $0.url.pathExtension == "json" }
    }
}

enum ArchiveExporter {
    enum Format: String, CaseIterable, Identifiable, Sendable {
        case csv, json

        var id: Self { self }
    }

    struct Archive: Codable, Equatable, Sendable {
        struct Device: Codable, Equatable, Sendable {
            let id: String
            let cardID: String?
            let name: String
            let model: String
            let sampleCount: Int
            let seconds: Double
            let averageDecibels: Double?
            let daily: [Int: Double]
            /// Session bounds use Unix time in seconds. Daily totals use local YYYYMMDD keys.
            let sessions: [SessionSet.Span]
        }

        let schemaVersion: Int
        let exportedAt: Date
        let devices: [Device]
    }

    static func archive(aggregate: ListeningAggregate, cards: [HeadphoneCard], now: Date = Date()) -> Archive {
        let devices = aggregate.devices.values.sorted { $0.key < $1.key }.map { device in
            let card = cards.first { $0.matches(id: device.key) }
            let model = HeadphoneModelCatalog.resolve(device.descriptor)
            return Archive.Device(
                id: device.key, cardID: card?.id,
                name: card?.nickname ?? DeviceDescriptor.clean(device.descriptor?.name) ?? model.shortName,
                model: card?.model ?? model.marketingName,
                sampleCount: device.sampleCount, seconds: device.seconds, averageDecibels: device.averageDecibels,
                daily: device.daily, sessions: device.sessions.spans
            )
        }
        return Archive(schemaVersion: 1, exportedAt: now, devices: devices)
    }

    static func csv(aggregate: ListeningAggregate, cards: [HeadphoneCard]) -> Data {
        let archive = archive(aggregate: aggregate, cards: cards)
        let date = ISO8601DateFormatter()
        date.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var result = "type,device_id,device_name,device_model,day,start_utc,end_utc,listening_seconds,average_decibels,peak_decibels\r\n"
        for device in archive.devices {
            let identity = [device.id, device.name, device.model]
            for (day, seconds) in device.daily.sorted(by: { $0.key < $1.key }) {
                result += csvRow(["daily"] + identity + [String(day), "", "", String(seconds), "", ""])
            }
            for span in device.sessions {
                let start = date.string(from: Date(timeIntervalSince1970: span.start))
                let end = date.string(from: Date(timeIntervalSince1970: span.end))
                let average = span.averageDecibels.map { String($0) } ?? ""
                let peak = span.energy > 0 ? String(span.peakDecibels) : ""
                result += csvRow(["session"] + identity + ["", start, end, String(span.effectiveSeconds), average, peak])
            }
        }
        return Data(result.utf8)
    }

    static func json(aggregate: ListeningAggregate, cards: [HeadphoneCard], now: Date = Date()) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(archive(aggregate: aggregate, cards: cards, now: now))
    }

    static func export(
        _ format: Format,
        aggregate: ListeningAggregate,
        cards: [HeadphoneCard],
        directory: URL = FileManager.default.temporaryDirectory
    ) throws -> ArchiveExportFile {
        let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let data = switch format {
        case .csv: csv(aggregate: aggregate, cards: cards)
        case .json: try json(aggregate: aggregate, cards: cards)
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("Earprint-Listening-Archive").appendingPathExtension(format.rawValue)
        do {
            try data.write(to: url, options: .atomic)
            return ArchiveExportFile(url: url)
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }

    private static func csvRow(_ fields: [String]) -> String {
        fields.map { value in
            guard value.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return value }
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }.joined(separator: ",") + "\r\n"
    }
}
