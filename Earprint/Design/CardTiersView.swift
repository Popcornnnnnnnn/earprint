import SwiftUI

/// Multi-device summary for a single card tier inside `CardTiersView`.
struct CardTierBinderSummary: Equatable {
    let tier: Rarity
    let scopedCards: [HeadphoneCard]
    let unlockedCards: [HeadphoneCard]
    let isUnlocked: Bool
    let isCurrent: Bool
    let firstAchiever: HeadphoneCard?
    let achievedDate: Date?

    init(cards: [HeadphoneCard], selectedCardID: String?, tier: Rarity) {
        self.tier = tier
        let scoped: [HeadphoneCard]
        if let selectedCardID, let match = cards.first(where: { $0.matches(id: selectedCardID) }) {
            scoped = [match]
        } else {
            scoped = cards
        }
        self.scopedCards = scoped

        let minMinutes = tier.minimumHours * 60
        let unlocked = scoped
            .filter { $0.lifetimeMinutes >= minMinutes }
            .sorted { a, b in
                let da = a.tierAchievedDates[tier] ?? .distantFuture
                let db = b.tierAchievedDates[tier] ?? .distantFuture
                if da != db { return da < db }
                return a.lifetimeMinutes > b.lifetimeMinutes
            }
        self.unlockedCards = unlocked
        self.isUnlocked = !unlocked.isEmpty
        self.isCurrent = scoped.contains { $0.rarity == tier }
        self.firstAchiever = unlocked.first
        self.achievedDate = unlocked.first?.tierAchievedDates[tier]
    }

    func compactAttribution(calendar: Calendar = .current, isSingleDevice: Bool, locale: Locale = AppLanguage.current.locale) -> String? {
        guard let firstAchiever else { return nil }
        let dateText = achievedDate.map { DateText.shortMonthYear($0, calendar: calendar, locale: locale) }
        if isSingleDevice {
            return dateText ?? firstAchiever.lifetimeMinutes.minutesText
        }
        let extra = unlockedCards.count - 1
        let shortModel = Self.shortModelName(firstAchiever.model)
        let prefix = extra > 0 ? "\(shortModel) +\(extra)" : shortModel
        if let dateText {
            return "\(prefix) · \(dateText)"
        }
        return prefix
    }

    static func shortModelName(_ model: String) -> String {
        model
            .replacingOccurrences(of: " · USB-C", with: "")
            .replacingOccurrences(of: " (ANC)", with: "")
    }
}

/// Collector Trophy Binder + Interactive Spotlight for Earprint's 6-tier system (0h -> 2,000h).
struct CardTiersView: View {
    var ownedCards: [HeadphoneCard] = []
    var showsDoneButton = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @State private var inspectedTier: Rarity?
    @State private var selectedCardID: String? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var selectedCard: HeadphoneCard? {
        guard let selectedCardID else { return nil }
        return ownedCards.first(where: { $0.matches(id: selectedCardID) })
    }

    private var scopedCards: [HeadphoneCard] {
        if let selectedCard { return [selectedCard] }
        return ownedCards
    }

