import RealityKit
import SwiftUI

private let wrappedMint = Color(red: 0.68, green: 0.97, blue: 0.87)
private let wrappedInk = Color(red: 0.04, green: 0.06, blue: 0.09)
private let wrappedPlum = Color(red: 0.19, green: 0.11, blue: 0.28)
private let wrappedDeepTeal = Color(red: 0.06, green: 0.16, blue: 0.20)

struct WrappedStoryView: View {
    let summary: WrappedSummary
    var aggregate: ListeningAggregate? = nil
    var cards: [HeadphoneCard] = []
    var isLoading: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.proAccess) private var proAccess
    @Environment(ProEntitlementStore.self) private var proStore: ProEntitlementStore?
    @Environment(DeviceColorStore.self) private var colorStore: DeviceColorStore?
    @Environment(SlabCustomizationStore.self) private var customizationStore: SlabCustomizationStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var page = Self.initialSlide
    @State private var exportProgress = 0.0
    @State private var exportTask: Task<Void, Never>?
    @State private var archiveTask: Task<Void, Never>?
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var exportFailed = false
    @State private var paywallFeature: ProFeature?

    private static var initialSlide: Int {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-wrappedSlide"),
           idx + 1 < args.count,
           let value = Int(args[idx + 1]) {
            return max(0, min(4, value))
        }
        #endif
        return 0
    }

    private var slideCount: Int { summary.isThinData ? 2 : 5 }

    private var resolvedTopCard: HeadphoneCard {
        summary.topCard ?? .wrappedFallback(from: summary)
    }

    private var resolvedColor: DeviceColorOption? {
        colorStore?.selectedColor(for: resolvedTopCard)
            ?? DeviceColorOption.defaultOption(for: resolvedTopCard.modelKey)
    }

    private var resolvedProFoil: ProFoilStyle? {
        guard proAccess.isUnlocked(.foilShaders) else { return nil }
        return summary.topCard.flatMap { (customizationStore ?? .shared).customization(for: $0.id).proFoil }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingState
                } else {
                    storyContent
                }
            }
            .background {
                ZStack {
                    LinearGradient(
                        colors: [wrappedInk, wrappedPlum, wrappedInk],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    RadialGradient(
                        colors: [wrappedMint.opacity(0.14), .clear],
                        center: .topTrailing,
                        startRadius: 20,
                        endRadius: 420
                    )
                }
                .ignoresSafeArea()
            }
            .foregroundStyle(.white)
            .tint(wrappedMint)
            .navigationTitle("Earprint Wrapped")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
                if let aggregate {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                exportArchive(.csv, aggregate: aggregate)
                            } label: {
                                Label("Export CSV", systemImage: "tablecells")
                            }
                            Button {
                                exportArchive(.json, aggregate: aggregate)
                            } label: {
                                Label("Export JSON", systemImage: "curlybraces")
                            }
                        } label: {
                            if archiveTask != nil {
                                ProgressView()
                                    .tint(wrappedMint)
                            } else {
                                Label("Listening archive", systemImage: "arrow.down.doc")
                                    .foregroundStyle(.white)
                            }
                        }
                        .disabled(archiveTask != nil || exportTask != nil)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(exportTask != nil)
        .overlay {
            if exportTask != nil {
                ZStack {
                    Color.black.opacity(0.68).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView(value: exportProgress)
                            .tint(wrappedMint)
                            .accessibilityLabel("Rendering your reel")
                        Text("Rendering your reel")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Button {
                            exportTask?.cancel()
                        } label: {
                            Text("Cancel")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 9)
                                .background(.white.opacity(0.14), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(24)
                    .frame(maxWidth: 280)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.18), lineWidth: 1))
                }
            }
        }
        .sheet(isPresented: $showShare, onDismiss: clearShare) {
            if let shareURL {
                WrappedActivitySheet(url: shareURL)
            }
        }
        .alert("Export failed", isPresented: $exportFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try again.")
        }
        .sheet(item: $paywallFeature) { feature in
            if let proStore {
                PaywallView(store: proStore, highlightedFeature: feature)
                    .environment(\.locale, locale)
                    .preferredColorScheme(colorScheme)
            }
        }
        .onAppear {
            page = min(page, slideCount - 1)
        }
        .onDisappear {
            exportTask?.cancel()
            archiveTask?.cancel()
        }
        .onChange(of: slideCount) { _, count in
            page = min(page, count - 1)
        }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .tint(wrappedMint)
            Text("Loading Wrapped…")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.86))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var storyContent: some View {
        VStack(spacing: 10) {
            GeometryReader { stage in
                TabView(selection: $page) {
                    ForEach(0..<slideCount, id: \.self) { index in
                        ScrollView {
                            VStack(spacing: 0) {
                                Spacer(minLength: 8)
                                slide(index, availableHeight: stage.size.height)
                                    .frame(maxWidth: 440)
                                Spacer(minLength: 8)
                            }
                            .frame(maxWidth: .infinity, minHeight: stage.size.height)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 8)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .scrollIndicators(.hidden)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }

            HStack(spacing: 6) {
                ForEach(0..<slideCount, id: \.self) { index in
                    Button {
                        move(to: index)
                    } label: {
                        Capsule()
                            .fill(index <= page ? wrappedMint : .white.opacity(0.20))
                            .frame(height: 4)
                            .frame(height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Slide \(index + 1) of \(slideCount)")
                    .accessibilityAddTraits(index == page ? .isSelected : [])
                }
            }
            .padding(.horizontal, 24)

            HStack(spacing: 12) {
                Button {
                    move(to: page - 1)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.caption.weight(.bold))
                        Text("Previous")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(page == 0 ? .white.opacity(0.32) : .white)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 40)
                    .background(.white.opacity(page == 0 ? 0.05 : 0.11), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(page == 0 ? 0.07 : 0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(page == 0)

                Spacer()

                Button {
                    move(to: page + 1)
                } label: {
                    HStack(spacing: 5) {
                        Text("Next")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(page == slideCount - 1 ? .white.opacity(0.32) : wrappedInk)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 40)
                    .background(page == slideCount - 1 ? .white.opacity(0.05) : wrappedMint, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(page == slideCount - 1)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private func slide(_ index: Int, availableHeight: CGFloat) -> some View {
        let topCard = resolvedTopCard
        let rarity = summary.topCard?.rarity ?? Rarity(minutes: summary.topDeviceMinutes)

        if summary.isThinData {
            if index == 0 {
                VStack(spacing: 18) {
                    heroPedestal(card: topCard, size: 162, glow: rarity.glow)

                    VStack(spacing: 8) {
                        Text("\(summary.year.formatted(.number.grouping(.never)))")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .tracking(4)
                            .foregroundStyle(wrappedMint)
                        Text("First Card")
                            .font(.system(.largeTitle, design: .rounded, weight: .black))
                            .multilineTextAlignment(.center)
                        Text("Your listening year is taking shape.")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.78))
                            .multilineTextAlignment(.center)
                    }

                    if summary.totalMinutes == 0 {
                        Text("Listen with headphones to start your first card.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.84))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(.white.opacity(0.08), in: .rect(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.14), lineWidth: 1))
                    } else {
                        HStack(spacing: 12) {
                            metric(summary.totalMinutes.minutesText, label: "Time listened")
                            metric(summary.activeDays.formatted(), label: "Active days")
                        }
                    }
                }
            } else {
                VStack(spacing: 16) {
                    heading("Mini-Snapshot")
                    if summary.totalMinutes > 0 {
                        let scale = posterScale(for: availableHeight)
                        WrappedReelPoster(
                            summary: summary,
                            progress: 0.12,
                            colorOption: resolvedColor,
                            proFoil: resolvedProFoil
                        )
                        .clipShape(.rect(cornerRadius: 26))
                        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(.white.opacity(0.16), lineWidth: 1))
                        .scaleEffect(scale)
                        .frame(width: WrappedReelPoster.size.width * scale, height: WrappedReelPoster.size.height * scale)
                        .shadow(color: wrappedMint.opacity(0.18), radius: 20, y: 8)
                        .accessibilityHidden(true)

                        exportButtons
                    } else {
                        HStack(spacing: 12) {
                            metric(summary.totalMinutes.minutesText, label: "Time listened")
                            metric(summary.activeDays.formatted(), label: "Active days")
                        }
                        Text("Listen with headphones to start your first card.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                    }
                }
            }
        } else {
            switch index {
            case 0:
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("\(summary.year.formatted(.number.grouping(.never))) WRAPPED")
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                            .tracking(3.6)
                            .foregroundStyle(wrappedMint)
                        heading("Your listening year")
                    }

                    VStack(spacing: 8) {
                        Text(summary.totalMinutes.minutesText)
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, wrappedMint],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("Time listened")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.76))
                    }
                    .padding(.vertical, 26)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(wrappedMint.opacity(0.28), lineWidth: 1)
                    )
                    .accessibilityElement(children: .combine)

                    HStack(spacing: 12) {
                        metric(summary.activeDays.formatted(), label: "Active days")
                        metric(summary.totalSessions.formatted(), label: "Sessions")
                    }
                }

            case 1:
                let sharePercent = summary.totalMinutes > 0
                    ? Int(((summary.topDeviceMinutes / summary.totalMinutes) * 100).rounded())
                    : 100
                VStack(spacing: 18) {
                    heading("Top headphones")

                    heroPedestal(card: topCard, size: 176, glow: rarity.glow)

                    VStack(spacing: 8) {
                        Text(verbatim: localizedDeviceName(summary.topDeviceName))
                            .font(.system(.title, design: .rounded, weight: .black))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)

                        if summary.topDeviceModel != summary.topDeviceName {
                            Text(verbatim: localizedDeviceName(summary.topDeviceModel))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.76))
                        }

                        Text(LocalizedStringKey(rarity.title))
                            .font(.caption.weight(.heavy))
                            .tracking(1.1)
                            .foregroundStyle(wrappedInk)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(wrappedMint, in: Capsule())
                            .padding(.top, 2)
                    }

                    HStack(spacing: 12) {
                        metric(summary.topDeviceMinutes.minutesText, label: "Time with this pair")
                        metric("\(sharePercent)%", label: "Share of year")
                    }
                }

            case 2:
                VStack(spacing: 18) {
                    heading("Your listening rhythm")

                    if let month = summary.peakMonth, let name = monthName(month) {
                        VStack(spacing: 6) {
                            Text("Peak month")
                                .font(.caption.weight(.heavy))
                                .tracking(1.4)
                                .textCase(.uppercase)
                                .foregroundStyle(.white.opacity(0.68))
                            Text(name)
                                .font(.system(size: 38, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            Text(summary.peakMonthMinutes.minutesText)
                                .font(.title3.weight(.heavy))
                                .foregroundStyle(wrappedMint)
                        }
                        .padding(.vertical, 22)
                        .padding(.horizontal, 18)
                        .frame(maxWidth: .infinity)
                        .background(.white.opacity(0.08), in: .rect(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.16), lineWidth: 1))
                        .accessibilityElement(children: .combine)
                    }

                    HStack(spacing: 12) {
                        metric(summary.longestStreakDays.formatted(), label: "Longest streak in days")
                        let dailyAvg = summary.activeDays > 0 ? summary.totalMinutes / Double(summary.activeDays) : 0
                        metric(dailyAvg.minutesText, label: "Daily average")
                    }
                }

            case 3:
                VStack(spacing: 18) {
                    heading("How you listened")

                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(wrappedMint.opacity(0.14))
                                .frame(width: 96, height: 96)
                            Circle()
                                .strokeBorder(wrappedMint.opacity(0.42), lineWidth: 1.5)
                                .frame(width: 96, height: 96)
                            Image(systemName: personaSymbol(summary.persona))
                                .font(.system(size: 38, weight: .semibold))
                                .foregroundStyle(wrappedMint)
                        }
                        .accessibilityHidden(true)

                        Text(LocalizedStringKey(summary.persona.title))
                            .font(.system(.title, design: .rounded, weight: .black))
                            .multilineTextAlignment(.center)

                        Text(LocalizedStringKey(summary.persona.detail))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.80))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 12)
                    }

                    HStack(spacing: 12) {
                        metric(
                            summary.whoSafeWeeksCount.formatted(),
                            label: "Weeks within the WHO listening budget"
                        )
                        if summary.averageDecibels > 0 {
                            metric(
                                summary.averageDecibels.formatted(.number.precision(.fractionLength(0))) + " dB",
                                label: "Average listening level"
                            )
                        }
                    }
                }

            default:
                let scale = posterScale(for: availableHeight)
                VStack(spacing: 16) {
                    heading("Your Wrapped card")
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || page != index || exportTask != nil)) { timeline in
                        let t = reduceMotion ? 0.08 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) / 6
                        WrappedFinalePoster(
                            summary: summary,
                            progress: t,
                            showsModel: page == index && exportTask == nil,
                            colorOption: resolvedColor,
                            proFoil: resolvedProFoil
                        )
                        .clipShape(.rect(cornerRadius: 28))
                        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(.white.opacity(0.18), lineWidth: 1.2))
                        .scaleEffect(scale)
                        .frame(width: WrappedReelPoster.size.width * scale, height: WrappedReelPoster.size.height * scale)
                        .shadow(color: wrappedMint.opacity(0.18), radius: 22, y: 10)
                        .accessibilityHidden(true)
                    }
                    exportButtons
                }
            }
        }
    }

    private func posterScale(for availableHeight: CGFloat) -> CGFloat {
        // Reserve room for slide heading (~46), export buttons (~118), and vertical spacing (~44).
        let targetHeight = max(280, min(410, availableHeight - 208))
        return max(0.46, min(0.62, targetHeight / WrappedReelPoster.size.height))
    }

    private func heroPedestal(card: HeadphoneCard, size: CGFloat, glow: Color) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [glow.opacity(0.32), wrappedMint.opacity(0.14), .clear],
                        center: .center,
                        startRadius: 12,
                        endRadius: size * 0.65
                    )
                )
                .frame(width: size * 1.25, height: size * 1.25)
            Circle()
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                .frame(width: size, height: size)
            WrappedHeroArtwork(
                card: card,
                colorOption: resolvedColor,
                fallbackSymbol: summary.topDeviceSymbol
            )
            .frame(width: size * 0.78, height: size * 0.78)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func personaSymbol(_ persona: ListeningPersona) -> String {
        switch persona {
        case .nightOwl: "moon.stars.fill"
        case .commuter: "tram.fill"
        case .earlyBird: "sunrise.fill"
        case .allDay: "headphones"
        }
    }

    private func heading(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(.largeTitle, design: .rounded, weight: .black))
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
    }

    private func metric(_ value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(wrappedMint)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.80))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.14), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var exportButtons: some View {
        VStack(spacing: 10) {
            Button {
                exportVideo(.mp4)
            } label: {
                Label("Export 3D Reel (MP4)", systemImage: "film")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(wrappedInk)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(wrappedMint, in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                exportVideo(.gif)
            } label: {
                Label("Export Animated GIF", systemImage: "photo.stack")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(.white.opacity(0.11), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.20), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .disabled(exportTask != nil || archiveTask != nil)
    }

    private func localizedDeviceName(_ name: String) -> String {
        switch name {
        case "Studio Headphones", "Over-ear headphones":
            AppLanguage.systemResolved(preferredLanguages: [locale.identifier]).text(name)
        default:
            name
        }
    }

    private func monthName(_ month: Int) -> String? {
        let formatter = DateFormatter()
        formatter.locale = locale
        let names = formatter.standaloneMonthSymbols ?? []
        return names.indices.contains(month - 1) ? names[month - 1] : nil
    }

    private func move(to index: Int) {
        guard (0..<slideCount).contains(index) else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) { page = index }
    }

    private func exportVideo(_ format: CardVideoExporter.Format) {
        guard proAccess.isUnlocked(.wrappedVideo) else {
            if proStore != nil {
                paywallFeature = .wrappedVideo
            } else {
                ProPaywallRequester.request(feature: .wrappedVideo)
            }
            return
        }
        guard exportTask == nil, archiveTask == nil else { return }
        let color = resolvedColor
        let foil = resolvedProFoil
        exportProgress = 0
        exportTask = Task {
            defer { exportTask = nil }
            do {
                let url = try await CardVideoExporter().export(
                    format,
                    summary: summary,
                    colorOption: color,
                    proFoil: foil,
                    locale: locale
                ) {
                    exportProgress = $0
                }
                shareURL = url
                showShare = true
            } catch is CancellationError {
                return
            } catch {
                if !Task.isCancelled { exportFailed = true }
            }
        }
    }

    private func exportArchive(_ format: ArchiveExporter.Format, aggregate: ListeningAggregate) {
        guard proAccess.isUnlocked(.archiveExport) else {
            if proStore != nil {
                paywallFeature = .archiveExport
            } else {
                ProPaywallRequester.request(feature: .archiveExport)
            }
            return
        }
        guard archiveTask == nil, exportTask == nil else { return }
        let cards = cards
        archiveTask = Task {
            defer { archiveTask = nil }
            do {
                let file = try await Task.detached(priority: .userInitiated) {
                    try ArchiveExporter.export(format, aggregate: aggregate, cards: cards)
                }.value
                if Task.isCancelled {
                    try? FileManager.default.removeItem(at: file.url.deletingLastPathComponent())
                    return
                }
                shareURL = file.url
                showShare = true
            } catch {
                if !Task.isCancelled { exportFailed = true }
            }
        }
    }

    private func clearShare() {
        if let shareURL {
            try? FileManager.default.removeItem(at: shareURL.deletingLastPathComponent())
        }
        shareURL = nil
    }
}

/// Real product render for Earprint Wrapped with a glowing SF Symbol fallback for non-collectible generic models.
struct WrappedHeroArtwork: View {
    let card: HeadphoneCard
    var colorOption: DeviceColorOption? = nil
    var fallbackSymbol: String = "headphones"

    var body: some View {
        if card.modelKey.collectibleArtwork != nil {
            HeadphoneArtwork(card: card, colorOption: colorOption, showsChargingCase: false, showsShadow: false)
                .shadow(color: .black.opacity(0.45), radius: 10, y: 6)
        } else {
            Image(systemName: fallbackSymbol)
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(wrappedMint)
        }
    }
}

private struct WrappedActivitySheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct WrappedFinalePoster: View {
    let summary: WrappedSummary
    let progress: Double
    let showsModel: Bool
    var colorOption: DeviceColorOption? = nil
    var proFoil: ProFoilStyle? = nil

    var body: some View {
        #if targetEnvironment(simulator)
        WrappedReelPoster(
            summary: summary,
            progress: progress,
            includesHeadphones: true,
            colorOption: colorOption,
            proFoil: proFoil
        )
        #else
        if showsModel {
            let modelKey = summary.topDeviceKey
            let rarity = summary.topCard?.rarity ?? Rarity(minutes: summary.topDeviceMinutes)
            let finish = (colorOption ?? DeviceColorOption.defaultOption(for: modelKey))?.modelFinish
                ?? HeadphoneFinish.glossWhite
            let tintColors = (proFoil?.baseColors ?? rarity.baseColors).map { UIColor($0) }

            WrappedReelPoster(
                summary: summary,
                progress: progress,
                includesHeadphones: false,
                colorOption: colorOption,
                proFoil: proFoil
            )
            .overlay(alignment: .topLeading) {
                RealityView { content in
                    content.camera = .virtual
                    content.add(WrappedHeadphoneScene.makeCamera())
                    for light in WrappedHeadphoneScene.makeLights() { content.add(light) }

                    let model = await WrappedHeadphoneScene.makeHeadphones(
                        modelKey: modelKey,
                        finish: finish
                    )
                    model.name = "Wrapped headphones"
                    model.orientation = WrappedHeadphoneScene.orientation(at: progress)
                    if let iblEnv = try? await StudioEnvironment.make(tint: tintColors) {
                        let iblEntity = Entity()
                        iblEntity.components.set(ImageBasedLightComponent(source: .single(iblEnv), intensityExponent: 1.25))
                        content.add(iblEntity)
                        WrappedHeadphoneScene.applyReceiver(
                            ImageBasedLightReceiverComponent(imageBasedLight: iblEntity),
                            to: model
                        )
                    }
                    content.add(model)
                } update: { content in
                    content.entities.first { $0.name == "Wrapped headphones" }?.orientation =
                        WrappedHeadphoneScene.orientation(at: progress)
                } placeholder: {
                    WrappedHeroArtwork(
                        card: summary.topCard ?? .wrappedFallback(from: summary),
                        colorOption: colorOption,
                        fallbackSymbol: summary.topDeviceSymbol
                    )
                    .frame(width: 142, height: 142)
                }
                .frame(width: 274, height: 274)
                .offset(x: 43, y: WrappedReelPoster.modelCenter - 137)
                .allowsHitTesting(false)
            }
        } else {
            WrappedReelPoster(
                summary: summary,
                progress: progress,
                includesHeadphones: true,
                colorOption: colorOption,
                proFoil: proFoil
            )
        }
        #endif
    }
}

/// Shared fixed layout for the in-app finale, 3D background and SwiftUI fallback.
struct WrappedReelPoster: View {
    static let size = CGSize(width: 360, height: 640)
    static let modelCenter: CGFloat = 296

    let summary: WrappedSummary
    let progress: Double
    var includesHeadphones = true
    var colorOption: DeviceColorOption? = nil
    var proFoil: ProFoilStyle? = nil

    private var posterCard: HeadphoneCard {
        summary.topCard ?? .wrappedFallback(from: summary)
    }

    var body: some View {
        let wave = sin(progress * 2 * .pi)
        let phase = cos(progress * 2 * .pi)
        let rarity = summary.topCard?.rarity ?? Rarity(minutes: summary.topDeviceMinutes)
        let cardFoil = proFoil ?? .obsidianPrism
        let accentGlow = cardFoil.glow

        ZStack {
            LinearGradient(
                colors: [wrappedInk, wrappedDeepTeal, wrappedPlum, wrappedInk],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [accentGlow.opacity(0.28), wrappedMint.opacity(0.16), .clear],
                center: UnitPoint(x: 0.5 + wave * 0.14, y: 0.46),
                startRadius: 16,
                endRadius: 245
            )
            ForEach(0..<4) { ring in
                Ellipse()
                    .strokeBorder(wrappedMint.opacity(0.11 - Double(ring) * 0.015), lineWidth: 1)
                    .frame(width: CGFloat(228 + ring * 38), height: CGFloat(84 + ring * 28))
                    .rotationEffect(.degrees(-24))
                    .position(x: 180, y: Self.modelCenter)
            }

            VStack(spacing: 6) {
                Text(summary.year.formatted(.number.grouping(.never)))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(wrappedMint)
                Text(summary.isThinData ? "First Card" : "Earprint Wrapped")
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 20)
            }
            .position(x: 180, y: 92)

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(wrappedInk.opacity(0.88))
                FoilSurface(rarity: rarity, tilt: CGSize(width: wave, height: phase * 0.5), proFoil: cardFoil)
                    .opacity(0.88)
                    .clipShape(.rect(cornerRadius: 24))
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [wrappedMint.opacity(0.75), accentGlow.opacity(0.45), .white.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                if includesHeadphones {
                    WrappedHeroArtwork(
                        card: posterCard,
                        colorOption: colorOption,
                        fallbackSymbol: summary.topDeviceSymbol
                    )
                    .frame(width: 148, height: 148)
                }
            }
            .frame(width: 186, height: 244)
            .rotation3DEffect(.degrees(wave * 34), axis: (x: 0.05, y: 1, z: 0), perspective: 0.56)
            .rotationEffect(.degrees(phase * 4))
            .shadow(color: .black.opacity(0.58), radius: 24, y: 14)
            .position(x: 180, y: Self.modelCenter)

            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text(summary.topDeviceName)
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(LocalizedStringKey(rarity.title))
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1.3)
                        .foregroundStyle(wrappedInk)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(wrappedMint, in: Capsule())
                }

                HStack(spacing: 18) {
                    posterMetric(summary.totalMinutes.minutesText, label: "Time listened")
                    posterMetric(summary.activeDays.formatted(), label: "Active days")
                }
            }
            .padding(.horizontal, 26)
            .position(x: 180, y: 526)
        }
        .foregroundStyle(.white)
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
    }

    private func posterMetric(_ value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 25, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(wrappedMint)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

private extension HeadphoneCard {
    static func wrappedFallback(from summary: WrappedSummary) -> HeadphoneCard {
        HeadphoneCard(
            id: "wrapped-\(summary.topDeviceKey.rawValue)",
            nickname: summary.topDeviceName,
            model: summary.topDeviceModel,
            symbol: summary.topDeviceSymbol,
            lifetimeMinutes: summary.topDeviceMinutes,
            sessions: summary.totalSessions,
            longestMinutes: 0,
            averageDecibels: summary.averageDecibels,
            firstMet: "",
            lastUsed: "",
            serial: 1,
            grid: ListeningGrid(minutes: [], decibels: []),
            modelKey: summary.topDeviceKey,
            kind: summary.topDeviceKey.kind
        )
    }
}
