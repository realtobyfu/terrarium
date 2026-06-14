//
//  WorldStore.swift
//  Terrarium — Domain
//
//  SwiftData-backed source of truth for the world (§G) and the engine for
//  quest completion → growth (§D) and journaling (§E). Reads/writes records;
//  hands rendering a derived `WorldState` value type.
//

import Foundation
import SwiftData
import simd

@MainActor
final class WorldStore: WorldStateProviding {

    private let context: ModelContext

    /// Vitality gained per verified completion, and the small bonus for
    /// attaching a reflection.
    private let completionVitality = 0.08
    private let reflectionVitality = 0.02

    init(context: ModelContext, seedIfEmpty: Bool = true) {
        self.context = context
        if seedIfEmpty && (try? fetchRecord()) == nil {
            seed()
        }
    }

    // MARK: - WorldStateProviding

    func current() -> WorldState {
        let vitality = (try? fetchRecord())?.vitality ?? 0.6
        let props = (try? fetchAllProps()) ?? []
        let ordered = props.sorted { $0.createdAt < $1.createdAt }
        return WorldState(props: ordered.map(\.renderProp), vitality: vitality)
    }

    // MARK: - Completion → growth (§D)

    /// Verify and, on success, grow the world by one specimen and raise
    /// vitality. Idempotent: a quest already completed is a no-op (returns nil).
    ///
    /// - Parameters:
    ///   - quest:    The quest being verified.
    ///   - verifier: Determines whether the quest counts as completed.
    ///   - variant:  Specimen appearance variant ("clear" or "foggy"). Defaults
    ///               to "clear" so existing callers keep compiling.
    @discardableResult
    func complete(quest: Quest, with verifier: QuestVerifier,
                  variant: String = "clear") async -> WorldPropRecord? {
        guard await verifier.verify(quest) else { return nil }
        return award(quest: quest, verifierKind: verifier.kind, variant: variant)
    }

    /// The synchronous award step, separated so it is directly unit-testable
    /// and so the idempotency check is atomic.
    ///
    /// - Parameters:
    ///   - quest:        The quest being awarded.
    ///   - verifierKind: How verification was performed (stored for analytics).
    ///   - variant:      Appearance variant key (US-F2): "clear" or "foggy".
    ///                   Defaults to "clear" so existing callers keep compiling.
    @discardableResult
    func award(quest: Quest, verifierKind: VerifierKind,
               variant: String = "clear") -> WorldPropRecord? {
        guard let world = try? fetchRecord() else { return nil }
        if alreadyCompleted(quest.id) { return nil }

        context.insert(CompletedQuest(questId: quest.id, verifierKind: verifierKind))

        let prop = WorldPropRecord(
            kind: quest.suggestedKind,
            coordinate: POIPlacement.sphereCoordinate(forPOIRef: quest.poiRef),
            poiRef: quest.poiRef,
            variant: variant
        )
        context.insert(prop)
        world.vitality = min(1, world.vitality + completionVitality)

        try? context.save()
        return prop
    }

    // MARK: - Journal (§E/§F)

    /// Attach a reflection (and optional photo) to a specimen; small vitality
    /// bonus for reflecting.
    @discardableResult
    func addJournal(to prop: WorldPropRecord,
                    questId: UUID,
                    text: String,
                    photoRef: String? = nil,
                    placeName: String) -> JournalEntry {
        let entry = JournalEntry(questId: questId, propID: prop.id, text: text,
                                 photoRef: photoRef, placeName: placeName)
        context.insert(entry)

        if let world = try? fetchRecord() {
            world.vitality = min(1, world.vitality + reflectionVitality)
        }
        try? context.save()
        return entry
    }

    /// The reflection attached to a given specimen, if any. Backs the
    /// tap-a-specimen-to-open-its-journal interaction.
    func journalEntry(forPropID id: UUID) -> JournalEntry? {
        try? context.fetch(
            FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.propID == id })
        ).first
    }

    func prop(withID id: UUID) -> WorldPropRecord? {
        try? fetchProp(id: id)
    }

    // MARK: - Fetching

    private func fetchRecord() throws -> WorldStateRecord? {
        try context.fetch(FetchDescriptor<WorldStateRecord>()).first
    }

    private func fetchAllProps() throws -> [WorldPropRecord] {
        try context.fetch(FetchDescriptor<WorldPropRecord>())
    }

    private func fetchProp(id: UUID) throws -> WorldPropRecord? {
        try context.fetch(
            FetchDescriptor<WorldPropRecord>(predicate: #Predicate { $0.id == id })
        ).first
    }

    private func alreadyCompleted(_ questId: UUID) -> Bool {
        let count = (try? context.fetchCount(
            FetchDescriptor<CompletedQuest>(predicate: #Predicate { $0.questId == questId })
        )) ?? 0
        return count > 0
    }

    // MARK: - Seed

    /// First-launch world: a few starter specimens so the globe reads as
    /// inhabited. Subsequent growth is driven by quest completion.
    private func seed() {
        context.insert(WorldStateRecord(vitality: 0.6))
        // Clustered tightly around one "home" spot so the patches merge into a
        // single landmass with the tree, shop and flowers all on it.
        let starters: [(WorldProp.Kind, SIMD2<Float>)] = [
            (.tree, SIMD2(0.16, -0.07)),
            (.building, SIMD2(0.09, 0.06)),
            (.flowers, SIMD2(0.13, 0.00)),
        ]
        for (kind, coord) in starters {
            context.insert(WorldPropRecord(kind: kind, coordinate: coord))
        }
        try? context.save()
    }
}
