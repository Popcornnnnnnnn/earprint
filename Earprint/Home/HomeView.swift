import SwiftUI

struct HomeView: View {
    let summary: ListeningSummary
    var isSampleData: Bool = false
    var sampleBadgeText: String = "Sample data"
    var statusMessage: String? = nil
    var isLoading: Bool = false
    var onConnectHealth: (() -> Void)? = nil

    @State private var showShare = ProcessInfo.processInfo.arguments.contains("-showShare")
    @State private var space = LayoutSpace()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var listeningTimeSize: CGFloat = 43

    private let background = Color(red: 0.05, green: 0.05, blue: 0.07)
    private let accent = Theme.quiet.color

    var body: some View {
        ScrollView {
            Group {
                if space.isWide || (space.isLandscape && space.size.width >= 520) {
                    let split = ColumnSplit(space: space, padding: 24, gap: 24)
                    HStack(alignment: .top, spacing: split.gap) {
                        VStack(alignment: .leading, spacing: 16) {
                            header
                            healthStatus
                            weeklyOverview
                            hearingBudget
                        }
                        .frame(width: split.leading)
                        VStack(alignment: .leading, spacing: 16) {
                            listeningPattern
                            history
                        }
                        .frame(width: split.trailing)
                    }
                    .padding(.horizontal, split.padding)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        healthStatus
                        weeklyOverview
                        hearingBudget
                        listeningPattern
                        history
                    }
                    .padding(.horizontal, 18)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .readLayoutSpace($space)
        .background(background.ignoresSafeArea())
        .foregroundStyle(.white)
        .sheet(isPresented: $showShare) { ShareSheet(summary: summary) }
    }

    private var header: some View {
        let name = isSampleData ? summary.deviceModel : summary.deviceName
        return VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("Rings")
                    .font(.largeTitle.weight(.heavy))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button { showShare = true } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 44, height: 44)
                        .background(Theme.card, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share my Earprint")
            }
            HStack(spacing: 9) {
                Image(systemName: summary.deviceSymbol)
                    .foregroundStyle(accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.subheadline.weight(.semibold))
                    if summary.deviceModel != name {
                        Text(summary.deviceModel).font(.caption).foregroundStyle(Theme.secondaryText)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder private var healthStatus: some View {
        if isSampleData {
            SampleDataBanner(badgeText: sampleBadgeText, detail: statusMessage,
                             isLoading: isLoading, onConnect: onConnectHealth)
        }
    }

    private var weeklyOverview: some View {
        let shape = RoundedRectangle(cornerRadius: 26)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Last 7 days").font(.headline).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Text(summary.periodLabel).font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .lastTextBaseline, spacing: 14) {
                    weeklyListeningTime.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    weeklyLevel.fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 10) {
                    weeklyListeningTime
                    weeklyLevel
                }
            }
            dailyListeningBars
        }
        .padding(18)
        .background {
            shape.fill(Color(red: 0.075, green: 0.11, blue: 0.14))
                .overlay(alignment: .topTrailing) {
                    RadialGradient(colors: [accent.opacity(0.16), .clear], center: .topTrailing,
                                   startRadius: 12, endRadius: 245)
                        .clipShape(shape)
                }
        }
        .overlay { shape.strokeBorder(accent.opacity(0.16)) }
    }

    private var weeklyListeningTime: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(summary.weekMinutes.minutesText)
                .font(.system(size: listeningTimeSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text("Listening time").font(.subheadline).foregroundStyle(Theme.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }

    private var weeklyLevel: some View {
        let level = summary.weekDecibels
        return VStack(alignment: .leading, spacing: 3) {
            Text(summary.weekMinutes > 0 ? "\(Int(level.rounded())) dB" : "—")
                .font(.title2.weight(.semibold).monospacedDigit())
                .foregroundStyle(summary.weekMinutes > 0 ? Theme.levelColor(db: level) : Theme.secondaryText)
            Text("Avg. level").font(.caption).foregroundStyle(Theme.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }

    private var dailyListeningBars: some View {
        let days = summary.grid.minutes.suffix(7).map { $0.reduce(0, +) }
        let maxMinutes = max(days.max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(days.indices, id: \.self) { index in
                let minutes = days[index]
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.055))
                    if minutes > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(index == days.indices.last ? accent : accent.opacity(0.48))
                            .frame(height: max(3, 42 * minutes / maxMinutes))
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Day \(index + 1) of \(days.count)")
                .accessibilityValue(Text(minutes.minutesText))
            }
        }
        .frame(height: 42)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Daily listening, earliest to latest")
    }

    private var hearingBudget: some View {
        let used = summary.weeklyBudgetUsed
        let tint = used >= 1 ? Theme.loud.color : (used >= 0.75 ? Theme.moderate.color : accent)
        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Label("Hearing budget", systemImage: "ear")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(Int((used * 100).rounded()))% used")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(tint)
            }
            ProgressView(value: min(used, 1)).tint(tint).accessibilityHidden(true)
            Text("7-day exposure for this pair · WHO reference: 40 hours at 80 dB(A)")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .card()
    }

    private var listeningPattern: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
        return VStack(alignment: .leading, spacing: 12) {
            layout {
                EarprintGlyph(grid: summary.grid, showHourLabels: false)
                    .frame(maxWidth: 132)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text("28-day pattern").font(.headline).accessibilityAddTraits(.isHeader)
                    Text("One ring per day, newest on the outside. Midnight is at the top.")
                        .font(.caption).foregroundStyle(Theme.secondaryText)
                    VStack(alignment: .leading, spacing: 5) {
                        legendDot(accent, "Quiet")
                        legendDot(Theme.moderate.color, "Moderate")
                        legendDot(Theme.loud.color, "Loud")
                    }
                }
            }
            if summary.grid.totalMinutes(lastDays: 28) > 0 {
                Divider()
                Label(summary.persona.title, systemImage: "waveform")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .card()
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.caption).foregroundStyle(Theme.secondaryText)
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 4) {
                Text("All-time listening").font(.headline).accessibilityAddTraits(.isHeader)
                if summary.firstUse != "—" {
                    Text("Since \(summary.firstUse)").font(.caption).foregroundStyle(Theme.secondaryText)
                }
            }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 13) {
                GridRow {
                    stat("Listening time", summary.lifetimeMinutes.minutesText)
                    stat("Sessions", summary.sessions.formatted())
                }
                Divider().gridCellUnsizedAxes(.horizontal)
                GridRow {
                    stat("Avg. session", summary.averageSessionMinutes.minutesText)
                    stat("Longest session", summary.longestSessionMinutes.minutesText)
                }
            }
        }
        .card()
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.system(.title3, design: .rounded).weight(.semibold)).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HomeView(summary: SampleData.summary, isSampleData: true)
}
