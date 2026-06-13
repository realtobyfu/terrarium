//
//  QuestGrounding.swift
//  Terrarium — Domain
//
//  Grounding guard for AI-generated quests (§C step 3): drop any quest whose
//  `poiRef` is not in the set of real POIs supplied to the generator. This is
//  what guarantees the model can never invent a place. Pure + testable; the
//  network call that produces the candidates is layered on top later (Loop 4).
//

enum QuestGrounding {

    /// Keep only quests grounded on one of the allowed POI references.
    static func grounded(_ quests: [Quest], allowedPOIRefs: Set<String>) -> [Quest] {
        quests.filter { allowedPOIRefs.contains($0.poiRef) }
    }

    /// Whether a single quest is grounded on a real, supplied POI.
    static func isGrounded(_ quest: Quest, allowedPOIRefs: Set<String>) -> Bool {
        allowedPOIRefs.contains(quest.poiRef)
    }
}