    var body: some View {
        let topCard = scopedCards.max(by: { $0.lifetimeMinutes < $1.lifetimeMinutes })
        let highestHours = (topCard?.lifetimeMinutes ?? 0) / 60
        let hasCards = !scopedCards.isEmpty
        let unlockedTierCount = hasCards ? Rarity.allAscending.filter { highestHours >= $0.minimumHours }.count : 0
        let selectedTier = inspectedTier ?? topCard?.rarity ?? .bronze
        let heroSummary = CardTierBinderSummary(cards: ownedCards, selectedCardID: selectedCard?.id, tier: selectedTier)

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if ownedCards.count > 1 {
                    deviceFilterBar
                }

                LiveTiltView(isActive: true) { tilt in
                    spotlightHero(selectedTier, summary: heroSummary, tilt: tilt)
                }

                HStack {
                    Text("COLLECTOR BINDER")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1.6)
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text("\(unlockedTierCount)/\(Rarity.allAscending.count)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.surfaceFill, in: Capsule())
                        .foregroundStyle(selectedTier.accent)
                }
                .padding(.horizontal, 2)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Rarity.allAscending) { tier in
                        let summary = CardTierBinderSummary(cards: ownedCards, selectedCardID: selectedCard?.id, tier: tier)
                        binderCard(summary, selectedTier: selectedTier)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 16)
        }
        .pauseMotionWhileScrolling("tiers")
        .background(Theme.canvas.ignoresSafeArea())
        .foregroundStyle(Theme.primaryText)
        .navigationTitle("Card Tiers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            if inspectedTier == nil {
                inspectedTier = topCard?.rarity ?? .bronze
            }
        }
        .onChange(of: selectedCardID) { _, _ in
            if let top = scopedCards.max(by: { $0.lifetimeMinutes < $1.lifetimeMinutes }) {
                inspectedTier = top.rarity
            }
        }
    }

    // MARK: - Device Filter Bar

    private var deviceFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(
                    title: LocalizedStringKey("All Pairs"),
                    isSelected: selectedCard == nil
                ) {
                    selectedCardID = nil
                }

                ForEach(ownedCards) { item in
                    let isSelected = selectedCard?.id == item.id
                    filterChip(
                        title: CardTierBinderSummary.shortModelName(item.model),
                        isSelected: isSelected
                    ) {
                        selectedCardID = item.id
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func filterChip(title: LocalizedStringKey, isSelected: Bool, action: @escaping () -> Void) -> some View {
        filterChipButton(isSelected: isSelected, action: action) {
            Text(title)
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        filterChipButton(isSelected: isSelected, action: action) {
            Text(verbatim: title)
        }
    }

    private func filterChipButton<LabelContent: View>(
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> LabelContent
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.snappy(duration: 0.22)) {
                action()
            }
        } label: {
            label()
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .foregroundStyle(isSelected ? Theme.invertedText : Theme.primaryText)
                .background(isSelected ? Theme.invertedFill : Theme.surfaceFill, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: isSelected ? 0 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Interactive Spotlight Hero

    private func spotlightHero(
        _ tier: Rarity,
        summary: CardTierBinderSummary,
        tilt liveTilt: CGSize
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        let ink = tier.ink
        let badgeBg = Color.black.opacity(ink == .white ? 0.36 : 0.76)
        let isLightCanvas = colorScheme == .light

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TierBadgePill(
                    title: LocalizedStringKey(tier.title),
                    ink: ink,
                    isHolo: tier == .holo,
                    fontSize: 10.5,
                    tracking: 1.2,
                    horizontalPadding: 10,
                    verticalPadding: 4
                )

                Spacer(minLength: 6)

                HStack(spacing: 4) {
                    Image(systemName: summary.isUnlocked ? "checkmark.circle.fill" : "clock")
                        .font(.system(size: 10.5, weight: .bold))
                    Text(summary.isUnlocked ? LocalizedStringKey("Unlocked") : LocalizedStringKey(hoursLabel(tier.minimumHours)))
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(badgeBg, in: Capsule())
                .foregroundStyle(.white)
            }

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey(tier.finishLabel))
                        .font(.caption.weight(.semibold))
                        .opacity(0.78)

                    Text(hoursLabel(tier.minimumHours))
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: tier == .holo ? "sparkles" : (selectedCard?.symbol ?? summary.firstAchiever?.symbol ?? "headphones"))
                    .font(.system(size: 42, weight: .thin))
                    .opacity(0.86)
                    .offset(x: liveTilt.width * -6, y: liveTilt.height * -4)
                    .accessibilityHidden(true)
            }

            spotlightFooter(tier: tier, summary: summary, ink: ink)
        }
        .foregroundStyle(ink)
        .padding(18)
        .background(FoilSurface(rarity: tier, tilt: liveTilt))
        .clipShape(shape)
        .overlay(
            CardSpecularBorder(
                cornerRadius: 24,
                rarity: tier,
                ink: ink,
                tilt: liveTilt,
                usesPrismRim: true
            )
        )
        .background {
            shape.fill(Theme.card)
                .shadow(color: isLightCanvas ? Theme.cardShadow : tier.glow.opacity(tier == .holo ? 0.45 : 0.35), radius: isLightCanvas ? 14 : 20, y: isLightCanvas ? 6 : 12)
        }
        .rotation3DEffect(.degrees(Double(liveTilt.width) * 4), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
        .rotation3DEffect(.degrees(Double(-liveTilt.height) * 3), axis: (x: 1, y: 0, z: 0), perspective: 0.7)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func spotlightFooter(tier: Rarity, summary: CardTierBinderSummary, ink: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Rectangle()
                .fill(ink.opacity(0.16))
                .frame(height: 1)

            if let singleCard = selectedCard {
                let currentTier = singleCard.rarity
                let hours = singleCard.lifetimeMinutes / 60
                let inspectingFutureTier = tier.minimumHours > currentTier.minimumHours && !summary.isUnlocked
                HStack {
                    Text("\(CardTierBinderSummary.shortModelName(singleCard.model)) · \(singleCard.lifetimeMinutes.minutesText)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .lineLimit(1)
                    Spacer()
                    if let achieved = singleCard.tierAchievedDates[tier] {
                        Text(DateText.shortMonthYear(achieved, calendar: .current, locale: locale))
                            .font(.caption2.weight(.semibold))
                            .opacity(0.78)
                    }
                }
                if inspectingFutureTier {
                    let progress = tier.minimumHours > 0 ? min(max(hours / tier.minimumHours, 0), 1) : 1
                    let remaining = max(1, Int(ceil(tier.minimumHours - hours)))
                    tierProgressBar(progress, ink: ink)
                    Text("\(remaining)h to \(Text(LocalizedStringKey(tier.title)))")
                        .font(.caption2.weight(.semibold))
                        .opacity(0.86)
                } else {
                    tierProgressBar(currentTier.progressToNextTier(minutes: singleCard.lifetimeMinutes), ink: ink)
                    if let next = currentTier.nextTier {
                        let remaining = max(1, Int(ceil(next.minimumHours - hours)))
                        Text("\(remaining)h to \(Text(LocalizedStringKey(next.title)))")
                            .font(.caption2.weight(.semibold))
                            .opacity(0.86)
                    } else {
                        Text("Max tier reached ✦")
                            .font(.caption2.weight(.bold))
                    }
                }
            } else if summary.isUnlocked {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(summary.unlockedCards) { item in
                            let dateText = item.tierAchievedDates[tier].map {
                                " · " + DateText.shortMonthYear($0, calendar: .current, locale: locale)
                            } ?? ""
                            HStack(spacing: 4) {
                                Image(systemName: item.symbol)
                                    .font(.system(size: 10, weight: .semibold))
                                Text("\(CardTierBinderSummary.shortModelName(item.model))\(dateText)")
                                    .lineLimit(1)
                            }
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(ink == .white ? 0.24 : 0.10), in: Capsule())
                        }
                    }
                }
            } else if let closest = scopedCards.max(by: { $0.lifetimeMinutes < $1.lifetimeMinutes }) {
                let closestHours = closest.lifetimeMinutes / 60
                let remaining = max(1, Int(ceil(tier.minimumHours - closestHours)))
                let progress = tier.minimumHours > 0 ? min(max(closestHours / tier.minimumHours, 0), 1) : 1
                HStack {
                    Text(CardTierBinderSummary.shortModelName(closest.model))
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                    Spacer()
                    Text("\(remaining)h to go")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .opacity(0.82)
                }
                tierProgressBar(progress, ink: ink)
            } else {
                Text("Listen with supported headphones to unlock tiers.")
                    .font(.caption2.weight(.medium))
                    .opacity(0.82)
            }
        }
    }

    private func tierProgressBar(_ value: Double, ink: Color) -> some View {
        let clamped = min(max(value, 0), 1)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(ink.opacity(0.20))
                if clamped > 0 {
                    Capsule()
                        .fill(ink)
                        .frame(width: max(6, geo.size.width * clamped))
                }
            }
        }
        .frame(height: 5)
    }

    // MARK: - Minimal 2x3 Binder Tile

    private func binderCard(_ summary: CardTierBinderSummary, selectedTier: Rarity) -> some View {
        let tier = summary.tier
        let unlocked = summary.isUnlocked
        let isSelected = selectedTier == tier
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let ink = tier.ink
        let isLightCanvas = colorScheme == .light
        let attribution = summary.compactAttribution(isSingleDevice: selectedCard != nil, locale: locale)

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.snappy(duration: 0.24)) {
                inspectedTier = tier
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    TierBadgePill(
                        title: LocalizedStringKey(tier.shortName.uppercased()),
                        ink: ink,
                        isHolo: tier == .holo,
                        fontSize: 9.5,
                        tracking: 0.8,
                        horizontalPadding: 7,
                        verticalPadding: 3
                    )

                    Spacer(minLength: 4)

                    if summary.isCurrent {
                        Text("NOW")
                            .font(.system(size: 8.5, weight: .black, design: .rounded))
                            .tracking(0.5)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(ink, in: Capsule())
                            .foregroundStyle(ink == .white ? .black : .white)
                    } else if unlocked {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                    } else {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .opacity(0.75)
                    }
                }

                Spacer(minLength: 10)

                Text(hoursLabel(tier.minimumHours))
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if let attribution {
                    Text(attribution)
                        .font(.system(size: 10.5, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .opacity(0.78)
                        .padding(.top, 2)
                }
            }
            .foregroundStyle(ink)
            .padding(13)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .background(FoilSurface(rarity: tier, tilt: .zero))
            .clipShape(shape)
            .saturation(unlocked || isSelected ? 1.0 : 0.78)
            .opacity(unlocked || isSelected ? 1.0 : (isLightCanvas ? 0.86 : 0.74))
            .overlay(
                Group {
                    if tier == .holo && (unlocked || isSelected) {
                        shape.strokeBorder(
                            AngularGradient(colors: tier.prismRimColors, center: .center),
                            lineWidth: isSelected ? 2.2 : 1.6
                        )
                    } else {
                        shape.strokeBorder(
                            isSelected
                                ? (isLightCanvas ? Color.black.opacity(0.78) : Color.white.opacity(0.92))
                                : (isLightCanvas ? Color.black.opacity(unlocked ? 0.14 : 0.08) : Color.white.opacity(unlocked ? 0.36 : 0.16)),
                            lineWidth: isSelected ? 2 : 1
                        )
                    }
                }
            )
            .background {
                if isSelected {
                    shape.fill(Theme.card)
                        .shadow(color: isLightCanvas ? Theme.cardShadow : tier.glow.opacity(0.38), radius: 10, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Text(LocalizedStringKey(tier.title))), \(hoursLabel(tier.minimumHours))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func hoursLabel(_ hours: Double) -> String {
        hours == 0 ? "0h+" : "\(Int(hours))h+"
    }
}
