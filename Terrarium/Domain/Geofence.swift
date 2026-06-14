//
//  Geofence.swift
//  Terrarium — Domain
//
//  Pure haversine containment check (US-F1, FR-15). No CoreLocation dependency —
//  Domain stays unit-testable with injected Coordinate values.
//
//  Mirror the determinism discipline of POIPlacement: pure function, no hidden
//  state, no device reads.
//

import Foundation

enum Geofence {

    /// Mean radius of Earth in metres.
    private static let earthRadiusMeters: Double = 6_371_000

    /// Returns true when `point` is within `meters` of `center`.
    ///
    /// Uses the haversine formula for great-circle distance.
    ///
    /// - Parameters:
    ///   - center:  The centre of the geofence (target POI coordinate).
    ///   - meters:  Radius of the geofence in metres.
    ///   - point:   The coordinate to test (user's current location).
    static func contains(center: Coordinate, radius meters: Double, point: Coordinate) -> Bool {
        distance(from: center, to: point) <= meters
    }

    /// Great-circle distance in metres between two coordinates.
    static func distance(from a: Coordinate, to b: Coordinate) -> Double {
        let lat1 = a.latitude  * .pi / 180
        let lat2 = b.latitude  * .pi / 180
        let dLat = (b.latitude  - a.latitude)  * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180

        let sinHalfLat = sin(dLat / 2)
        let sinHalfLon = sin(dLon / 2)
        let aVal = sinHalfLat * sinHalfLat
                 + cos(lat1) * cos(lat2) * sinHalfLon * sinHalfLon
        let c = 2 * atan2(sqrt(aVal), sqrt(1 - aVal))
        return earthRadiusMeters * c
    }
}
