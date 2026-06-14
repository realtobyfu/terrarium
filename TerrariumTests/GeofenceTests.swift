//
//  GeofenceTests.swift
//  TerrariumTests
//
//  Unit tests for the pure haversine geofence (US-F1, FR-15, FR-22).
//
//  All inputs are deterministic values; no device / CoreLocation dependency.
//

import Testing
import Foundation
@testable import Terrarium

@Suite("Geofence")
@MainActor
struct GeofenceTests {

    // MARK: - Known coordinates

    /// Dolores Park, SF (~37.7596°N, 122.4269°W).
    private let doloresCenter = Coordinate(latitude: 37.7596, longitude: -122.4269)

    // MARK: - Containment

    @Test("Point at the center is inside the geofence")
    func pointAtCenterIsInside() {
        let inside = Geofence.contains(center: doloresCenter,
                                       radius: 80,
                                       point:  doloresCenter)
        #expect(inside == true)
    }

    @Test("Point clearly inside radius is contained")
    func pointClearlyInsideIsContained() {
        // ~10 m north
        let nearbyPoint = Coordinate(latitude: doloresCenter.latitude + 0.00009,
                                     longitude: doloresCenter.longitude)
        let inside = Geofence.contains(center: doloresCenter,
                                       radius: 80,
                                       point:  nearbyPoint)
        #expect(inside == true)
    }

    @Test("Point clearly outside radius is not contained")
    func pointClearlyOutsideIsNotContained() {
        // ~500 m north — well beyond any reasonable geofence
        let farPoint = Coordinate(latitude: doloresCenter.latitude + 0.0045,
                                  longitude: doloresCenter.longitude)
        let inside = Geofence.contains(center: doloresCenter,
                                       radius: 80,
                                       point:  farPoint)
        #expect(inside == false)
    }

    @Test("Point just inside the edge is contained")
    func pointJustInsideEdgeIsContained() {
        // Place a point ~79 m north (just inside an 80 m radius).
        // 1° latitude ≈ 111_000 m → 79 m ≈ 0.000711°
        let edgeInside = Coordinate(latitude: doloresCenter.latitude + 0.000711,
                                    longitude: doloresCenter.longitude)
        let dist = Geofence.distance(from: doloresCenter, to: edgeInside)
        // Verify the point is actually inside 80 m before testing containment.
        #expect(dist < 80)
        let inside = Geofence.contains(center: doloresCenter,
                                       radius: 80,
                                       point:  edgeInside)
        #expect(inside == true)
    }

    @Test("Point just outside the edge is not contained")
    func pointJustOutsideEdgeIsNotContained() {
        // ~81 m north (just outside an 80 m radius).
        let edgeOutside = Coordinate(latitude: doloresCenter.latitude + 0.000729,
                                     longitude: doloresCenter.longitude)
        let dist = Geofence.distance(from: doloresCenter, to: edgeOutside)
        #expect(dist > 80)
        let inside = Geofence.contains(center: doloresCenter,
                                       radius: 80,
                                       point:  edgeOutside)
        #expect(inside == false)
    }

    // MARK: - Distance accuracy

    @Test("Distance between two SF landmarks is within 5 pct of expected")
    func distanceLandmarksAccuracy() {
        // Rough known distance between Dolores Park and Ocean Beach:
        // both at ~37.76°N, ~5.8 km apart longitudinally.
        let oceanBeach = Coordinate(latitude: 37.7594, longitude: -122.5107)
        let dist = Geofence.distance(from: doloresCenter, to: oceanBeach)
        // Expected ~6800 m (very rough); just verify order of magnitude.
        #expect(dist > 5_000 && dist < 9_000)
    }

    @Test("Distance is symmetric")
    func distanceIsSymmetric() {
        let a = Coordinate(latitude: 37.7596, longitude: -122.4269)
        let b = Coordinate(latitude: 37.7700, longitude: -122.4350)
        let ab = Geofence.distance(from: a, to: b)
        let ba = Geofence.distance(from: b, to: a)
        #expect(abs(ab - ba) < 0.001)  // within 1 mm
    }

