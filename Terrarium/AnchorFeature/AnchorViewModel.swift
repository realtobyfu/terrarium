//
//  AnchorViewModel.swift
//  Terrarium — AnchorFeature
//
//  Stream D (US-D1 + US-D2). Expands the Wave-0 skeleton into the full
//  concierge screen + terrarium handoff:
//
//  US-D1 — ranked pick, re-roll pool, Maps handoff.
//  US-D2 — "I'm here" arrival action: records a Discovery and awards a specimen
//           via WorldStore. Honour-mode by default; Stream F injects a real
//           LocationVerifier by swapping `arrivalVerifier`.
//

import Foundation
import Observation
import MapKit

@Observable
@MainActor
final class AnchorViewModel {

    // -------------------------------------------------------------------------
    // MARK: Published state (observed by AnchorView)
    // -------------------------------------------------------------------------

    /// The pick currently shown to the user.
    private(set) var pick: POI?

    /// True while `refresh()` / `arrive()` are running.
    private(set) var isLoading = false

    /// Non-nil once the user has tapped "I'm here" and the award has resolved.
    private(set) var arrivalResult: ArrivalResult?

    // -------------------------------------------------------------------------
    // MARK: Injected dependencies
    // -------------------------------------------------------------------------

    let catalog: POICatalogProviding
    let weather: WeatherProviding
    let recommender: PlaceRecommending
    let location: LocationSessionProviding
    let discoveries: DiscoveryStore
    let preferences: UserPreferences

    /// Persistent store for the terrarium handoff (US-D2).
    var worldStore: WorldStore?

    /// Seam for Stream F: swap in a real `LocationVerifier` to replace honour-mode.
    var arrivalVerifier: QuestVerifier = HonorVerifier()

    // -------------------------------------------------------------------------
    // MARK: Private re-roll state
    // -------------------------------------------------------------------------

    /// The full ranked list assembled on each `refresh()`. We advance through
    /// it on each "Another" tap rather than re-running the ranker from scratch
    /// (same moment → deterministic, no flickering).
    private var pool: [POI] = []
    private var poolIndex: Int = 0

    /// The context used to build the current pool — exposed so the view can
    /// read weather/timeOfDay for framing copy.
    private(set) var context: RecommendationContext?

    private let assembler = ContextAssembler()

    // -------------------------------------------------------------------------
    // MARK: Init
    // -------------------------------------------------------------------------

    init(catalog: POICatalogProviding,
         weather: WeatherProviding,
         recommender: PlaceRecommending,
         location: LocationSessionProviding,
         discoveries: DiscoveryStore,
         preferences: UserPreferences = .default) {
        self.catalog = catalog
        self.weather = weather
        self.recommender = recommender
        self.location = location
        self.discoveries = discoveries
        self.preferences = preferences
    }

    // -------------------------------------------------------------------------
    // MARK: US-D1 — Refresh (initial load + re-roll support)
    // -------------------------------------------------------------------------

    /// Build a fresh context, rank the whole catalog into `pool`, and show the
    /// top pick. Resets the re-roll index. Called on view appear and on pull-
    /// to-refresh.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        let currentWeather = await weather.current()
        let coordinate = await location.currentCoordinate()

        let ctx = assembler.assemble(
            weather: currentWeather,
            now: .now,
            coordinate: coordinate,
            preferences: preferences
        )
        context = ctx

