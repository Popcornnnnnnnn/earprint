import SwiftUI

/// Caches generated sample dossiers so SwiftUI parent re-evaluations never regenerate sessions synchronously.
@MainActor
private enum DossierSampleCache {
    private struct Key: Hashable {
        let id: String
        let minutes: Int
        let sessions: Int
        let firstMet: String
        let lastUsed: String
        let isDemo: Bool
        let dayStart: TimeInterval
    }

    private static var entries: [Key: DeviceDossier] = [:]

    static func dossier(for card: HeadphoneCard, isDemo: Bool, referenceDate: Date) -> DeviceDossier {
        let key = Key(
            id: card.id,
            minutes: Int(card.lifetimeMinutes.rounded()),
            sessions: card.sessions,
            firstMet: card.firstMet,
            lastUsed: card.lastUsed,
            isDemo: isDemo,
            dayStart: Calendar.current.startOfDay(for: referenceDate).timeIntervalSince1970
        )
        if let cached = entries[key] { return cached }
        if entries.count > 12 { entries.removeAll(keepingCapacity: true) }
        let built = DeviceDossier.sample(for: card, now: referenceDate)
        entries[key] = built
        return built
    }
}

/// Full-screen dossier for a single headphone: PSA-style grading slab, period airtime,
/// interactive trend & 24-hour charts, listening habits, milestones, and hardware certificate.
struct DeviceDossierView: View {
    let card: HeadphoneCard
    let dossier: DeviceDossier
    var onClose: (() -> Void)?
    private let includesHealthDetails: Bool
    private let isSampleData: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(DeviceColorStore.self) private var colorStore: DeviceColorStore?

    @State private var period: DossierPeriod = .month
    @State private var selectedDate: Date?
    @State private var selectedHour: Int?
    @State private var slabFlipped = false
    @State private var demoTilt: CGSize = .zero
    @State private var showStickyIdentity = false
    @State private var demoStarted = false
    @State private var showShare = false
    @State private var shareInitialFormat: DossierShareFormat = .simple
    @State private var showSlabStudio = false

    init(card: HeadphoneCard, dossier: DeviceDossier? = nil, isSampleData: Bool = false, onClose: (() -> Void)? = nil) {
        self.card = card
        // Keep fixed referenceNow for deterministic demo launches; use current date for live cards.
        let args = ProcessInfo.processInfo.arguments
        let isDemo = args.contains("-dossier") || args.contains("-dossierDemo") || args.contains("-demo")
        let referenceDate = isDemo ? DossierSample.referenceNow : max(DossierSample.referenceNow, Date())
        self.dossier = dossier ?? DossierSampleCache.dossier(for: card, isDemo: isDemo, referenceDate: referenceDate)
        includesHealthDetails = dossier != nil
        self.isSampleData = isSampleData
        self.onClose = onClose
    }

    private var stats: PeriodStats { dossier.stats(period) }
    private var rarity: Rarity { card.rarity }
    private var tiltActive: Bool { !showShare && !showSlabStudio }
    private var demoOverrideTilt: CGSize? { demoTilt == .zero ? nil : demoTilt }

