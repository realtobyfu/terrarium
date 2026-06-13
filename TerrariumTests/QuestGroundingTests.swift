//
//  QuestGroundingTests.swift
//  TerrariumTests
//
//  Grounding guard (§C): a quest referencing a POI that was not supplied to the
//  generator must be rejected, so the model can never invent a place.
//

import Testing
@testable import Terrarium

@Suite("Quest grounding")
struct QuestGroundingTests {

    private func quest(_ poiRef: String) -> Quest {
        Quest(title: "t", prompt: "p", placeName: "place", poiRef: poiRef)
    }

    @Test("A quest referencing a non-supplied POI is rejected")
    func rejectsHallucinatedPOI() {
        let allowed: Set<String> = ["poi.real-a", "poi.real-b"]
        let invented = quest("poi.invented-z")
        #expect(!QuestGrounding.isGrounded(invented, allowedPOIRefs: allowed))
    }

    @Test("Grounded quests are kept; hallucinated ones are dropped")
    func filtersToGroundedOnly() {
        let allowed: Set<String> = ["poi.real-a", "poi.real-b"]
        let quests = [quest("poi.real-a"), quest("poi.invented-z"), quest("poi.real-b")]
        let grounded = QuestGrounding.grounded(quests, allowedPOIRefs: allowed)
        #expect(grounded.count == 2)
        #expect(grounded.allSatisfy { allowed.contains($0.poiRef) })
    }

    @Test("Empty allowed set drops everything")
    func emptyAllowedDropsAll() {
        let quests = [quest("poi.a"), quest("poi.b")]
        #expect(QuestGrounding.grounded(quests, allowedPOIRefs: []).isEmpty)
    }
}
