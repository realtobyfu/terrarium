//
//  StreamFIntegrationTests.swift
//  TerrariumTests
//
//  Integration tests for Stream F (US-F1, US-F2, US-F3).
//
//  Coverage
//  ────────
//  1. award() stores the variant on WorldPropRecord.
//  2. A foggy discovery produces variant == "foggy".
//  3. A clear discovery produces variant == "clear".
//  4. Foggy vs clear discoveries produce visibly different variant keys.
//  5. Journal round-trip: Explore discovery creates a JournalEntry with
//     the right placeName, and journalEntry(forPropID:) retrieves it.
//  6. AnchorViewModel.arrive() seeds a journal entry for the grown specimen.
//  7. DriftViewModel grows a specimen and seeds a journal for a new cell.
//

import Testing
import Foundation
import SwiftData
@testable import Terrarium

// MARK: - Shared SwiftData container helper

/// One container shared across Stream F tests (same pattern as WorldStoreTests).
private enum StreamFContainer {
    static let shared: ModelContainer = {
        let url = URL.temporaryDirectory
            .appending(path: "streamf-tests-\(UUID().uuidString).store")
        return try! ModelContainer(
            for: WorldStateRecord.self, WorldPropRecord.self,
                 CompletedQuest.self, JournalEntry.self,
            configurations: ModelConfiguration(url: url)
        )
    }()
}

@MainActor
private func freshStore() -> WorldStore {
    let ctx = StreamFContainer.shared.mainContext
    try? ctx.delete(model: WorldStateRecord.self)
    try? ctx.delete(model: WorldPropRecord.self)
    try? ctx.delete(model: CompletedQuest.self)
    try? ctx.delete(model: JournalEntry.self)
    try? ctx.save()
    return WorldStore(context: ctx)
}

private func makeQuest(ref: String = "poi.test",
                       kind: WorldProp.Kind = .tree) -> Quest {
    Quest(title: "t", prompt: "p", placeName: "Test Place",
          poiRef: ref, suggestedKind: kind)
}

// MARK: - WorldStore variant persistence (US-F2)

@MainActor
@Suite("StreamF — Variant persistence", .serialized)
struct VariantPersistenceTests {

    @Test("award stores the variant on WorldPropRecord")
    func awardStoresVariant() {
        let store = freshStore()
        let q = makeQuest(ref: "poi.variant.test")
        let prop = store.award(quest: q, verifierKind: .honor, variant: "foggy")
        #expect(prop?.variant == "foggy")
    }

    @Test("Default variant is clear")
    func defaultVariantIsClear() {
        let store = freshStore()
        let q = makeQuest(ref: "poi.default.variant")
        let prop = store.award(quest: q, verifierKind: .honor)
        #expect(prop?.variant == "clear")
    }

    @Test("Foggy discovery produces foggy variant key")
    func foggyDiscoveryProducesFoggyVariant() {
        let store = freshStore()
        let q = makeQuest(ref: "poi.foggy.discovery")
        let discoveryWeather = Weather.fog
        let variant = SpecimenMapping.variant(for: discoveryWeather)
        let prop = store.award(quest: q, verifierKind: .honor, variant: variant)
        #expect(prop?.variant == "foggy")
    }

    @Test("Clear discovery produces clear variant key")
    func clearDiscoveryProducesClearVariant() {
        let store = freshStore()
        let q = makeQuest(ref: "poi.clear.discovery")
        let variant = SpecimenMapping.variant(for: .clear)
        let prop = store.award(quest: q, verifierKind: .honor, variant: variant)
        #expect(prop?.variant == "clear")
    }

    @Test("Foggy vs clear discovery produce different variant keys")
    func foggyVsClearProduceDifferentKeys() {
        let store = freshStore()

        let foggyProp = store.award(
            quest: makeQuest(ref: "poi.foggy"),
            verifierKind: .honor,
            variant: SpecimenMapping.variant(for: .fog)
        )
        let clearProp = store.award(
            quest: makeQuest(ref: "poi.clear"),
            verifierKind: .honor,
            variant: SpecimenMapping.variant(for: .clear)
        )

        #expect(foggyProp?.variant != clearProp?.variant)
        #expect(foggyProp?.variant == "foggy")
        #expect(clearProp?.variant == "clear")
    }