    var body: some View {
        ZStack {
            backdrop
            ScrollViewReader { proxy in
                ScrollView {
                    dossierContent(exporting: false)
                    .padding(.top, 8)
                    .padding(.bottom, 48)
                }
                .scrollIndicators(.hidden)
                .pauseMotionWhileScrolling("dossier")
                .onScrollGeometryChange(for: Bool.self) { geo in
                    (geo.contentOffset.y + geo.contentInsets.top) > 380
                } action: { _, shouldShow in
                    if showStickyIdentity != shouldShow {
                        showStickyIdentity = shouldShow
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    topBar(proxy: proxy)
                }
                .task {
                    await handleLaunchArguments(proxy: proxy)
                }
            }
        }
        .foregroundStyle(DossierPalette.primaryText)
        .sheet(isPresented: $showShare) {
            DossierShareSheet(
                card: card,
                dossier: dossier,
                period: period,
                color: colorStore?.selectedColor(for: card),
                isSampleData: isSampleData,
                initialFormat: shareInitialFormat
            )
        }
        .sheet(isPresented: $showSlabStudio) {
            CustomizeSlabSheet(card: card, dossier: dossier)
        }
        .onChange(of: period) {
            selectedDate = nil
            selectedHour = nil
        }
    }

    private func dossierContent(exporting: Bool) -> some View {
        VStack(spacing: 22) {
            if exporting {
                HStack {
                    Text("Device Dossier")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Spacer()
                    dataSourceNote
                }
                .foregroundStyle(DossierPalette.primaryText.opacity(0.8))
                .padding(.top, 4)
            }
            slabStage(exporting: exporting)
                .id("slab")
            if exporting {
                CardBack(card: card)
            }
            airtimeSection(exporting: exporting)
                .padding(.top, 10)
                .id("airtime")
            rhythmSection(exporting: exporting)
                .padding(.top, 10)
                .id("charts")
            habitsSection.padding(.top, 10).id("habits")
            milestonesSection.padding(.top, 10).id("milestones")
            certificateSection(exporting: exporting)
                .padding(.top, 10)
                .id("certificate")
            if includesHealthDetails && !exporting { footerNote }
        }
        .padding(.horizontal, 18)
    }

    @ViewBuilder
    private var dataSourceNote: some View {
        #if DEBUG
        if !ProcessInfo.processInfo.arguments.contains("-hideSampleBanner") {
            rawDataSourceNote
        }
        #else
        rawDataSourceNote
        #endif
    }

    @ViewBuilder
    private var rawDataSourceNote: some View {
        if isSampleData {
            Text("Sample data").font(.caption)
        } else if !includesHealthDetails {
            Text("Dossier details are illustrative.").font(.caption)
        }
    }

    // MARK: - Backdrop & Sticky Header

    private var backdrop: some View {
        let isLight = colorScheme == .light
        return ZStack {
            DossierPalette.ink.ignoresSafeArea()
            RadialGradient(
                colors: [rarity.glow.opacity(isLight ? 0.14 : 0.24), rarity.accent.opacity(isLight ? 0.04 : 0.06), .clear],
                center: UnitPoint(x: 0.5, y: 0.14),
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()
        }
    }

    private func topBar(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                    proxy.scrollTo("slab", anchor: .top)
                }
            } label: {
                if showStickyIdentity {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(rarity.foil)
                                .frame(width: 28, height: 28)
                            if card.modelKey.collectionArtwork != nil {
                                HeadphoneArtwork(
                                    card: card,
                                    colorOption: colorStore?.selectedColor(for: card),
                                    showsChargingCase: false,
                                    showsShadow: false
                                )
                                .frame(width: 22, height: 22)
                            } else {
                                Image(systemName: card.symbol)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(rarity.ink)
                            }
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(card.model)
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .lineLimit(1)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(rarity.accent)
                            .frame(width: 7, height: 7)
                            .shadow(color: rarity.glow, radius: 4)
                        Text(AppLanguage.current.text("DOSSIER · #%04d", card.serial))
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(DossierPalette.primaryText.opacity(0.75))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(DossierPalette.surfaceFill, in: Capsule())
                    .overlay(Capsule().strokeBorder(DossierPalette.hairline, lineWidth: 1))
                    .transition(.opacity)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            if showStickyIdentity {
                HStack(spacing: 5) {
                    Text("GRADE")
                        .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(DossierPalette.dim)
                    Text(dossier.grade.scoreText)
                        .font(.system(.subheadline, design: .rounded, weight: .black))
                        .foregroundStyle(rarity.accent)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(DossierPalette.surfaceFill, in: Capsule())
                .overlay(Capsule().strokeBorder(rarity.accent.opacity(0.3), lineWidth: 1))
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            Button {
                showShare = true
            } label: {
                topBarIcon("square.and.arrow.up")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share dossier")

            Button {
                if let onClose { onClose() } else { dismiss() }
            } label: {
                topBarIcon("xmark")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close dossier")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background {
            if showStickyIdentity {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(DossierPalette.ink.opacity(0.68))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(DossierPalette.hairline).frame(height: 1)
                    }
                    .ignoresSafeArea(edges: .top)
            }
        }
        .animation(.snappy(duration: 0.25), value: showStickyIdentity)
    }

    private func topBarIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(DossierPalette.primaryText.opacity(0.88))
            .frame(width: 34, height: 34)
            .background(DossierPalette.surfaceFill, in: Circle())
            .overlay(Circle().strokeBorder(DossierPalette.hairline, lineWidth: 1))
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }

    // MARK: - Hero Slab Stage

    private func slabStage(exporting: Bool) -> some View {
        VStack(spacing: 16) {
            LiveTiltView(
                isActive: !exporting && tiltActive && !showStickyIdentity,
                overrideTilt: exporting ? .zero : demoOverrideTilt
            ) { slabTilt in
                GradingSlab(
                    card: card,
                    dossier: dossier,
                    tilt: slabTilt,
                    flipped: !exporting && slabFlipped,
                    animateSeal: !exporting && tiltActive && !showStickyIdentity
                )
                    .rotation3DEffect(.degrees(Double(slabTilt.width) * 10), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                    .rotation3DEffect(.degrees(Double(-slabTilt.height) * 8), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.65, dampingFraction: 0.78)) {
                    slabFlipped.toggle()
                }
            }
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.75), trigger: slabFlipped)
            .padding(.top, 4)

            if !exporting {
                HStack(spacing: 8) {
                    Image(systemName: "hand.tap")
                        .font(.caption2.weight(.semibold))
                    Text(slabFlipped ? "Tap slab to view front" : "Tap slab to flip · tilt phone for foil")
                        .font(.caption)
                }
                .foregroundStyle(DossierPalette.dim)

                Button {
                    showSlabStudio = true
                } label: {
                    Label("Customize Slab", systemImage: "wand.and.stars")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DossierPalette.primaryText)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 42)
                        .background(DossierPalette.panel, in: Capsule())
                        .overlay(Capsule().strokeBorder(DossierPalette.hairline, lineWidth: 1))
                        .shadow(color: Theme.cardShadow, radius: 8, y: 3)
                }
                .buttonStyle(.plain)
            }

            lifetimeQuickStrip
        }
    }

    private var lifetimeQuickStrip: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                quickStat("LIFETIME", dossier.lifetimeMinutes.minutesText, accent: rarity.accent)
                stripDivider
                quickStat("FIRST WEAR", dossier.firstWear.map(DossierFormat.dot) ?? "—")
                stripDivider
                quickStat("LAST WEAR", dossier.lastWear.map { $0.start.dossierRelative(to: dossier.now, calendar: dossier.calendar) } ?? "—")
                stripDivider
                quickStat("RECORD DAYS", "\(dossier.recordDays) days")
            }
            .padding(.vertical, 12)
            .background(DossierPalette.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(DossierPalette.hairline, lineWidth: 1))

            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(rarity.accent.opacity(0.85))
                Text("\(dossier.hardware.manufacturer) · \(dossier.hardware.productID)")
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .foregroundStyle(DossierPalette.primaryText.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let fw = dossier.hardware.firmwareVersion {
                    Text("· FW \(fw)")
                        .font(.system(.caption2, design: .monospaced, weight: .medium))
                        .foregroundStyle(DossierPalette.dim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 4)
                Text(dossier.hardware.sourceName)
                    .font(.system(.caption2, design: .monospaced, weight: .medium))
                    .foregroundStyle(DossierPalette.faint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 6)
        }
    }

    private var stripDivider: some View {
        Rectangle().fill(DossierPalette.hairline).frame(width: 1, height: 28)
    }

    private func quickStat(_ label: LocalizedStringKey, _ value: String, accent: Color = DossierPalette.primaryText) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(DossierPalette.faint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(value)
                .font(.system(.footnote, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 01 Airtime

    private func airtimeSection(exporting: Bool) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            DossierSectionHeader(index: 1, title: "Airtime", trailing: AppLanguage.current.text(period.title).uppercased(), accent: rarity.accent)
            if exporting {
                Text(DossierFormat.range(stats.start, stats.end))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DossierPalette.dim)
            } else {
                PeriodSwitcher(period: $period, rarity: rarity, rangeText: DossierFormat.range(stats.start, stats.end))
                dataSourceNote.foregroundStyle(DossierPalette.dim)
            }
            AirtimeHero(stats: stats, rarity: rarity, otherDeviceCount: max(0, SampleCards.all.count - 1))
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 02 Rhythm & Charts

    private func rhythmSection(exporting: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            DossierSectionHeader(index: 2, title: "Rhythm", trailing: AppLanguage.current.text(stats.period.title).uppercased(), accent: rarity.accent)

            DossierTrendChart(stats: stats, rarity: rarity, firstWear: dossier.firstWear,
                              selection: exporting ? .constant(nil) : $selectedDate, showsInteractionHint: !exporting)
                .dossierTile(tint: rarity.accent)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Eyebrow("24-hour clock")
                        Text("When you wear it")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                    }
                    Spacer()
                    let lateNightMinutes = stats.hours
                        .filter { $0.hour >= 22 || $0.hour <= 3 }
                        .reduce(0.0) { $0 + $1.minutes }
                    let periodNightShare = stats.totalMinutes > 0 ? lateNightMinutes / stats.totalMinutes : 0
                    let nightPct = Int((periodNightShare * 100).rounded())
                    let moonColor = Color.adaptive(
                        light: UIColor(red: 0.28, green: 0.36, blue: 0.78, alpha: 1),
                        dark: UIColor(red: 0.65, green: 0.72, blue: 1, alpha: 1)
                    )
                    Label("\(nightPct)% late night", systemImage: "moon.stars.fill")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .lineLimit(1)
                        .foregroundStyle(nightPct > 20 ? Theme.moderateColor : moonColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(DossierPalette.surfaceFill, in: Capsule())
                }

                DayClock(stats: stats, rarity: rarity, selectedHour: exporting ? .constant(nil) : $selectedHour)
                    .frame(maxWidth: 300)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)

                if !exporting {
                    Text("Tap or press-drag any hour · bar color shows loudness")
                        .font(.caption2)
                        .foregroundStyle(DossierPalette.faint)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .dossierTile(tint: rarity.glow)
            .padding(.top, 6)
            .id("clock")
        }
    }

    // MARK: - 03 Habits & Lifetime

    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            DossierSectionHeader(index: 3, title: "Habits & Hearing", trailing: AppLanguage.current.text("%lld wears", stats.sessionCount), accent: rarity.accent)

            HabitsBento(stats: stats, dossier: dossier, rarity: rarity)

            LifetimeLedgerCard(dossier: dossier, rarity: rarity)
                .padding(.top, 6)
                .id("lifetime")
        }
    }

    // MARK: - 04 Milestones

    private var milestonesSection: some View {
        let unlocked = dossier.milestones.filter { !$0.isFuture }.count
        return VStack(alignment: .leading, spacing: 16) {
            DossierSectionHeader(index: 4, title: "Milestones", trailing: AppLanguage.current.text("%lld unlocked", unlocked), accent: rarity.accent)
            MilestoneTimelineCard(milestones: dossier.milestones, rarity: rarity)
        }
    }

    // MARK: - 05 Certificate & Grade

    private func certificateSection(exporting: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            DossierSectionHeader(index: 5, title: "Certificate", trailing: dossier.hardware.productID, accent: rarity.accent)
            LiveTiltView(
                isActive: !exporting && tiltActive && showStickyIdentity,
                overrideTilt: exporting ? .zero : demoOverrideTilt
            ) { liveTilt in
                CertificateLabel(
                    card: card,
                    dossier: dossier,
                    tilt: liveTilt,
                    animateSeal: !exporting && !showShare && showStickyIdentity
                )
            }
            GradeBreakdown(grade: dossier.grade, accent: rarity.accent)
                .dossierTile(tint: rarity.accent)
                .id("grade")
        }
    }

    private var footerNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.shield.fill")
                .font(.caption2)
            Text("Computed locally from Apple Health · stays on your iPhone")
                .font(.caption2)
        }
        .foregroundStyle(DossierPalette.faint)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Launch arguments (-dossierScroll / -dossierDemo)

    private func handleLaunchArguments(proxy: ScrollViewProxy) async {
        let args = ProcessInfo.processInfo.arguments

        if let i = args.firstIndex(of: "-dossierPeriod"), i + 1 < args.count,
           let p = DossierPeriod(rawValue: args[i + 1]) {
            period = p
        }

        if let i = args.firstIndex(of: "-dossierScroll"), i + 1 < args.count {
            let target = args[i + 1]
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.none) {
                proxy.scrollTo(target, anchor: .top)
            }
            return
        }

        #if DEBUG
        if args.contains("-customizeSlab"), !showSlabStudio {
            try? await Task.sleep(for: .milliseconds(550))
            showSlabStudio = true
            return
        }
        if args.contains("-dossierShareLong"), !showShare {
            try? await Task.sleep(for: .milliseconds(500))
            shareInitialFormat = .long
            showShare = true
            return
        }
        if args.contains("-dossierShare"), !showShare {
            try? await Task.sleep(for: .milliseconds(500))
            shareInitialFormat = .simple
            showShare = true
            return
        }
        #endif

        guard args.contains("-dossierDemo"), !demoStarted else { return }
        demoStarted = true
        await runDemoSequence(proxy: proxy)
    }

    private func runDemoSequence(proxy: ScrollViewProxy) async {
        // 1. Subtle tilt shimmer on the acrylic grading slab.
        try? await Task.sleep(for: .milliseconds(450))
        for step in 0..<36 {
            let t = Double(step) / 35
            demoTilt = CGSize(width: sin(t * .pi * 2) * 0.85, height: sin(t * .pi * 2) * 0.25)
            try? await Task.sleep(for: .milliseconds(25))
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { demoTilt = .zero }
        try? await Task.sleep(for: .milliseconds(250))

        // 2. Scroll to Airtime and cycle periods so ring + numeric transitions animate.
        withAnimation(.easeInOut(duration: 0.7)) {
            proxy.scrollTo("airtime", anchor: .top)
        }
        try? await Task.sleep(for: .milliseconds(900))
        for nextPeriod in [DossierPeriod.week, .year, .all, .month] {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.8)) {
                period = nextPeriod
            }
            try? await Task.sleep(for: .milliseconds(850))
        }

        // 3. Scroll to the 30-day trend chart and scrub across active bars.
        withAnimation(.easeInOut(duration: 0.7)) {
            proxy.scrollTo("charts", anchor: .top)
        }
        try? await Task.sleep(for: .milliseconds(800))
        let scrubBuckets = stats.buckets.filter { $0.minutes > 0 }
        let stepCount = min(8, scrubBuckets.count)
        if stepCount > 0 {
            let strideVal = max(1, scrubBuckets.count / stepCount)
            for idx in stride(from: 0, to: scrubBuckets.count, by: strideVal).prefix(stepCount) {
                selectedDate = scrubBuckets[idx].start
                try? await Task.sleep(for: .milliseconds(280))
            }
        }
        selectedDate = nil
        try? await Task.sleep(for: .milliseconds(450))

        // 4. Briefly scroll to Habits & Certificate to conclude.
        withAnimation(.easeInOut(duration: 0.8)) {
            proxy.scrollTo("habits", anchor: .top)
        }
        try? await Task.sleep(for: .milliseconds(900))
    }
}

