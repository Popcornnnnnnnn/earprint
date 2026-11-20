import SwiftUI
import UniformTypeIdentifiers

enum DossierShareFormat: String, CaseIterable, Identifiable {
    case simple, long

    var id: Self { self }
    var title: LocalizedStringKey { self == .simple ? "Simple" : "Long" }
    var subtitle: LocalizedStringKey { self == .simple ? "1 page" : "4 pages" }
}

/// Crisp PNG page exported by `DossierShareSheet` via `ShareLink(items:)`.
struct DossierShareImage: Identifiable, Transferable {
    let id: Int
    let pageLabel: LocalizedStringKey
    let fileStem: String
    let uiImage: UIImage
    let pngData: Data

    var image: Image { Image(uiImage: uiImage) }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            item.pngData
        }
        .suggestedFileName { item in
            "\(item.fileStem).png"
        }
    }
}

struct DossierShareSheet: View {
    let card: HeadphoneCard
    let dossier: DeviceDossier
    let period: DossierPeriod
    let color: DeviceColorOption?
    let isSampleData: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Namespace private var switcherNamespace
    @State private var format: DossierShareFormat = .simple
    @State private var simplePages: [DossierShareImage] = []
    @State private var longPages: [DossierShareImage] = []
    @State private var isRendering = false
    @State private var activePageIndex = 0

    private static let pageSize = CGSize(width: 400, height: 560)

    private var activePages: [DossierShareImage] {
        format == .simple ? simplePages : longPages
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                formatSwitcher
                    .padding(.top, 6)

                previewStage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                shareActionButton
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
            .background(DossierPalette.ink.ignoresSafeArea())
            .navigationTitle("Share dossier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task(id: format) {
            await renderCurrentFormatIfNeeded()
        }
    }

    // MARK: - Format Switcher

