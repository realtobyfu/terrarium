//
//  RouteGeneratorTests.swift
//  TerrariumTests
//
//  Pure unit tests for RouteGenerator (US-E3, FR-13, FR-14).
//
//  Coverage
//  ────────
//  1. Loop returns close to start (within reasonable distance).
//  2. Longer target → longer (or equal) route total distance.
//  3. randomness=0 vs randomness=1 produce different waypoints.
//  4. Deterministic: same seed → identical output.
//  5. Empty seeds → still returns a loop.
//  6. Safety filter (night hour) reduces effective radius.
//  7. targetMinutes=0 returns only the origin.
//  8. Waypoint count matches expectation.
//

import Testing
import Foundation
@testable import Terrarium

@Suite("RouteGenerator")
struct RouteGeneratorTests {

    // ── Fixtures ──────────────────────────────────────────────────────────────

    private let sfOrigin = Coordinate(latitude: 37.7749, longitude: -122.4194)

    private func makeSeed(lat: Double, lon: Double) -> POI {
        POI(
            poiRef: "poi.test.\(Int(lat * 1000))",
            name: "Test POI",
            category: .park,
            neighborhood: "Test",
            coordinate: Coordinate(latitude: lat, longitude: lon),
            indoorOutdoor: .outdoor,
            bestTime: [.morning],
            weatherFit: [.clear],
            goodFor: [.solo],
            vibe: [.scenic],
            price: .free,
            specimenKind: .tree,
            source: .curated
        )
    }

    private var seeds: [POI] {
        [
            makeSeed(lat: 37.7796, lon: -122.4195),   // ~500 m N
            makeSeed(lat: 37.7749, lon: -122.4245),   // ~400 m W
            makeSeed(lat: 37.7705, lon: -122.4150),   // ~500 m SE
        ]
    }

    // ── Tests ─────────────────────────────────────────────────────────────────

    @Test("Loop returns close to origin (within 300 m)")
    func loopClosesNearOrigin() {
        var rng = SeedableRNG(seed: 42)
        let waypoints = RouteGenerator.generateLoop(
            from: sfOrigin,
            targetMinutes: 30,
            randomness: 0.5,
            seeds: seeds,
            rng: &rng
        )
        guard let last = waypoints.last else {
            Issue.record("Route was empty")
            return
        }
        let distToOrigin = RouteGenerator.haversine(last, sfOrigin)
        #expect(distToOrigin < 300, "Last waypoint \(distToOrigin) m from origin, expected < 300 m")
    }

    @Test("Longer target duration produces a longer or equal total route distance")
    func longerTargetLongerRoute() {
        var rng1 = SeedableRNG(seed: 7)
        var rng2 = SeedableRNG(seed: 7)
        let short = RouteGenerator.generateLoop(
            from: sfOrigin, targetMinutes: 20, randomness: 0.0, seeds: seeds, rng: &rng1)
        let long  = RouteGenerator.generateLoop(
            from: sfOrigin, targetMinutes: 60, randomness: 0.0, seeds: seeds, rng: &rng2)

        let shortDist = totalDistance(short)
        let longDist  = totalDistance(long)
        #expect(longDist >= shortDist, "60 min route (\(longDist) m) should be ≥ 20 min (\(shortDist) m)")
    }

    @Test("randomness=0 and randomness=1 produce different waypoints")
    func randomnessExtremesProduceDifferentRoutes() {
        var rng0 = SeedableRNG(seed: 99)
        var rng1 = SeedableRNG(seed: 99)
        let anchored = RouteGenerator.generateLoop(
            from: sfOrigin, targetMinutes: 30, randomness: 0.0, seeds: seeds, rng: &rng0)
        let free = RouteGenerator.generateLoop(
            from: sfOrigin, targetMinutes: 30, randomness: 1.0, seeds: seeds, rng: &rng1)
        // At least some intermediate waypoints differ.
        let differ = zip(anchored, free).contains { a, b in
            abs(a.latitude - b.latitude) > 0.0001 || abs(a.longitude - b.longitude) > 0.0001
        }
        #expect(differ, "randomness=0 and randomness=1 should produce different routes for same seed")
    }

    @Test("Same seed always produces identical waypoints")
    func deterministicForSameSeed() {
        var rngA = SeedableRNG(seed: 1234)
        var rngB = SeedableRNG(seed: 1234)
        let a = RouteGenerator.generateLoop(
            from: sfOrigin, targetMinutes: 30, randomness: 0.5, seeds: seeds, rng: &rngA)
        let b = RouteGenerator.generateLoop(
            from: sfOrigin, targetMinutes: 30, randomness: 0.5, seeds: seeds, rng: &rngB)
        #expect(a.count == b.count)
        for (wa, wb) in zip(a, b) {
            #expect(wa.latitude  == wb.latitude)
            #expect(wa.longitude == wb.longitude)
        }
    }

