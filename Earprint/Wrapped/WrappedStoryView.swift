import RealityKit
import SwiftUI

private let wrappedMint = Color(red: 0.68, green: 0.97, blue: 0.87)
private let wrappedInk = Color(red: 0.035, green: 0.071, blue: 0.092)
private let wrappedPlum = Color(red: 0.20, green: 0.11, blue: 0.28)

struct WrappedStoryView: View {
    let summary: WrappedSummary
    var aggregate: ListeningAggregate? = nil
    var cards: [HeadphoneCard] = []

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.proAccess) private var proAccess
    @Environment(ProEntitlementStore.self) private var proStore: ProEntitlementStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var exportProgress = 0.0
    @State private var exportTask: Task<Void, Never>?
    @State private var archiveTask: Task<Void, Never>?
    @State private var shareItem: ShareItem?
    @State private var showShare = false
    @State private var exportFailed = false
    @State private var paywallFeature: ProFeature?

    private enum ShareItem {
        case video(URL)
        case archive(ArchiveExportFile)

        var url: URL {
            switch self {
            case .video(let url): url
            case .archive(let file): file.url
            }
        }
    }

    private var slideCount: Int { summary.isThinData ? 2 : 5 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                TabView(selection: $page) {
                    ForEach(0..<slideCount, id: \.self) { index in
                        ScrollView {
                            slide(index)
                                .frame(maxWidth: 460)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 12)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 6) {
                    ForEach(0..<slideCount, id: \.self) { index in
                        Button {
                            move(to: index)
                        } label: {
                            Capsule()
                                .fill(index == page ? wrappedMint : .white.opacity(0.25))
                                .frame(height: 4)
                                .frame(height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Slide \(index + 1) of \(slideCount)")
                        .accessibilityAddTraits(index == page ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 24)

                HStack {
                    Button {
                        move(to: page - 1)
                    } label: {
                        Label("Previous", systemImage: "chevron.left")
                    }
                    .disabled(page == 0)
                    Spacer()
                    Button {
                        move(to: page + 1)
                    } label: {
                        Label("Next", systemImage: "chevron.right")
                            .labelStyle(.titleAndIcon)
                    }
                    .disabled(page == slideCount - 1)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .background {
                LinearGradient(colors: [wrappedInk, wrappedPlum, wrappedInk], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
            }
            .foregroundStyle(.white)
            .tint(wrappedMint)
            .navigationTitle("Earprint Wrapped")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if let aggregate {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Export CSV") { exportArchive(.csv, aggregate: aggregate) }
                            Button("Export JSON") { exportArchive(.json, aggregate: aggregate) }
                        } label: {
                            Label("Listening archive", systemImage: "archivebox")
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
                    Color.black.opacity(0.65).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView(value: exportProgress)
                            .accessibilityLabel("Rendering your reel")
                        Text("Rendering your reel")
                            .font(.headline)
                        Button("Cancel") { exportTask?.cancel() }
                            .buttonStyle(.bordered)
                    }
                    .padding(22)
                    .frame(maxWidth: 280)
                    .background(.regularMaterial, in: .rect(cornerRadius: 20))
                }
                .tint(wrappedMint)
            }
        }
        .sheet(isPresented: $showShare, onDismiss: clearShare) {
            switch shareItem {
            case .video(let url):
                WrappedActivitySheet(url: url)
            case .archive(let file):
                NavigationStack {
                    ShareLink(item: file, preview: SharePreview("Listening archive")) {
                        Label("Share archive", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .navigationTitle("Listening archive")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showShare = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            case nil:
                EmptyView()
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
        .onDisappear {
            exportTask?.cancel()
            archiveTask?.cancel()
        }
        .onChange(of: slideCount) { _, count in page = min(page, count - 1) }
    }

    @ViewBuilder
    private func slide(_ index: Int) -> some View {
        if summary.isThinData {
            if index == 0 {
                VStack(spacing: 14) {
                    WrappedHeadphoneMark(overEar: summary.topDeviceKey.kind == .overEar)
                        .foregroundStyle(wrappedMint)
                        .frame(width: 122, height: 122)
                        .accessibilityHidden(true)
                    Text("\(summary.year.formatted(.number.grouping(.never))) First Card")
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                    Text("Your listening year is taking shape.")
                        .foregroundStyle(.white.opacity(0.78))
                    if summary.totalMinutes == 0 {
                        Text("Listen with headphones to start your first card.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 16) {
                    Text("Mini-Snapshot").font(.system(.title, design: .rounded, weight: .black))
                    metric(summary.totalMinutes.minutesText, label: "Time listened")
                    metric(summary.activeDays.formatted(), label: "Active days")
                    exportButtons
                }
            }
        } else {
            switch index {
            case 0:
                VStack(spacing: 14) {
                    heading("Your listening year")
                    metric(summary.totalMinutes.minutesText, label: "Time listened")
                    HStack(spacing: 12) {
                        metric(summary.activeDays.formatted(), label: "Active days")
                        metric(summary.totalSessions.formatted(), label: "Sessions")
                    }
                }
            case 1:
                VStack(spacing: 14) {
                    heading("Top headphones")
                    WrappedHeadphoneMark(overEar: summary.topDeviceKey.kind == .overEar)
                        .foregroundStyle(wrappedMint)
                        .frame(width: 120, height: 120)
                        .accessibilityHidden(true)
                    Text(verbatim: localizedDeviceName(summary.topDeviceName))
                        .font(.system(.title, design: .rounded, weight: .black))
                        .multilineTextAlignment(.center)
                    if summary.topDeviceModel != summary.topDeviceName {
                        Text(verbatim: localizedDeviceName(summary.topDeviceModel)).foregroundStyle(.white.opacity(0.76))
                    }
                    let rarity = summary.topCard?.rarity ?? Rarity(minutes: summary.topDeviceMinutes)
                    Text(LocalizedStringKey(rarity.title))
                        .font(.caption.weight(.heavy))
                        .tracking(1.1)
                        .foregroundStyle(wrappedMint)
                    metric(summary.topDeviceMinutes.minutesText, label: "Time with this pair")
                }
            case 2:
                VStack(spacing: 14) {
                    heading("Your listening rhythm")
                    if let month = summary.peakMonth, let name = monthName(month) {
                        metric(name, label: "Peak month")
                        metric(summary.peakMonthMinutes.minutesText, label: "Time in peak month")
                    }
                    metric(summary.longestStreakDays.formatted(), label: "Longest streak in days")
                }
            case 3:
                VStack(spacing: 14) {
                    heading("How you listened")
                    Text(summary.persona.emoji).font(.system(size: 56)).accessibilityHidden(true)
                    Text(LocalizedStringKey(summary.persona.title))
                        .font(.system(.title, design: .rounded, weight: .black))
                        .multilineTextAlignment(.center)
                    metric(summary.whoSafeWeeksCount.formatted(), label: "Weeks within the WHO listening budget")
                    if summary.averageDecibels > 0 {
                        metric(summary.averageDecibels.formatted(.number.precision(.fractionLength(0))) + " dB", label: "Average listening level")
                    }
                }
            default:
                VStack(spacing: 14) {
                    heading("Your Wrapped card")
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || page != index || exportTask != nil)) { timeline in
                        let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) / 6
                        WrappedFinalePoster(summary: summary, progress: t,
                                            showsModel: page == index && exportTask == nil)
                            .scaleEffect(0.47)
                            .frame(width: WrappedReelPoster.size.width * 0.47, height: WrappedReelPoster.size.height * 0.47)
                            .accessibilityHidden(true)
                    }
                    exportButtons
                }
            }
        }
    }

    private func heading(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(.largeTitle, design: .rounded, weight: .black))
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
    }

    private func metric(_ value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title, design: .rounded, weight: .heavy))
                .foregroundStyle(wrappedMint)
                .minimumScaleFactor(0.65)
            Text(label).font(.subheadline).foregroundStyle(.white.opacity(0.8))
        }
        .multilineTextAlignment(.center)
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.075), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private var exportButtons: some View {
        VStack(spacing: 8) {
            Button {
                exportVideo(.mp4)
            } label: {
                Label("Export 3D Reel (MP4)", systemImage: "film")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button {
                exportVideo(.gif)
            } label: {
                Label("Export Animated GIF", systemImage: "photo.stack")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.large)
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
        exportProgress = 0
        exportTask = Task {
            defer { exportTask = nil }
            do {
                let url = try await CardVideoExporter().export(format, summary: summary, locale: locale) {
                    exportProgress = $0
                }
                shareItem = .video(url)
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
                shareItem = .archive(file)
                showShare = true
            } catch {
                if !Task.isCancelled { exportFailed = true }
            }
        }
    }

    private func clearShare() {
        if let shareItem {
            try? FileManager.default.removeItem(at: shareItem.url.deletingLastPathComponent())
        }
        shareItem = nil
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

    var body: some View {
        #if targetEnvironment(simulator)
        WrappedReelPoster(summary: summary, progress: progress)
        #else
        if showsModel {
            let overEar = summary.topDeviceKey.kind == .overEar
            WrappedReelPoster(summary: summary, progress: progress, includesHeadphones: false)
                .overlay(alignment: .topLeading) {
                    RealityView { content in
                        content.camera = .virtual
                        content.add(WrappedHeadphoneScene.makeCamera())
                        for light in WrappedHeadphoneScene.makeLights() { content.add(light) }
                        let model = WrappedHeadphoneScene.makeHeadphones(overEar: overEar)
                        model.name = "Wrapped headphones"
                        model.orientation = WrappedHeadphoneScene.orientation(at: progress)
                        content.add(model)
                    } update: { content in
                        content.entities.first { $0.name == "Wrapped headphones" }?.orientation =
                            WrappedHeadphoneScene.orientation(at: progress)
                    } placeholder: {
                        WrappedHeadphoneMark(overEar: overEar)
                            .fill(wrappedMint)
                            .frame(width: 125, height: 125)
                    }
                    .frame(width: 274, height: 274)
                    .offset(x: 43, y: WrappedReelPoster.modelCenter - 137)
                    .allowsHitTesting(false)
                }
        } else {
            WrappedReelPoster(summary: summary, progress: progress)
        }
        #endif
    }
}

/// Original vector artwork used on the reel and enhanced share posters.
struct WrappedHeadphoneMark: Shape {
    var overEar: Bool

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        guard side > 0 else { return Path() }

        var shape = Path()
        if overEar {
            var band = Path()
            band.move(to: CGPoint(x: 18, y: 60))
            band.addQuadCurve(to: CGPoint(x: 50, y: 17), control: CGPoint(x: 14, y: 17))
            band.addQuadCurve(to: CGPoint(x: 82, y: 60), control: CGPoint(x: 86, y: 17))
            shape.addPath(band.strokedPath(StrokeStyle(lineWidth: 7, lineCap: .round)))
            shape.addRoundedRect(in: CGRect(x: 7, y: 51, width: 26, height: 34), cornerSize: CGSize(width: 10, height: 10))
            shape.addRoundedRect(in: CGRect(x: 67, y: 51, width: 26, height: 34), cornerSize: CGSize(width: 10, height: 10))
        } else {
            shape.addEllipse(in: CGRect(x: 13, y: 31, width: 34, height: 38))
            shape.addEllipse(in: CGRect(x: 53, y: 18, width: 34, height: 38))
            shape.addRoundedRect(in: CGRect(x: 28, y: 53, width: 12, height: 22), cornerSize: CGSize(width: 6, height: 6))
            shape.addRoundedRect(in: CGRect(x: 60, y: 40, width: 12, height: 22), cornerSize: CGSize(width: 6, height: 6))
        }
        let scale = side / 100
        let transform = CGAffineTransform(a: scale, b: 0, c: 0, d: scale,
                                          tx: rect.midX - side / 2, ty: rect.midY - side / 2)
        return shape.applying(transform)
    }
}

/// Shared fixed layout for the in-app finale, 3D background and SwiftUI fallback.
struct WrappedReelPoster: View {
    static let size = CGSize(width: 360, height: 640)
    static let modelCenter: CGFloat = 317

    let summary: WrappedSummary
    let progress: Double
    var includesHeadphones = true

    var body: some View {
        let wave = sin(progress * 2 * .pi)
        let phase = cos(progress * 2 * .pi)
        let rarity = summary.topCard?.rarity ?? Rarity(minutes: summary.topDeviceMinutes)
        ZStack {
            LinearGradient(colors: [wrappedInk, wrappedPlum, wrappedInk], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [wrappedMint.opacity(0.24), .clear],
                           center: UnitPoint(x: 0.5 + wave * 0.17, y: 0.49), startRadius: 14, endRadius: 240)
            ForEach(0..<5) { ring in
                Ellipse()
                    .strokeBorder(wrappedMint.opacity(0.12), lineWidth: 1)
                    .frame(width: CGFloat(224 + ring * 38), height: CGFloat(88 + ring * 31))
                    .rotationEffect(.degrees(-31))
                    .position(x: 180, y: Self.modelCenter)
            }

            VStack(spacing: 7) {
                Text(summary.year.formatted(.number.grouping(.never)))
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(wrappedMint)
                Text(summary.isThinData ? "First Card" : "Earprint Wrapped")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 22)
            }
            .position(x: 180, y: 111)

            ZStack {
                RoundedRectangle(cornerRadius: 23)
                    .fill(wrappedInk.opacity(0.84))
                FoilSurface(rarity: rarity, tilt: CGSize(width: wave, height: phase * 0.5), proFoil: .obsidianPrism)
                    .opacity(0.82)
                    .clipShape(.rect(cornerRadius: 23))
                RoundedRectangle(cornerRadius: 23)
                    .strokeBorder(wrappedMint.opacity(0.58), lineWidth: 1.5)
                if includesHeadphones {
                    WrappedHeadphoneMark(overEar: summary.topDeviceKey.kind == .overEar)
                        .fill(LinearGradient(colors: [.white, wrappedMint, Color(red: 0.30, green: 0.67, blue: 0.72)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 125, height: 125)
                        .shadow(color: .black.opacity(0.52), radius: 9, y: 7)
                }
            }
            .frame(width: 179, height: 236)
            .rotation3DEffect(.degrees(wave * 42), axis: (x: 0.06, y: 1, z: 0), perspective: 0.56)
            .rotationEffect(.degrees(phase * 5))
            .shadow(color: .black.opacity(0.55), radius: 24, y: 14)
            .position(x: 180, y: Self.modelCenter)

            HStack(spacing: 20) {
                posterMetric(summary.totalMinutes.minutesText, label: "Time listened")
                posterMetric(summary.activeDays.formatted(), label: "Active days")
            }
            .padding(.horizontal, 30)
            .position(x: 180, y: 541)
        }
        .foregroundStyle(.white)
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
    }

    private func posterMetric(_ value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(wrappedMint)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.76))
        }
        .frame(maxWidth: .infinity)
    }
}
