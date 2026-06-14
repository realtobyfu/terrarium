//
//  JournalListView.swift
//  Terrarium — Prototypes
//
//  A warm, Hidden Garden / Liquid Glass redesign of the Journal: the place where
//  past discoveries are revisited. A list of tactile glass rows (specimen icon,
//  place, when) that open a detail/reflection sheet keyed to the tapped
//  discovery.
//
//  Reads its data the same way the existing journal views do — purely through the
//  existing `WorldStore` public read APIs (`current()`, `journalEntry(forPropID:)`,
//  `prop(withID:)`). No domain logic is changed; the view also takes plain
//  `[JournalDiscovery]` value types so it previews and tests in isolation.
//
//  iOS 26 APIs: glassEffect / GlassEffectContainer (rows, empty state),
//  .buttonStyle(.glassProminent / .glass), .sheet(item:), .scrollEdgeEffectStyle.
//

import SwiftUI

// MARK: - Read model

/// One revisitable discovery — a grown specimen with its attached reflection.
/// A plain value type so `JournalListView` is previewable and testable without a
/// SwiftData context.
struct JournalDiscovery: Identifiable, Equatable {
    let id: UUID
    let kind: WorldProp.Kind
    /// Specimen appearance variant ("clear" / "foggy"), tints the row & art.
    let variant: String
    let placeName: String
    let date: Date
    let text: String
    let hasPhoto: Bool
    let poiRef: String?

    /// One-line VoiceOver label for a journal row.
    var rowAccessibilityLabel: String {
        let day = date.formatted(date: .abbreviated, time: .omitted)
        return "\(placeName), \(kind.gardenLabel), \(day)" + (hasPhoto ? ", photo attached" : "")
    }
}

extension JournalDiscovery {
    /// Builds the full list of journaled discoveries from a `WorldStore`, newest
    /// first, using only its existing public read APIs (no domain changes).
    @MainActor
    static func all(from store: WorldStore) -> [JournalDiscovery] {
        store.current().props
            .compactMap { prop -> JournalDiscovery? in
                guard let entry = store.journalEntry(forPropID: prop.id) else { return nil }
                return JournalDiscovery(
                    id: prop.id,
                    kind: prop.kind,
                    variant: prop.variant,
                    placeName: entry.placeName,
                    date: entry.date,
                    text: entry.text,
                    hasPhoto: entry.photoRef != nil,
                    poiRef: store.prop(withID: prop.id)?.poiRef
                )
            }
            .sorted { $0.date > $1.date }
    }
}

// MARK: - JournalListView

struct JournalListView: View {
    let discoveries: [JournalDiscovery]
    /// Persist an edited reflection. No-op by default; the `WorldStore`
    /// convenience init wires it to the existing journaling API.
    var onSaveReflection: (JournalDiscovery, String) -> Void = { _, _ in }

    @State private var selected: JournalDiscovery?

    init(discoveries: [JournalDiscovery],
         onSaveReflection: @escaping (JournalDiscovery, String) -> Void = { _, _ in }) {
        self.discoveries = discoveries
        self.onSaveReflection = onSaveReflection
    }

