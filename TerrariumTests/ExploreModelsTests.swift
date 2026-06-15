//
//  ExploreModelsTests.swift
//  TerrariumTests
//
//  Wave-0 contract tests (Stream H): the new Explore value types are Equatable
//  and the catalog/store types round-trip through Codable (bundled JSON + the
//  on-device discovery store rely on this). Keeps the frozen contract honest.
//

import Foundation
import Testing
@testable import Terrarium

@Suite("Explore domain contracts")
struct ExploreModelsTests {

    private func samplePOI(_ ref: String = "poi.sample.sf") -> POI {
        POI(poiRef: ref, name: "Sample", category: .coffee, neighborhood: "SoMa",
            coordinate: Coordinate(latitude: 37.78, longitude: -122.41),
            indoorOutdoor: .indoor, bestTime: [.morning], weatherFit: [.rain, .fog],
            goodFor: [.solo], vibe: [.cozy], price: .medium,
            hoursRef: "hours.sample", specimenKind: .building, source: .curated)
    }

    @Test("POI round-trips through Codable unchanged")
    func poiCodableRoundTrip() throws {
        let poi = samplePOI()
        let data = try JSONEncoder().encode(poi)
        let decoded = try JSONDecoder().decode(POI.self, from: data)
        #expect(decoded == poi)
    }

    @Test("PriceTier raw values match the catalog JSON tokens")
    func priceTierRawValues() {
        #expect(PriceTier.free.rawValue == "free")
        #expect(PriceTier.low.rawValue == "$")
        #expect(PriceTier.medium.rawValue == "$$")
        #expect(PriceTier.high.rawValue == "$$$")
    }

    @Test("UserPreferences default is the Restless Local with a sane radius")
    func preferencesDefault() {
        let prefs = UserPreferences.default
        #expect(prefs.persona == .restlessLocal)
        #expect(prefs.travelRadiusMeters == 1500)
    }

    @Test("Discovery round-trips, preserving its target case and context")
    func discoveryCodableRoundTrip() throws {
        let discovery = Discovery(
            target: .poi(poiRef: "poi.sample.sf"),
            context: DiscoveryContext(weather: .fog, timeOfDay: .evening)
        )
        let data = try JSONEncoder().encode(discovery)
        let decoded = try JSONDecoder().decode(Discovery.self, from: data)
        #expect(decoded == discovery)
        #expect(decoded.target == .poi(poiRef: "poi.sample.sf"))
    }

    @Test("RambleSession is active until it is ended")
    func rambleSessionActivity() {
        var session = RambleSession()
        #expect(session.isActive)
        session.endedAt = .now
        #expect(!session.isActive)
    }
}

@Suite("Explore stub providers")
struct ExploreStubProviderTests {

    @Test("Stub catalog allowedRefs matches its POIs")
    func stubCatalogAllowedRefs() {
        let catalog = StubPOICatalog()
        #expect(catalog.allowedRefs() == Set(catalog.all().map(\.poiRef)))
        #expect(!catalog.all().isEmpty)
    }

    @Test("In-memory discovery store partitions cells and refs by target")
    func discoveryStorePartitions() {
        let store = InMemoryDiscoveryStore()
        let ctx = DiscoveryContext(weather: .clear, timeOfDay: .morning)
        store.record(Discovery(target: .poi(poiRef: "poi.a"), context: ctx))
        store.record(Discovery(target: .cell(id: "cell.1"), context: ctx))
        #expect(store.exploredRefs() == ["poi.a"])
        #expect(store.exploredCells() == ["cell.1"])
    }

    @Test("Stub weather matches the offline foggy default")
    func stubWeatherIsFog() async {
        #expect(await StubWeatherProvider().current() == .fog)
    }
}
