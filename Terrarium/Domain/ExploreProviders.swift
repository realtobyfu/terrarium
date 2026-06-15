//
//  ExploreProviders.swift
//  Terrarium — Domain
//
//  Provider protocols + offline stubs for the Explore feature, mirroring the
//  existing Providers.swift pattern (SkyStateProviding / WorldStateProviding).
//  These protocol signatures are the FROZEN integration contract (Stream H /
//  Wave 0): every Wave-1 stream builds against them, including against each
//  other's stubs, so no agent waits on another's implementation. A stream that
//  needs a signature change must surface it for a coordinated bump — do not edit
//  unilaterally.
//
//  Real implementations:
//    POICatalogProviding   → Stream A (BundledPOICatalog)
//    WeatherProviding      → Stream B (WeatherKitProvider)
//    LocationSessionProviding → Stream B (LocationSessionManager)
//    PlaceRecommending     → Stream C (RulesRecommender)
//    DiscoveryStore        → Stream F (SwiftData-backed) / Stream E uses it
//

import Foundation

// MARK: - Protocols

/// The curated POI catalog. `allowedRefs()` is the grounding allow-list reused by
/// `QuestGrounding` so no recommendation can reference a place outside the catalog
/// (FR-2).
protocol POICatalogProviding {
    func all() -> [POI]
    func allowedRefs() -> Set<String>
}

/// Current weather, mapped to the existing `Weather` enum (FR-5). Async so the
/// real WeatherKit call can do I/O; implementations must never block the UI and
/// must fall back rather than throw.
protocol WeatherProviding {
    func current() async -> Weather
}

/// Session-scoped location (FR-6): tracking happens *only* between `start()` and
/// `stop()`, using `When In Use`. Exposes a breadcrumb stream for Drift and a
/// one-shot read for the geofence verifier. No background/ambient tracking.
protocol LocationSessionProviding: AnyObject {
    /// True while a session is running (between start and stop).
    var isActive: Bool { get }
    func start()
    func stop()
    /// Breadcrumbs emitted only while a session is active. Each call returns a
    /// fresh stream bound to the current/next session.
    func breadcrumbStream() -> AsyncStream<Coordinate>
    /// Momentary current-location read (used by `LocationVerifier`, FR-15).
    /// Returns nil when permission is unavailable.
    func currentCoordinate() async -> Coordinate?
}

/// The deterministic, rules-based recommender (FR-9). No ML, no network at rank
/// time. `anchor` returns the single best open-now place; `driftSeeds` returns N
/// ranked seeds for route shaping.
protocol PlaceRecommending {
    func anchor(_ context: RecommendationContext) -> POI?
    func driftSeeds(_ context: RecommendationContext) -> [POI]
}

/// On-device record of what's been discovered (FR-8). Backs novelty in the ranker
/// and fog-of-war in Drift.
protocol DiscoveryStore: AnyObject {
    func record(_ discovery: Discovery)
    /// Cell ids the user has ever lit.
    func exploredCells() -> Set<String>
    /// POI refs the user has ever discovered (demoted by ranker novelty).
    func exploredRefs() -> Set<String>
}

// MARK: - Stubs

/// A tiny in-memory catalog so the app and downstream stubs have real data
/// offline before Stream A's bundled loader lands. A few recognisable SF spots
/// spanning categories/specimen kinds.
struct StubPOICatalog: POICatalogProviding {
    // TODO(Stream A): replace with BundledPOICatalog loading sf-pois.json.
    static let fixtures: [POI] = [
        POI(poiRef: "poi.ocean-beach.sf", name: "Ocean Beach",
            category: .viewpoint, neighborhood: "Outer Sunset",
            coordinate: Coordinate(latitude: 37.7594, longitude: -122.5107),
            indoorOutdoor: .outdoor, bestTime: [.evening], weatherFit: [.clear, .fog],
            goodFor: [.solo, .date], vibe: [.scenic, .quiet], price: .free,
            hoursRef: nil, specimenKind: .tree, source: .curated),
        POI(poiRef: "poi.sightglass-coffee.sf", name: "Sightglass Coffee",
            category: .coffee, neighborhood: "SoMa",
            coordinate: Coordinate(latitude: 37.7765, longitude: -122.4089),
            indoorOutdoor: .indoor, bestTime: [.morning], weatherFit: [.rain, .cloudy, .fog],
            goodFor: [.solo, .group], vibe: [.cozy, .lively], price: .medium,
            hoursRef: nil, specimenKind: .building, source: .curated),
        POI(poiRef: "poi.dolores-park.sf", name: "Dolores Park",
            category: .park, neighborhood: "Mission",
            coordinate: Coordinate(latitude: 37.7596, longitude: -122.4269),
            indoorOutdoor: .outdoor, bestTime: [.afternoon], weatherFit: [.clear],
            goodFor: [.group, .date], vibe: [.lively, .scenic], price: .free,
            hoursRef: nil, specimenKind: .tree, source: .curated),
    ]

    func all() -> [POI] { Self.fixtures }
    func allowedRefs() -> Set<String> { Set(Self.fixtures.map(\.poiRef)) }
}

/// Returns `.fog` to match the current offline sky behaviour (StubSkyStateProvider).
struct StubWeatherProvider: WeatherProviding {
    // TODO(Stream B): WeatherKitProvider mapping real conditions → Weather.
    func current() async -> Weather { .fog }
}

/// A no-op location session: never emits breadcrumbs, no coordinate. Keeps the
/// app runnable with no location permission and lets Drift/Anchor compile.
final class StubLocationSession: LocationSessionProviding {
    // TODO(Stream B): LocationSessionManager wrapping CLLocationManager.
    private(set) var isActive = false
    func start() { isActive = true }
    func stop() { isActive = false }
    func breadcrumbStream() -> AsyncStream<Coordinate> { AsyncStream { $0.finish() } }
    func currentCoordinate() async -> Coordinate? { nil }
}

/// Naïve recommender: hands back catalog order, demoting already-explored places.
/// Just enough behaviour for Anchor/Drift to render before Stream C's real scorer.
struct StubRecommender: PlaceRecommending {
    // TODO(Stream C): RulesRecommender with the full weighted score.
    let catalog: POICatalogProviding
    let discoveries: DiscoveryStore

    private func ranked() -> [POI] {
        let explored = discoveries.exploredRefs()
        return catalog.all().sorted { a, b in
            explored.contains(a.poiRef) ? false : (explored.contains(b.poiRef) ? true : false)
        }
    }

    func anchor(_ context: RecommendationContext) -> POI? { ranked().first }
    func driftSeeds(_ context: RecommendationContext) -> [POI] { ranked() }
}

/// In-memory discovery store. Real persistence (SwiftData) lands in Stream F;
/// this keeps novelty + fog working offline and in tests.
final class InMemoryDiscoveryStore: DiscoveryStore {
    // TODO(Stream F): SwiftData-backed store persisting on-device (FR-8).
    private var discoveries: [Discovery] = []

    func record(_ discovery: Discovery) { discoveries.append(discovery) }

    func exploredCells() -> Set<String> {
        Set(discoveries.compactMap { d in
            if case .cell(let id) = d.target { return id } else { return nil }
        })
    }

    func exploredRefs() -> Set<String> {
        Set(discoveries.compactMap { d in
            if case .poi(let ref) = d.target { return ref } else { return nil }
        })
    }
}
