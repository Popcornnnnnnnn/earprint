import SwiftUI
import UniformTypeIdentifiers

enum DossierShareFormat: String, CaseIterable, Identifiable {
    case simple, long

    var id: Self { self }
    var title: LocalizedStringKey { self == .simple ? "Simple" : "Long" }
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

/// Renders the exact exportable PNG pages shared by both the live preview stage and `ShareLink`.
@MainActor
enum DossierShareRenderer {
    /// Exact 3:4 portrait aspect ratio for RedNote and Douyin posts.
    static let pageSize = CGSize(width: 420, height: 560)

    static func renderPages(
        card: HeadphoneCard,
        dossier: DeviceDossier,
        period: DossierPeriod,
        color: DeviceColorOption?,
        isSampleData: Bool,
        format: DossierShareFormat,
        options: DossierShareOptions = .default,
        customization: CardCustomization? = nil,
        scheme: ColorScheme,
        locale: Locale = .current,
        scale: CGFloat = 3
    ) -> [DossierShareImage] {
        let sanitizedModel = card.model
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        let canvas = DossierSharePosterCanvas(
            card: card,
            dossier: dossier,
            period: period,
            color: color,
            isSampleData: isSampleData,
            options: options,
            customization: customization?.sanitized,
            posterScheme: scheme,
            locale: locale
        )

        switch format {
        case .simple:
            guard let page = renderPage(
                id: 0,
                label: "Summary",
                fileStem: "Earprint-\(sanitizedModel)-Summary",
                scheme: scheme,
                locale: locale,
                scale: options.is4K ? options.scale : scale,
                content: canvas.simpleOnePagePoster
            ) else {
                return []
            }
            return [page]

        case .long:
            let pages = options.long.effectivePages
            let total = pages.count
            return pages.enumerated().compactMap { index, page in
                let stem = "Earprint-\(sanitizedModel)-\(String(format: "%02d", index + 1))-\(page.fileSlug)"
                return renderPage(
                    id: index,
                    label: page.labelKey,
                    fileStem: stem,
                    scheme: scheme,
                    locale: locale,
                    scale: options.is4K ? options.scale : scale,
                    content: canvas.longPageView(for: page, index: index, total: total)
                )
            }
        }
    }

    private static func renderPage<Content: View>(
        id: Int,
        label: LocalizedStringKey,
        fileStem: String,
        scheme: ColorScheme,
        locale: Locale,
        scale: CGFloat,
        content: Content
    ) -> DossierShareImage? {
        let renderer = ImageRenderer(
            content: content
                .frame(width: pageSize.width, height: pageSize.height)
                .environment(\.locale, locale)
                .environment(\.colorScheme, scheme)
                .dynamicTypeSize(.medium)
        )
        renderer.scale = scale
        renderer.isOpaque = true
        guard let uiImage = renderer.uiImage, let data = uiImage.pngData() else { return nil }
        return DossierShareImage(id: id, pageLabel: label, fileStem: fileStem, uiImage: uiImage, pngData: data)
    }
}

struct DossierShareSheet: View {
    let card: HeadphoneCard
    let dossier: DeviceDossier
    let period: DossierPeriod
    let color: DeviceColorOption?
    let isSampleData: Bool
    let initialFormat: DossierShareFormat

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var envColorScheme
    @Environment(\.proAccess) private var proAccess
    @Environment(SlabCustomizationStore.self) private var customizationStore: SlabCustomizationStore?
    @Namespace private var switcherNamespace
    @State private var format: DossierShareFormat
    @State private var posterScheme: ColorScheme? = nil
    @State private var options = DossierShareOptions.default
    @State private var simplePages: [DossierShareImage] = []
    @State private var longPages: [DossierShareImage] = []
    @State private var renderedSimpleKey: RenderKey? = nil
    @State private var renderedLongKey: RenderKey? = nil
    @State private var isRendering = false
    @State private var activePageIndex = 0
    @State private var showCustomize = false

    init(
        card: HeadphoneCard,
        dossier: DeviceDossier,
        period: DossierPeriod,
        color: DeviceColorOption?,
        isSampleData: Bool,
        initialFormat: DossierShareFormat = .simple
    ) {
        self.card = card
        self.dossier = dossier
        self.period = period
        self.color = color
        self.isSampleData = isSampleData
        self.initialFormat = initialFormat
        _format = State(initialValue: initialFormat)
    }

    private var activePosterScheme: ColorScheme {
        posterScheme ?? envColorScheme
    }

    private var activePages: [DossierShareImage] {
        format == .simple ? simplePages : longPages
    }

    private var isActiveFormatReady: Bool {
        let readyKey = format == .simple ? renderedSimpleKey : renderedLongKey
        return readyKey == renderKey && !activePages.isEmpty
    }

    private var isCurrentFormatCustomized: Bool {
        let formatCustom = format == .simple ? !options.simple.isDefault : !options.long.isDefault
        return formatCustom || options.is4K || options.isWatermarkHidden
    }

    private struct RenderKey: Hashable {
        let format: DossierShareFormat
        let scheme: ColorScheme
        let localeID: String
        let options: DossierShareOptions
        let customization: CardCustomization
    }

    private var effectiveCustomization: CardCustomization {
        let saved = (customizationStore ?? .shared).customization(for: card.id)
        return CardCustomization(
            proFoil: proAccess.isUnlocked(.foilShaders) ? saved.proFoil : nil,
            engravedTitle: proAccess.isUnlocked(.slabEngraving) ? saved.engravedTitle : "",
            customSerial: proAccess.isUnlocked(.slabEngraving) ? saved.customSerial : ""
        ).sanitized
    }

    private var renderKey: RenderKey {
        RenderKey(
            format: format,
            scheme: activePosterScheme,
            localeID: locale.identifier,
            options: effectiveOptions,
            customization: effectiveCustomization
        )
    }