    private var formatSwitcher: some View {
        HStack(spacing: 6) {
            ForEach(DossierShareFormat.allCases) { option in
                let selected = format == option
                Button {
                    guard format != option else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    activePageIndex = 0
                    withAnimation(.snappy(duration: 0.24)) {
                        format = option
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(option.title)
                            .font(.subheadline.weight(.semibold))
                        Text(option.subtitle)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(selected ? .black.opacity(0.65) : .white.opacity(0.48))
                    }
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .foregroundStyle(selected ? .black : .white.opacity(0.85))
                    .background {
                        if selected {
                            Capsule()
                                .fill(.white)
                                .matchedGeometryEffect(id: "shareFormatPill", in: switcherNamespace)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(.white.opacity(0.08), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }

    // MARK: - Preview Stage

    @ViewBuilder private var previewStage: some View {
        if isRendering && activePages.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                Text("Rendering preview…")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if activePages.count == 1, let first = activePages.first {
            VStack(spacing: 8) {
                first.image
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(color: card.rarity.glow.opacity(0.28), radius: 22, y: 10)
                    .frame(maxWidth: 420)
                    .accessibilityLabel("Dossier image preview")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if activePages.count > 1 {
            VStack(spacing: 10) {
                TabView(selection: $activePageIndex) {
                    ForEach(activePages) { page in
                        page.image
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                            )
                            .shadow(color: card.rarity.glow.opacity(0.24), radius: 18, y: 8)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .accessibilityLabel("Dossier image preview")

                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        ForEach(activePages) { page in
                            Capsule()
                                .fill(page.id == activePageIndex ? card.rarity.accent : .white.opacity(0.25))
                                .frame(width: page.id == activePageIndex ? 18 : 6, height: 6)
                                .animation(.snappy(duration: 0.22), value: activePageIndex)
                        }
                    }

                    if activePages.indices.contains(activePageIndex) {
                        Text("\(activePageIndex + 1) / \(activePages.count) · \(Text(activePages[activePageIndex].pageLabel))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.68))
                            .monospacedDigit()
                    }
                }
            }
        } else {
            Text("Image unavailable")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder private var shareActionButton: some View {
        if !activePages.isEmpty {
            let label: LocalizedStringKey = activePages.count > 1
                ? "Share \(activePages.count) images"
                : "Share image"
            ShareLink(items: activePages) { page in
                SharePreview("\(card.model) · \(page.id + 1)/\(activePages.count)", image: page.image)
            } label: {
                Label(label, systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(.black)
                    .background(.white, in: Capsule())
            }
        } else {
            Label("Share image", systemImage: "square.and.arrow.up")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(.black.opacity(0.4))
                .background(.white.opacity(0.4), in: Capsule())
        }
    }

    // MARK: - Rendering

    @MainActor private func renderCurrentFormatIfNeeded() async {
        let target = format
        if target == .simple, !simplePages.isEmpty { return }
        if target == .long, !longPages.isEmpty { return }

        isRendering = true
        // Yield one tick so the format switcher animation & loading indicator paint immediately on tap.
        await Task.yield()

        let sanitizedModel = card.model
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        let rendered: [DossierShareImage]

        switch target {
        case .simple:
            if let page = renderPage(
                id: 0,
                label: "Summary",
                fileStem: "Earprint-\(sanitizedModel)-Summary",
                content: simpleOnePagePoster
            ) {
                rendered = [page]
            } else {
                rendered = []
            }
            simplePages = rendered
        case .long:
            let specs: [(Int, LocalizedStringKey, String, AnyView)] = [
                (0, "Cover", "Earprint-\(sanitizedModel)-01-Cover", AnyView(longPage1Cover)),
                (1, "Rhythm", "Earprint-\(sanitizedModel)-02-Rhythm", AnyView(longPage2Rhythm)),
                (2, "Habits", "Earprint-\(sanitizedModel)-03-Habits", AnyView(longPage3Habits)),
                (3, "Certificate", "Earprint-\(sanitizedModel)-04-Certificate", AnyView(longPage4Certificate)),
            ]
            var results: [DossierShareImage] = []
            for spec in specs {
                if let page = renderPage(id: spec.0, label: spec.1, fileStem: spec.2, content: spec.3) {
                    results.append(page)
                }
                await Task.yield()
            }
            longPages = results
        }
        isRendering = false
    }

    @MainActor private func renderPage<Content: View>(
        id: Int,
        label: LocalizedStringKey,
        fileStem: String,
        content: Content
    ) -> DossierShareImage? {
        let renderer = ImageRenderer(content:
            content
                .frame(width: Self.pageSize.width, height: Self.pageSize.height)
                .environment(\.locale, locale)
                .environment(\.colorScheme, .dark)
                .dynamicTypeSize(.medium)
        )
        renderer.scale = 3
        renderer.isOpaque = true
        guard let uiImage = renderer.uiImage, let data = uiImage.pngData() else { return nil }
        return DossierShareImage(id: id, pageLabel: label, fileStem: fileStem, uiImage: uiImage, pngData: data)
    }

    // MARK: - Shared Poster Frame

    private func posterFrame<Content: View>(
        pageTag: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(pageTag)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(card.rarity.accent)
                Spacer()
                Text(LocalizedStringKey(card.rarity.title))
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.0)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(card.rarity.accent.opacity(0.16), in: Capsule())
                    .overlay(Capsule().strokeBorder(card.rarity.accent.opacity(0.45), lineWidth: 0.9))
                    .foregroundStyle(card.rarity.accent)
            }

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "ear.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(card.rarity.accent)
                    Text("Earprint")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                    Text("· \(card.model)")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if isSampleData {
                    Text("Sample data")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                } else {
                    Text(dossier.hardware.productID)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .foregroundStyle(.white)
        .padding(18)
        .background {
            DossierPalette.ink
            RadialGradient(
                colors: [card.rarity.glow.opacity(0.24), card.rarity.accent.opacity(0.06), .clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 340
            )
            RadialGradient(
                colors: [card.rarity.accent.opacity(0.12), .clear],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 280
            )
        }
    }

    // MARK: - Simple (Full 1-Page Poster)

    private var simpleOnePagePoster: some View {
        let rarity = card.rarity
        let hours = card.lifetimeMinutes / 60
        return posterFrame(pageTag: "EARPRINT · DEVICE DOSSIER") {
            VStack(spacing: 12) {
                // Hero foil showcase banner with open-case render + grade + lifetime total
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text("GRADE \(dossier.grade.scoreText)")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .tracking(0.8)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.black.opacity(0.28), in: Capsule())
                                .foregroundStyle(.white)
                        }

                        Spacer(minLength: 4)

                        Text(card.model)
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)

                        Text(card.lifetimeMinutes.minutesText)
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text("\(dossier.hardware.manufacturer) · \(dossier.hardware.productID)")
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .opacity(0.72)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HeadphoneArtwork(card: card, colorOption: color, showsChargingCase: true)
                        .frame(width: 132, height: 132)
                }
                .foregroundStyle(rarity.ink)
                .padding(16)
                .frame(height: 176)
                .background(FoilSurface(rarity: rarity, tilt: CGSize(width: 0.22, height: -0.15)))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(.white.opacity(0.45), lineWidth: 1.4)
                )

                // Middle data split: 4-week Earprint ring + 2x2 lifetime metrics
                HStack(spacing: 10) {
                    VStack(spacing: 4) {
                        ZStack {
                            EarprintGlyph(grid: card.grid, showHourLabels: false)
                            VStack(spacing: 0) {
                                Text("4 weeks")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .opacity(0.72)
                                Text("listening")
                                    .font(.system(size: 9))
                                    .opacity(0.5)
                            }
                        }
                        .frame(width: 138, height: 138)
                    }
                    .frame(width: 158, height: 168)
                    .background(DossierPalette.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(DossierPalette.hairline, lineWidth: 1))

                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            posterMetricTile("Sessions", "\(card.sessions)")
                            posterMetricTile("Longest", card.longestMinutes.minutesText)
                        }
                        HStack(spacing: 8) {
                            posterMetricTile("Avg level", "\(Int(card.averageDecibels.rounded())) dB", valueColor: Theme.levelColor(db: card.averageDecibels))
                            posterMetricTile("First wear", dossier.firstWear.map(DossierFormat.dot) ?? card.firstMet)
                        }
                    }
                    .frame(height: 168)
                }

                // Tier & Hearing summary footer card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        if let next = rarity.nextTier {
                            let remaining = max(1, Int(ceil(next.minimumHours - hours)))
                            Text("\(remaining)h to \(Text(LocalizedStringKey(next.title)))")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.88))
                        } else {
                            Text("Max tier reached ✦")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(rarity.accent)
                        }
                        Spacer()
                        Text("\(dossier.recordDays) record days")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(rarity.accent)
                    }
                    ProgressView(value: rarity.progressToNextTier(minutes: card.lifetimeMinutes))
                        .tint(rarity.accent)
                    HStack {
                        Label("\(Int((dossier.nightShare * 100).rounded()))% late night", systemImage: "moon.stars.fill")
                        Spacer()
                        Label(dossier.grade.label, systemImage: "checkmark.seal.fill")
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.58))
                }
                .padding(14)
                .background(DossierPalette.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(DossierPalette.hairline, lineWidth: 1))
            }
        }
    }

    private func posterMetricTile(_ label: LocalizedStringKey, _ value: String, valueColor: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DossierPalette.dim)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(DossierPalette.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(DossierPalette.hairline, lineWidth: 1))
    }

    // MARK: - Long Page 1: Cover & PSA Slab

    private var longPage1Cover: some View {
        posterFrame(pageTag: "01 / 04 · COVER") {
            VStack(spacing: 12) {
                GradingSlab(card: card, dossier: dossier, tilt: CGSize(width: 0.18, height: -0.12), flipped: false, animateSeal: false)
                    .scaleEffect(0.73)
                    .frame(width: SlabMetrics.width * 0.73, height: SlabMetrics.height * 0.73)

                HStack(spacing: 0) {
                    quickStatTile("LIFETIME", dossier.lifetimeMinutes.minutesText, accent: card.rarity.accent)
                    Rectangle().fill(DossierPalette.hairline).frame(width: 1, height: 26)
                    quickStatTile("FIRST WEAR", dossier.firstWear.map(DossierFormat.dot) ?? "—")
                    Rectangle().fill(DossierPalette.hairline).frame(width: 1, height: 26)
                    quickStatTile("RECORD DAYS", "\(dossier.recordDays)")
                }
                .padding(.vertical, 10)
                .background(DossierPalette.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(DossierPalette.hairline, lineWidth: 1))

                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(card.rarity.accent)
                    Text("\(dossier.hardware.manufacturer) · \(dossier.hardware.productID)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.78))
                    if let fw = dossier.hardware.firmwareVersion {
                        Text("· FW \(fw)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(DossierPalette.dim)
                    }
                    Spacer()
                }
                .padding(.horizontal, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func quickStatTile(_ label: LocalizedStringKey, _ value: String, accent: Color = .white) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                .tracking(1.0)
                .foregroundStyle(DossierPalette.faint)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Long Page 2: Airtime & Listening Rhythm

    private var longPage2Rhythm: some View {
        let stats = dossier.stats(period)
        let nightPct = Int((dossier.nightShare * 100).rounded())
        let peakHour = stats.peakHour?.hour
        return posterFrame(pageTag: "02 / 04 · RHYTHM") {
            VStack(spacing: 10) {
                HStack(spacing: 0) {
                    quickStatTile(LocalizedStringKey(period.title), stats.totalMinutes.minutesText, accent: card.rarity.accent)
                    Rectangle().fill(DossierPalette.hairline).frame(width: 1, height: 26)
                    quickStatTile("WEAR SHARE", "\(Int((stats.share * 100).rounded()))%")
                    Rectangle().fill(DossierPalette.hairline).frame(width: 1, height: 26)
                    quickStatTile("DAILY AVG", stats.dailyAverage.minutesText)
                }
                .padding(.vertical, 10)
                .background(DossierPalette.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(DossierPalette.hairline, lineWidth: 1))

                DossierTrendChart(
                    stats: stats,
                    rarity: card.rarity,
                    firstWear: dossier.firstWear,
                    selection: .constant(nil),
                    showsInteractionHint: false
                )
                .scaleEffect(0.92, anchor: .top)
                .frame(height: 215, alignment: .top)
                .clipped()
                .dossierTile(tint: card.rarity.accent)

                HStack(spacing: 12) {
                    DayClock(stats: stats, rarity: card.rarity, selectedHour: .constant(nil))
                        .frame(width: 138, height: 138)

                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("24-hour clock")
                        Text("When you wear it")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                        if let peakHour {
                            Label("Peak \(DossierFormat.hourLabel(peakHour))", systemImage: "clock.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(card.rarity.accent)
                        }
                        Label("\(nightPct)% late night", systemImage: "moon.stars.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(nightPct > 20 ? Theme.moderate.color : Color(red: 0.65, green: 0.72, blue: 1))
                        Text("\(stats.sessionCount) wears in \(DossierFormat.range(stats.start, stats.end))")
                            .font(.caption2)
                            .foregroundStyle(DossierPalette.dim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .dossierTile(tint: card.rarity.glow)
            }
        }
    }

    // MARK: - Long Page 3: Habits & Hearing Health

    private var longPage3Habits: some View {
        let stats = dossier.stats(period)
        let budgetPct = Int((stats.weeklyDose * 100).rounded())
        let loudPct = Int((stats.loudShare * 100).rounded())
        let longestMinutes = stats.longest?.minutes ?? card.longestMinutes
        return posterFrame(pageTag: "03 / 04 · HABITS & HEARING") {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    posterMetricTile("Longest single wear", longestMinutes.minutesText, valueColor: card.rarity.accent)
                    posterMetricTile("Avg session", stats.averagePerWear.minutesText)
                }
                .frame(height: 82)

                HStack(spacing: 10) {
                    posterMetricTile("Avg loudness", "\(Int(stats.averageDecibels.rounded())) dB(A)", valueColor: Theme.levelColor(db: stats.averageDecibels))
                    posterMetricTile("WHO weekly dose", "\(budgetPct)%", valueColor: budgetPct > 80 ? Theme.loud.color : Theme.quiet.color)
                }
                .frame(height: 82)

                HStack(spacing: 10) {
                    posterMetricTile("Loud sessions ≥80 dB", "\(loudPct)%", valueColor: loudPct > 15 ? Theme.moderate.color : .white)
                    posterMetricTile("Active days", "\(stats.activeDays) / \(max(1, stats.spanDays))")
                }
                .frame(height: 82)

                GradeBreakdown(grade: dossier.grade, accent: card.rarity.accent)
                    .dossierTile(tint: card.rarity.accent)
            }
        }
    }

    // MARK: - Long Page 4: Milestones & Certificate

    private var longPage4Certificate: some View {
        let highlightMilestones = Array(dossier.milestones.suffix(4))
        return posterFrame(pageTag: "04 / 04 · CERTIFICATE") {
            VStack(spacing: 10) {
                CertificateLabel(card: card, dossier: dossier, tilt: CGSize(width: 0.16, height: -0.10), animateSeal: false)
                    .scaleEffect(0.92, anchor: .top)
                    .frame(height: 205, alignment: .top)

                if !highlightMilestones.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("Milestones")
                        MilestoneTimelineCard(milestones: highlightMilestones, rarity: card.rarity)
                            .scaleEffect(0.90, anchor: .topLeading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 245, alignment: .top)
                    .clipped()
                }
            }
        }
    }
}