    var body: some View {
        ZStack {
            JournalGlass.backgroundWash.ignoresSafeArea()
            content
        }
        .sheet(item: $selected) { discovery in
            JournalDetailSheet(discovery: discovery) { text in
                onSaveReflection(discovery, text)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if discoveries.isEmpty {
            JournalEmptyState().padding(Theme.Spacing.l)
        } else {
            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    header
                    GlassEffectContainer(spacing: Theme.Spacing.m) {
                        VStack(spacing: Theme.Spacing.m) {
                            ForEach(discoveries) { discovery in
                                Button {
                                    selected = discovery
                                } label: {
                                    JournalRow(discovery: discovery)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(discovery.rowAccessibilityLabel)
                                .accessibilityHint("Opens the discovery")
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.s)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .scrollIndicators(.hidden)
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("FIELD NOTES")
                .font(Theme.Typography.body(13, weight: .semibold))
                .tracking(2.0)
                .foregroundStyle(Theme.Garden.mossLight)
            Text("Your Journal")
                .font(Theme.Typography.display(30, weight: .bold))
                .foregroundStyle(Theme.Palette.title)
            Text(subtitle)
                .font(Theme.Typography.body(14))
                .foregroundStyle(Theme.Palette.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.m)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        discoveries.count == 1 ? "1 place revisited" : "\(discoveries.count) places revisited"
    }
}

extension JournalListView {
    /// Live, `WorldStore`-backed journal. Saving an edited reflection appends a
    /// note via the existing `addJournal` API (no domain change).
    @MainActor
    init(store: WorldStore) {
        self.init(
            discoveries: JournalDiscovery.all(from: store),
            onSaveReflection: { discovery, text in
                guard let prop = store.prop(withID: discovery.id) else { return }
                store.addJournal(to: prop, questId: UUID(), text: text,
                                 placeName: discovery.placeName)
            }
        )
    }
}

// MARK: - Row

private struct JournalRow: View {
    let discovery: JournalDiscovery

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            specimenBadge

            VStack(alignment: .leading, spacing: 3) {
                Text(discovery.placeName)
                    .font(Theme.Typography.display(19, weight: .semibold))
                    .foregroundStyle(Theme.Palette.title)
                    .lineLimit(1)
                Text(metaLine)
                    .font(Theme.Typography.body(13))
                    .foregroundStyle(Theme.Palette.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Theme.Spacing.s)

            if discovery.hasPhoto {
                Image(systemName: "photo")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.label)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Palette.secondary.opacity(0.6))
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.card))
    }

    private var specimenBadge: some View {
        let tint = JournalGlass.badgeTint(for: discovery.variant)
        return Image(systemName: discovery.kind.rewardSymbol)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(tint.icon)
            .frame(width: 46, height: 46)
            .background(Circle().fill(tint.fill))
            .overlay(Circle().strokeBorder(tint.icon.opacity(0.18), lineWidth: 1))
    }

    private var metaLine: String {
        "\(discovery.kind.gardenLabel) · \(JournalGlass.timeOfDay(discovery.date)) · "
            + discovery.date.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Empty state

private struct JournalEmptyState: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            ZStack {
                Circle().fill(Theme.Garden.leaf.opacity(0.30)).frame(width: 96, height: 96)
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(Theme.Garden.moss)
            }

            Text("No discoveries yet")
                .font(Theme.Typography.display(24, weight: .bold))
                .foregroundStyle(Theme.Palette.title)

            Text("Arrive somewhere new and your garden will start filling these pages.")
                .font(Theme.Typography.body(15))
                .foregroundStyle(Theme.Palette.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.glass))
        .overlay(alignment: .topTrailing) {
            WashiTape(width: 84, height: 22, rotation: .degrees(-7)).offset(x: -14, y: 10)
        }
    }
}

// MARK: - Detail / reflection sheet

private struct JournalDetailSheet: View {
    let discovery: JournalDiscovery
    var onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reflection: String
    @State private var saved = false

    init(discovery: JournalDiscovery, onSave: @escaping (String) -> Void) {
        self.discovery = discovery
        self.onSave = onSave
        _reflection = State(initialValue: discovery.text)
    }

    var body: some View {
        ZStack {
            JournalGlass.backgroundWash.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    artHeader
                    titleBlock
                    discoveryPanel
                    reflectionEditor
                }
                .padding(Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .scrollIndicators(.hidden)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Art header

    private var artHeader: some View {
        ScenicArtBand(poiRef: artSeed, category: artCategory, weather: artWeather)
            .frame(height: 176)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottomLeading) {
                specimenChip.padding(Theme.Spacing.m)
            }
            .overlay(alignment: .topTrailing) {
                WashiTape(width: 88, height: 22, rotation: .degrees(-5)).offset(x: -12, y: 10)
            }
            .clipShape(.rect(cornerRadius: Theme.Radius.hero))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
                    .strokeBorder(Theme.Palette.cardBorder.opacity(0.5), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }

    private var specimenChip: some View {
        HStack(spacing: 6) {
            Image(systemName: discovery.kind.rewardSymbol)
                .font(.system(size: 14, weight: .semibold))
            Text(discovery.kind.gardenLabel)
                .font(Theme.Typography.body(13, weight: .semibold))
        }
        .foregroundStyle(Theme.Palette.title)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassEffect(.regular, in: .capsule)
    }

    // MARK: Title

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(discovery.date.formatted(date: .complete, time: .omitted).uppercased())
                .font(Theme.Typography.body(12, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(Theme.Palette.label)
            Text(discovery.placeName)
                .font(Theme.Typography.display(28, weight: .bold))
                .foregroundStyle(Theme.Palette.title)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Discovery text (read)

    private var discoveryPanel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label("What you found", systemImage: "sparkles")
                .font(Theme.Typography.body(13, weight: .semibold))
                .foregroundStyle(Theme.Garden.mossLight)

            SoftPanel(cornerRadius: Theme.Radius.card) {
                Text(discovery.text)
                    .font(Theme.Typography.body(16))
                    .foregroundStyle(Theme.Palette.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(Theme.Spacing.l)
            }

            if discovery.hasPhoto {
                Label("Photo attached", systemImage: "photo")
                    .font(Theme.Typography.body(14))
                    .foregroundStyle(Theme.Palette.secondary)
            }
        }
    }

    // MARK: Reflection (edit)

    private var reflectionEditor: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label("Your reflection", systemImage: "pencil.and.scribble")
                .font(Theme.Typography.body(13, weight: .semibold))
                .foregroundStyle(Theme.Garden.mossLight)

            SoftPanel(cornerRadius: Theme.Radius.card) {
                TextEditor(text: $reflection)
                    .font(Theme.Typography.body(16))
                    .foregroundStyle(Theme.Palette.title)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(Theme.Spacing.m)
                    .onChange(of: reflection) { _, _ in saved = false }
            }

            GlassEffectContainer(spacing: Theme.Spacing.m) {
                HStack(spacing: Theme.Spacing.m) {
                    Button {
                        // Photo capture is out of scope for this prototype.
                    } label: {
                        Label("Add photo", systemImage: "photo.badge.plus")
                            .font(Theme.Typography.body(15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.glass)
                    .tint(Theme.Garden.mossLight)
                    .disabled(true)

                    Button {
                        onSave(reflection)
                        saved = true
                    } label: {
                        Label(saved ? "Saved" : "Save",
                              systemImage: saved ? "checkmark" : "tray.and.arrow.down.fill")
                            .font(Theme.Typography.body(15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.Garden.moss)
                    .disabled(reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    // MARK: Art derivation

    /// Cosmetic art mood from the specimen kind (no POI category is stored on a
    /// discovery): foliage reads as a meadow, structures as a warm hearth.
    private var artCategory: POICategory {
        switch discovery.kind {
        case .tree, .flowers: return .park
        case .building:       return .coffee
        }
    }

    private var artWeather: Weather { discovery.variant == "foggy" ? .fog : .clear }
    private var artSeed: String { discovery.poiRef ?? "poi.\(discovery.placeName)" }
}

// MARK: - Shared helpers

private enum JournalGlass {
    static var backgroundWash: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "F2E8D2"), Color(hex: "FBF2E0"), Color(hex: "EFF1E2")],
            startPoint: .top, endPoint: .bottom
        )
    }

    static func badgeTint(for variant: String) -> (icon: Color, fill: Color) {
        variant == "foggy"
            ? (Theme.Garden.pineLight, Theme.Garden.mint.opacity(0.35))
            : (Theme.Garden.moss, Theme.Garden.leaf.opacity(0.40))
    }

    static func timeOfDay(_ date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12:  return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<21: return "Evening"
        default:      return "Night"
        }
    }
}

// MARK: - Previews

private extension JournalDiscovery {
    static let samples: [JournalDiscovery] = [
        JournalDiscovery(id: UUID(), kind: .tree, variant: "clear",
                         placeName: "Dolores Park", date: Date(timeIntervalSinceNow: -3_600),
                         text: "Sun on the slope, dogs everywhere, the city humming below. I sat for an hour and didn't reach for my phone once.",
                         hasPhoto: true, poiRef: "poi.dolores-park.sf"),
        JournalDiscovery(id: UUID(), kind: .building, variant: "clear",
                         placeName: "Sightglass Coffee", date: Date(timeIntervalSinceNow: -90_000),
                         text: "Cortado at the upstairs rail. Watched the roaster turn for a while.",
                         hasPhoto: false, poiRef: "poi.sightglass-coffee.sf"),
        JournalDiscovery(id: UUID(), kind: .flowers, variant: "foggy",
                         placeName: "Ocean Beach", date: Date(timeIntervalSinceNow: -280_000),
                         text: "The fog came in fast. I named three sounds: gulls, surf, a far-off dog.",
                         hasPhoto: true, poiRef: "poi.ocean-beach.sf"),
    ]
}

#Preview("Journal — list") {
    JournalListView(discoveries: JournalDiscovery.samples)
}

#Preview("Journal — empty") {
    JournalListView(discoveries: [])
}

#Preview("Journal — detail sheet") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            JournalDetailSheet(discovery: JournalDiscovery.samples[2]) { _ in }
        }
}
