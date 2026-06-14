//
//  RulesRecommender.swift
//  Terrarium — Domain
//
//  US-C1: Pure, deterministic rules-based recommender (FR-9). Conforms to
//  `PlaceRecommending`. No ML, no network at rank time. All weights are named
//  constants so the scoring contract is readable and tweakable without touching
//  the algorithm.
//
//  Score formula:
//      score = categoryMatch × openNow × weatherFit × distance × novelty + personaBias
//
//  All factors are [0, 1] multipliers except `personaBias` (additive ±offset).
//

import Foundation

// MARK: - Haversine distance

private extension Coordinate {
    /// Distance in meters between two coordinates (degrees → meters, haversine).
    func distance(to other: Coordinate) -> Double {
        let r = 6_371_000.0 // Earth radius in metres
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let dLat = (other.latitude - latitude) * .pi / 180
        let dLon = (other.longitude - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return r * c
    }
}

// MARK: - RulesRecommender

/// Deterministic, rules-based place recommender (FR-9).
///
/// All scoring multipliers live as named static constants so they are
/// self-documenting and unit-testable. Inject the catalog, discovery store,
/// and optional hours-lookup closure at construction time.
struct RulesRecommender: PlaceRecommending {

    // -------------------------------------------------------------------------
    // MARK: Named constants — the full scoring contract
    // -------------------------------------------------------------------------

    // --- Open-now multipliers (FR-10, decisions §4) --------------------------
    /// Place is confirmed open → full score.
    static let openMultiplier: Double = 1.0
    /// Hours unknown → soft penalty (not hard-excluded). Decisions: 0.6.
    static let unknownHoursPenalty: Double = 0.6
    /// Place is closed → excluded from Anchor; drift seeds too.
    static let closedMultiplier: Double = 0.0

    // --- Category match -------------------------------------------------------
    /// POI's category is in the user's interest list.
    static let categoryMatchBoost: Double = 1.3
    /// No interest categories set (empty list) → neutral.
    static let categoryMatchNeutral: Double = 1.0
    /// POI's category is NOT in the list but list is non-empty.
    static let categoryMatchPenalty: Double = 0.7

    // --- Weather fit ----------------------------------------------------------
    /// POI's `weatherFit` array contains the current weather → boost.
    static let weatherFitBoost: Double = 1.2
    /// POI's `weatherFit` doesn't mention current weather → neutral.
    static let weatherFitNeutral: Double = 1.0
    /// Rain/snow/fog + outdoor place → mismatch penalty.
    static let outdoorRainPenalty: Double = 0.4
    /// Rain/snow/fog + indoor place → bonus (shelter).
    static let indoorRainBoost: Double = 1.15
    /// Clear weather + indoor-only place → mild penalty (could be outside).
    static let indoorClearPenalty: Double = 0.85

    // --- Distance (soft penalty beyond travel radius) -------------------------
    /// Multiplier applied per each full radius of extra distance beyond radius.
    /// e.g. if radius = 1500 m and POI is 3000 m away → 1 extra radius → 0.75.
    static let distancePenaltyFactor: Double = 0.75
    /// When context has no coordinate (no active session) → neutral.
    static let distanceNeutral: Double = 1.0

    // --- Novelty (already-explored demotion) ----------------------------------
    /// POI already discovered by the user → demote.
    static let noveltyExploredMultiplier: Double = 0.3
    /// POI not yet explored → full score.
    static let noveltyFreshMultiplier: Double = 1.0

    // --- Persona bias (additive offset, applied after the product) -----------
    /// restlessLocal: slightly favours quirky places and novel locations.
    static let restlessLocalQuirkyBonus: Double = 0.15
    static let restlessLocalNoveltyBonus: Double = 0.10
    /// newcomer: favours scenic / landmark places.
    static let newcomerScenicBonus: Double = 0.15
    static let newcomerLandmarkBonus: Double = 0.10 // viewpoint + museum
    /// weekendDrifter: slight bonus for highly-scored anchor candidates; mildly
    /// prefers "cozy" vibes (coffee/bookstore/bar on rainy Saturdays).
    static let weekendDrifterCozyBonus: Double = 0.12

    // --- Top N for driftSeeds -------------------------------------------------
    /// Number of seeds returned by `driftSeeds(_:)`.
    static let driftSeedCount: Int = 5

    // -------------------------------------------------------------------------
    // MARK: Stored properties
    // -------------------------------------------------------------------------

    private let catalog: POICatalogProviding
    private let discoveryStore: DiscoveryStore
    /// Returns the opening hours for a POI if known. Default: `{ _ in nil }`.
    /// The pilot catalog carries only `hoursRef` (not inline hours), so the
    /// default closure returns nil → unknown → soft penalty.
    private let hoursLookup: (POI) -> OpeningHours?

    // -------------------------------------------------------------------------
    // MARK: Init
    // -------------------------------------------------------------------------

    init(
        catalog: POICatalogProviding,
        discoveryStore: DiscoveryStore,
        hoursLookup: @escaping (POI) -> OpeningHours? = { _ in nil }
    ) {
        self.catalog = catalog
        self.discoveryStore = discoveryStore
        self.hoursLookup = hoursLookup
    }

    // -------------------------------------------------------------------------
    // MARK: PlaceRecommending
    // -------------------------------------------------------------------------

    /// The single best non-closed place for the current moment.
    /// Returns `nil` if all POIs are closed or the catalog is empty.
    func anchor(_ context: RecommendationContext) -> POI? {
        ranked(context: context, excludeClosed: true).first
    }