    @Test("Variant persists across store instances (SwiftData round-trip)")
    func variantRoundTripsAcrossStoreInstances() {
        let store1 = freshStore()
        let q = makeQuest(ref: "poi.round-trip")
        let prop = store1.award(quest: q, verifierKind: .honor, variant: "foggy")
        let propID = prop?.id

        let store2 = WorldStore(context: StreamFContainer.shared.mainContext,
                                seedIfEmpty: false)
        let loaded = propID.flatMap { store2.prop(withID: $0) }
        #expect(loaded?.variant == "foggy")
    }

    @Test("renderProp carries the stored variant")
    func renderPropCarriesVariant() {
        let store = freshStore()
        let q = makeQuest(ref: "poi.render-variant")
        let record = store.award(quest: q, verifierKind: .honor, variant: "foggy")
        let rendered = record?.renderProp
        #expect(rendered?.variant == "foggy")
    }
}

// MARK: - Journal round-trip (US-F3)

@MainActor
@Suite("StreamF — Journal round-trip", .serialized)
struct JournalRoundTripTests {

    @Test("addJournal with Explore place name round-trips through WorldStore")
    func exploreDiscoveryJournalRoundTrip() {
        let store = freshStore()
        let q = makeQuest(ref: "poi.sightglass-coffee.sf")
        let prop = store.award(quest: q, verifierKind: .honor)!

        store.addJournal(to: prop, questId: q.id,
                         text: "Discovered Sightglass Coffee.",
                         placeName: "Sightglass Coffee")

        let entry = store.journalEntry(forPropID: prop.id)
        #expect(entry?.placeName == "Sightglass Coffee")
        #expect(entry?.text == "Discovered Sightglass Coffee.")
        #expect(entry?.propID == prop.id)
    }

    @Test("journalEntry(forPropID:) returns nil when no entry exists")
    func noJournalEntryReturnsNil() {
        let store = freshStore()
        let q = makeQuest(ref: "poi.no-journal")
        let prop = store.award(quest: q, verifierKind: .honor)!
        // No addJournal call — entry should be nil.
        #expect(store.journalEntry(forPropID: prop.id) == nil)
    }
}

// MARK: - AnchorViewModel arrive() journal (US-F3)

private struct FixtureCatalog: POICatalogProviding {
    let pois: [POI]
    func all() -> [POI] { pois }
    func allowedRefs() -> Set<String> { Set(pois.map(\.poiRef)) }
}

private struct OrderedRecommender: PlaceRecommending {
    let catalog: POICatalogProviding
    func anchor(_ context: RecommendationContext) -> POI? { catalog.all().first }
    func driftSeeds(_ context: RecommendationContext) -> [POI] { catalog.all() }
}

private func makePOI(ref: String,
                     category: POICategory = .park,
                     coord: Coordinate = Coordinate(latitude: 37.76, longitude: -122.42)
) -> POI {
    POI(poiRef: ref, name: "Test POI", category: category,
        neighborhood: "Mission",
        coordinate: coord,
        indoorOutdoor: .outdoor, bestTime: [.afternoon],
        weatherFit: [.clear], goodFor: [.solo], vibe: [.scenic],
        price: .free, hoursRef: nil, specimenKind: .tree, source: .curated)
}

@MainActor
@Suite("StreamF — AnchorViewModel arrival journal", .serialized)
struct AnchorArrivalJournalTests {

    /// Shared container for this suite (avoid multiple containers).
    static let container: ModelContainer = {
        let url = URL.temporaryDirectory
            .appending(path: "anchor-journal-\(UUID().uuidString).store")
        return try! ModelContainer(
            for: WorldStateRecord.self, WorldPropRecord.self,
                 CompletedQuest.self, JournalEntry.self,
            configurations: ModelConfiguration(url: url)
        )
    }()

