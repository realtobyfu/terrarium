//
//  AnchorViewModelTests.swift
//  TerrariumTests
//
//  Stream D (US-D1 + US-D2) unit tests.
//
//  Covered:
//    1. Re-roll advances to a different pick.
//    2. Arrival awards a specimen (prop count grows) and records a discovery.
//    3. Empty catalog → no pick after refresh.
//    4. Weather is reflected in the assembled context.
//    5. Re-roll wraps around the pool (cycle behaviour).
//    6. Arrival is idempotent (second tap on same POI doesn't double-grow).
//    7. Maps handoff smoke test (no crash).
//
//  WorldStore uses the same shared-container pattern as WorldStoreTests to avoid
//  "multiple containers" trap on this SDK.
//

import Testing
import Foundation
import SwiftData
@testable import Terrarium

// MARK: - Fixtures

/// Minimal in-memory catalog with a predictable ordered set of POIs.
private struct FixtureCatalog: POICatalogProviding {
    let pois: [POI]
    func all() -> [POI] { pois }
    func allowedRefs() -> Set<String> { Set(pois.map(\.poiRef)) }
}

/// Controllable weather stub.
private final class ControlledWeather: WeatherProviding {
    var nextWeather: Weather = .clear
    func current() async -> Weather { nextWeather }
}

/// Recommender that returns catalog in order (no filtering).
private struct OrderedRecommender: PlaceRecommending {
    let catalog: POICatalogProviding
    func anchor(_ context: RecommendationContext) -> POI? { catalog.all().first }
    func driftSeeds(_ context: RecommendationContext) -> [POI] { catalog.all() }
}

/// Recommender backed by an empty catalog so anchor() returns nil.
private struct EmptyRecommender: PlaceRecommending {
    func anchor(_ context: RecommendationContext) -> POI? { nil }
    func driftSeeds(_ context: RecommendationContext) -> [POI] { [] }
}

private func makePOI(ref: String, name: String = "Test", kind: WorldProp.Kind = .tree) -> POI {
    POI(
        poiRef: ref,
        name: name,
        category: .park,
        neighborhood: "Test",
        coordinate: Coordinate(latitude: 37.76, longitude: -122.42),
        indoorOutdoor: .outdoor,
        bestTime: [.afternoon],
        weatherFit: [.clear],
        goodFor: [.solo],
        vibe: [.scenic],
        price: .free,
        hoursRef: nil,
        specimenKind: kind,
        source: .curated
    )
}

// MARK: - Test Suite

@MainActor
@Suite("AnchorViewModel", .serialized)
struct AnchorViewModelTests {

    // Shared SwiftData container across this suite (must be a single instance).
    static let container: ModelContainer = {
        let url = URL.temporaryDirectory
            .appending(path: "anchor-tests-\(UUID().uuidString).store")
        return try! ModelContainer(
            for: WorldStateRecord.self, WorldPropRecord.self,
                 CompletedQuest.self, JournalEntry.self,
            configurations: ModelConfiguration(url: url)
        )
    }()

    /// Returns a fresh WorldStore on a wiped context.
    private func freshWorldStore() -> WorldStore {
        let ctx = Self.container.mainContext
        try? ctx.delete(model: WorldStateRecord.self)
        try? ctx.delete(model: WorldPropRecord.self)
        try? ctx.delete(model: CompletedQuest.self)
        try? ctx.delete(model: JournalEntry.self)
        try? ctx.save()
        return WorldStore(context: ctx)
    }

    // -------------------------------------------------------------------------

    @Test("Re-roll advances to a different pick")
    func rerollAdvancesPick() async throws {
        let poiA = makePOI(ref: "poi.a", name: "Alpha")
        let poiB = makePOI(ref: "poi.b", name: "Beta")
        let catalog = FixtureCatalog(pois: [poiA, poiB])
        let store = InMemoryDiscoveryStore()

        let vm = AnchorViewModel(
            catalog: catalog,
            weather: StubWeatherProvider(),
            recommender: OrderedRecommender(catalog: catalog),
            location: StubLocationSession(),
            discoveries: store
        )

        await vm.refresh()
        let firstPick = try #require(vm.pick)
        #expect(firstPick.poiRef == "poi.a")

        vm.rollAnother()
        let secondPick = try #require(vm.pick)
        #expect(secondPick.poiRef != firstPick.poiRef)
        #expect(secondPick.poiRef == "poi.b")
    }

    @Test("Re-roll wraps around the pool")
    func rerollWrapsAround() async throws {
        let poiA = makePOI(ref: "poi.a")
        let poiB = makePOI(ref: "poi.b")
        let catalog = FixtureCatalog(pois: [poiA, poiB])
        let store = InMemoryDiscoveryStore()

        let vm = AnchorViewModel(
            catalog: catalog,
            weather: StubWeatherProvider(),
            recommender: OrderedRecommender(catalog: catalog),
            location: StubLocationSession(),
            discoveries: store
        )

        await vm.refresh()
        // Start at index 0 (poi.a)
        vm.rollAnother() // index 1 → poi.b
        vm.rollAnother() // index 0 → poi.a (wrap)
        let pick = try #require(vm.pick)
        #expect(pick.poiRef == "poi.a")
    }

