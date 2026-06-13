//
//  POIPlacementTests.swift
//  TerrariumTests
//
//  Deterministic POI → globe coordinate mapping (§D).
//

import Testing
import simd
@testable import Terrarium

@Suite("POI placement")
struct POIPlacementTests {

    @Test("Same POI ref always maps to the same coordinate")
    func deterministic() {
        let a = POIPlacement.sphereCoordinate(forPOIRef: "poi.ocean-beach.sf")
        let b = POIPlacement.sphereCoordinate(forPOIRef: "poi.ocean-beach.sf")
        #expect(a == b)
    }

    @Test("Different POI refs map to different coordinates")
    func distinct() {
        let a = POIPlacement.sphereCoordinate(forPOIRef: "poi.ocean-beach.sf")
        let b = POIPlacement.sphereCoordinate(forPOIRef: "poi.dolores-park.sf")
        #expect(a != b)
    }

    @Test("Coordinates stay within the placement bounds (±60° lat, ±180° lon)")
    func withinBounds() {
        for ref in ["a", "longer-poi-id", "poi.x.y.z", "café ☕️"] {
            let c = POIPlacement.sphereCoordinate(forPOIRef: ref)
            #expect(abs(c.x) <= Float.pi / 3 + 1e-5)
            #expect(abs(c.y) <= Float.pi + 1e-5)
        }
    }
}
