import SwiftUI
import Vision
import XCTest
@testable import Earprint

final class DossierShareOptionsTests: XCTestCase {
    func testDefaultStateAndResetBehavior() {
        var options = DossierShareOptions.default
        XCTAssertTrue(options.simple.isDefault)
        XCTAssertTrue(options.long.isDefault)
        XCTAssertEqual(options.long.effectivePages, [.cover, .rhythm, .habits, .certificate])

        options.simple.showGrade = false
        options.simple.showTierSummary = false
        XCTAssertFalse(options.simple.isDefault)
        options.simple.reset()
        XCTAssertTrue(options.simple.isDefault)
        XCTAssertEqual(options.simple, DossierShareOptions.Simple.default)

        options.long.includeCertificatePage = false
        options.long.showHardwareID = false
        XCTAssertFalse(options.long.isDefault)
        options.long.reset()
        XCTAssertTrue(options.long.isDefault)
        XCTAssertEqual(options.long, DossierShareOptions.Long.default)
    }

    func testLongPageGuardrailNeverLeavesZeroPages() {
        var long = DossierShareOptions.Long.default
        long.setPage(.rhythm, included: false)
        long.setPage(.habits, included: false)
        long.setPage(.certificate, included: false)

        XCTAssertEqual(long.effectivePages, [.cover])
        XCTAssertFalse(long.canTogglePage(.cover))
        XCTAssertTrue(long.canTogglePage(.rhythm))

        // Attempting to turn off the sole remaining page must be ignored.
        long.setPage(.cover, included: false)
        XCTAssertEqual(long.effectivePages, [.cover])
        XCTAssertTrue(long.includeCoverPage)

        // Enabling another page unlocks toggling cover off.
        long.setPage(.habits, included: true)
        XCTAssertTrue(long.canTogglePage(.cover))
        long.setPage(.cover, included: false)
        XCTAssertEqual(long.effectivePages, [.habits])
    }

    func testLongPerPageSectionGuardrailsKeepAtLeastOneSection() {
        var long = DossierShareOptions.Long.default

        long.setRhythmSection(.periodSummary, shown: false)
        long.setRhythmSection(.trendChart, shown: false)
        XCTAssertFalse(long.canToggleRhythmSection(.dayClock))
        long.setRhythmSection(.dayClock, shown: false)
        XCTAssertTrue(long.showDayClock)

        long.setHabitsSection(.wearHabits, shown: false)
        long.setHabitsSection(.hearingHealth, shown: false)
        XCTAssertFalse(long.canToggleHabitsSection(.gradeBreakdown))
        long.setHabitsSection(.gradeBreakdown, shown: false)
        XCTAssertTrue(long.showGradeBreakdown)

        long.setCertificateSection(.certificate, shown: false)
        XCTAssertFalse(long.canToggleCertificateSection(.milestones))
        long.setCertificateSection(.milestones, shown: false)
        XCTAssertTrue(long.showMilestones)
    }