    @Test("Arrival awards points and records a discovery")
    func arrivalAwardsPointsAndRecordsDiscovery() async throws {
        let poi = makePOI(ref: "poi.ocean-beach.sf", kind: .tree)
        let catalog = FixtureCatalog(pois: [poi])
        let discoveryStore = InMemoryDiscoveryStore()
        let worldStore = freshWorldStore()

        let vm = AnchorViewModel(
            catalog: catalog,
            weather: StubWeatherProvider(),
            recommender: OrderedRecommender(catalog: catalog),
            location: StubLocationSession(),
            discoveries: discoveryStore
        )
        vm.worldStore = worldStore

        await vm.refresh()
        let pointsBefore = worldStore.totalPoints()

        await vm.arrive()

        // Points awarded (no per-discovery specimen — grow-a-tree is cut)
        #expect(worldStore.totalPoints() == pointsBefore + AnchorViewModel.arrivalPoints)

        // Discovery was recorded
        #expect(!discoveryStore.exploredRefs().isEmpty)
        #expect(discoveryStore.exploredRefs().contains("poi.ocean-beach.sf"))

        // ArrivalResult is set
        let result = try #require(vm.arrivalResult)
        #expect(result.poi.poiRef == "poi.ocean-beach.sf")
        #expect(result.pointsEarned == AnchorViewModel.arrivalPoints)
    }

    @Test("Arrival is idempotent for the same POI (no double points)")
    func arrivalIsIdempotent() async throws {
        let poi = makePOI(ref: "poi.idempotent.test", kind: .building)
        let catalog = FixtureCatalog(pois: [poi])
        let discoveryStore = InMemoryDiscoveryStore()
        let worldStore = freshWorldStore()

        let vm = AnchorViewModel(
            catalog: catalog,
            weather: StubWeatherProvider(),
            recommender: OrderedRecommender(catalog: catalog),
            location: StubLocationSession(),
            discoveries: discoveryStore
        )
        vm.worldStore = worldStore

        await vm.refresh()
        await vm.arrive()
        let pointsAfterFirst = worldStore.totalPoints()

        // Second arrive on the same pick should NOT award more points
        await vm.arrive()
        #expect(worldStore.totalPoints() == pointsAfterFirst)
    }

    @Test("Empty catalog yields no pick")
    func emptyCatalogNoPick() async {
        let catalog = FixtureCatalog(pois: [])
        let store = InMemoryDiscoveryStore()

        let vm = AnchorViewModel(
            catalog: catalog,
            weather: StubWeatherProvider(),
            recommender: EmptyRecommender(),
            location: StubLocationSession(),
            discoveries: store
        )

        await vm.refresh()
        #expect(vm.pick == nil)
    }

    @Test("Weather is reflected in the assembled context")
    func weatherReflectedInContext() async {
        let poi = makePOI(ref: "poi.x")
        let catalog = FixtureCatalog(pois: [poi])
        let controlledWeather = ControlledWeather()
        controlledWeather.nextWeather = .rain

        let vm = AnchorViewModel(
            catalog: catalog,
            weather: controlledWeather,
            recommender: OrderedRecommender(catalog: catalog),
            location: StubLocationSession(),
            discoveries: InMemoryDiscoveryStore()
        )

        await vm.refresh()
        #expect(vm.context?.weather == .rain)
    }

    @Test("Re-roll does not change pick when pool has only one item")
    func rerollSingleItemNoOp() async throws {
        let onlyPOI = makePOI(ref: "poi.solo")
        let catalog = FixtureCatalog(pois: [onlyPOI])
        let store = InMemoryDiscoveryStore()

        let vm = AnchorViewModel(
            catalog: catalog,
            weather: StubWeatherProvider(),
            recommender: OrderedRecommender(catalog: catalog),
            location: StubLocationSession(),
            discoveries: store
        )

        await vm.refresh()
        let before = vm.pick?.poiRef

        vm.rollAnother()
        #expect(vm.pick?.poiRef == before)
    }

    @Test("Arrival records discovery with correct weather context")
    func arrivalDiscoveryMatchesWeatherContext() async throws {
        let poi = makePOI(ref: "poi.fog.test")
        let catalog = FixtureCatalog(pois: [poi])
        let discoveryStore = InMemoryDiscoveryStore()
        let controlledWeather = ControlledWeather()
        controlledWeather.nextWeather = .fog

        let vm = AnchorViewModel(
            catalog: catalog,
            weather: controlledWeather,
            recommender: OrderedRecommender(catalog: catalog),
            location: StubLocationSession(),
            discoveries: discoveryStore
        )
        vm.worldStore = freshWorldStore()

        await vm.refresh()
        #expect(vm.context?.weather == .fog)

        await vm.arrive()
        let result = try #require(vm.arrivalResult)
        #expect(result.discovery.context.weather == .fog)
    }

    @Test("openInMaps does not crash when pick is nil")
    func openInMapsWithNilPickNoCrash() {
        let vm = AnchorViewModel(
            catalog: FixtureCatalog(pois: []),
            weather: StubWeatherProvider(),
            recommender: EmptyRecommender(),
            location: StubLocationSession(),
            discoveries: InMemoryDiscoveryStore()
        )
        // Should not crash — pick is nil so method is a no-op
        vm.openInMaps()
    }

    @Test("Refresh resets arrival result")
    func refreshResetsArrivalResult() async throws {
        let poi = makePOI(ref: "poi.reset.test")
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

        await vm.refresh()
        await vm.arrive()
        #expect(vm.arrivalResult != nil)

        await vm.refresh()
        #expect(vm.arrivalResult == nil)
    }
}
