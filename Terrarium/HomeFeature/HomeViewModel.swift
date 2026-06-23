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
    case growthLog
    case specimenJournal(UUID)
    case settings

    var id: String {
        switch self {
        case .growthLog:                   return "growthLog"
        case .specimenJournal(let propID): return "specimen-\(propID.uuidString)"
        case .settings:                    return "settings"
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
    var activeSheet: HomeSheet?

    /// Exploration points total — drives the garden-progress surface. Refreshed
    /// when the Home tab appears (Explore awards points on other tabs).
    private(set) var points: Int = 0
    /// Points needed per garden tier (mirrors WorldStore).
    let pointsPerTier = 100

    /// Persistent store, when available — drives points + journaling.
    var worldStore: WorldStore?

    private let skyProvider: SkyStateProviding
    private let worldProvider: WorldStateProviding
    private let cycler = DebugSkyCycler()

    init(sky: SkyStateProviding, world: WorldStateProviding) {
        self.skyProvider = sky
        self.worldProvider = world
        self.sky = sky.current()
        self.world = world.current()
    }

    // MARK: - Garden progress

    /// Re-read the world + points (call when the Home tab becomes visible, since
    /// points are awarded from the Drift/Anchor tabs while Home stays alive).
    func refresh() {
        world = worldProvider.current()
        points = worldStore?.totalPoints() ?? 0
    }

    /// Identity for the globe render — changes when props grow or vitality shifts,
    /// so WorldView rebuilds and the growth/lushness actually appears.
    var globeSignature: String {
        "\(world.props.count)-\(Int((world.vitality * 20).rounded()))"
    }

    /// Current garden tier and progress (0...1) toward the next.
    var tier: Int { points / pointsPerTier }
    var tierProgress: Double {
        Double(points % pointsPerTier) / Double(pointsPerTier)
    }
    var pointsToNextTier: Int { pointsPerTier - (points % pointsPerTier) }

    // MARK: - Navigation

    func openGrowthLog() {
        activeSheet = .growthLog
    }

    func openSettings() {
        activeSheet = .settings
    }

    func dismissSheet() {
        activeSheet = nil
    }

    // MARK: - Journal (§E)

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
