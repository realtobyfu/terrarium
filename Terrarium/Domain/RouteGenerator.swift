//
//  RouteGenerator.swift
//  Terrarium — Domain
//
//  US-E3 / FR-13 / FR-14: Deterministic loop-walk generator.
//
//  Design
//  ──────
//  `generateLoop` returns a list of waypoints that form a rough loop starting
//  and ending near the origin coordinate. The caller injects the random-number
//  generator so the function is pure and deterministic for a given seed.
//
//  Walking model
//  ─────────────
//  Assume 80 m / min (≈ 4.8 km/h) — a comfortable urban walking pace
//  accounting for pauses at crossings. `targetMinutes` × 80 → target total
//  path length in metres. The loop uses roughly half the budget to go out and
//  half to come back.
//
//  Randomness dial (0.0 – 1.0)
//  ────────────────────────────
//  • 0.0 → anchored: waypoints route *through* the top POI seeds (a park, a
//    coffee shop, …), then arc back. The seeds act as magnetic attractors
//    weighted by rank order.
//  • 1.0 → freestyle: waypoints are placed on random headings from origin.
//  • Values in between blend the two approaches proportionally.
//
//  Safety filter (FR-14) — documented limitations
//  ───────────────────────────────────────────────
//  This layer is purely geometric (no map data). It applies the following
//  heuristic guards:
//  1. No waypoint is placed more than `maxRadiusMeters` from origin.
//     Default = half the total path length (so the loop can reasonably close).
//  2. Time-of-day: if `safeHoursOnly` is true (default) and `currentHour` is
//     outside 06:00–22:00, the route radius is reduced by 50 % and randomness
//     is clamped to ≤ 0.3 (stay close, prefer known seeds).
//  3. A note on "public/walkable": no real map data is available at this
//     layer. Callers should treat the returned waypoints as *suggestions* and
//     display them alongside standard map tiles (Stream D / the shell) so the
//     user can see streets. The Wave-3 integration agent may add a snap-to-
//     road pass using MapKit's `MKDirections` if desired.
//
//  Determinism
//  ───────────
//  The function is generic over `RandomNumberGenerator` (injected, not
//  captured). It contains no hidden clock reads or singleton RNG calls.
//  The same `origin`, `targetMinutes`, `randomness`, `seeds`, and RNG seed
//  always produce identical output — required by the decisions doc and
//  unit-test contract.
//

import Foundation

// MARK: - RouteGenerator

enum RouteGenerator {

    // -------------------------------------------------------------------------
    // MARK: Constants
    // -------------------------------------------------------------------------

    /// Metres per minute at a comfortable urban walking pace.
    static let metersPerMinute: Double = 80.0

    /// Default number of intermediate waypoints (not counting the return arc).
    static let defaultWaypointCount: Int = 5

    /// Earth radius in metres (for haversine / inverse-haversine math).
    private static let earthRadius: Double = 6_371_000.0

    // -------------------------------------------------------------------------
    // MARK: Public entry point
    // -------------------------------------------------------------------------

    /// Generate a loop route starting and ending near `origin`.
    ///
    /// - Parameters:
    ///   - origin:         The user's current position (degrees).
    ///   - targetMinutes:  Desired walk duration in minutes (e.g. 30, 60).
    ///   - randomness:     0 = through seeds, 1 = random headings.
    ///   - seeds:          Ranked POI seeds from `PlaceRecommending.driftSeeds`.
    ///   - currentHour:    Hour of day (0–23) used for the safety filter.
    ///                     Default 12 (noon) when omitted.
    ///   - safeHoursOnly:  Apply time-of-day safety reduction outside 06–22.
    ///   - waypointCount:  Number of outbound waypoints before the return arc.
    ///   - rng:            Injected RNG (e.g. `SystemRandomNumberGenerator()`
    ///                     for production, or a seeded `SeedableRNG` in tests).
    /// - Returns: An array of coordinates forming a loop. Always begins with
    ///   `origin` and ends with a coordinate close to `origin`. Returns just
    ///   `[origin]` when `targetMinutes ≤ 0`.
    static func generateLoop(
        from origin: Coordinate,
        targetMinutes: Double,
        randomness: Double,
        seeds: [POI],
        currentHour: Int = 12,
        safeHoursOnly: Bool = true,
        waypointCount: Int = defaultWaypointCount,
        rng: inout some RandomNumberGenerator
    ) -> [Coordinate] {
        guard targetMinutes > 0 else { return [origin] }

        // Safety filter: restrict at night / early morning.
        let isUnsafeHour = safeHoursOnly && (currentHour < 6 || currentHour >= 22)
        let effectiveRandomness = isUnsafeHour ? min(randomness, 0.3) : randomness

        // Total path budget in metres.
        let totalMeters    = targetMinutes * metersPerMinute
        // Max radius: limit how far any point can stray from origin so the loop
        // can close within the remaining budget.
        var maxRadius      = totalMeters / 2.5
        if isUnsafeHour { maxRadius *= 0.5 }

        // Step size: divide outbound budget evenly among waypoints.
        let outboundBudget = totalMeters * 0.55
        let stepMeters     = outboundBudget / Double(max(1, waypointCount))

        // Build outbound waypoints.
        var waypoints: [Coordinate] = [origin]
        var current = origin
        var cumulativeHeading: Double = 0.0   // running heading for coherence

        for i in 0 ..< waypointCount {
            let seedCoord: Coordinate? = seeds.indices.contains(i) ? seeds[i].coordinate : nil
            let wp = nextWaypoint(
                from:         current,
                origin:       origin,
                seedTarget:   seedCoord,
                randomness:   effectiveRandomness,
                stepMeters:   stepMeters,
                maxRadius:    maxRadius,
                runningHeading: &cumulativeHeading,
                rng:          &rng
            )
            waypoints.append(wp)
            current = wp
        }

        // Return arc: interpolate back toward origin in two steps so the loop
        // doesn't just snap back in a straight line (looks more natural).
        let returnArc = returnWaypoints(from: current, to: origin, steps: 2)
        waypoints.append(contentsOf: returnArc)

        return waypoints
    }