// MARK: - Lifetime & Career Ledger

private struct LifetimeLedgerCard: View {
    let dossier: DeviceDossier
    let rarity: Rarity

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow("Lifetime ledger")
                    Text(dossier.lifetimeMinutes.minutesText)
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(dossier.recordDays) record days")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(rarity.accent)
                    Text("\(dossier.sessions.count) total wears · \(Int(dossier.averageDecibels.rounded())) dB(A)")
                        .font(.caption2)
                        .foregroundStyle(DossierPalette.dim)
                }
            }

            HStack(spacing: 12) {
                dateBlock(
                    title: "FIRST WEAR",
                    primary: dossier.firstWear.map(DossierFormat.dot) ?? "—",
                    secondary: dossier.firstWear.map { $0.dossierRelative(to: dossier.now, calendar: dossier.calendar) } ?? ""
                )
                dateBlock(
                    title: "LAST WEAR",
                    primary: dossier.lastWear.map { $0.start.dossierRelative(to: dossier.now, calendar: dossier.calendar) } ?? "—",
                    secondary: dossier.lastWear.map { "\($0.start.dossierTime) · \($0.minutes.minutesText)" } ?? ""
                )
            }

            if !dossier.careerRows.isEmpty {
                Rectangle().fill(DossierPalette.hairline).frame(height: 1)

                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Text("MONTH").frame(width: 58, alignment: .leading)
                        Text("TIME").frame(maxWidth: .infinity, alignment: .trailing)
                        Text("WEARS").frame(width: 44, alignment: .trailing)
                        Text("MAX").frame(width: 52, alignment: .trailing)
                        Text("AVG").frame(width: 46, alignment: .trailing)
                    }
                    .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(DossierPalette.faint)

                    ForEach(dossier.careerRows.prefix(6)) { row in
                        HStack(spacing: 6) {
                            Text(row.label)
                                .font(.system(.caption, design: .monospaced, weight: .bold))
                                .foregroundStyle(DossierPalette.primaryText.opacity(0.88))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .frame(width: 58, alignment: .leading)
                            Text(row.minutes.minutesText)
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text("\(row.sessions)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(DossierPalette.dim)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .frame(width: 44, alignment: .trailing)
                            Text(row.longest.minutesText)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(DossierPalette.dim)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .frame(width: 52, alignment: .trailing)
                            Text("\(Int(row.averageDecibels.rounded())) dB")
                                .font(.system(.caption, design: .monospaced, weight: .semibold))
                                .foregroundStyle(Theme.levelColor(db: row.averageDecibels, colorScheme: colorScheme))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .frame(width: 46, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .dossierTile()
    }

    private func dateBlock(title: LocalizedStringKey, primary: String, secondary: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(DossierPalette.faint)
            Text(primary)
                .font(.system(.subheadline, design: .monospaced, weight: .bold))
                .lineLimit(1)
            Text(secondary)
                .font(.caption2)
                .foregroundStyle(DossierPalette.dim)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DossierPalette.surfaceFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(DossierPalette.hairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Milestone Timeline

struct MilestoneTimelineCard: View {
    let milestones: [DossierMilestone]
    let rarity: Rarity

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(milestones.enumerated()), id: \.element.id) { index, item in
                let isLast = index == milestones.count - 1
                let nodeColor = color(for: item)

                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        ZStack {
                            if item.isFuture {
                                Circle()
                                    .strokeBorder(nodeColor.opacity(0.55), style: StrokeStyle(lineWidth: 1.4, dash: [3, 3]))
                                    .frame(width: 28, height: 28)
                            } else {
                                Circle()
                                    .fill(nodeColor.opacity(0.18))
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().strokeBorder(nodeColor.opacity(0.75), lineWidth: 1.2))
                            }
                            Image(systemName: icon(for: item.kind))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(item.isFuture ? nodeColor.opacity(0.75) : nodeColor)
                        }

                        if !isLast {
                            let nextIsFuture = milestones[index + 1].isFuture
                            Rectangle()
                                .fill(nextIsFuture ? DossierPalette.hairline : nodeColor.opacity(0.28))
                                .frame(width: 1.5)
                                .frame(minHeight: 28)
                                .padding(.vertical, 3)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(LocalizedStringKey(item.title))
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(item.isFuture ? DossierPalette.primaryText.opacity(0.75) : DossierPalette.primaryText)
                            if let tier = item.tier, item.kind == .tier || item.kind == .minted {
                                Text(LocalizedStringKey(tier.shortName.uppercased()))
                                    .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                                    .tracking(0.8)
                                    .lineLimit(1)
                                    .fixedSize()
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(tier.accent.opacity(0.18), in: Capsule())
                                    .foregroundStyle(tier.accent)
                            } else if item.isFuture {
                                Text("NEXT")
                                    .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                                    .tracking(0.8)
                                    .lineLimit(1)
                                    .fixedSize()
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(rarity.accent.opacity(0.18), in: Capsule())
                                    .foregroundStyle(rarity.accent)
                            }
                            Spacer(minLength: 8)
                            Text(item.isFuture ? AppLanguage.current.text("ETA %@", item.date.dossierShort) : DossierFormat.dot(item.date))
                                .font(.system(.caption2, design: .monospaced, weight: .semibold))
                                .foregroundStyle(item.isFuture ? rarity.accent.opacity(0.8) : DossierPalette.dim)
                                .lineLimit(1)
                                .fixedSize()
                        }
                        Text(LocalizedStringKey(item.detail))
                            .font(.caption)
                            .foregroundStyle(DossierPalette.dim)
                    }
                    .padding(.top, 3)
                    .padding(.bottom, isLast ? 2 : 14)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .dossierTile(tint: rarity.accent)
    }

    private func icon(for kind: DossierMilestone.Kind) -> String {
        switch kind {
        case .minted: "sparkles"
        case .hours: "clock.fill"
        case .tier: "seal.fill"
        case .longest: "flame.fill"
        case .bestDay: "crown.fill"
        case .upcoming: "flag.checkered"
        }
    }

    private func color(for item: DossierMilestone) -> Color {
        if let tier = item.tier { return tier.accent }
        switch item.kind {
        case .longest: return Theme.moderateColor
        case .bestDay: return rarity.accent
        case .hours: return Theme.quietColor
        case .upcoming: return rarity.accent
        case .minted, .tier: return rarity.accent
        }
    }
}

#Preview {
    DeviceDossierView(card: SampleCards.all[0], isSampleData: true)
}