    /// Top N ranked seeds for Drift route shaping. Closed places excluded.
    func driftSeeds(_ context: RecommendationContext) -> [POI] {
        let top = ranked(context: context, excludeClosed: true)
        return Array(top.prefix(Self.driftSeedCount))
    }

    // -------------------------------------------------------------------------
    // MARK: Core scoring
    // -------------------------------------------------------------------------

    /// Score every POI, filter optionally, and return sorted highest-first.
    private func ranked(context: RecommendationContext, excludeClosed: Bool) -> [POI] {
        let pois = catalog.all()
        let explored = discoveryStore.exploredRefs()

        var scored: [(poi: POI, score: Double)] = pois.compactMap { poi in
            let openState = OpenNowEvaluator.evaluate(
                hours: hoursLookup(poi),
                at: context.date
            )
            if excludeClosed && openState == .closed { return nil }

            let s = score(poi: poi,
                          context: context,
                          openState: openState,
                          explored: explored)
            return (poi, s)
        }

        scored.sort { $0.score > $1.score }
        return scored.map(\.poi)
    }

    /// Full deterministic score for one POI given the current context.
    func score(
        poi: POI,
        context: RecommendationContext,
        openState: OpenState,
        explored: Set<String>
    ) -> Double {
        let openNow = openNowMultiplier(openState)
        let catMatch = categoryMatchMultiplier(poi: poi, prefs: context.preferences)
        let wFit = weatherFitMultiplier(poi: poi, weather: context.weather)
        let dist = distanceMultiplier(poi: poi, context: context)
        let novelty = noveltyMultiplier(poi: poi, explored: explored)
        let persona = personaBias(poi: poi,
                                  context: context,
                                  explored: explored)

        return catMatch * openNow * wFit * dist * novelty + persona
    }

    // -------------------------------------------------------------------------
    // MARK: Individual factor calculations
    // -------------------------------------------------------------------------

    private func openNowMultiplier(_ state: OpenState) -> Double {
        switch state {
        case .open:    return Self.openMultiplier
        case .unknown: return Self.unknownHoursPenalty
        case .closed:  return Self.closedMultiplier
        }
    }

    private func categoryMatchMultiplier(poi: POI, prefs: UserPreferences) -> Double {
        guard !prefs.interestCategories.isEmpty else { return Self.categoryMatchNeutral }
        return prefs.interestCategories.contains(poi.category)
            ? Self.categoryMatchBoost
            : Self.categoryMatchPenalty
    }

    private func weatherFitMultiplier(poi: POI, weather: Weather) -> Double {
        var multiplier = poi.weatherFit.contains(weather)
            ? Self.weatherFitBoost
            : Self.weatherFitNeutral

        // Indoor/outdoor bias by precipitation / sky condition
        switch weather {
        case .rain, .snow, .fog:
            switch poi.indoorOutdoor {
            case .outdoor: multiplier *= Self.outdoorRainPenalty
            case .indoor:  multiplier *= Self.indoorRainBoost
            case .mixed:   break // neutral — mixed is sheltered enough
            }
        case .clear:
            if poi.indoorOutdoor == .indoor {
                multiplier *= Self.indoorClearPenalty
            }
        case .cloudy:
            break // cloudy is benign — no indoor/outdoor bias
        }

        return multiplier
    }

    private func distanceMultiplier(poi: POI, context: RecommendationContext) -> Double {
        guard let userCoord = context.coordinate else { return Self.distanceNeutral }
        let dist = userCoord.distance(to: poi.coordinate)
        let radius = context.preferences.travelRadiusMeters
        guard dist > radius else { return 1.0 }

        // Soft exponential-style penalty: one application of distancePenaltyFactor
        // per full radius of extra distance beyond the user's radius.
        let extraRadii = (dist - radius) / radius
        return pow(Self.distancePenaltyFactor, extraRadii)
    }

    private func noveltyMultiplier(poi: POI, explored: Set<String>) -> Double {
        explored.contains(poi.poiRef)
            ? Self.noveltyExploredMultiplier
            : Self.noveltyFreshMultiplier
    }

    /// Small additive persona adjustment. Documented choices:
    ///
    /// - **restlessLocal**: Surprise-me ethos. Boost `quirky` vibe places
    ///   (hidden gems). Extra bonus if not yet explored (novelty-on-novelty).
    ///
    /// - **newcomer**: Everything is new and landmarks are the hook. Boost
    ///   `scenic` vibe + `viewpoint`/`museum` categories (classic discovery).
    ///
    /// - **weekendDrifter**: No-plans Saturday energy. Boost `cozy` vibe places
    ///   — coffee shops, bookstores, bars — that feel like a good anchor.
    private func personaBias(
        poi: POI,
        context: RecommendationContext,
        explored: Set<String>
    ) -> Double {
        switch context.preferences.persona {
        case .restlessLocal:
            var bias = 0.0
            if poi.vibe.contains(.quirky) { bias += Self.restlessLocalQuirkyBonus }
            if !explored.contains(poi.poiRef) { bias += Self.restlessLocalNoveltyBonus }
            return bias

        case .newcomer:
            var bias = 0.0
            if poi.vibe.contains(.scenic) { bias += Self.newcomerScenicBonus }
            if poi.category == .viewpoint || poi.category == .museum {
                bias += Self.newcomerLandmarkBonus
            }
            return bias

        case .weekendDrifter:
            return poi.vibe.contains(.cozy) ? Self.weekendDrifterCozyBonus : 0.0
        }
    }
}
