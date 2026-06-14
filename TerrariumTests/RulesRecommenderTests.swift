//
//  RulesRecommenderTests.swift
//  TerrariumTests
//
//  US-C1: Unit tests for RulesRecommender. Proves:
//  - Weather flips indoor/outdoor ranking
//  - Closed places are excluded from anchor() and driftSeeds()
//  - Explored places are demoted by the novelty factor
//  - Persona bias changes ordering
//  - Unknown-hours soft penalty applies (0.6 × score, not hard-excluded)
//  - Distance penalty beyond travel radius
//

import Testing
import Foundation
@testable import Terrarium

// MARK: - Shared fixtures

/// Minimal calendar/date helpers for all recommender tests.
private extension Date {
    /// 2026-01-05 10:00 UTC (Monday morning) — a stable test timestamp.
    static var mondayMorning: Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 1; comps.day = 5
        comps.hour = 10; comps.minute = 0; comps.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: comps)!
    }
}

/// Factory for minimal valid POIs — only fields the recommender reads need values.
private func makePOI(
    ref: String,
    category: POICategory = .park,
    indoorOutdoor: IndoorOutdoor = .outdoor,
    weatherFit: [Weather] = [],
    vibe: [Vibe] = [],
    coord: Coordinate = Coordinate(latitude: 37.76, longitude: -122.43)
) -> POI {
    POI(
        poiRef: ref,
        name: ref,
        category: category,
        neighborhood: "Test",
        coordinate: coord,
        indoorOutdoor: indoorOutdoor,
        bestTime: [.morning],
        weatherFit: weatherFit,
        goodFor: [.solo],
        vibe: vibe,
        price: .free,
        hoursRef: nil,
        specimenKind: .tree,
        source: .curated
    )
}

/// A simple catalog backed by an explicit POI list.
private struct FixtureCatalog: POICatalogProviding {
    let pois: [POI]
    func all() -> [POI] { pois }
    func allowedRefs() -> Set<String> { Set(pois.map(\.poiRef)) }
}

/// All-open hours (any weekday 00:00–24:00, no midnight wrap needed —
/// we encode as 00:00–23:59 to avoid closeMinute == openMinute ambiguity).
private let alwaysOpenHours = OpeningHours.allWeek(TimeRange(openHour: 0, openMin: 0, closeHour: 23, closeMin: 59))

/// Definitively closed hours (empty array for every weekday).
private let alwaysClosedHours = OpeningHours(schedule: Dictionary(uniqueKeysWithValues: (1...7).map { ($0, [TimeRange]()) }))

// MARK: - Test suite

@Suite("RulesRecommender")
struct RulesRecommenderTests {

    // -------------------------------------------------------------------------
    // MARK: Helpers
    // -------------------------------------------------------------------------

    private func makeRecommender(
        pois: [POI],
        explored: [String] = [],
        hoursLookup: @escaping (POI) -> OpeningHours? = { _ in nil }
    ) -> RulesRecommender {
        let store = InMemoryDiscoveryStore()
        for ref in explored {
            store.record(Discovery(
                target: .poi(poiRef: ref),
                timestamp: .now,
                context: DiscoveryContext(weather: .clear, timeOfDay: .morning)
            ))
        }
        return RulesRecommender(
            catalog: FixtureCatalog(pois: pois),
            discoveryStore: store,
            hoursLookup: hoursLookup
        )
    }

    private func context(
        weather: Weather = .clear,
        coord: Coordinate? = nil,
        persona: PersonaKind = .restlessLocal,
        interestCategories: [POICategory] = [],
        radius: Double = 1500
    ) -> RecommendationContext {
        RecommendationContext(
            weather: weather,
            date: .mondayMorning,
            timeOfDay: .morning,
            coordinate: coord,
            preferences: UserPreferences(
                persona: persona,
                interestCategories: interestCategories,
                preferredVibes: [],
                travelRadiusMeters: radius
            )
        )
    }

    // -------------------------------------------------------------------------
    // MARK: 1. Weather flips indoor/outdoor ranking
    // -------------------------------------------------------------------------

