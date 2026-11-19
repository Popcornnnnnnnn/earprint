import SwiftUI

/// Full-screen dossier for a single headphone: PSA-style grading slab, period airtime,
/// interactive trend & 24-hour charts, listening habits, milestones, and hardware certificate.
struct DeviceDossierView: View {
    let card: HeadphoneCard
    let dossier: DeviceDossier
    var onClose: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var motion = TiltMotion()

    @State private var period: DossierPeriod = .month
    @State private var selectedDate: Date?
    @State private var selectedHour: Int?
    @State private var slabFlipped = false
    @State private var demoTilt: CGSize = .zero
    @State private var scrollOffset: CGFloat = 0
    @State private var demoStarted = false

    init(card: HeadphoneCard, dossier: DeviceDossier? = nil, onClose: (() -> Void)? = nil) {
        self.card = card
        // Keep fixed referenceNow for deterministic demo launches; use current date for live cards.
        let args = ProcessInfo.processInfo.arguments
        let isDemo = args.contains("-dossier") || args.contains("-dossierDemo") || args.contains("-demo")
        let referenceDate = isDemo ? DossierSample.referenceNow : max(DossierSample.referenceNow, Date())
        self.dossier = dossier ?? DeviceDossier.sample(for: card, now: referenceDate)
        self.onClose = onClose
    }

    private var stats: PeriodStats { dossier.stats(period) }
    private var rarity: Rarity { card.rarity }
    private var tilt: CGSize { demoTilt == .zero ? motion.tilt : demoTilt }
    private var showStickyIdentity: Bool { scrollOffset > 380 }