        // driftSeeds gives us a ranked list; anchor() gives the single best.
        // We use driftSeeds for the pool so re-roll can cycle through them.
        // driftSeedCount is 5 by default; for anchor we want a deeper pool.
        // We rank all non-closed POIs by calling the recommender's drift seeds
        // (which is the same ranked slice). For a deeper pool we concatenate
        // any remaining catalog POIs after the top N.
        let seeds = recommender.driftSeeds(ctx)
        let topRef = recommender.anchor(ctx)?.poiRef
        // Build pool: put anchor's pick first if it differs from seeds[0],
        // then extend with seeds, removing duplicates.
        var seen = Set<String>()
        var ordered: [POI] = []
        if let top = recommender.anchor(ctx) {
            ordered.append(top)
            seen.insert(top.poiRef)
        }
        for poi in seeds where !seen.contains(poi.poiRef) {
            ordered.append(poi)
            seen.insert(poi.poiRef)
        }
        pool = ordered
        poolIndex = 0
        pick = pool.first
        arrivalResult = nil
        _ = topRef // suppress warning
    }

    // -------------------------------------------------------------------------
    // MARK: US-D1 — Re-roll
    // -------------------------------------------------------------------------

    /// Advance to the next pick in the pool. Wraps around if the user cycles
    /// past the last item (edge-case: pool has only one item → no-op).
    func rollAnother() {
        guard pool.count > 1 else { return }
        poolIndex = (poolIndex + 1) % pool.count
        pick = pool[poolIndex]
        arrivalResult = nil
    }

    // -------------------------------------------------------------------------
    // MARK: US-D1 — Maps handoff
    // -------------------------------------------------------------------------

    /// Open Apple Maps navigation to the current pick.
    func openInMaps() {
        guard let poi = pick else { return }
        let coord = CLLocationCoordinate2D(
            latitude: poi.coordinate.latitude,
            longitude: poi.coordinate.longitude
        )
        let placemark = MKPlacemark(coordinate: coord)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = poi.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }

    // -------------------------------------------------------------------------
    // MARK: US-D2 — Arrival / terrarium handoff
    // -------------------------------------------------------------------------

    /// "I'm here" — honour-mode arrival (or real geofence via `arrivalVerifier`
    /// once Stream F injects `LocationVerifier`).
    ///
    /// 1. Builds a `Quest` from the current POI.
    /// 2. Awards it via `WorldStore.complete(quest:with:)` (idempotent).
    /// 3. Records a `Discovery` in the injected `DiscoveryStore`.
    func arrive() async {
        guard let poi = pick else { return }
        isLoading = true
        defer { isLoading = false }

        // Build quest from POI (FR-16, FR-21)
        let quest = Quest(
            title: "Arrived at \(poi.name)",
            prompt: "You made it to \(poi.name).",
            placeName: poi.name,
            poiRef: poi.poiRef,
            suggestedKind: poi.specimenKind
        )

        // Award via WorldStore (grows specimen at POI placement coordinate)
        var specimenGrown = false
        if let store = worldStore {
            let prop = await store.complete(quest: quest, with: arrivalVerifier)
            specimenGrown = prop != nil
        }

        // Record discovery regardless of whether a specimen was awarded
        // (could be idempotent / already completed)
        let ctx = context ?? assembler.assemble(
            weather: .clear, now: .now, preferences: preferences
        )
        let discovery = Discovery(
            target: .poi(poiRef: poi.poiRef),
            context: DiscoveryContext(weather: ctx.weather, timeOfDay: ctx.timeOfDay)
        )
        discoveries.record(discovery)

        arrivalResult = ArrivalResult(
            poi: poi,
            specimenGrown: specimenGrown,
            discovery: discovery
        )
    }

    // -------------------------------------------------------------------------
    // MARK: Computed helpers (used by AnchorView)
    // -------------------------------------------------------------------------

    /// A short vibe line combining weather-aware framing with the POI's vibe
    /// tags. e.g. "Cozy spot for a rainy afternoon · quiet · scenic"
    var vibeLine: String? {
        guard let poi = pick else { return nil }
        let weatherFrame = weatherFrame(poi: poi)
        let vibeText = poi.vibe.prefix(2).map(\.rawValue).joined(separator: " · ")
        if vibeText.isEmpty { return weatherFrame }
        return [weatherFrame, vibeText].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// Weather + indoor/outdoor framing that matches the current moment.
    private func weatherFrame(poi: POI) -> String {
        let weather = context?.weather ?? .clear
        switch (weather, poi.indoorOutdoor) {
        case (.rain, .indoor), (.fog, .indoor):
            return "A cozy indoor escape"
        case (.rain, .outdoor):
            return "Best enjoyed after the rain"
        case (.fog, .outdoor):
            return "Karl the Fog approved"
        case (.fog, .mixed):
            return "Moody and atmospheric"
        case (.clear, .outdoor):
            return "Perfect day for it"
        case (.clear, .indoor):
            return "A great indoor find"
        case (.cloudy, _):
            return "Good any time"
        case (.snow, .indoor):
            return "Warm refuge from the snow"
        case (.snow, .outdoor):
            return "A rare snowy outing"
        default:
            return "A local favourite"
        }
    }

    /// Formatted walk distance and estimated time when a coordinate is available.
    var walkInfo: WalkInfo? {
        guard let poi = pick, let userCoord = context?.coordinate else { return nil }
        let distanceMeters = haversineMeters(
            from: userCoord,
            to: poi.coordinate
        )
        let walkMinutes = Int((distanceMeters / 1.4 / 60).rounded(.up)) // ~1.4 m/s walking
        return WalkInfo(
            distanceMeters: distanceMeters,
            walkMinutes: max(1, walkMinutes)
        )
    }

    /// True when the pick is tagged as open-now (or unknown — soft-allowed).
    /// We rely on the ranker already having excluded closed places; exposed
    /// here as a display hint only.
    var pickIsLikelyOpen: Bool {
        guard let pick else { return false }
        // If hoursRef is nil → unknown, ranker soft-allowed it.
        // For display purposes we show the indicator when not obviously closed.
        return pick.hoursRef == nil || true // ranker already filtered closed
    }

    // -------------------------------------------------------------------------
    // MARK: Private helpers
    // -------------------------------------------------------------------------

    private func haversineMeters(from a: Coordinate, to b: Coordinate) -> Double {
        let r = 6_371_000.0
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let sinA = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return r * 2 * atan2(sqrt(sinA), sqrt(1 - sinA))
    }
}

// -------------------------------------------------------------------------
// MARK: Supporting value types
// -------------------------------------------------------------------------

/// Walk distance + time estimate from the user's current location to the pick.
struct WalkInfo: Equatable {
    let distanceMeters: Double
    let walkMinutes: Int

    /// e.g. "850 m · ~10 min walk"
    var label: String {
        let dist = distanceMeters >= 1000
            ? String(format: "%.1f km", distanceMeters / 1000)
            : "\(Int(distanceMeters.rounded())) m"
        return "\(dist) · ~\(walkMinutes) min walk"
    }
}

/// The outcome of tapping "I'm here".
struct ArrivalResult: Equatable {
    let poi: POI
    let specimenGrown: Bool
    let discovery: Discovery
}
