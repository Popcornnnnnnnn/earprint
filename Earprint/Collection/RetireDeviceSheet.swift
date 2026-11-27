import SwiftUI

/// Retirement ceremony sheet to seal an old headphone pair in the Vault with a reason, date, and farewell engraving.
struct RetireDeviceSheet: View {
    let card: HeadphoneCard
    var firstWear: Date? = nil
    var lastWear: Date? = nil
    var existingRetirement: DeviceRetirement? = nil
    var colorOption: DeviceColorOption? = nil
    let onSave: (DeviceRetirement) -> Void
    var onUnretire: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var reason: RetirementReason
    @State private var retiredAt: Date
    @State private var farewellNote: String

    private let reasonColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    init(
        card: HeadphoneCard,
        firstWear: Date? = nil,
        lastWear: Date? = nil,
        existingRetirement: DeviceRetirement? = nil,
        colorOption: DeviceColorOption? = nil,
        onSave: @escaping (DeviceRetirement) -> Void,
        onUnretire: (() -> Void)? = nil
    ) {
        self.card = card
        self.firstWear = firstWear
        self.lastWear = lastWear
        self.existingRetirement = existingRetirement
        self.colorOption = colorOption
        self.onSave = onSave
        self.onUnretire = onUnretire

        let upper = max(Date(), firstWear ?? Date())
        let lower = min(firstWear ?? .distantPast, upper)
        let defaultDate = min(max(existingRetirement?.retiredAt ?? lastWear ?? Date(), lower), upper)
        _reason = State(initialValue: existingRetirement?.reason ?? .upgraded)
        _retiredAt = State(initialValue: defaultDate)
        _farewellNote = State(initialValue: existingRetirement?.farewellNote ?? "")
    }

    private var dateRange: ClosedRange<Date> {
        let upper = max(Date(), firstWear ?? Date())
        let lower = min(firstWear ?? .distantPast, upper)
        return lower...upper
    }

    private var careerSpanText: String {
        let start = firstWear.map(DossierFormat.dot) ?? (card.firstMet.isEmpty ? "—" : card.firstMet)
        let end = DossierFormat.dot(retiredAt)
        return "\(start) – \(end)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroCard

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Why are you retiring this pair?")
                            .font(.headline)

                        LazyVGrid(columns: reasonColumns, spacing: 10) {
                            ForEach(RetirementReason.allCases) { item in
                                reasonTile(item)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Retirement date")
                            .font(.headline)

                        DatePicker(
                            "Retirement date",
                            selection: $retiredAt,
                            in: dateRange,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DossierPalette.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(DossierPalette.hairline, lineWidth: 1)
                        )

                        Text("Freezes this pair's career span, daily averages, and final Ear Grade on this date.")
                            .font(.caption)
                            .foregroundStyle(DossierPalette.dim)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Farewell note")
                                .font(.headline)
                            Text("Optional")
                                .font(.caption)
                                .foregroundStyle(DossierPalette.dim)
                            Spacer()
                            Text("\(min(farewellNote.count, DeviceRetirement.maxFarewellLength))/\(DeviceRetirement.maxFarewellLength)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(DossierPalette.faint)
                        }

                        TextField("e.g. Survived 3 winters & 40 flights", text: $farewellNote)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .background(DossierPalette.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(DossierPalette.hairline, lineWidth: 1)
                            )
                    }

                    VStack(spacing: 10) {
                        Button {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            let payload = DeviceRetirement(
                                retiredAt: retiredAt,
                                reason: reason,
                                farewellNote: farewellNote,
                                acknowledgedActivityAt: existingRetirement?.acknowledgedActivityAt
                            ).sanitized
                            onSave(payload)
                            dismiss()
                        } label: {
                            Label(
                                existingRetirement == nil ? "Seal in Vault" : "Save Vault Details",
                                systemImage: "archivebox.fill"
                            )
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .foregroundStyle(Theme.invertedText)
                            .background(Theme.invertedFill, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        if existingRetirement != nil, let onUnretire {
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onUnretire()
                                dismiss()
                            } label: {
                                Label("Restore to Active Collection", systemImage: "arrow.uturn.backward")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 46)
                                    .foregroundStyle(DossierPalette.primaryText)
                                    .background(DossierPalette.panel, in: Capsule())
                                    .overlay(Capsule().strokeBorder(DossierPalette.hairline, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(18)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .foregroundStyle(DossierPalette.primaryText)
            .background(DossierPalette.ink.ignoresSafeArea())
            .navigationTitle(existingRetirement == nil ? "Retire to Vault" : "Vault Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var heroCard: some View {
        let rarity = card.rarity
        let isLight = colorScheme == .light
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [rarity.glow.opacity(isLight ? 0.24 : 0.34), rarity.accent.opacity(0.08), .clear],
                            center: .center,
                            startRadius: 4,
                            endRadius: 34
                        )
                    )
                Circle()
                    .strokeBorder(rarity.accent.opacity(0.45), lineWidth: 1.2)
                if card.modelKey.collectionArtwork != nil {
                    HeadphoneArtwork(card: card, colorOption: colorOption, showsChargingCase: false, showsShadow: false)
                        .padding(7)
                } else {
                    Image(systemName: card.symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(rarity.accent)
                }
            }
            .frame(width: 58, height: 58)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(card.model)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .lineLimit(1)
                Text("\(card.lifetimeMinutes.minutesText) · \(card.sessions) sessions")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(rarity.accent)
                    .monospacedDigit()
                Text(careerSpanText)
                    .font(.caption.monospaced())
                    .foregroundStyle(DossierPalette.dim)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(DossierPalette.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(rarity.accent.opacity(0.28), lineWidth: 1)
        )
    }

    private func reasonTile(_ item: RetirementReason) -> some View {
        let selected = reason == item
        let accent = card.rarity.accent
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.snappy(duration: 0.2)) {
                reason = item
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: item.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selected ? accent : DossierPalette.dim)
                    .frame(width: 20)
                Text(LocalizedStringKey(item.title))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? accent.opacity(0.14) : DossierPalette.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? accent.opacity(0.75) : DossierPalette.hairline, lineWidth: selected ? 1.4 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