    @MainActor
    func testSimpleShareImageOmitsHiddenFieldsAndRestoresDefaultOnReset() throws {
        let card = SampleCards.all[0]
        let dossier = DeviceDossier.sample(for: card)
        let color = DeviceColorOption.defaultOption(for: card.modelKey)
        let locale = Locale(identifier: "en")

        var options = DossierShareOptions.default
        let defaultPages = DossierShareRenderer.renderPages(
            card: card,
            dossier: dossier,
            period: .month,
            color: color,
            isSampleData: false,
            format: .simple,
            options: options,
            scheme: .dark,
            locale: locale,
            scale: 2
        )
        XCTAssertEqual(defaultPages.count, 1)
        let defaultText = try recognizeNormalizedText(fromPNG: defaultPages[0].pngData)
        XCTAssertTrue(defaultText.contains("grade"), "Expected grade in default Simple OCR: \(defaultText)")
        XCTAssertTrue(defaultText.contains(dossier.grade.label.lowercased()))
        XCTAssertTrue(defaultText.contains(dossier.hardware.productID.lowercased()))
        XCTAssertTrue(defaultText.contains("sessions"))
        XCTAssertTrue(defaultText.contains("longest"))
        XCTAssertTrue(defaultText.contains("avg level"))
        XCTAssertTrue(defaultText.contains("first wear"))
        XCTAssertTrue(defaultText.contains("record days"))

        options.simple.showGrade = false
        options.simple.showHardwareID = false
        options.simple.showRing = false
        options.simple.showSessions = false
        options.simple.showFirstWear = false
        options.simple.showTierSummary = false

        let customPages = DossierShareRenderer.renderPages(
            card: card,
            dossier: dossier,
            period: .month,
            color: color,
            isSampleData: false,
            format: .simple,
            options: options,
            scheme: .dark,
            locale: locale,
            scale: 3
        )
        XCTAssertEqual(customPages.count, 1)
        XCTAssertNotEqual(customPages[0].pngData, defaultPages[0].pngData)

        let customText = try recognizeNormalizedText(fromPNG: customPages[0].pngData)
        XCTAssertFalse(customText.contains("grade"), "Hidden grade appeared in OCR: \(customText)")
        XCTAssertFalse(customText.contains(dossier.grade.label.lowercased()), "Hidden grade label appeared in OCR: \(customText)")
        XCTAssertFalse(customText.contains(dossier.hardware.productID.lowercased()), "Hidden productID appeared in OCR: \(customText)")
        XCTAssertFalse(customText.contains("sessions"), "Hidden sessions appeared in OCR: \(customText)")
        XCTAssertFalse(customText.contains("first wear"), "Hidden first wear appeared in OCR: \(customText)")
        XCTAssertFalse(customText.contains(card.firstMet.lowercased()), "Hidden firstMet date appeared in OCR: \(customText)")
        XCTAssertFalse(customText.contains("record days"), "Hidden tier summary appeared in OCR: \(customText)")
        XCTAssertFalse(customText.contains("4 weeks"), "Hidden ring appeared in OCR: \(customText)")
        XCTAssertTrue(customText.contains("longest"))
        XCTAssertTrue(customText.contains("avg level"))

        var onlySessionsAndRing = DossierShareOptions.default
        onlySessionsAndRing.simple.showLongestWear = false
        onlySessionsAndRing.simple.showAverageLevel = false
        let hiddenMetricsPages = DossierShareRenderer.renderPages(
            card: card,
            dossier: dossier,
            period: .month,
            color: color,
            isSampleData: false,
            format: .simple,
            options: onlySessionsAndRing,
            scheme: .dark,
            locale: locale,
            scale: 3
        )
        let hiddenMetricsText = try recognizeNormalizedText(fromPNG: hiddenMetricsPages[0].pngData)
        XCTAssertFalse(hiddenMetricsText.contains("longest"))
        XCTAssertFalse(hiddenMetricsText.contains("avg level"))
        XCTAssertTrue(hiddenMetricsText.contains("sessions"))
        XCTAssertTrue(hiddenMetricsText.contains("first wear"))

        options.simple.reset()
        let resetPages = DossierShareRenderer.renderPages(
            card: card,
            dossier: dossier,
            period: .month,
            color: color,
            isSampleData: false,
            format: .simple,
            options: options,
            scheme: .dark,
            locale: locale,
            scale: 2
        )
        let resetText = try recognizeNormalizedText(fromPNG: resetPages[0].pngData)
        XCTAssertTrue(resetText.contains("grade"))
        XCTAssertTrue(resetText.contains(dossier.hardware.productID.lowercased()))
        XCTAssertTrue(resetText.contains("sessions"))
        XCTAssertTrue(resetText.contains("first wear"))
        XCTAssertTrue(resetText.contains("record days"))
    }