    @Test("Rain promotes indoor over outdoor")
    func rainFavorsIndoor() {
        let indoor = makePOI(ref: "indoor", indoorOutdoor: .indoor, weatherFit: [.rain])
        let outdoor = makePOI(ref: "outdoor", indoorOutdoor: .outdoor, weatherFit: [.clear])
        let recommender = makeRecommender(
            pois: [outdoor, indoor], // outdoor first in catalog
            hoursLookup: { _ in alwaysOpenHours }
        )

        let seeds = recommender.driftSeeds(context(weather: .rain))
        #expect(seeds.first?.poiRef == "indoor",
                "Indoor place should rank above outdoor in rain")
    }

    @Test("Clear weather promotes outdoor over indoor")
    func clearFavorsOutdoor() {
        let indoor = makePOI(ref: "indoor", indoorOutdoor: .indoor, weatherFit: [.rain])
        let outdoor = makePOI(ref: "outdoor", indoorOutdoor: .outdoor, weatherFit: [.clear])
        let recommender = makeRecommender(
            pois: [indoor, outdoor], // indoor first in catalog
            hoursLookup: { _ in alwaysOpenHours }
        )

        let seeds = recommender.driftSeeds(context(weather: .clear))
        #expect(seeds.first?.poiRef == "outdoor",
                "Outdoor place should rank above indoor in clear weather")
    }

    @Test("Fog promotes indoor and penalises outdoor")
    func fogFavorsIndoor() {
        let indoor = makePOI(ref: "indoor", indoorOutdoor: .indoor, weatherFit: [.fog])
        let outdoor = makePOI(ref: "outdoor", indoorOutdoor: .outdoor)
        let recommender = makeRecommender(
            pois: [outdoor, indoor],
            hoursLookup: { _ in alwaysOpenHours }
        )

        let seeds = recommender.driftSeeds(context(weather: .fog))
        #expect(seeds.first?.poiRef == "indoor")
    }

    // -------------------------------------------------------------------------
    // MARK: 2. Closed places excluded from anchor() and driftSeeds()
    // -------------------------------------------------------------------------

    @Test("anchor() excludes closed places")
    func anchorExcludesClosed() {
        let closedPOI = makePOI(ref: "closed-best")
        let openPOI = makePOI(ref: "open-second")
        let recommender = makeRecommender(pois: [closedPOI, openPOI]) { poi in
            poi.poiRef == "closed-best" ? alwaysClosedHours : alwaysOpenHours
        }

        let anchor = recommender.anchor(context())
        #expect(anchor?.poiRef == "open-second",
                "Closed place must never be returned by anchor()")
    }

    @Test("driftSeeds() excludes closed places")
    func driftSeedsExcludeClosed() {
        let closed = makePOI(ref: "closed")
        let open = makePOI(ref: "open")
        let recommender = makeRecommender(pois: [closed, open]) { poi in
            poi.poiRef == "closed" ? alwaysClosedHours : alwaysOpenHours
        }

        let seeds = recommender.driftSeeds(context())
        #expect(!seeds.contains(where: { $0.poiRef == "closed" }),
                "Closed place must not appear in driftSeeds()")
        #expect(seeds.contains(where: { $0.poiRef == "open" }))
    }

    @Test("anchor() returns nil when all places are closed")
    func anchorReturnsNilWhenAllClosed() {
        let pois = [makePOI(ref: "a"), makePOI(ref: "b")]
        let recommender = makeRecommender(pois: pois) { _ in alwaysClosedHours }
        #expect(recommender.anchor(context()) == nil)
    }

    // -------------------------------------------------------------------------
    // MARK: 3. Unknown-hours soft penalty (0.6 × product, not excluded)
    // -------------------------------------------------------------------------

    @Test("Unknown-hours place gets softer score than open, not hard-excluded")
    func unknownHoursSoftPenalty() {
        let unknownHoursPOI = makePOI(ref: "unknown")
        // No hoursLookup override → default returns nil → .unknown
        let recommender = makeRecommender(pois: [unknownHoursPOI])
        // Should appear in anchor (not hard-excluded)
        let anchor = recommender.anchor(context())
        #expect(anchor?.poiRef == "unknown",
                "Unknown-hours place must not be hard-excluded from anchor()")
    }

    @Test("Open-hours place beats unknown-hours place when otherwise equal")
    func openBeatsUnknown() {
        // Both parks, same coord, no weatherFit distinction
        let openPOI = makePOI(ref: "open")
        let unknownPOI = makePOI(ref: "unknown")
        let recommender = makeRecommender(pois: [unknownPOI, openPOI]) { poi in
            poi.poiRef == "open" ? alwaysOpenHours : nil // nil → .unknown
        }

        let seeds = recommender.driftSeeds(context())
        #expect(seeds.first?.poiRef == "open",
                "Open-hours place should rank above unknown-hours place")
    }

    @Test("Unknown-hours multiplier is 0.6")
    func unknownHoursMultiplierValue() {
        #expect(RulesRecommender.unknownHoursPenalty == 0.6)
    }

    // -------------------------------------------------------------------------
    // MARK: 4. Explored places demoted by novelty factor
    // -------------------------------------------------------------------------

    @Test("Already-explored POI is demoted below fresh POI")
    func exploredIsDemoted() {
        let fresh = makePOI(ref: "fresh")
        let explored = makePOI(ref: "explored")
        let recommender = makeRecommender(
            pois: [explored, fresh], // explored first in catalog
            explored: ["explored"],
            hoursLookup: { _ in alwaysOpenHours }
        )

        let seeds = recommender.driftSeeds(context())
        #expect(seeds.first?.poiRef == "fresh",
                "Fresh place should rank above explored place")
    }

    @Test("Explored POI still appears (not hard-excluded) but ranks lower")
    func exploredStillAppears() {
        let explored = makePOI(ref: "explored")
        let recommender = makeRecommender(
            pois: [explored],
            explored: ["explored"],
            hoursLookup: { _ in alwaysOpenHours }
        )
        // Should still be returned — just with a lower score
        let seeds = recommender.driftSeeds(context())
        #expect(seeds.contains(where: { $0.poiRef == "explored" }))
    }

    @Test("Novelty explored multiplier is 0.3")
    func noveltyExploredMultiplierValue() {
        #expect(RulesRecommender.noveltyExploredMultiplier == 0.3)
    }

    // -------------------------------------------------------------------------
    // MARK: 5. Persona bias changes ordering
    // -------------------------------------------------------------------------

    @Test("restlessLocal favors quirky places over non-quirky")
    func restlessLocalFavorsQuirky() {
        let quirky = makePOI(ref: "quirky", vibe: [.quirky])
        let plain = makePOI(ref: "plain", vibe: [.quiet])
        let recommender = makeRecommender(
            pois: [plain, quirky], // plain first in catalog
            hoursLookup: { _ in alwaysOpenHours }
        )

        let seeds = recommender.driftSeeds(context(persona: .restlessLocal))
        #expect(seeds.first?.poiRef == "quirky",
                "restlessLocal should prefer quirky vibe places")
    }

    @Test("newcomer favors scenic places")
    func newcomerFavorsScenic() {
        let scenic = makePOI(ref: "scenic", category: .viewpoint, vibe: [.scenic])
        let plain = makePOI(ref: "plain", vibe: [.quiet])
        let recommender = makeRecommender(
            pois: [plain, scenic],
            hoursLookup: { _ in alwaysOpenHours }
        )

        let seeds = recommender.driftSeeds(context(persona: .newcomer))
        #expect(seeds.first?.poiRef == "scenic",
                "newcomer should prefer scenic/landmark places")
    }

    @Test("weekendDrifter favors cozy places")
    func weekendDrifterFavorsCozy() {
        let cozy = makePOI(ref: "cozy", category: .coffee, vibe: [.cozy])
        let lively = makePOI(ref: "lively", vibe: [.lively])
        let recommender = makeRecommender(
            pois: [lively, cozy], // lively first in catalog
            hoursLookup: { _ in alwaysOpenHours }
        )

        let seeds = recommender.driftSeeds(context(persona: .weekendDrifter))
        #expect(seeds.first?.poiRef == "cozy",
                "weekendDrifter should prefer cozy places")
    }

    @Test("newcomer landmark bonus applies to museums")
    func newcomerMuseumBonus() {
        let museum = makePOI(ref: "museum", category: .museum, vibe: [])
        let park = makePOI(ref: "park", category: .park, vibe: [])
        let recommender = makeRecommender(
            pois: [park, museum],
            hoursLookup: { _ in alwaysOpenHours }
        )

        let seeds = recommender.driftSeeds(context(persona: .newcomer))
        #expect(seeds.first?.poiRef == "museum",
                "newcomer should get a bonus for museums")
    }

    // -------------------------------------------------------------------------
    // MARK: 6. Category match boost / penalty
    // -------------------------------------------------------------------------

    @Test("Category match boosts POIs in user interests")
    func categoryMatchBoost() {
        let coffee = makePOI(ref: "coffee", category: .coffee)
        let museum = makePOI(ref: "museum", category: .museum)
        let recommender = makeRecommender(
            pois: [museum, coffee],
            hoursLookup: { _ in alwaysOpenHours }
        )

        let seeds = recommender.driftSeeds(
            context(persona: .newcomer, interestCategories: [.coffee])
        )
        #expect(seeds.first?.poiRef == "coffee",
                "Category match should boost coffee when user prefers coffee")
    }

    @Test("Empty interest list → neutral (no boost, no penalty)")
    func emptyInterestListIsNeutral() {
        let store = InMemoryDiscoveryStore()
        let poi1 = makePOI(ref: "a", category: .coffee)
        let poi2 = makePOI(ref: "b", category: .park)
        let recommender = RulesRecommender(
            catalog: FixtureCatalog(pois: [poi1, poi2]),
            discoveryStore: store,
            hoursLookup: { _ in alwaysOpenHours }
        )

        let explored = Set<String>()
        let openState = OpenState.open
        let ctx = context(interestCategories: [])
        let s1 = recommender.score(poi: poi1, context: ctx, openState: openState, explored: explored)
        let s2 = recommender.score(poi: poi2, context: ctx, openState: openState, explored: explored)
        // Both should use categoryMatchNeutral; persona bias for restlessLocal only for quirky/novelty
        // Without quirky/explored both get same persona bias; scores should be equal
        #expect(abs(s1 - s2) < 0.001, "Equal POIs with no interest filter should score equally")
    }

    // -------------------------------------------------------------------------
    // MARK: 7. Distance penalty beyond travel radius
    // -------------------------------------------------------------------------

    @Test("POI beyond travel radius scores lower than one within radius")
    func distancePenaltyBeyondRadius() {
        // User at (37.76, -122.43); radius 1500 m
        let userCoord = Coordinate(latitude: 37.76, longitude: -122.43)
        // Near POI: same location (~0 m away)
        let near = makePOI(ref: "near", coord: Coordinate(latitude: 37.76, longitude: -122.43))
        // Far POI: ~5 km away
        let far = makePOI(ref: "far", coord: Coordinate(latitude: 37.76, longitude: -122.50))
        let recommender = makeRecommender(
            pois: [far, near], // far first in catalog
            hoursLookup: { _ in alwaysOpenHours }
        )

        let seeds = recommender.driftSeeds(context(coord: userCoord, radius: 1500))
        #expect(seeds.first?.poiRef == "near",
                "Near POI should rank above far POI when both are otherwise equal")
    }

    @Test("No coordinate → distance factor is neutral (1.0) for all POIs")
    func noCoordinateIsNeutral() {
        let store = InMemoryDiscoveryStore()
        let poi = makePOI(ref: "somewhere")
        let recommender = RulesRecommender(
            catalog: FixtureCatalog(pois: [poi]),
            discoveryStore: store,
            hoursLookup: { _ in alwaysOpenHours }
        )

        let ctx = context(coord: nil)
        let score = recommender.score(
            poi: poi,
            context: ctx,
            openState: .open,
            explored: []
        )
        // With no coord, distance is 1.0. Category neutral, weather neutral, novelty fresh.
        // Score = 1.0 (cat) × 1.0 (open) × 1.0 (weather) × 1.0 (dist) × 1.0 (novelty) + bias
        // No quirky/explored bias for restlessLocal + no explored → persona bias = 0.10 (novelty bonus)
        let expected = 1.0 * 1.0 * 1.0 * 1.0 * 1.0 + RulesRecommender.restlessLocalNoveltyBonus
        #expect(abs(score - expected) < 0.001)
    }

    @Test("Distance penalty factor is 0.75")
    func distancePenaltyFactorValue() {
        #expect(RulesRecommender.distancePenaltyFactor == 0.75)
    }

    // -------------------------------------------------------------------------
    // MARK: 8. driftSeeds returns at most driftSeedCount items
    // -------------------------------------------------------------------------

    @Test("driftSeeds returns at most driftSeedCount items")
    func driftSeedsCountCapped() {
        let pois = (1...10).map { i in makePOI(ref: "poi-\(i)") }
        let recommender = makeRecommender(pois: pois, hoursLookup: { _ in alwaysOpenHours })
        let seeds = recommender.driftSeeds(context())
        #expect(seeds.count <= RulesRecommender.driftSeedCount)
    }

    // -------------------------------------------------------------------------
    // MARK: 9. Empty catalog edge cases
    // -------------------------------------------------------------------------

    @Test("anchor() returns nil for empty catalog")
    func anchorEmptyCatalog() {
        let recommender = makeRecommender(pois: [])
        #expect(recommender.anchor(context()) == nil)
    }

    @Test("driftSeeds() returns empty array for empty catalog")
    func driftSeedsEmptyCatalog() {
        let recommender = makeRecommender(pois: [])
        #expect(recommender.driftSeeds(context()).isEmpty)
    }
}