    private func freshWorldStore() -> WorldStore {
        let ctx = Self.container.mainContext
        try? ctx.delete(model: WorldStateRecord.self)
        try? ctx.delete(model: WorldPropRecord.self)
        try? ctx.delete(model: CompletedQuest.self)
        try? ctx.delete(model: JournalEntry.self)
        try? ctx.save()
        return WorldStore(context: ctx)
    }

    @Test("arrive() seeds a journal entry for the grown specimen")
    func arriveSeesJournalEntryForSpecimen() async throws {
        let poi = makePOI(ref: "poi.coffee.test", category: .coffee)
        let catalog = FixtureCatalog(pois: [poi])
        let worldStore = freshWorldStore()
        let discoveryStore = InMemoryDiscoveryStore()

        let vm = AnchorViewModel(
            catalog: catalog,
            weather: StubWeatherProvider(),
            recommender: OrderedRecommender(catalog: catalog),
            location: StubLocationSession(),
            discoveries: discoveryStore
        )
        vm.worldStore = worldStore
        vm.arrivalVerifier = HonorVerifier()  // ensure award succeeds

        await vm.refresh()
        await vm.arrive()

        // Specimen should have grown.
        let result = try #require(vm.arrivalResult)
        #expect(result.specimenGrown == true)

        // Journal entry should exist.
        let props = worldStore.current().props
        let lastProp = try #require(props.last)
        let entry = worldStore.journalEntry(forPropID: lastProp.id)
        #expect(entry != nil)
        #expect(entry?.placeName == poi.name)
    }

    @Test("arrive() with fog weather stores foggy variant on specimen")
    func arriveWithFogStoresFoggyVariant() async throws {
        let poi = makePOI(ref: "poi.fog.journal", category: .viewpoint)
        let catalog = FixtureCatalog(pois: [poi])
        let worldStore = freshWorldStore()

        final class FogWeather: WeatherProviding {
            func current() async -> Weather { .fog }
        }

        let vm = AnchorViewModel(
            catalog: catalog,
            weather: FogWeather(),
            recommender: OrderedRecommender(catalog: catalog),
            location: StubLocationSession(),
            discoveries: InMemoryDiscoveryStore()
        )
        vm.worldStore = worldStore
        vm.arrivalVerifier = HonorVerifier()

        await vm.refresh()
        await vm.arrive()

        let result = try #require(vm.arrivalResult)
        #expect(result.specimenGrown == true)

        // The context weather was .fog → variant should be "foggy".
        // We verify via the ArrivalResult's discovery context.
        #expect(result.discovery.context.weather == .fog)

        // And the stored prop should carry the foggy variant.
        let props = worldStore.current().props
        let lastProp = try #require(props.last)
        #expect(lastProp.variant == "foggy")
    }

    @Test("SpecimenMapping.kind is applied at arrive time (park → tree)")
    func arriveAppliesCategoryMapping() async throws {
        let poi = makePOI(ref: "poi.park.mapping", category: .park)
        let catalog = FixtureCatalog(pois: [poi])
        let worldStore = freshWorldStore()

        let vm = AnchorViewModel(
            catalog: catalog,
            weather: StubWeatherProvider(),
            recommender: OrderedRecommender(catalog: catalog),
            location: StubLocationSession(),
            discoveries: InMemoryDiscoveryStore()
        )
        vm.worldStore = worldStore
        vm.arrivalVerifier = HonorVerifier()

        await vm.refresh()
        await vm.arrive()

        let lastProp = try #require(worldStore.current().props.last)
        #expect(lastProp.kind == .tree)  // park → tree (FR-21)
    }
}

// MARK: - DriftViewModel specimen growth (US-F2, US-F3)

@MainActor
@Suite("StreamF — DriftViewModel specimen growth", .serialized)
struct DriftSpecimenGrowthTests {

    static let container: ModelContainer = {
        let url = URL.temporaryDirectory
            .appending(path: "drift-specimen-\(UUID().uuidString).store")
        return try! ModelContainer(
            for: WorldStateRecord.self, WorldPropRecord.self,
                 CompletedQuest.self, JournalEntry.self,
            configurations: ModelConfiguration(url: url)
        )
    }()

