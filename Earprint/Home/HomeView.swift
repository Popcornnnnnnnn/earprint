import SwiftUI

struct HomeView: View {
    let summary: ListeningSummary
    var isSampleData: Bool = false
    var sampleBadgeText: String = "Sample data"
    var statusMessage: String? = nil
    var isLoading: Bool = false
    var onConnectHealth: (() -> Void)? = nil

    @State private var showShare = ProcessInfo.processInfo.arguments.contains("-showShare")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if isSampleData {
                    SampleDataBanner(
                        badgeText: sampleBadgeText,
                        detail: statusMessage,
                        isLoading: isLoading,
                        onConnect: onConnectHealth
                    )
                }
                hero
                legend
                personaCard
                statsGrid
                budgetCard
                shareButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .foregroundStyle(.white)
        .sheet(isPresented: $showShare) { ShareSheet(summary: summary) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("THIS WEEK · \(summary.periodLabel)")
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.secondaryText)
            HStack(spacing: 8) {
                Image(systemName: summary.deviceSymbol)
                Text(summary.deviceName).font(.headline)
            }
            Text(summary.deviceModel).font(.subheadline).foregroundStyle(Theme.secondaryText)
        }
        .padding(.top, 8)
    }

    private var hero: some View {
        ZStack {
            EarprintGlyph(grid: summary.grid)
            VStack(spacing: 2) {
                Text(summary.weekMinutes.minutesText)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("listened")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(.vertical, 4)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendDot(Theme.quiet.color, "Quiet")
            legendDot(Theme.moderate.color, "Moderate")
            legendDot(Theme.loud.color, "Loud")
            Spacer()
            Text("4 weeks · rings = days")
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.caption2).foregroundStyle(Theme.secondaryText)
        }
    }

    private var personaCard: some View {
        HStack(spacing: 14) {
            Text(summary.persona.emoji).font(.system(size: 40))
            VStack(alignment: .leading, spacing: 4) {
                Text("You're a \(summary.persona.title)").font(.headline)
                Text(summary.persona.detail).font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
        }
        .card()
    }

    private var statsGrid: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                stat("Sessions", "\(summary.sessions)", "since \(summary.firstUse)")
                stat("Avg session", summary.averageSessionMinutes.minutesText, "per wear")
            }
            GridRow {
                stat("Longest", summary.longestSessionMinutes.minutesText, "estimated")
                stat("Avg level", "\(Int(summary.weekDecibels.rounded())) dB", levelWord(summary.weekDecibels))
            }
        }
    }

    private func stat(_ title: String, _ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(Theme.secondaryText)
            Text(value).font(.system(.title2, design: .rounded).weight(.semibold)).monospacedDigit()
            Text(caption).font(.caption2).foregroundStyle(Theme.secondaryText)
        }
        .card()
    }

    private func levelWord(_ db: Double) -> String {
        db < 65 ? "comfortable" : db < 75 ? "moderate" : "loud"
    }

    private var budgetCard: some View {
        let used = summary.weeklyBudgetUsed
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Weekly hearing budget").font(.headline)
                Spacer()
                Text("\(Int((used * 100).rounded()))% used")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.levelColor(db: 55 + 30 * min(used, 1)))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.quiet.color, Theme.moderate.color, Theme.loud.color],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * min(used, 1))
                }
            }
            .frame(height: 10)
            Text("Based on the WHO safe-listening guide: 40 hours a week at 80 dB(A).")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .card()
    }

    private var shareButton: some View {
        Button { showShare = true } label: {
            Label("Share my Earprint", systemImage: "square.and.arrow.up")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.white, in: Capsule())
                .foregroundStyle(.black)
        }
        .padding(.top, 4)
    }
}

#Preview {
    HomeView(summary: SampleData.summary)
}
