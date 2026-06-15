//
//  HomeViewModel.swift
//  Terrarium — HomeFeature
//
//  Observation-based view model. Holds render state (sky/world/quest) and the
//  active presentation sheet. Constructed with providers; mock them in tests.
//

import Foundation
import Observation

/// The sheets HomeView can present.
enum HomeSheet: Identifiable, Equatable {
    case questDetail(Quest)
    case journal(Quest)
    case growthLog
    case specimenJournal(UUID)

    var id: String {
        switch self {
        case .questDetail(let quest): return "questDetail-\(quest.id.uuidString)"
        case .journal(let quest):     return "journal-\(quest.id.uuidString)"
        case .growthLog:              return "growthLog"
        case .specimenJournal(let propID): return "specimen-\(propID.uuidString)"
        }
    }
}

/// Read-only reflection shown when a specimen is tapped.
struct SpecimenReflection: Equatable {
    let placeName: String
    let date: Date
    let text: String
    let hasPhoto: Bool
}

@Observable
@MainActor
final class HomeViewModel {
    private(set) var sky: SkyState
    private(set) var world: WorldState
    private(set) var suggestedQuest: Quest
    var activeSheet: HomeSheet?

    /// Exploration points total — drives the garden-progress surface. Refreshed
    /// when the Home tab appears (Explore awards points on other tabs).
    private(set) var points: Int = 0
    /// Points needed per garden tier (mirrors WorldStore).
    let pointsPerTier = 100

    /// Persistent store, when available — drives completion + journaling.
    var worldStore: WorldStore?
    /// The specimen most recently grown, so the journal sheet can attach to it.
    private(set) var lastAwardedPropID: UUID?

    private let skyProvider: SkyStateProviding
    private let worldProvider: WorldStateProviding
    private let cycler = DebugSkyCycler()

    init(sky: SkyStateProviding, world: WorldStateProviding, quests: QuestSuggesting) {
        self.skyProvider = sky
        self.worldProvider = world
        self.sky = sky.current()
        self.world = world.current()
        self.suggestedQuest = quests.suggestion()
    }

    // MARK: - Garden progress

    /// Re-read the world + points (call when the Home tab becomes visible, since
    /// points are awarded from the Drift/Anchor tabs while Home stays alive).
    func refresh() {
        world = worldProvider.current()
        points = worldStore?.totalPoints() ?? 0
    }

    /// Current garden tier and progress (0...1) toward the next.
    var tier: Int { points / pointsPerTier }
    var tierProgress: Double {
        Double(points % pointsPerTier) / Double(pointsPerTier)
    }
    var pointsToNextTier: Int { pointsPerTier - (points % pointsPerTier) }

    // MARK: - Navigation

    func beginQuest() {
        activeSheet = .questDetail(suggestedQuest)
    }

    func openJournal(for quest: Quest) {
        activeSheet = .journal(quest)
    }

    func openGrowthLog() {
        activeSheet = .growthLog
    }

    func dismissSheet() {
        activeSheet = nil
    }

    // MARK: - Completion → growth (§D)

    /// Verify the quest (honor by default), grow + persist the world, then
    /// offer the reflection sheet. Refreshes the render state so the globe grows.
    func completeQuest(_ quest: Quest, verifier: QuestVerifier = HonorVerifier()) async {
        guard let store = worldStore else { return }
        let awarded = await store.complete(quest: quest, with: verifier)
        lastAwardedPropID = awarded?.id
        world = worldProvider.current()
        activeSheet = .journal(quest)
    }

    // MARK: - Journal (§E)

    /// Save a reflection against the most recently grown specimen.
    func saveReflection(for quest: Quest, text: String, photoRef: String? = nil) {
        guard let store = worldStore,
              let propID = lastAwardedPropID,
              let prop = store.prop(withID: propID) else { return }
        store.addJournal(to: prop, questId: quest.id, text: text,
                         photoRef: photoRef, placeName: quest.placeName)
        world = worldProvider.current()
    }

    /// The reflection attached to a tapped specimen, if any.
    func journalEntry(forPropID id: UUID) -> JournalEntry? {
        worldStore?.journalEntry(forPropID: id)
    }

    /// Open the reflection for a tapped specimen (no-op if it has none).
    func openSpecimen(propID id: UUID) {
        guard journalEntry(forPropID: id) != nil else { return }
        activeSheet = .specimenJournal(id)
    }

    /// Display data for a tapped specimen's reflection.
    func reflection(forPropID id: UUID) -> SpecimenReflection? {
        guard let entry = worldStore?.journalEntry(forPropID: id) else { return nil }
        return SpecimenReflection(placeName: entry.placeName,
                                  date: entry.date,
                                  text: entry.text,
                                  hasPhoto: entry.photoRef != nil)
    }

    // MARK: - Debug

    /// Steps the sky through dawn → midday → goldenHour → night so the dynamic
    /// SkyLayer is provable offline. Wired to a hidden long-press in HomeView.
    func cycleSky() {
        sky = cycler.next(after: sky)
    }
}
