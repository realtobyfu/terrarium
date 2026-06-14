//
//  WorldStoreTests.swift
//  TerrariumTests
//
//  Completion → growth (§D) and journaling (§E) against SwiftData. Uses a
//  single shared container (this SDK traps when many containers coexist in one
//  process), serialized, with the store wiped between tests for isolation.
//

import Testing
import Foundation
import SwiftData
import simd
@testable import Terrarium

@MainActor
@Suite("WorldStore", .serialized)
struct WorldStoreTests {

    /// One container for the whole suite.
    static let container: ModelContainer = {
        let url = URL.temporaryDirectory.appending(path: "terr-shared-\(UUID().uuidString).store")
        return try! ModelContainer(
            for: WorldStateRecord.self, WorldPropRecord.self,
                 CompletedQuest.self, JournalEntry.self,
            configurations: ModelConfiguration(url: url)
        )
    }()

    /// A freshly-seeded store on a wiped context.
    private func freshStore() -> WorldStore {
        let ctx = Self.container.mainContext
        try? ctx.delete(model: WorldStateRecord.self)
        try? ctx.delete(model: WorldPropRecord.self)
        try? ctx.delete(model: CompletedQuest.self)
        try? ctx.delete(model: JournalEntry.self)
        try? ctx.save()
        return WorldStore(context: ctx)
    }

    private func quest(_ poiRef: String, kind: WorldProp.Kind = .tree) -> Quest {
        Quest(title: "t", prompt: "p", placeName: "Place", poiRef: poiRef, suggestedKind: kind)
    }

    @Test("Completion appends one specimen at the deterministic POI coordinate")
    func awardAppendsOneAtDeterministicCoord() {
        let store = freshStore()
        let before = store.current().props.count

        let q = quest("poi.ocean-beach.sf", kind: .flowers)
        let prop = store.award(quest: q, verifierKind: .honor)

        #expect(prop != nil)
        #expect(store.current().props.count == before + 1)

        let expected = POIPlacement.sphereCoordinate(forPOIRef: q.poiRef)
        #expect(abs(prop!.latitude - expected.x) < 1e-6)
        #expect(abs(prop!.longitude - expected.y) < 1e-6)
        #expect(prop!.kind == .flowers)
    }

    @Test("Vitality increases monotonically with each completion")
    func vitalityMonotonic() {
        let store = freshStore()
        let v0 = store.current().vitality
        store.award(quest: quest("poi.a"), verifierKind: .honor)
        let v1 = store.current().vitality
        store.award(quest: quest("poi.b"), verifierKind: .honor)
        let v2 = store.current().vitality
        #expect(v1 > v0)
        #expect(v2 > v1)
        #expect(v2 <= 1.0)
    }

    @Test("Completing the same quest twice is a no-op (idempotent)")
    func doubleCompletionNoOp() {
        let store = freshStore()
        let q = quest("poi.a")

        let first = store.award(quest: q, verifierKind: .honor)
        let countAfterFirst = store.current().props.count
        let vitalityAfterFirst = store.current().vitality

        let second = store.award(quest: q, verifierKind: .honor)

        #expect(first != nil)
        #expect(second == nil)
        #expect(store.current().props.count == countAfterFirst)
        #expect(store.current().vitality == vitalityAfterFirst)
    }

    @Test("Honor verifier grows the world; a failing verifier does not")
    func verifierGatesGrowth() async {
        let store = freshStore()
        let before = store.current().props.count

        let honored = await store.complete(quest: quest("poi.a"), with: HonorVerifier())
        #expect(honored != nil)
        #expect(store.current().props.count == before + 1)

        // LocationVerifier with a known-outside coordinate: user is at 0,0
        // (far from any SF POI), but since the catalog has no poi.b the verifier
        // degrades to honor-mode and returns true. To get a failing verifier,
        // use a catalog that contains the POI and a user far away.
        let sfCoord = Coordinate(latitude: 37.7596, longitude: -122.4269)
        let testPOI = POI(poiRef: "poi.b", name: "Test", category: .park,
                          neighborhood: "Mission",
                          coordinate: sfCoord,
                          indoorOutdoor: .outdoor, bestTime: [.afternoon],
                          weatherFit: [.clear], goodFor: [.solo], vibe: [.scenic],
                          price: .free, hoursRef: nil, specimenKind: .tree, source: .curated)

        struct SinglePOICatalog: POICatalogProviding {
            let poi: POI
            func all() -> [POI] { [poi] }
            func allowedRefs() -> Set<String> { [poi.poiRef] }
        }
        final class FixedLocationSession: LocationSessionProviding {
            let coord: Coordinate?
            init(coord: Coordinate?) { self.coord = coord }
            var isActive: Bool { false }
            func start() {}
            func stop() {}
            func breadcrumbStream() -> AsyncStream<Coordinate> { AsyncStream { $0.finish() } }
            func currentCoordinate() async -> Coordinate? { coord }
        }
        // User is at 0°N 0°E — ~11,000 km from Dolores Park, outside the 80 m fence.
        let farLocation = FixedLocationSession(coord: Coordinate(latitude: 0, longitude: 0))
        let verifier = LocationVerifier(catalog: SinglePOICatalog(poi: testPOI),
                                        location: farLocation)
        let denied = await store.complete(quest: quest("poi.b"), with: verifier)
        #expect(denied == nil)
        #expect(store.current().props.count == before + 1)
    }

    @Test("Growth persists when a new store reads the same container")
    func persistsAcrossReopen() {
        let store1 = freshStore()
        store1.award(quest: quest("poi.persist"), verifierKind: .honor)
        let expectedCount = store1.current().props.count

        let store2 = WorldStore(context: Self.container.mainContext, seedIfEmpty: false)
        #expect(store2.current().props.count == expectedCount)
        #expect(store2.current().props.contains { $0.kind == .tree })
    }

    @Test("A reflection round-trips: journal ↔ specimen through SwiftData")
    func journalRoundTrip() throws {
        let store = freshStore()
        let q = quest("poi.a")
        let prop = try #require(store.award(quest: q, verifierKind: .honor))

        let vitalityBefore = store.current().vitality
        store.addJournal(to: prop, questId: q.id, text: "three sounds", placeName: "Ocean Beach")

        let entry = store.journalEntry(forPropID: prop.id)
        #expect(entry?.text == "three sounds")
        #expect(entry?.placeName == "Ocean Beach")
        #expect(entry?.propID == prop.id)
        #expect(store.current().vitality > vitalityBefore)
    }
}