    @Test("Different seeds produce different routes")
    func differentSeedsDifferentRoutes() {
        var rngA = SeedableRNG(seed: 1)
        var rngB = SeedableRNG(seed: 9999)
        let a = RouteGenerator.generateLoop(
            from: sfOrigin, targetMinutes: 30, randomness: 1.0, seeds: [], rng: &rngA)
        let b = RouteGenerator.generateLoop(
            from: sfOrigin, targetMinutes: 30, randomness: 1.0, seeds: [], rng: &rngB)
        let differ = zip(a, b).contains { wa, wb in
            abs(wa.latitude - wb.latitude) > 1e-9 || abs(wa.longitude - wb.longitude) > 1e-9
        }
        #expect(differ)
    }

    @Test("Empty seeds still produces a valid loop")
    func emptySeeds() {
        var rng = SeedableRNG(seed: 17)
        let waypoints = RouteGenerator.generateLoop(
            from: sfOrigin, targetMinutes: 30, randomness: 1.0, seeds: [], rng: &rng)
        #expect(waypoints.count > 1)
        // First waypoint is the origin.
        #expect(waypoints[0].latitude  == sfOrigin.latitude)
        #expect(waypoints[0].longitude == sfOrigin.longitude)
    }

    @Test("targetMinutes=0 returns only the origin coordinate")
    func zeroMinutesReturnsOnlyOrigin() {
        var rng = SeedableRNG(seed: 0)
        let waypoints = RouteGenerator.generateLoop(
            from: sfOrigin, targetMinutes: 0, randomness: 0.5, seeds: seeds, rng: &rng)
        #expect(waypoints.count == 1)
        #expect(waypoints[0] == sfOrigin)
    }

    @Test("Night-hour safety filter reduces route distance compared to midday")
    func nightHourReducesRadius() {
        var rngDay   = SeedableRNG(seed: 5)
        var rngNight = SeedableRNG(seed: 5)
        let dayRoute   = RouteGenerator.generateLoop(
            from: sfOrigin, targetMinutes: 60, randomness: 0.8, seeds: seeds,
            currentHour: 14, safeHoursOnly: true, rng: &rngDay)
        let nightRoute = RouteGenerator.generateLoop(
            from: sfOrigin, targetMinutes: 60, randomness: 0.8, seeds: seeds,
            currentHour: 23, safeHoursOnly: true, rng: &rngNight)

        // Night route max radius from origin should be smaller than day route.
        let dayMaxRadius   = maxRadius(dayRoute,   from: sfOrigin)
        let nightMaxRadius = maxRadius(nightRoute, from: sfOrigin)
        // Night radius ≤ day radius (safety-constrained).
        #expect(dayMaxRadius >= nightMaxRadius,
                "Day radius (\(dayMaxRadius) m) should be ≥ night (\(nightMaxRadius) m)")
    }

    @Test("Waypoint count matches defaultWaypointCount + return arc + origin")
    func waypointCountStructure() {
        var rng = SeedableRNG(seed: 3)
        let wc = RouteGenerator.defaultWaypointCount
        let waypoints = RouteGenerator.generateLoop(
            from: sfOrigin, targetMinutes: 30, randomness: 0.5, seeds: seeds,
            waypointCount: wc, rng: &rng)
        // Expected: 1 (origin) + waypointCount (outbound) + 2 (return arc) = wc + 3
        let expected = 1 + wc + 2
        #expect(waypoints.count == expected,
                "Expected \(expected) waypoints, got \(waypoints.count)")
    }

    // ── Math helpers ──────────────────────────────────────────────────────────

    @Test("bearing from a to b is inverse of bearing from b to a (≈ ±180°)")
    func bearingInverse() {
        let a = Coordinate(latitude: 37.7749, longitude: -122.4194)
        let b = Coordinate(latitude: 37.7800, longitude: -122.4150)
        let ab = RouteGenerator.bearing(from: a, to: b)
        let ba = RouteGenerator.bearing(from: b, to: a)
        let diff = abs(ab - ba)
        let wrapped = min(diff, 360 - diff)
        #expect(abs(wrapped - 180) < 2, "bearing diff \(wrapped)° should be ≈ 180°")
    }

    @Test("project + haversine are consistent")
    func projectRoundTrip() {
        let origin  = Coordinate(latitude: 37.7749, longitude: -122.4194)
        let dist    = 500.0   // metres
        let bearing = 45.0   // NE
        let projected = RouteGenerator.project(from: origin, distanceMeters: dist, bearingDegrees: bearing)
        let measured  = RouteGenerator.haversine(origin, projected)
        #expect(abs(measured - dist) < 1, "Expected \(dist) m, got \(measured) m")
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private func totalDistance(_ coords: [Coordinate]) -> Double {
        guard coords.count > 1 else { return 0 }
        return zip(coords, coords.dropFirst())
            .map { RouteGenerator.haversine($0, $1) }
            .reduce(0, +)
    }

    private func maxRadius(_ coords: [Coordinate], from origin: Coordinate) -> Double {
        coords.map { RouteGenerator.haversine(origin, $0) }.max() ?? 0
    }
}
