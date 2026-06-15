//
//  PointSpotTests.swift
//  TerrariumTests
//
//  PointSpotField is pure value math (deterministic, no RNG state across launches).
//  These pin its contract: spots are stable for a given area, distinct, and within
//  the requested radius — so the Drift bonus loop is reproducible.
//

import Testing
import Foundation
@testable import Terrarium

@Suite("PointSpotField")
struct PointSpotTests {

    private let sf = Coordinate(latitude: 37.7596, longitude: -122.4269)

    @Test("Spots are deterministic for the same center")
    func deterministic() {
        let a = PointSpotField.spots(near: sf)
        let b = PointSpotField.spots(near: sf)
        #expect(a == b)
        #expect(a.map(\.cellID) == b.map(\.cellID))
    }

    @Test("Produces the requested number of distinct-cell spots")
    func distinctCount() {
        let spots = PointSpotField.spots(near: sf, count: 5)
        #expect(spots.count == 5)
        #expect(Set(spots.map(\.cellID)).count == 5)   // all distinct cells
        #expect(spots.allSatisfy { !$0.collected })    // start uncollected
    }

    @Test("Spots fall within the requested radius of the center")
    func withinRadius() {
        let radius = 1300.0
        let spots = PointSpotField.spots(near: sf, radiusMeters: radius)
        for spot in spots {
            let d = haversine(sf, spot.coordinate)
            #expect(d <= radius * 1.05)   // small slack for cell-center rounding
        }
    }

    @Test("A spot's id matches its geohash cell")
    func idIsCell() {
        let spots = PointSpotField.spots(near: sf)
        for spot in spots {
            #expect(spot.id == spot.cellID)
            #expect(spot.cellID == GeohashCell.encode(spot.coordinate, precision: 7))
        }
    }

    private func haversine(_ a: Coordinate, _ b: Coordinate) -> Double {
        let r = 6_371_000.0
        let lat1 = a.latitude * .pi / 180, lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let s = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return r * 2 * atan2(sqrt(s), sqrt(1 - s))
    }
}
