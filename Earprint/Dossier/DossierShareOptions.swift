import SwiftUI

/// User-selectable visibility options for Simple and Long exported Dossier images.
struct DossierShareOptions: Equatable, Hashable {
    struct Simple: Equatable, Hashable {
        var showGrade = true
        var showHardwareID = true
        var showRing = true
        var showSessions = true
        var showLongestWear = true
        var showAverageLevel = true
        var showFirstWear = true
        var showTierSummary = true

        static let `default` = Simple()

        var isDefault: Bool { self == .default }

        mutating func reset() {
            self = .default
        }
    }

    enum LongPage: String, CaseIterable, Identifiable, Hashable {
        case cover
        case rhythm
        case habits
        case certificate

        var id: Self { self }

        var labelKey: LocalizedStringKey {
            switch self {
            case .cover: "Cover"
            case .rhythm: "Rhythm"
            case .habits: "Habits & Hearing"
            case .certificate: "Certificate"
            }
        }

        var headerTagKey: LocalizedStringKey {
            switch self {
            case .cover: "COVER"
            case .rhythm: "RHYTHM"
            case .habits: "HABITS & HEARING"
            case .certificate: "CERTIFICATE"
            }
        }

        var fileSlug: String {
            switch self {
            case .cover: "Cover"
            case .rhythm: "Rhythm"
            case .habits: "Habits"
            case .certificate: "Certificate"
            }
        }
    }

    enum RhythmSection: CaseIterable, Hashable {
        case periodSummary
        case trendChart
        case dayClock
    }

    enum HabitsSection: CaseIterable, Hashable {
        case wearHabits
        case hearingHealth
        case gradeBreakdown
    }

    enum CertificateSection: CaseIterable, Hashable {
        case certificate
        case milestones
    }

    struct Long: Equatable, Hashable {
        // Pages
        var includeCoverPage = true
        var includeRhythmPage = true
        var includeHabitsPage = true
        var includeCertificatePage = true

        // Cover details
        var showGrade = true
        var showCoverStats = true
        var showFirstWear = true
        var showHardwareID = true

        // Rhythm sections
        var showPeriodSummary = true
        var showTrendChart = true
        var showDayClock = true

        // Habits & Hearing sections
        var showWearHabits = true
        var showHearingHealth = true
        var showGradeBreakdown = true

        // Certificate sections
        var showCertificate = true
        var showSourceMetadata = true
        var showMilestones = true

        static let `default` = Long()

        var isDefault: Bool { self == .default }

        mutating func reset() {
            self = .default
        }

        /// Ordered pages currently enabled for export; guaranteed non-empty.
        var effectivePages: [LongPage] {
            let selected = LongPage.allCases.filter { isPageIncluded($0) }
            return selected.isEmpty ? [.cover] : selected
        }

        func isPageIncluded(_ page: LongPage) -> Bool {
            switch page {
            case .cover: includeCoverPage
            case .rhythm: includeRhythmPage
            case .habits: includeHabitsPage
            case .certificate: includeCertificatePage
            }
        }

        func canTogglePage(_ page: LongPage) -> Bool {
            !isPageIncluded(page) || effectivePages.count > 1
        }

        mutating func setPage(_ page: LongPage, included: Bool) {
            if !included && !canTogglePage(page) { return }
            switch page {
            case .cover: includeCoverPage = included
            case .rhythm: includeRhythmPage = included
            case .habits: includeHabitsPage = included
            case .certificate: includeCertificatePage = included
            }
        }

        func isRhythmSectionShown(_ section: RhythmSection) -> Bool {
            switch section {
            case .periodSummary: showPeriodSummary
            case .trendChart: showTrendChart
            case .dayClock: showDayClock
            }
        }

        func canToggleRhythmSection(_ section: RhythmSection) -> Bool {
            let enabledCount = RhythmSection.allCases.filter { isRhythmSectionShown($0) }.count
            return !isRhythmSectionShown(section) || enabledCount > 1
        }

        mutating func setRhythmSection(_ section: RhythmSection, shown: Bool) {
            if !shown && !canToggleRhythmSection(section) { return }
            switch section {
            case .periodSummary: showPeriodSummary = shown
            case .trendChart: showTrendChart = shown
            case .dayClock: showDayClock = shown
            }
        }

        func isHabitsSectionShown(_ section: HabitsSection) -> Bool {
            switch section {
            case .wearHabits: showWearHabits
            case .hearingHealth: showHearingHealth
            case .gradeBreakdown: showGradeBreakdown
            }
        }

        func canToggleHabitsSection(_ section: HabitsSection) -> Bool {
            let enabledCount = HabitsSection.allCases.filter { isHabitsSectionShown($0) }.count
            return !isHabitsSectionShown(section) || enabledCount > 1
        }

        mutating func setHabitsSection(_ section: HabitsSection, shown: Bool) {
            if !shown && !canToggleHabitsSection(section) { return }
            switch section {
            case .wearHabits: showWearHabits = shown
            case .hearingHealth: showHearingHealth = shown
            case .gradeBreakdown: showGradeBreakdown = shown
            }
        }

        func isCertificateSectionShown(_ section: CertificateSection) -> Bool {
            switch section {
            case .certificate: showCertificate
            case .milestones: showMilestones
            }
        }

        func canToggleCertificateSection(_ section: CertificateSection) -> Bool {
            let enabledCount = CertificateSection.allCases.filter { isCertificateSectionShown($0) }.count
            return !isCertificateSectionShown(section) || enabledCount > 1
        }

        mutating func setCertificateSection(_ section: CertificateSection, shown: Bool) {
            if !shown && !canToggleCertificateSection(section) { return }
            switch section {
            case .certificate: showCertificate = shown
            case .milestones: showMilestones = shown
            }
        }
    }

    var simple = Simple()
    var long = Long()
    var is4K = false
    var isWatermarkHidden = false

    var scale: CGFloat { is4K ? 5 : 3 }
    var usesOriginalArtwork: Bool { false }

    static let `default` = DossierShareOptions()
}