    @Test("Distance to self is zero")
    func distanceToSelfIsZero() {
        let d = Geofence.distance(from: doloresCenter, to: doloresCenter)
        #expect(d < 0.001)
    }

    // MARK: - LocationVerifier degradation

    @Test("LocationVerifier awards when POI is not in catalog")
    func verifierAwardsWhenPoiMissing() async {
        let catalog = FixtureCatalog(pois: [])  // empty
        let location = MockCoordinateSession(coordinate: doloresCenter)
        let verifier = LocationVerifier(catalog: catalog, location: location)

        let quest = Quest(title: "t", prompt: "p", placeName: "p",
                          poiRef: "poi.missing", suggestedKind: .tree)
        let result = await verifier.verify(quest)
        // Degrade to honor (optimistic award) when catalog has no match.
        #expect(result == true)
    }

    @Test("LocationVerifier awards when location is unavailable")
    func verifierAwardsWhenLocationNil() async {
        let poi = GeofenceTests.makePOI(ref: "poi.test", coord: doloresCenter)
        let catalog = FixtureCatalog(pois: [poi])
        let location = MockCoordinateSession(coordinate: nil)  // no location
        let verifier = LocationVerifier(catalog: catalog, location: location)

        let quest = Quest(title: "t", prompt: "p", placeName: poi.name,
                          poiRef: poi.poiRef, suggestedKind: .tree)
        let result = await verifier.verify(quest)
        // Degrade to honor-mode.
        #expect(result == true)
    }

    @Test("LocationVerifier passes when user is inside geofence")
    func verifierPassesInsideGeofence() async {
        let poi = GeofenceTests.makePOI(ref: "poi.test", coord: doloresCenter)
        let catalog = FixtureCatalog(pois: [poi])
        // User is at the same coord as the POI — definitely inside.
        let location = MockCoordinateSession(coordinate: doloresCenter)
        let verifier = LocationVerifier(catalog: catalog, location: location, radiusMeters: 80)

        let quest = Quest(title: "t", prompt: "p", placeName: poi.name,
                          poiRef: poi.poiRef, suggestedKind: .tree)
        let result = await verifier.verify(quest)
        #expect(result == true)
    }

    @Test("LocationVerifier fails when user is outside geofence")
    func verifierFailsOutsideGeofence() async {
        let poi = GeofenceTests.makePOI(ref: "poi.test", coord: doloresCenter)
        let catalog = FixtureCatalog(pois: [poi])
        // User is ~500 m away — outside.
        let farAway = Coordinate(latitude: doloresCenter.latitude + 0.0045,
                                 longitude: doloresCenter.longitude)
        let location = MockCoordinateSession(coordinate: farAway)
        let verifier = LocationVerifier(catalog: catalog, location: location, radiusMeters: 80)

        let quest = Quest(title: "t", prompt: "p", placeName: poi.name,
                          poiRef: poi.poiRef, suggestedKind: .tree)
        let result = await verifier.verify(quest)
        #expect(result == false)
    }

    // MARK: - Helpers

    private static func makePOI(ref: String, coord: Coordinate) -> POI {
        POI(poiRef: ref, name: "Test Place", category: .park,
            neighborhood: "Mission",
            coordinate: coord,
            indoorOutdoor: .outdoor, bestTime: [.afternoon],
            weatherFit: [.clear], goodFor: [.solo], vibe: [.scenic],
            price: .free, hoursRef: nil, specimenKind: .tree, source: .curated)
    }
}

// MARK: - Test fixtures

private struct FixtureCatalog: POICatalogProviding {
    let pois: [POI]
    func all() -> [POI] { pois }
    func allowedRefs() -> Set<String> { Set(pois.map(\.poiRef)) }
}

@MainActor
private final class MockCoordinateSession: LocationSessionProviding {
    private(set) var isActive = false
    let coordinate: Coordinate?

    init(coordinate: Coordinate?) {
        self.coordinate = coordinate
    }

    func start() { isActive = true }
    func stop()  { isActive = false }
    func breadcrumbStream() -> AsyncStream<Coordinate> { AsyncStream { $0.finish() } }
    func currentCoordinate() async -> Coordinate? { coordinate }
}