    private func freshWorldStore() -> WorldStore {
        let ctx = Self.container.mainContext
        try? ctx.delete(model: WorldStateRecord.self)
        try? ctx.delete(model: WorldPropRecord.self)
        try? ctx.delete(model: CompletedQuest.self)
        try? ctx.delete(model: JournalEntry.self)
        try? ctx.save()
        return WorldStore(context: ctx)
    }

    /// Coord that maps to a unique precision-7 cell.
    private let coordA = Coordinate(latitude: 37.7596, longitude: -122.4269)
    private let coordB = Coordinate(latitude: 37.7700, longitude: -122.4350)

    @Test("A new cell in a Drift session grows a specimen")
    func newCellGrowsSpecimen() async throws {
        let discoveryStore = InMemoryDiscoveryStore()
        let worldStore = freshWorldStore()

        let location = MockDriftLocationSession()
        location.queuedCoordinates = [coordA]

        let vm = DriftViewModel(
            location: location,
            recommender: StubRecommender(catalog: StubPOICatalog(),
                                        discoveries: discoveryStore),
            discoveries: discoveryStore
        )
        vm.worldStore = worldStore

        let propsBefore = worldStore.current().props.count

        vm.startRamble()
        try? await Task.sleep(for: .milliseconds(150))

        let propsAfter = worldStore.current().props.count
        #expect(propsAfter > propsBefore)
    }

    @Test("A Drift cell specimen has a journal entry")
    func driftCellSpecimenHasJournalEntry() async throws {
        let discoveryStore = InMemoryDiscoveryStore()
        let worldStore = freshWorldStore()

        let location = MockDriftLocationSession()
        location.queuedCoordinates = [coordA]

        let vm = DriftViewModel(
            location: location,
            recommender: StubRecommender(catalog: StubPOICatalog(),
                                        discoveries: discoveryStore),
            discoveries: discoveryStore
        )
        vm.worldStore = worldStore

        vm.startRamble()
        try? await Task.sleep(for: .milliseconds(150))

        // Find the newly grown specimen(s).
        let props = worldStore.current().props
        let newProps = props.filter { worldStore.journalEntry(forPropID: $0.id) != nil }
        #expect(!newProps.isEmpty)
    }

    @Test("A re-explored cell does not grow a second specimen")
    func reExploredCellDoesNotGrowSecondSpecimen() async throws {
        let discoveryStore = InMemoryDiscoveryStore()
        // Pre-populate the store with coordA's cell as already explored.
        let cellID = GeohashCell.encode(coordA, precision: 7)
        discoveryStore.record(Discovery(
            target: .cell(id: cellID),
            context: DiscoveryContext(weather: .clear, timeOfDay: .morning)
        ))

        let worldStore = freshWorldStore()

        let location = MockDriftLocationSession()
        location.queuedCoordinates = [coordA]  // same already-explored cell

        let vm = DriftViewModel(
            location: location,
            recommender: StubRecommender(catalog: StubPOICatalog(),
                                        discoveries: discoveryStore),
            discoveries: discoveryStore
        )
        vm.worldStore = worldStore

        let propsBefore = worldStore.current().props.count

        vm.startRamble()
        try? await Task.sleep(for: .milliseconds(150))

        // No new specimen should have grown for the re-explored cell.
        let propsAfter = worldStore.current().props.count
        #expect(propsAfter == propsBefore)
    }
}

// MARK: - MockDriftLocationSession (local to this file)

@MainActor
private final class MockDriftLocationSession: LocationSessionProviding {
    private(set) var isActive = false
    var queuedCoordinates: [Coordinate] = []

    func start() { isActive = true }
    func stop()  { isActive = false }

    func breadcrumbStream() -> AsyncStream<Coordinate> {
        let coords = queuedCoordinates
        return AsyncStream { continuation in
            for coord in coords { continuation.yield(coord) }
            continuation.finish()
        }
    }

    func currentCoordinate() async -> Coordinate? { nil }
}