    var body: some View {
        ZStack {
            backdrop
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 22) {
                        slabStage
                            .id("slab")

                        airtimeSection
                            .padding(.top, 10)
                            .id("airtime")

                        rhythmSection
                            .padding(.top, 10)
                            .id("charts")

                        habitsSection
                            .padding(.top, 10)
                            .id("habits")

                        milestonesSection
                            .padding(.top, 10)
                            .id("milestones")

                        certificateSection
                            .padding(.top, 10)
                            .id("certificate")

                        footerNote
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 48)
                }
                .scrollIndicators(.hidden)
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    geo.contentOffset.y + geo.contentInsets.top
                } action: { _, newValue in
                    scrollOffset = newValue
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    topBar(proxy: proxy)
                }
                .task {
                    await handleLaunchArguments(proxy: proxy)
                }
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
        .onChange(of: period) {
            selectedDate = nil
            selectedHour = nil
        }
    }

    // MARK: - Backdrop & Sticky Header

    private var backdrop: some View {
        ZStack {
            DossierPalette.ink.ignoresSafeArea()
            RadialGradient(
                colors: [rarity.glow.opacity(0.24), rarity.accent.opacity(0.06), .clear],
                center: UnitPoint(x: 0.5 + tilt.width * 0.12, y: 0.14),
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
                            Image(systemName: card.symbol)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(rarity.ink)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(card.nickname)
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .lineLimit(1)
                            Text(dossier.hardware.modelName)
                                .font(.system(.caption2, design: .monospaced, weight: .medium))
                                .foregroundStyle(DossierPalette.dim)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(rarity.accent)
                            .frame(width: 7, height: 7)
                            .shadow(color: rarity.glow, radius: 4)
                        Text(String(format: "DOSSIER · #%04d", card.serial))
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.06), in: Capsule())
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
                .background(.white.opacity(0.06), in: Capsule())
                .overlay(Capsule().strokeBorder(rarity.accent.opacity(0.3), lineWidth: 1))
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            Button {
                if let onClose { onClose() } else { dismiss() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.10), in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
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

    // MARK: - Hero Slab Stage

    private var slabStage: some View {
        VStack(spacing: 16) {
            GradingSlab(card: card, dossier: dossier, tilt: tilt, flipped: slabFlipped)
                .rotation3DEffect(.degrees(Double(tilt.width) * 10), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                .rotation3DEffect(.degrees(Double(-tilt.height) * 8), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                .onTapGesture {
                    withAnimation(.spring(response: 0.65, dampingFraction: 0.78)) {
                        slabFlipped.toggle()
                    }
                }
                .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.75), trigger: slabFlipped)
                .padding(.top, 4)

            HStack(spacing: 8) {
                Image(systemName: "hand.tap")
                    .font(.caption2.weight(.semibold))
                Text(slabFlipped ? "Tap slab to view front" : "Tap slab to flip · tilt phone for foil")
                    .font(.caption)
            }
            .foregroundStyle(DossierPalette.dim)

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
                    .foregroundStyle(.white.opacity(0.75))
                if let fw = dossier.hardware.firmwareVersion {
                    Text("· FW \(fw)")
                        .font(.system(.caption2, design: .monospaced, weight: .medium))
                        .foregroundStyle(DossierPalette.dim)
                }
                Spacer(minLength: 0)
                Text(dossier.hardware.sourceName)
                    .font(.system(.caption2, design: .monospaced, weight: .medium))
                    .foregroundStyle(DossierPalette.faint)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
        }
    }

    private var stripDivider: some View {
        Rectangle().fill(DossierPalette.hairline).frame(width: 1, height: 28)
    }

    private func quickStat(_ label: String, _ value: String, accent: Color = .white) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(DossierPalette.faint)
            Text(value)
                .font(.system(.footnote, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 01 Airtime

    private var airtimeSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            DossierSectionHeader(index: 1, title: "Airtime", trailing: period.title.uppercased(), accent: rarity.accent)
            PeriodSwitcher(period: $period, rarity: rarity, rangeText: DossierFormat.range(stats.start, stats.end))
            AirtimeHero(stats: stats, rarity: rarity, otherDeviceCount: max(0, SampleCards.all.count - 1))
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 02 Rhythm & Charts

    private var rhythmSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            DossierSectionHeader(index: 2, title: "Rhythm", trailing: stats.period.title.uppercased(), accent: rarity.accent)

            DossierTrendChart(stats: stats, rarity: rarity, firstWear: dossier.firstWear, selection: $selectedDate)
                .dossierTile(tint: rarity.accent)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Eyebrow("24-hour clock")
                        Text("When you wear it")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                    }
                    Spacer()
                    let nightPct = Int((dossier.nightShare * 100).rounded())
                    Label("\(nightPct)% late night", systemImage: "moon.stars.fill")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(nightPct > 20 ? Theme.moderate.color : Color(red: 0.65, green: 0.72, blue: 1))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.06), in: Capsule())
                }

                DayClock(stats: stats, rarity: rarity, selectedHour: $selectedHour)
                    .frame(maxWidth: 300)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)

                Text("Tap or press-drag any hour · bar color shows loudness")
                    .font(.caption2)
                    .foregroundStyle(DossierPalette.faint)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .dossierTile(tint: rarity.glow)
            .padding(.top, 6)
            .id("clock")
        }
    }

    // MARK: - 03 Habits & Lifetime

    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            DossierSectionHeader(index: 3, title: "Habits & Hearing", trailing: "\(stats.sessionCount) wears", accent: rarity.accent)

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
            DossierSectionHeader(index: 4, title: "Milestones", trailing: "\(unlocked) unlocked", accent: rarity.accent)
            MilestoneTimelineCard(milestones: dossier.milestones, rarity: rarity)
        }
    }

    // MARK: - 05 Certificate & Grade

    private var certificateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            DossierSectionHeader(index: 5, title: "Certificate", trailing: dossier.hardware.productID, accent: rarity.accent)
            CertificateLabel(card: card, dossier: dossier, tilt: tilt)
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
                    HStack {
                        Text("MONTH").frame(width: 64, alignment: .leading)
                        Text("TIME").frame(maxWidth: .infinity, alignment: .trailing)
                        Text("WEARS").frame(width: 48, alignment: .trailing)
                        Text("MAX").frame(width: 58, alignment: .trailing)
                        Text("AVG").frame(width: 48, alignment: .trailing)
                    }
                    .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(DossierPalette.faint)

                    ForEach(dossier.careerRows.prefix(6)) { row in
                        HStack {
                            Text(row.label)
                                .font(.system(.caption, design: .monospaced, weight: .bold))
                                .foregroundStyle(.white.opacity(0.88))
                                .frame(width: 64, alignment: .leading)
                            Text(row.minutes.minutesText)
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .monospacedDigit()
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text("\(row.sessions)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(DossierPalette.dim)
                                .frame(width: 48, alignment: .trailing)
                            Text(row.longest.minutesText)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(DossierPalette.dim)
                                .frame(width: 58, alignment: .trailing)
                            Text("\(Int(row.averageDecibels.rounded())) dB")
                                .font(.system(.caption, design: .monospaced, weight: .semibold))
                                .foregroundStyle(Theme.levelColor(db: row.averageDecibels))
                                .frame(width: 48, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .dossierTile()
    }

    private func dateBlock(title: String, primary: String, secondary: String) -> some View {
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
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(DossierPalette.hairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Milestone Timeline

private struct MilestoneTimelineCard: View {
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
                                .fill(nextIsFuture ? Color.white.opacity(0.10) : nodeColor.opacity(0.28))
                                .frame(width: 1.5)
                                .frame(minHeight: 28)
                                .padding(.vertical, 3)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(item.title)
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(item.isFuture ? .white.opacity(0.78) : .white)
                            if let tier = item.tier, item.kind == .tier || item.kind == .minted {
                                Text(tier.rawValue)
                                    .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                                    .tracking(0.8)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(tier.accent.opacity(0.18), in: Capsule())
                                    .foregroundStyle(tier.accent)
                            } else if item.isFuture {
                                Text("NEXT")
                                    .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                                    .tracking(0.8)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(rarity.accent.opacity(0.18), in: Capsule())
                                    .foregroundStyle(rarity.accent)
                            }
                            Spacer(minLength: 8)
                            Text(item.isFuture ? "ETA \(item.date.dossierShort)" : DossierFormat.dot(item.date))
                                .font(.system(.caption2, design: .monospaced, weight: .semibold))
                                .foregroundStyle(item.isFuture ? rarity.accent.opacity(0.8) : DossierPalette.dim)
                        }
                        Text(item.detail)
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
        case .longest: return Theme.moderate.color
        case .bestDay: return rarity.accent
        case .hours: return Theme.quiet.color
        case .upcoming: return rarity.accent
        case .minted, .tier: return rarity.accent
        }
    }
}

#Preview {
    DeviceDossierView(card: SampleCards.all[0])
}