    private var effectiveOptions: DossierShareOptions {
        guard !proAccess.isUnlocked(.export4K) else { return options }
        var effective = options
        effective.is4K = false
        effective.isWatermarkHidden = false
        return effective
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    formatSwitcher
                    customizeButton
                    posterThemeToggle
                }
                .padding(.top, 6)

                if isCurrentFormatCustomized {
                    customizedStatusBanner
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

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
        .sheet(isPresented: $showCustomize) {
            DossierShareCustomizeSheet(format: format, options: $options)
                .presentationDetents([.medium, .large])
                .environment(\.locale, locale)
                .preferredColorScheme(envColorScheme)
        }
        .onChange(of: options.long) { _, updated in
            let maxIndex = max(0, updated.effectivePages.count - 1)
            if activePageIndex > maxIndex {
                activePageIndex = maxIndex
            }
        }
        .task(id: renderKey) {
            await renderCurrentFormatIfNeeded()
        }
    }

    private var customizeButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showCustomize = true
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isCurrentFormatCustomized ? dossier.rarity.accent : Theme.primaryText)
                .frame(width: 46, height: 46)
                .background(Theme.surfaceFill, in: Circle())
                .overlay(
                    Circle().strokeBorder(
                        isCurrentFormatCustomized ? dossier.rarity.accent.opacity(0.65) : Theme.hairline,
                        lineWidth: isCurrentFormatCustomized ? 1.4 : 1
                    )
                )
                .overlay(alignment: .topTrailing) {
                    if isCurrentFormatCustomized {
                        Circle()
                            .fill(dossier.rarity.accent)
                            .frame(width: 9, height: 9)
                            .offset(x: -3, y: 3)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Customize details")
    }

    private var customizedStatusBanner: some View {
        HStack(spacing: 8) {
            Label("Customized details", systemImage: "slider.horizontal.3")
                .font(.caption.weight(.semibold))
                .foregroundStyle(dossier.rarity.accent)
            Spacer()
            Button("Reset") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.snappy(duration: 0.22)) {
                    resetCurrentFormat()
                }
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(Theme.primaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.surfaceFill, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
    }

    private func resetCurrentFormat() {
        options.is4K = false
        options.isWatermarkHidden = false
        switch format {
        case .simple: options.simple.reset()
        case .long: options.long.reset()
        }
    }

    private var posterThemeToggle: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.snappy(duration: 0.22)) {
                posterScheme = activePosterScheme == .dark ? .light : .dark
            }
        } label: {
            Image(systemName: activePosterScheme == .light ? "sun.max.fill" : "moon.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.primaryText)
                .frame(width: 46, height: 46)
                .background(Theme.surfaceFill, in: Circle())
                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(activePosterScheme == .light ? "Light poster" : "Dark poster")
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
                    HStack(spacing: 5) {
                        Text(option.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(formatSubtitle(for: option))
                            .font(.caption2.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(selected ? Theme.invertedText.opacity(0.68) : Theme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .foregroundStyle(selected ? Theme.invertedText : Theme.primaryText.opacity(0.85))
                    .background {
                        if selected {
                            Capsule()
                                .fill(Theme.invertedFill)
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
        .background(Theme.surfaceFill, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
    }

    private func formatSubtitle(for option: DossierShareFormat) -> LocalizedStringKey {
        switch option {
        case .simple:
            return "1 page"
        case .long:
            let count = options.long.effectivePages.count
            return count == 1 ? "1 page" : "\(count) pages"
        }
    }

    // MARK: - Preview Stage

    @ViewBuilder private var previewStage: some View {
        let previewGlow = activePosterScheme == .light ? Theme.cardShadow : dossier.rarity.glow.opacity(0.28)
        let previewStroke = activePosterScheme == .light ? Color.black.opacity(0.10) : Color.white.opacity(0.12)
        if isRendering && activePages.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(Theme.primaryText)
                Text("Rendering preview…")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
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
                            .strokeBorder(previewStroke, lineWidth: 1)
                    )
                    .overlay {
                        if isRendering {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(.black.opacity(0.22))
                                .overlay(ProgressView().tint(.white))
                        }
                    }
                    .shadow(color: previewGlow, radius: 22, y: 10)
                    .frame(maxWidth: 420)
                    .accessibilityLabel("Dossier image preview")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if activePages.count > 1 {
            let safeIndex = min(activePageIndex, activePages.count - 1)
            VStack(spacing: 10) {
                TabView(selection: $activePageIndex) {
                    ForEach(activePages) { page in
                        page.image
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .strokeBorder(previewStroke, lineWidth: 1)
                            )
                            .shadow(color: previewGlow, radius: 18, y: 8)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .overlay {
                    if isRendering {
                        ProgressView()
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                .accessibilityLabel("Dossier image preview")

                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        ForEach(activePages) { page in
                            Capsule()
                                .fill(page.id == safeIndex ? dossier.rarity.accent : Theme.primaryText.opacity(0.25))
                                .frame(width: page.id == safeIndex ? 18 : 6, height: 6)
                                .animation(.snappy(duration: 0.22), value: safeIndex)
                        }
                    }

                    if activePages.indices.contains(safeIndex) {
                        Text("\(safeIndex + 1) / \(activePages.count) · \(Text(activePages[safeIndex].pageLabel))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.secondaryText)
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
        if isActiveFormatReady {
            let label: LocalizedStringKey = activePages.count > 1
                ? "Share \(activePages.count) images"
                : "Share image"
            ShareLink(items: activePages) { page in
                SharePreview("\(card.model) · \(page.id + 1)/\(activePages.count)", image: page.image)
            } label: {
                Label(label, systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(Theme.invertedText)
                    .background(Theme.invertedFill, in: Capsule())
            }
        } else {
            Label("Share image", systemImage: "square.and.arrow.up")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(Theme.tertiaryText)
                .background(Theme.surfaceFill, in: Capsule())
        }
    }

    // MARK: - Rendering

    @MainActor private func renderCurrentFormatIfNeeded() async {
        let key = renderKey
        if key.format == .simple, renderedSimpleKey == key, !simplePages.isEmpty {
            isRendering = false
            return
        }
        if key.format == .long, renderedLongKey == key, !longPages.isEmpty {
            isRendering = false
            return
        }

        isRendering = true
        defer { isRendering = false }
        // Yield one tick so the format switcher animation & loading indicator paint immediately on tap.
        await Task.yield()
        guard !Task.isCancelled else { return }

        let rendered = DossierShareRenderer.renderPages(
            card: card,
            dossier: dossier,
            period: period,
            color: color,
            isSampleData: isSampleData,
            format: key.format,
            options: key.options,
            customization: key.customization,
            scheme: key.scheme,
            locale: locale
        )
        guard !Task.isCancelled else { return }

        switch key.format {
        case .simple:
            simplePages = rendered
            renderedSimpleKey = key
        case .long:
            longPages = rendered
            renderedLongKey = key
            activePageIndex = min(activePageIndex, max(0, rendered.count - 1))
        }
    }
}

// MARK: - Customization Sheet

private struct DossierShareCustomizeSheet: View {
    let format: DossierShareFormat
    @Binding var options: DossierShareOptions

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.proAccess) private var proAccess
    @Environment(ProEntitlementStore.self) private var proStore: ProEntitlementStore?
    @State private var paywallFeature: ProFeature?

    private var isCurrentDefault: Bool {
        let contentIsDefault = format == .simple ? options.simple.isDefault : options.long.isDefault
        return contentIsDefault && !options.is4K && !options.isWatermarkHidden
    }

    var body: some View {
        NavigationStack {
            Form {
                if format == .simple {
                    simpleSections
                } else {
                    longSections
                }
                Section("Export quality") {
                    Toggle("High-Res (2100 × 2800)", isOn: proOption(\.is4K))
                    Toggle("Watermark-Free", isOn: proOption(\.isWatermarkHidden))
                }
            }
            .navigationTitle("Customize share image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset to defaults") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        options.is4K = false
                        options.isWatermarkHidden = false
                        switch format {
                        case .simple: options.simple.reset()
                        case .long: options.long.reset()
                        }
                    }
                    .disabled(isCurrentDefault)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $paywallFeature) { feature in
                if let proStore {
                    PaywallView(store: proStore, highlightedFeature: feature)
                        .environment(\.locale, locale)
                        .preferredColorScheme(colorScheme)
                }
            }
        }
    }

    private func proOption(_ option: WritableKeyPath<DossierShareOptions, Bool>) -> Binding<Bool> {
        Binding {
            proAccess.isUnlocked(.export4K) && options[keyPath: option]
        } set: { enabled in
            if enabled && !proAccess.isUnlocked(.export4K) {
                if proStore != nil {
                    paywallFeature = .export4K
                } else {
                    ProPaywallRequester.request(feature: .export4K)
                }
            } else {
                options[keyPath: option] = enabled
            }
        }
    }

    @ViewBuilder private var simpleSections: some View {
        Section("Header & visual") {
            Toggle("Ear Grade", isOn: $options.simple.showGrade)
            Toggle("Hardware ID", isOn: $options.simple.showHardwareID)
            Toggle("4-week Earprint ring", isOn: $options.simple.showRing)
        }

        Section("Metrics") {
            Toggle("Sessions", isOn: $options.simple.showSessions)
            Toggle("Longest", isOn: $options.simple.showLongestWear)
            Toggle("Avg level", isOn: $options.simple.showAverageLevel)
            Toggle("First wear", isOn: $options.simple.showFirstWear)
        }

        Section("Footer") {
            Toggle("Tier & hearing summary", isOn: $options.simple.showTierSummary)
        }
    }

    @ViewBuilder private var longSections: some View {
        Section {
            ForEach(DossierShareOptions.LongPage.allCases) { page in
                Toggle(page.labelKey, isOn: pageBinding(page))
                    .disabled(!options.long.canTogglePage(page))
            }
        } header: {
            Text("Pages")
        } footer: {
            Text("At least one page must stay enabled.")
        }

        Section {
            Toggle("Ear Grade", isOn: $options.long.showGrade)
            Toggle("Hardware ID", isOn: $options.long.showHardwareID)
            Toggle("First wear", isOn: $options.long.showFirstWear)
        } header: {
            Text("Details across pages")
        }

        if options.long.includeCoverPage {
            Section("Cover") {
                Toggle("Quick stats", isOn: $options.long.showCoverStats)
            }
        }

        if options.long.includeRhythmPage {
            Section("Rhythm") {
                Toggle("Period summary", isOn: rhythmBinding(.periodSummary))
                    .disabled(!options.long.canToggleRhythmSection(.periodSummary))
                Toggle("Trend chart", isOn: rhythmBinding(.trendChart))
                    .disabled(!options.long.canToggleRhythmSection(.trendChart))
                Toggle("24-hour clock", isOn: rhythmBinding(.dayClock))
                    .disabled(!options.long.canToggleRhythmSection(.dayClock))
            }
        }

        if options.long.includeHabitsPage {
            Section("Habits & Hearing") {
                Toggle("Wear habits", isOn: habitsBinding(.wearHabits))
                    .disabled(!options.long.canToggleHabitsSection(.wearHabits))
                Toggle("Hearing health", isOn: habitsBinding(.hearingHealth))
                    .disabled(!options.long.canToggleHabitsSection(.hearingHealth))
                Toggle("Grade breakdown", isOn: habitsBinding(.gradeBreakdown))
                    .disabled(!options.long.canToggleHabitsSection(.gradeBreakdown))
            }
        }

        if options.long.includeCertificatePage {
            Section("Certificate") {
                Toggle("Grading certificate", isOn: certificateBinding(.certificate))
                    .disabled(!options.long.canToggleCertificateSection(.certificate))
                if options.long.showCertificate {
                    Toggle("Source & sync metadata", isOn: $options.long.showSourceMetadata)
                }
                Toggle("Milestones", isOn: certificateBinding(.milestones))
                    .disabled(!options.long.canToggleCertificateSection(.milestones))
            }
        }
    }

    private func pageBinding(_ page: DossierShareOptions.LongPage) -> Binding<Bool> {
        Binding(
            get: { options.long.isPageIncluded(page) },
            set: { options.long.setPage(page, included: $0) }
        )
    }

    private func rhythmBinding(_ section: DossierShareOptions.RhythmSection) -> Binding<Bool> {
        Binding(
            get: { options.long.isRhythmSectionShown(section) },
            set: { options.long.setRhythmSection(section, shown: $0) }
        )
    }

    private func habitsBinding(_ section: DossierShareOptions.HabitsSection) -> Binding<Bool> {
        Binding(
            get: { options.long.isHabitsSectionShown(section) },
            set: { options.long.setHabitsSection(section, shown: $0) }
        )
    }

    private func certificateBinding(_ section: DossierShareOptions.CertificateSection) -> Binding<Bool> {
        Binding(
            get: { options.long.isCertificateSectionShown(section) },
            set: { options.long.setCertificateSection(section, shown: $0) }
        )
    }
}

// MARK: - Poster Canvas

private struct DossierSharePosterCanvas {
    let card: HeadphoneCard
    let dossier: DeviceDossier
    let period: DossierPeriod
    let color: DeviceColorOption?
    let isSampleData: Bool
    let options: DossierShareOptions
    var customization: CardCustomization? = nil
    let posterScheme: ColorScheme
    var locale: Locale = AppLanguage.current.locale

    private var displayCard: HeadphoneCard { dossier.cardSnapshot(from: card) }
    private var displayRarity: Rarity { dossier.rarity }

    private struct MetricTileItem: Identifiable {
        let id: String
        let label: LocalizedStringKey
        let value: String
        let valueColor: Color
    }

    // MARK: - Shared Poster Frame

    private func posterFrame<Tag: View, Content: View>(
        showsHardwareID: Bool,
        @ViewBuilder pageTag: () -> Tag,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isLight = posterScheme == .light
        let fg: Color = isLight ? Color(red: 0.075, green: 0.080, blue: 0.110) : .white
        let canvasBg = isLight ? Color(red: 0.960, green: 0.964, blue: 0.976) : Color(red: 0.035, green: 0.035, blue: 0.055)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                pageTag()
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(displayRarity.accent)
                Spacer()
                Text(LocalizedStringKey(displayRarity.title))
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.0)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(displayRarity.accent.opacity(0.16), in: Capsule())
                    .overlay(Capsule().strokeBorder(displayRarity.accent.opacity(0.45), lineWidth: 0.9))
                    .foregroundStyle(displayRarity.accent)
            }

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            HStack {
                if !options.isWatermarkHidden {
                    HStack(spacing: 5) {
                        Image(systemName: "ear.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(displayRarity.accent)
                        Text("Earprint")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                        Text("· \(card.model)")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(DossierPalette.dim)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                if isSampleData {
                    Text("Sample data")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DossierPalette.dim)
                } else if showsHardwareID {
                    Text(dossier.hardware.productID)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DossierPalette.faint)
                }
            }
        }
        .foregroundStyle(fg)
        .padding(18)
        .background {
            canvasBg
            RadialGradient(
                colors: [displayRarity.glow.opacity(isLight ? 0.16 : 0.24), displayRarity.accent.opacity(isLight ? 0.04 : 0.06), .clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 340
            )
            RadialGradient(
                colors: [displayRarity.accent.opacity(isLight ? 0.08 : 0.12), .clear],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 280
            )
        }
    }

    // MARK: - Simple (Full 1-Page Poster)

    var simpleOnePagePoster: some View {
        let s = options.simple
        let rarity = displayRarity
        let snapshotCard = displayCard
        let foil = customization?.proFoil
        let ink = foil?.ink ?? rarity.ink
        let accent = foil?.accent ?? rarity.accent
        let hours = snapshotCard.lifetimeMinutes / 60
        let visibleTiles = simpleVisibleTiles(s)
        return posterFrame(showsHardwareID: s.showHardwareID) {
            Text(dossier.isRetired ? "EARPRINT · HALL OF FAME" : "EARPRINT · DEVICE DOSSIER")
        } content: {
            VStack(spacing: 12) {
                // Hero foil showcase banner with open-case render + optional grade/hardware
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        if s.showGrade || dossier.isRetired {
                            HStack(spacing: 6) {
                                if s.showGrade {
                                    Text("GRADE \(dossier.grade.scoreText)")
                                        .font(.system(size: 10, weight: .black, design: .rounded))
                                        .tracking(0.8)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.black.opacity(ink == .white ? 0.34 : 0.74), in: Capsule())
                                        .foregroundStyle(.white)
                                }
                                if dossier.isRetired {
                                    HStack(spacing: 3) {
                                        Image(systemName: "archivebox.fill")
                                            .font(.system(size: 8.5, weight: .bold))
                                        Text("VAULTED")
                                            .font(.system(size: 9.5, weight: .black, design: .rounded))
                                            .tracking(0.8)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.black.opacity(ink == .white ? 0.34 : 0.74), in: Capsule())
                                    .foregroundStyle(.white)
                                }
                            }
                        }

                        Spacer(minLength: 4)

                        Text(card.model)
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)

                        Text(snapshotCard.lifetimeMinutes.minutesText)
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        if s.showHardwareID {
                            Text("\(dossier.hardware.manufacturer) · \(dossier.hardware.productID)")
                                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                .opacity(0.72)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HeadphoneArtwork(card: snapshotCard, colorOption: color, showsChargingCase: true)
                        .frame(width: 132, height: 132)
                }
                .foregroundStyle(ink)
                .padding(16)
                .frame(height: 176)
                .background(FoilSurface(rarity: rarity, tilt: CGSize(width: 0.22, height: -0.15), proFoil: foil))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(ink == .white ? .white.opacity(0.35) : .black.opacity(0.14), lineWidth: 1.4)
                )

                if s.showRing || !visibleTiles.isEmpty {
                    simpleMiddleSection(showRing: s.showRing, tiles: visibleTiles)
                }

                // Tier & Hearing summary footer card (or Vault Career footer when retired)
                if s.showTierSummary {
                    if let retirement = dossier.retirement {
                        let firstDate = dossier.firstWear.map { DateText.dotted($0, calendar: dossier.calendar) }
                            ?? (snapshotCard.firstMet == "—" || snapshotCard.firstMet.isEmpty ? nil : snapshotCard.firstMet)
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(spacing: 6) {
                                if s.showFirstWear, let firstDate {
                                    Label(
                                        "\(firstDate) – \(retirement.formattedRetiredDate)",
                                        systemImage: "archivebox.fill"
                                    )
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(DossierPalette.primaryText.opacity(0.9))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                    Spacer()
                                    Text("\(dossier.historyDays) days")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(accent)
                                } else {
                                    Label(
                                        "Vaulted \(retirement.formattedRetiredDate)",
                                        systemImage: "archivebox.fill"
                                    )
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(DossierPalette.primaryText.opacity(0.9))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                    Spacer()
                                    Text("\(dossier.recordDays) record days")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(accent)
                                }
                            }
                            if !retirement.farewellNote.isEmpty {
                                Text("“\(retirement.farewellNote)”")
                                    .font(.caption2.italic())
                                    .foregroundStyle(DossierPalette.primaryText.opacity(0.82))
                                    .lineLimit(2)
                            }
                            HStack {
                                Label(LocalizedStringKey(retirement.reason.title), systemImage: retirement.reason.symbol)
                                Spacer()
                                if s.showGrade {
                                    Label(LocalizedStringKey(dossier.grade.label), systemImage: "checkmark.seal.fill")
                                }
                            }
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(DossierPalette.dim)
                        }
                        .padding(14)
                        .background(DossierPalette.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(DossierPalette.hairline, lineWidth: 1))
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                if let next = rarity.nextTier {
                                    let remaining = max(1, Int(ceil(next.minimumHours - hours)))
                                    Text("\(remaining)h to \(Text(LocalizedStringKey(next.title)))")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(DossierPalette.primaryText.opacity(0.88))
                                } else {
                                    Text("Max tier reached ✦")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(accent)
                                }
                                Spacer()
                                Text("\(dossier.recordDays) record days")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(accent)
                            }
                            let tierProgress = min(max(rarity.progressToNextTier(minutes: snapshotCard.lifetimeMinutes), 0), 1)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(DossierPalette.surfaceFill)
                                    Capsule()
                                        .fill(rarity.accent)
                                        .frame(width: max(tierProgress > 0 ? 6 : 0, geo.size.width * tierProgress))
                                }
                            }
                            .frame(height: 6)
                            HStack {
                                Label("\(Int((dossier.nightShare * 100).rounded()))% late night", systemImage: "moon.stars.fill")
                                Spacer()
                                if s.showGrade {
                                    Label(LocalizedStringKey(dossier.grade.label), systemImage: "checkmark.seal.fill")
                                }
                            }
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(DossierPalette.dim)
                        }
                        .padding(14)
                        .background(DossierPalette.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(DossierPalette.hairline, lineWidth: 1))
                    }
                }
            }
        }
    }

    private func simpleVisibleTiles(_ s: DossierShareOptions.Simple) -> [MetricTileItem] {
        let snapshotCard = displayCard
        var tiles: [MetricTileItem] = []
        if s.showSessions {
            tiles.append(MetricTileItem(id: "sessions", label: "Sessions", value: "\(snapshotCard.sessions)", valueColor: DossierPalette.primaryText))
        }
        if s.showLongestWear {
            tiles.append(MetricTileItem(id: "longest", label: "Longest", value: snapshotCard.longestMinutes.minutesText, valueColor: DossierPalette.primaryText))
        }
        if s.showAverageLevel {
            tiles.append(MetricTileItem(
                id: "avg",
                label: "Avg level",
                value: "\(Int(snapshotCard.averageDecibels.rounded())) dB",
                valueColor: Theme.levelColor(db: snapshotCard.averageDecibels, colorScheme: posterScheme)
            ))
        }
        if s.showFirstWear {
            tiles.append(MetricTileItem(
                id: "firstWear",
                label: "First wear",
                value: dossier.firstWear.map { DateText.dotted($0, calendar: dossier.calendar) } ?? snapshotCard.firstMet,
                valueColor: DossierPalette.primaryText
            ))
        }
        return tiles
    }

    @ViewBuilder
    private func simpleMiddleSection(showRing: Bool, tiles: [MetricTileItem]) -> some View {
        if showRing && !tiles.isEmpty {
            HStack(spacing: 10) {
                simpleRingPanel
                    .frame(width: 158, height: 168)
                simpleTileGrid(tiles, columnsWhenSplit: true)
                    .frame(height: 168)
            }
        } else if showRing {
            simpleRingPanel
                .frame(maxWidth: .infinity)
                .frame(height: 168)
        } else {
            simpleTileGrid(tiles, columnsWhenSplit: false)
                .frame(height: tiles.count <= 2 ? 96 : 168)
        }
    }

    private var simpleRingPanel: some View {
        VStack(spacing: 4) {
            ZStack {
                EarprintGlyph(grid: displayCard.grid, showHourLabels: false, forcedColorScheme: posterScheme)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DossierPalette.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(DossierPalette.hairline, lineWidth: 1))
    }

    @ViewBuilder
    private func simpleTileGrid(_ tiles: [MetricTileItem], columnsWhenSplit: Bool) -> some View {
        switch tiles.count {
        case 1:
            posterMetricTile(tiles[0].label, tiles[0].value, valueColor: tiles[0].valueColor)
        case 2 where columnsWhenSplit:
            VStack(spacing: 8) {
                posterMetricTile(tiles[0].label, tiles[0].value, valueColor: tiles[0].valueColor)
                posterMetricTile(tiles[1].label, tiles[1].value, valueColor: tiles[1].valueColor)
            }
        case 2:
            HStack(spacing: 8) {
                posterMetricTile(tiles[0].label, tiles[0].value, valueColor: tiles[0].valueColor)
                posterMetricTile(tiles[1].label, tiles[1].value, valueColor: tiles[1].valueColor)
            }
        case 3:
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    posterMetricTile(tiles[0].label, tiles[0].value, valueColor: tiles[0].valueColor)
                    posterMetricTile(tiles[1].label, tiles[1].value, valueColor: tiles[1].valueColor)
                }
                posterMetricTile(tiles[2].label, tiles[2].value, valueColor: tiles[2].valueColor)
            }
        default:
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    posterMetricTile(tiles[0].label, tiles[0].value, valueColor: tiles[0].valueColor)
                    posterMetricTile(tiles[1].label, tiles[1].value, valueColor: tiles[1].valueColor)
                }
                HStack(spacing: 8) {
                    posterMetricTile(tiles[2].label, tiles[2].value, valueColor: tiles[2].valueColor)
                    posterMetricTile(tiles[3].label, tiles[3].value, valueColor: tiles[3].valueColor)
                }
            }
        }
    }

    private func posterMetricTile(_ label: LocalizedStringKey, _ value: String, valueColor: Color = DossierPalette.primaryText) -> some View {
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

    // MARK: - Long Pages

    @ViewBuilder
    func longPageView(for page: DossierShareOptions.LongPage, index: Int, total: Int) -> some View {
        switch page {
        case .cover: longPageCover(index: index, total: total)
        case .rhythm: longPageRhythm(index: index, total: total)
        case .habits: longPageHabits(index: index, total: total)
        case .certificate: longPageCertificate(index: index, total: total)
        }
    }

    private func longFrame<Content: View>(
        page: DossierShareOptions.LongPage,
        index: Int,
        total: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        posterFrame(showsHardwareID: options.long.showHardwareID) {
            HStack(spacing: 0) {
                Text(verbatim: String(format: "%02d / %02d · ", index + 1, total))
                Text(page.headerTagKey)
            }
        } content: {
            content()
        }
    }

    private func longPageCover(index: Int, total: Int) -> some View {
        let l = options.long
        let snapshotCard = displayCard
        let rarity = displayRarity
        return longFrame(page: .cover, index: index, total: total) {
            VStack(spacing: 12) {
                GradingSlab(
                    card: snapshotCard,
                    dossier: dossier,
                    tilt: CGSize(width: 0.18, height: -0.12),
                    flipped: false,
                    animateSeal: false,
                    showsGrade: l.showGrade,
                    showsHardwareID: l.showHardwareID,
                    showsFirstWear: l.showFirstWear,
                    proFoil: customization?.proFoil,
                    engravedSubtitle: customization?.engravedTitle,
                    customSerialTag: customization?.customSerial,
                    usesSavedCustomization: false,
                    colorOption: color
                )
                .scaleEffect(0.67)
                .frame(width: SlabMetrics.width * 0.67, height: SlabMetrics.height * 0.67)

                if l.showCoverStats {
                    HStack(spacing: 0) {
                        quickStatTile("LIFETIME", dossier.lifetimeMinutes.minutesText, accent: rarity.accent)
                        if l.showFirstWear {
                            Rectangle().fill(DossierPalette.hairline).frame(width: 1, height: 26)
                            quickStatTile("FIRST WEAR", dossier.firstWear.map { DateText.dotted($0, calendar: dossier.calendar) } ?? "—")
                        }
                        if let retirement = dossier.retirement {
                            Rectangle().fill(DossierPalette.hairline).frame(width: 1, height: 26)
                            quickStatTile("RETIRED", retirement.formattedRetiredDate)
                        }
                        Rectangle().fill(DossierPalette.hairline).frame(width: 1, height: 26)
                        quickStatTile("RECORD DAYS", "\(dossier.recordDays)")
                    }
                    .padding(.vertical, 10)
                    .background(DossierPalette.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(DossierPalette.hairline, lineWidth: 1))
                }

                if l.showHardwareID {
                    HStack(spacing: 6) {
                        Image(systemName: "cpu")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(rarity.accent)
                        Text("\(dossier.hardware.manufacturer) · \(dossier.hardware.productID)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(DossierPalette.primaryText.opacity(0.78))
                        if let fw = dossier.hardware.firmwareVersion {
                            Text("· FW \(fw)")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(DossierPalette.dim)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 6)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func quickStatTile(_ label: LocalizedStringKey, _ value: String, accent: Color = DossierPalette.primaryText) -> some View {
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

    private func longPageRhythm(index: Int, total: Int) -> some View {
        let l = options.long
        let rarity = displayRarity
        let stats = dossier.stats(period)
        let lateNightMinutes = stats.hours
            .filter { $0.hour >= 22 || $0.hour <= 3 }
            .reduce(0.0) { $0 + $1.minutes }
        let periodNightShare = stats.totalMinutes > 0 ? lateNightMinutes / stats.totalMinutes : 0
        let nightPct = Int((periodNightShare * 100).rounded())
        let peakHour = stats.peakHour?.hour
        return longFrame(page: .rhythm, index: index, total: total) {
            VStack(spacing: 8) {
                if l.showPeriodSummary {
                    HStack(spacing: 0) {
                        quickStatTile(LocalizedStringKey(period.title), stats.totalMinutes.minutesText, accent: rarity.accent)
                        Rectangle().fill(DossierPalette.hairline).frame(width: 1, height: 24)
                        quickStatTile("WEAR SHARE", "\(Int((stats.share * 100).rounded()))%")
                        Rectangle().fill(DossierPalette.hairline).frame(width: 1, height: 24)
                        if l.showFirstWear {
                            quickStatTile("DAILY AVG", stats.dailyAverage.minutesText)
                        } else {
                            quickStatTile("WEARS", "\(stats.sessionCount)")
                        }
                    }
                    .padding(.vertical, 8)
                    .background(DossierPalette.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(DossierPalette.hairline, lineWidth: 1))
                }

                if l.showTrendChart {
                    DossierTrendChart(
                        stats: stats,
                        rarity: rarity,
                        firstWear: l.showFirstWear ? dossier.firstWear : nil,
                        selection: .constant(nil),
                        showsInteractionHint: false,
                        showsMintedMarker: l.showFirstWear,
                        chartHeight: 132
                    )
                    .dossierTile(tint: rarity.accent)
                }

                if l.showDayClock {
                    HStack(spacing: 12) {
                        DayClock(
                            stats: stats,
                            rarity: rarity,
                            selectedHour: .constant(nil),
                            showsPerDayAverage: l.showFirstWear
                        )
                            .frame(width: 134, height: 134)

                        VStack(alignment: .leading, spacing: 6) {
                            Eyebrow("24-hour clock")
                            Text("When you wear it")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                            if let peakHour {
                                Label("Peak \(DossierFormat.hourLabel(peakHour))", systemImage: "clock.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(rarity.accent)
                            }
                            Label("\(nightPct)% late night", systemImage: "moon.stars.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(nightPct > 20 ? Theme.moderateColor : Color.adaptive(light: UIColor(red: 0.28, green: 0.36, blue: 0.78, alpha: 1), dark: UIColor(red: 0.65, green: 0.72, blue: 1, alpha: 1)))
                            Group {
                                if !l.showFirstWear && period == .all {
                                    Text("\(stats.sessionCount) wears")
                                } else {
                                    Text("\(stats.sessionCount) wears in \(DateText.range(stats.start, stats.end, calendar: dossier.calendar, locale: locale))")
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(DossierPalette.dim)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .dossierTile(tint: rarity.glow)
                }
            }
        }
    }

    private func longPageHabits(index: Int, total: Int) -> some View {
        let l = options.long
        let rarity = displayRarity
        let stats = dossier.stats(period)
        let budgetPct = Int((stats.weeklyDose * 100).rounded())
        let loudPct = Int((stats.loudShare * 100).rounded())
        let longestMinutes = stats.longest?.minutes ?? displayCard.longestMinutes
        let activeDaysValue = l.showFirstWear
            ? "\(stats.activeDays) / \(max(1, stats.spanDays))"
            : "\(stats.activeDays)"
        return longFrame(page: .habits, index: index, total: total) {
            VStack(spacing: 7) {
                if l.showWearHabits && l.showHearingHealth {
                    HStack(spacing: 8) {
                        posterMetricTile("Longest single wear", longestMinutes.minutesText, valueColor: rarity.accent)
                        posterMetricTile("Avg session", stats.averagePerWear.minutesText)
                    }
                    .frame(height: 62)

                    HStack(spacing: 8) {
                        posterMetricTile("Avg loudness", "\(Int(stats.averageDecibels.rounded())) dB(A)", valueColor: Theme.levelColor(db: stats.averageDecibels, colorScheme: posterScheme))
                        posterMetricTile("WHO weekly dose", "\(budgetPct)%", valueColor: budgetPct > 80 ? Theme.loudColor : Theme.quietColor)
                    }
                    .frame(height: 62)

                    HStack(spacing: 8) {
                        posterMetricTile("Loud sessions ≥80 dB", "\(loudPct)%", valueColor: loudPct > 15 ? Theme.moderateColor : DossierPalette.primaryText)
                        posterMetricTile("Active days", activeDaysValue)
                    }
                    .frame(height: 62)
                } else if l.showWearHabits {
                    HStack(spacing: 8) {
                        posterMetricTile("Longest single wear", longestMinutes.minutesText, valueColor: rarity.accent)
                        posterMetricTile("Avg session", stats.averagePerWear.minutesText)
                    }
                    .frame(height: 68)

                    posterMetricTile("Active days", activeDaysValue)
                        .frame(height: 68)
                } else if l.showHearingHealth {
                    HStack(spacing: 8) {
                        posterMetricTile("Avg loudness", "\(Int(stats.averageDecibels.rounded())) dB(A)", valueColor: Theme.levelColor(db: stats.averageDecibels, colorScheme: posterScheme))
                        posterMetricTile("WHO weekly dose", "\(budgetPct)%", valueColor: budgetPct > 80 ? Theme.loudColor : Theme.quietColor)
                    }
                    .frame(height: 68)

                    posterMetricTile("Loud sessions ≥80 dB", "\(loudPct)%", valueColor: loudPct > 15 ? Theme.moderateColor : DossierPalette.primaryText)
                        .frame(height: 68)
                }

                if l.showGradeBreakdown {
                    GradeBreakdown(grade: dossier.grade, accent: rarity.accent)
                        .dossierTile(tint: rarity.accent)
                }
            }
        }
    }

    private func longPageCertificate(index: Int, total: Int) -> some View {
        let l = options.long
        let snapshotCard = displayCard
        let rarity = displayRarity
        let visibleMilestones: [DossierMilestone] = if l.showFirstWear {
            dossier.milestones
        } else {
            dossier.milestones.compactMap { item in
                guard item.kind != .minted else { return nil }
                if item.kind == .hours {
                    return DossierMilestone(
                        id: item.id,
                        kind: item.kind,
                        date: item.date,
                        title: item.title,
                        detail: "",
                        tier: item.tier,
                        isFuture: item.isFuture
                    )
                }
                return item
            }
        }
        let hasAnyMilestones = !visibleMilestones.isEmpty
        let showMilestones = l.showMilestones && hasAnyMilestones
        return longFrame(page: .certificate, index: index, total: total) {
            VStack(alignment: .leading, spacing: 8) {
                if l.showCertificate && showMilestones {
                    CertificateLabel(
                        card: snapshotCard,
                        dossier: dossier,
                        tilt: CGSize(width: 0.16, height: -0.10),
                        animateSeal: false,
                        showsGrade: l.showGrade,
                        showsHardwareDetails: l.showHardwareID,
                        showsSourceMetadata: l.showSourceMetadata,
                        showsFirstWear: l.showFirstWear,
                        compact: true
                    )

                    compactMilestonesSection(Array(visibleMilestones.suffix(3)))
                } else if l.showCertificate {
                    ViewThatFits(in: .vertical) {
                        CertificateLabel(
                            card: snapshotCard,
                            dossier: dossier,
                            tilt: CGSize(width: 0.16, height: -0.10),
                            animateSeal: false,
                            showsGrade: l.showGrade,
                            showsHardwareDetails: l.showHardwareID,
                            showsSourceMetadata: l.showSourceMetadata,
                            showsFirstWear: l.showFirstWear,
                            compact: false
                        )
                        CertificateLabel(
                            card: snapshotCard,
                            dossier: dossier,
                            tilt: CGSize(width: 0.16, height: -0.10),
                            animateSeal: false,
                            showsGrade: l.showGrade,
                            showsHardwareDetails: l.showHardwareID,
                            showsSourceMetadata: l.showSourceMetadata,
                            showsFirstWear: l.showFirstWear,
                            compact: true
                        )
                    }
                } else if showMilestones {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("Milestones")
                        MilestoneTimelineCard(milestones: Array(visibleMilestones.suffix(4)), rarity: rarity, calendar: dossier.calendar)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else if !l.showCertificate {
                    Text("No milestones yet")
                        .font(.subheadline)
                        .foregroundStyle(DossierPalette.dim)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func compactMilestonesSection(_ milestones: [DossierMilestone]) -> some View {
        let rarity = displayRarity
        return VStack(alignment: .leading, spacing: 6) {
            Eyebrow("Milestones")
            VStack(alignment: .leading, spacing: 6) {
                ForEach(milestones) { item in
                    HStack(spacing: 8) {
                        let nodeColor = compactMilestoneColor(for: item)
                        ZStack {
                            if item.isFuture {
                                Circle()
                                    .strokeBorder(nodeColor.opacity(0.6), style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 2.5]))
                            } else {
                                Circle()
                                    .fill(nodeColor.opacity(0.18))
                                    .overlay(Circle().strokeBorder(nodeColor.opacity(0.75), lineWidth: 1))
                            }
                            Image(systemName: compactMilestoneIcon(for: item.kind))
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundStyle(item.isFuture ? nodeColor.opacity(0.8) : nodeColor)
                        }
                        .frame(width: 18, height: 18)

                        Text(LocalizedStringKey(item.title))
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundStyle(item.isFuture ? DossierPalette.primaryText.opacity(0.78) : DossierPalette.primaryText)
                            .lineLimit(1)

                        if item.kind == .retired {
                            Text("VAULTED")
                                .font(.system(size: 7.5, weight: .heavy, design: .rounded))
                                .tracking(0.6)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(rarity.accent.opacity(0.18), in: Capsule())
                                .foregroundStyle(rarity.accent)
                        } else if let tier = item.tier, item.kind == .tier || item.kind == .minted {
                            Text(LocalizedStringKey(tier.shortName.uppercased()))
                                .font(.system(size: 7.5, weight: .heavy, design: .rounded))
                                .tracking(0.6)
                                .lineLimit(1)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(tier.accent.opacity(0.18), in: Capsule())
                                .foregroundStyle(tier.accent)
                        } else if item.isFuture {
                            Text("NEXT")
                                .font(.system(size: 7.5, weight: .heavy, design: .rounded))
                                .tracking(0.6)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(rarity.accent.opacity(0.18), in: Capsule())
                                .foregroundStyle(rarity.accent)
                        }

                        Spacer(minLength: 6)

                        Text(item.isFuture ? AppLanguage.current.text("ETA %@", item.date.dossierShort) : DateText.dotted(item.date, calendar: dossier.calendar))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(item.isFuture ? rarity.accent.opacity(0.85) : DossierPalette.dim)
                            .lineLimit(1)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DossierPalette.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(DossierPalette.hairline, lineWidth: 1))
        }
    }

    private func compactMilestoneIcon(for kind: DossierMilestone.Kind) -> String {
        switch kind {
        case .minted: "sparkles"
        case .hours: "clock.fill"
        case .tier: "seal.fill"
        case .longest: "flame.fill"
        case .bestDay: "crown.fill"
        case .upcoming: "flag.checkered"
        case .retired: "archivebox.fill"
        }
    }

    private func compactMilestoneColor(for item: DossierMilestone) -> Color {
        if let tier = item.tier { return tier.accent }
        switch item.kind {
        case .longest: return Theme.moderateColor
        case .bestDay, .upcoming, .minted, .tier, .retired: return displayRarity.accent
        case .hours: return Theme.quietColor
        }
    }
}
