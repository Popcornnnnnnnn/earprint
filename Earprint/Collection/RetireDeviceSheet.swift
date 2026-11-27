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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var reasonIconWidth: CGFloat = 20

    @State private var reason: RetirementReason
    @State private var retiredAt: Date
    @State private var farewellNote: String
    @State private var hasEditedDate = false
    private let initialPickedDay: DeviceRetirement.CalendarDay

    private var reasonColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            [GridItem(.flexible(), spacing: 10)]
        } else {
            [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        }
    }

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

        let cal = DeviceRetirement.gregorianCalendar(timeZone: .current)
        let allowed = Self.dateBounds(firstWear: firstWear, existingRetirement: existingRetirement, calendar: cal)
        let seed: Date = if let existing = existingRetirement,
            let localNoon = cal.date(from: DateComponents(year: existing.retiredDay.year, month: existing.retiredDay.month, day: existing.retiredDay.day, hour: 12)) {
            localNoon
        } else {
            cal.date(from: cal.dateComponents([.year, .month, .day], from: lastWear ?? Date()))
                .flatMap { cal.date(bySettingHour: 12, minute: 0, second: 0, of: $0) }
                ?? Date()
        }
        let defaultDate = min(max(seed, allowed.lowerBound), allowed.upperBound)
        let seedDay = existingRetirement?.retiredDay ?? DeviceRetirement.CalendarDay(date: defaultDate, calendar: cal)
        self.initialPickedDay = seedDay
        _reason = State(initialValue: existingRetirement?.reason ?? .upgraded)
        _retiredAt = State(initialValue: defaultDate)
        _farewellNote = State(initialValue: existingRetirement?.farewellNote ?? "")
    }

    private static func dateBounds(
        firstWear: Date?,
        existingRetirement: DeviceRetirement?,
        calendar: Calendar
    ) -> ClosedRange<Date> {
        let todayDay = DeviceRetirement.CalendarDay(date: Date(), calendar: calendar)
        var candidates = [todayDay]
        if let firstWear {
            candidates.append(DeviceRetirement.CalendarDay(date: firstWear, calendar: calendar))
        }
        if let existingRetirement {
            candidates.append(existingRetirement.retiredDay)
        }
        let minDay = candidates.min() ?? todayDay
        let maxDay = candidates.max() ?? todayDay
        let lowerAnchor = calendar.date(from: DateComponents(year: minDay.year, month: minDay.month, day: minDay.day, hour: 12)) ?? Date()
        let upperAnchor = calendar.date(from: DateComponents(year: maxDay.year, month: maxDay.month, day: maxDay.day, hour: 12)) ?? Date()
        let lower = calendar.dateInterval(of: .day, for: lowerAnchor)?.start ?? lowerAnchor
        let upper = calendar.dateInterval(of: .day, for: upperAnchor)?.end.addingTimeInterval(-1) ?? upperAnchor
        return min(lower, upper)...max(lower, upper)
    }

    private var dateRange: ClosedRange<Date> {
        Self.dateBounds(
            firstWear: firstWear,
            existingRetirement: existingRetirement,
            calendar: DeviceRetirement.gregorianCalendar(timeZone: .current)
        )
    }

    private var careerSpanText: String {
        let cal = DeviceRetirement.gregorianCalendar(timeZone: .current)
        let start = firstWear.map { DateText.dotted($0, calendar: cal) } ?? (card.firstMet.isEmpty ? "—" : card.firstMet)
        let end = if let existingRetirement, !hasEditedDate {
            existingRetirement.formattedRetiredDate
        } else {
            DeviceRetirement.CalendarDay(date: retiredAt, calendar: cal).dottedText
        }
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
                        .environment(\.calendar, DeviceRetirement.gregorianCalendar(timeZone: .current))
                        .onChange(of: retiredAt) { _, updated in
                            let currentDay = DeviceRetirement.CalendarDay(
                                date: updated,
                                calendar: DeviceRetirement.gregorianCalendar(timeZone: .current)
                            )
                            hasEditedDate = currentDay != initialPickedDay
                        }
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
                            Text("\(farewellNote.count)/\(DeviceRetirement.maxFarewellLength)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(DossierPalette.faint)
                        }

                        TextField("e.g. Survived 3 winters & 40 flights", text: $farewellNote)
                            .accessibilityLabel("Farewell note")
                            .onChange(of: farewellNote) { _, updated in
                                let clamped = DeviceRetirement.clampEditingNote(updated)
                                if clamped != updated {
                                    farewellNote = clamped
                                }
                            }
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
                            let cal = DeviceRetirement.gregorianCalendar(timeZone: .current)
                            let pickedDay = DeviceRetirement.CalendarDay(date: retiredAt, calendar: cal)
                            let payload: DeviceRetirement
                            if let existing = existingRetirement, !hasEditedDate || pickedDay == existing.retiredDay {
                                payload = DeviceRetirement(
                                    retiredDay: existing.retiredDay,
                                    timeZoneIdentifier: existing.timeZoneIdentifier,
                                    reason: reason,
                                    farewellNote: farewellNote,
                                    acknowledgedActivityAt: existing.acknowledgedActivityAt
                                ).sanitized
                            } else {
                                payload = DeviceRetirement(
                                    retiredDay: pickedDay,
                                    timeZoneIdentifier: TimeZone.current.identifier,
                                    reason: reason,
                                    farewellNote: farewellNote,
                                    acknowledgedActivityAt: nil
                                ).sanitized
                            }
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
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.78)
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
                    .frame(minWidth: reasonIconWidth)
                Text(LocalizedStringKey(item.title))
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
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