    @MainActor
    func testLongShareImagesOmitHiddenPagesAndSectionsAndRestoreDefaultOnReset() throws {
        let card = SampleCards.all[0]
        let dossier = DeviceDossier.sample(for: card)
        let color = DeviceColorOption.defaultOption(for: card.modelKey)
        let locale = Locale(identifier: "en")

        var options = DossierShareOptions.default
        let defaultPages = DossierShareRenderer.renderPages(
            card: card,
            dossier: dossier,
            period: .month,
            color: color,
            isSampleData: false,
            format: .long,
            options: options,
            scheme: .dark,
            locale: locale,
            scale: 3
        )
        XCTAssertEqual(defaultPages.count, 4)
        let defaultTexts = try defaultPages.map { try recognizeNormalizedText(fromPNG: $0.pngData) }
        XCTAssertTrue(defaultTexts[0].contains("ear grade"), "Missing ear grade on Page 1: \(defaultTexts[0])")
        XCTAssertTrue(defaultTexts[0].contains(dossier.hardware.productID.lowercased()))
        XCTAssertTrue(defaultTexts[1].contains("when you wear it"), "Missing when you wear it on Page 2: \(defaultTexts[1])")
        XCTAssertTrue(defaultTexts[1].contains("24-hour clock"), "Missing 24-hour clock on Page 2: \(defaultTexts[1])")
        XCTAssertTrue(defaultTexts[2].contains("how it's graded"))
        XCTAssertTrue(defaultTexts[3].contains("milestones"), "Missing milestones on Page 4: \(defaultTexts[3])")
        XCTAssertTrue(defaultTexts[3].contains("source bundle"), "Missing source bundle on Page 4: \(defaultTexts[3])")

        options.long.includeCertificatePage = false
        options.long.showGrade = false
        options.long.showHardwareID = false
        options.long.showFirstWear = false
        options.long.showDayClock = false
        options.long.showGradeBreakdown = false

        let customPages = DossierShareRenderer.renderPages(
            card: card,
            dossier: dossier,
            period: .month,
            color: color,
            isSampleData: false,
            format: .long,
            options: options,
            scheme: .dark,
            locale: locale,
            scale: 3
        )
        XCTAssertEqual(customPages.count, 3)
        XCTAssertTrue(customPages[0].fileStem.hasSuffix("-01-Cover"))
        XCTAssertTrue(customPages[1].fileStem.hasSuffix("-02-Rhythm"))
        XCTAssertTrue(customPages[2].fileStem.hasSuffix("-03-Habits"))

        let customJoined = try customPages.map { try recognizeNormalizedText(fromPNG: $0.pngData) }.joined(separator: "\n")
        XCTAssertFalse(customJoined.contains("ear grade"), "Hidden grade appeared in Long OCR: \(customJoined)")
        XCTAssertFalse(customJoined.contains(dossier.hardware.productID.lowercased()), "Hidden productID appeared in Long OCR: \(customJoined)")
        XCTAssertFalse(customJoined.contains("first wear"), "Hidden first wear appeared in Long OCR: \(customJoined)")
        XCTAssertFalse(customJoined.contains(card.firstMet.lowercased()), "Hidden firstMet date appeared in Long OCR: \(customJoined)")
        XCTAssertFalse(customJoined.contains("since"), "Hidden 'since' first-wear date appeared in Long OCR: \(customJoined)")
        XCTAssertFalse(customJoined.contains("minted"), "Hidden 'minted' marker/footer appeared in Long OCR: \(customJoined)")
        XCTAssertFalse(customJoined.contains("24-hour clock"), "Hidden clock appeared in Long OCR: \(customJoined)")
        XCTAssertFalse(customJoined.contains("how it's graded"), "Hidden grade breakdown appeared in Long OCR: \(customJoined)")
        XCTAssertFalse(customJoined.contains("source bundle"), "Hidden certificate page appeared in Long OCR: \(customJoined)")

        // Verify Page 4 (Certificate) customization directly when kept enabled.
        var page4Custom = DossierShareOptions.default
        page4Custom.long.includeCoverPage = false
        page4Custom.long.includeRhythmPage = false
        page4Custom.long.includeHabitsPage = false
        page4Custom.long.showGrade = false
        page4Custom.long.showHardwareID = false
        page4Custom.long.showFirstWear = false
        page4Custom.long.showSourceMetadata = false
        let certOnlyCustom = DossierShareRenderer.renderPages(
            card: card,
            dossier: dossier,
            period: .month,
            color: color,
            isSampleData: false,
            format: .long,
            options: page4Custom,
            scheme: .dark,
            locale: locale,
            scale: 3
        )
        XCTAssertEqual(certOnlyCustom.count, 1)
        let certCustomText = try recognizeNormalizedText(fromPNG: certOnlyCustom[0].pngData)
        XCTAssertFalse(certCustomText.contains("ear grade"))
        XCTAssertFalse(certCustomText.contains(dossier.hardware.productID.lowercased()))
        XCTAssertFalse(certCustomText.contains("source bundle"))
        XCTAssertFalse(certCustomText.contains("minted"))
        XCTAssertTrue(certCustomText.contains("milestones"))

        page4Custom.long.showMilestones = false
        let certWithoutMilestones = DossierShareRenderer.renderPages(
            card: card,
            dossier: dossier,
            period: .month,
            color: color,
            isSampleData: false,
            format: .long,
            options: page4Custom,
            scheme: .dark,
            locale: locale,
            scale: 3
        )
        let certWithoutMilestonesText = try recognizeNormalizedText(fromPNG: certWithoutMilestones[0].pngData)
        XCTAssertFalse(certWithoutMilestonesText.contains("milestones"))
        XCTAssertTrue(certWithoutMilestonesText.contains("earprint grading authority"))

        page4Custom.long.showCertificate = false
        page4Custom.long.showMilestones = true
        let milestonesOnly = DossierShareRenderer.renderPages(
            card: card,
            dossier: dossier,
            period: .month,
            color: color,
            isSampleData: false,
            format: .long,
            options: page4Custom,
            scheme: .dark,
            locale: locale,
            scale: 3
        )
        let milestonesOnlyText = try recognizeNormalizedText(fromPNG: milestonesOnly[0].pngData)
        XCTAssertFalse(milestonesOnlyText.contains("earprint grading authority"))
        XCTAssertTrue(milestonesOnlyText.contains("milestones"))

        options.long.reset()
        let resetPages = DossierShareRenderer.renderPages(
            card: card,
            dossier: dossier,
            period: .month,
            color: color,
            isSampleData: false,
            format: .long,
            options: options,
            scheme: .dark,
            locale: locale,
            scale: 3
        )
        XCTAssertEqual(resetPages.count, 4)
        let resetTexts = try resetPages.map { try recognizeNormalizedText(fromPNG: $0.pngData) }
        XCTAssertTrue(resetTexts[0].contains("ear grade"))
        XCTAssertTrue(resetTexts[0].contains(dossier.hardware.productID.lowercased()))
        XCTAssertTrue(resetTexts[1].contains("when you wear it"))
        XCTAssertTrue(resetTexts[1].contains("24-hour clock"))
        XCTAssertTrue(resetTexts[3].contains("milestones"))
        XCTAssertTrue(resetTexts[3].contains("source bundle"))

        if let outDir = ProcessInfo.processInfo.environment["EARPRINT_DOSSIER_SHARE_SNAPSHOT_DIR"] {
            let dirURL = URL(fileURLWithPath: outDir, isDirectory: true)
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

            for (label, scheme) in [("dark", ColorScheme.dark), ("light", ColorScheme.light)] {
                let sDef = DossierShareRenderer.renderPages(
                    card: card, dossier: dossier, period: .month, color: color,
                    isSampleData: false, format: .simple, options: .default,
                    scheme: scheme, locale: locale, scale: 2
                )
                try sDef.first?.pngData.write(to: dirURL.appendingPathComponent("simple-default-\(label).png"))

                var sMin = DossierShareOptions.default
                sMin.simple.showGrade = false
                sMin.simple.showHardwareID = false
                sMin.simple.showRing = false
                sMin.simple.showSessions = false
                sMin.simple.showFirstWear = false
                sMin.simple.showTierSummary = false
                let sCustom = DossierShareRenderer.renderPages(
                    card: card, dossier: dossier, period: .month, color: color,
                    isSampleData: false, format: .simple, options: sMin,
                    scheme: scheme, locale: locale, scale: 2
                )
                try sCustom.first?.pngData.write(to: dirURL.appendingPathComponent("simple-custom-\(label).png"))

                let lDef = DossierShareRenderer.renderPages(
                    card: card, dossier: dossier, period: .month, color: color,
                    isSampleData: false, format: .long, options: .default,
                    scheme: scheme, locale: locale, scale: 2
                )
                for p in lDef {
                    try p.pngData.write(to: dirURL.appendingPathComponent("long-default-\(label)-\(p.id + 1).png"))
                }

                var lCustomOpts = DossierShareOptions.default
                lCustomOpts.long.showGrade = false
                lCustomOpts.long.showHardwareID = false
                lCustomOpts.long.showSourceMetadata = false
                lCustomOpts.long.showDayClock = false
                lCustomOpts.long.showWearHabits = false
                let lCustom = DossierShareRenderer.renderPages(
                    card: card, dossier: dossier, period: .month, color: color,
                    isSampleData: false, format: .long, options: lCustomOpts,
                    scheme: scheme, locale: locale, scale: 2
                )
                for p in lCustom {
                    try p.pngData.write(to: dirURL.appendingPathComponent("long-custom-\(label)-\(p.id + 1).png"))
                }
            }
        }
    }

    private func recognizeNormalizedText(fromPNG data: Data) throws -> String {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else {
            XCTFail("Expected valid PNG image")
            return ""
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        let joined = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
        return joined
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: " -", with: "-")
            .replacingOccurrences(of: "- ", with: "-")
            .lowercased()
    }
}
