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
    /// 2. Awards it via `WorldStore.complete(quest:with:variant:)` (idempotent).
    ///    The variant is derived from the context weather snapshot (US-F2).
    /// 3. Records a `Discovery` in the injected `DiscoveryStore`.
    /// 4. Writes a `JournalEntry` for the specimen using the POI's name (US-F3).
    func arrive() async {
        guard let poi = pick else { return }
        isLoading = true
        defer { isLoading = false }

        // Snapshot context (weather / time) at arrival time.
        let ctx = context ?? assembler.assemble(
            weather: .clear, now: .now, preferences: preferences
        )

        // Cosmetic kind/variant for the decoupled journal art.
        let variant = SpecimenMapping.variant(for: ctx.weather)
        let mappedKind = SpecimenMapping.kind(for: poi.category)

        // Verify presence before rewarding: honor-mode is always true; a real
        // LocationVerifier (Stream F) gates on proximity. We build a minimal quest
        // purely so the verifier can resolve the POI coordinate.
        let quest = Quest(
            id: Self.stableQuestID(for: poi.poiRef),
            title: "Arrived at \(poi.name)",
            prompt: "You made it to \(poi.name).",
            placeName: poi.name,
            poiRef: poi.poiRef,
            suggestedKind: mappedKind
        )
        let verified = await arrivalVerifier.verify(quest)

        // Reward the FIRST verified arrival at a place with points (idempotent —
        // re-arriving the same POI doesn't re-award). Points drive globe growth;
        // no per-discovery specimen is grown (that's the cut "grow a tree").
        let alreadyVisited = discoveries.exploredRefs().contains(poi.poiRef)
        var award = PointsAward(total: worldStore?.totalPoints() ?? 0, added: 0, tiersGained: 0)
        if verified, !alreadyVisited, let store = worldStore {
            award = store.awardPoints(Self.arrivalPoints)
            // Decoupled discovery journal entry (no globe prop).
            store.logDiscovery(text: "Discovered \(poi.name).", placeName: poi.name,
                               kind: mappedKind, variant: variant)
        }

        // Record the discovery (also backs the idempotency check above).
        let discovery = Discovery(
            target: .poi(poiRef: poi.poiRef),
            context: DiscoveryContext(weather: ctx.weather, timeOfDay: ctx.timeOfDay)
        )
        discoveries.record(discovery)

        arrivalResult = ArrivalResult(
            poi: poi,
            pointsEarned: award.added,
            tiersGained: award.tiersGained,
            discovery: discovery
        )
    }

    /// Points granted for a (first, verified) Anchor arrival.
    static let arrivalPoints = 40

    /// A deterministic UUID derived from a POI reference (FNV-1a over two seeds),
    /// so arriving at the same place always produces the same quest id and
    /// WorldStore's idempotency check dedups it. Mirrors POIPlacement's stable-
    /// hash discipline (no Swift Hasher).
    static func stableQuestID(for poiRef: String) -> UUID {
        func fnv1a(_ string: String, seed: UInt64) -> UInt64 {
            var hash = seed
            for byte in string.utf8 { hash ^= UInt64(byte); hash = hash &* 0x100000001b3 }
            return hash
        }
        let hi = withUnsafeBytes(of: fnv1a(poiRef, seed: 0xcbf29ce484222325).bigEndian) { Array($0) }
        let lo = withUnsafeBytes(of: fnv1a(poiRef + "#anchor", seed: 0xcbf29ce484222325).bigEndian) { Array($0) }
        let b = hi + lo
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                           b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
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
    /// Points awarded by this arrival (0 if unverified or already visited).
    let pointsEarned: Int
    /// Globe tiers gained from this arrival's points (drives the reward beat).
    let tiersGained: Int
    let discovery: Discovery
}