    // -------------------------------------------------------------------------
    // MARK: Private helpers
    // -------------------------------------------------------------------------

    /// Compute the next outbound waypoint.
    private static func nextWaypoint(
        from current: Coordinate,
        origin: Coordinate,
        seedTarget: Coordinate?,
        randomness: Double,
        stepMeters: Double,
        maxRadius: Double,
        runningHeading: inout Double,
        rng: inout some RandomNumberGenerator
    ) -> Coordinate {
        // Seed-directed heading (toward the nearest seed).
        let seedHeading: Double
        if let t = seedTarget {
            seedHeading = bearing(from: current, to: t)
        } else {
            // When no seed available, continue roughly away from origin.
            seedHeading = bearing(from: origin, to: current) + Double.random(in: -30...30, using: &rng)
        }

        // Random heading: deviate from running heading for a wandering feel.
        let deviation = Double.random(in: -90...90, using: &rng)
        let randomHeading = runningHeading + deviation

        // Blend based on randomness dial.
        let clampedR = max(0, min(1, randomness))
        let heading  = blend(seedHeading, randomHeading, t: clampedR)
        runningHeading = heading   // update for next step

        // Project forward by stepMeters along heading.
        var candidate = project(from: current, distanceMeters: stepMeters, bearingDegrees: heading)

        // Safety clamp: if the candidate exceeds maxRadius from origin, pull it
        // back to the boundary along the same bearing from origin.
        let d = haversine(origin, candidate)
        if d > maxRadius {
            let bearingFromOrigin = bearing(from: origin, to: candidate)
            candidate = project(from: origin, distanceMeters: maxRadius, bearingDegrees: bearingFromOrigin)
        }

        return candidate
    }

    /// Two-step return arc from `from` back toward `to`.
    private static func returnWaypoints(
        from: Coordinate,
        to: Coordinate,
        steps: Int
    ) -> [Coordinate] {
        guard steps > 0 else { return [to] }
        var result: [Coordinate] = []
        for i in 1...steps {
            let t = Double(i) / Double(steps)
            result.append(interpolate(from, to, t: t))
        }
        return result
    }

    // -------------------------------------------------------------------------
    // MARK: Coordinate math (pure, deterministic)
    // -------------------------------------------------------------------------

    /// Bearing in degrees (0 = north, clockwise) from `a` to `b`.
    static func bearing(from a: Coordinate, to b: Coordinate) -> Double {
        let lat1 = a.latitude  * .pi / 180
        let lat2 = b.latitude  * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Projects a point from `origin` by `distanceMeters` on `bearingDegrees`.
    static func project(
        from origin: Coordinate,
        distanceMeters: Double,
        bearingDegrees: Double
    ) -> Coordinate {
        let d   = distanceMeters / earthRadius
        let br  = bearingDegrees * .pi / 180
        let lat = origin.latitude  * .pi / 180
        let lon = origin.longitude * .pi / 180

        let lat2 = asin(sin(lat) * cos(d) + cos(lat) * sin(d) * cos(br))
        let lon2 = lon + atan2(sin(br) * sin(d) * cos(lat),
                               cos(d) - sin(lat) * sin(lat2))

        return Coordinate(
            latitude:  lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
    }

    /// Haversine distance in metres between two coordinates.
    static func haversine(_ a: Coordinate, _ b: Coordinate) -> Double {
        let lat1 = a.latitude  * .pi / 180
        let lat2 = b.latitude  * .pi / 180
        let dLat = (b.latitude  - a.latitude)  * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
              + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return earthRadius * 2 * atan2(sqrt(h), sqrt(1 - h))
    }

    /// Linear interpolation between two coordinates in degree space.
    static func interpolate(
        _ a: Coordinate,
        _ b: Coordinate,
        t: Double
    ) -> Coordinate {
        Coordinate(
            latitude:  a.latitude  + (b.latitude  - a.latitude)  * t,
            longitude: a.longitude + (b.longitude - a.longitude) * t
        )
    }

    /// Blend two headings by weight `t` (0 → a, 1 → b), handling wrap-around.
    private static func blend(_ a: Double, _ b: Double, t: Double) -> Double {
        // Convert both to radians, use the shortest arc.
        var diff = (b - a).truncatingRemainder(dividingBy: 360)
        if diff > 180  { diff -= 360 }
        if diff < -180 { diff += 360 }
        return (a + diff * t).truncatingRemainder(dividingBy: 360)
    }
}

// MARK: - SeedableRNG (test helper — a simple LCG)

/// A deterministic `RandomNumberGenerator` for unit tests. Uses a Linear
/// Congruential Generator with the classic Knuth multiplier so callers get
/// reproducible routes for a given `seed` value.
struct SeedableRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Mix the seed with a fixed constant to avoid degeneracy for seed 0.
        self.state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        // Knuth's multiplicative LCG (64-bit).
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
