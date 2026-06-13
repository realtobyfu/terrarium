//
//  GlobePlacementTests.swift
//  TerrariumTests
//
//  Pure-math placement + entity-count checks. No RealityView is instantiated.
//

import Testing
import simd
@testable import Terrarium

@Suite("Globe placement")
struct GlobePlacementTests {

    @Test("lat/long → cartesian lands on the sphere of the given radius",
          arguments: [Float(0.5), 1.0, 2.0])
    func positionOnSphere(radius: Float) {
        let coords: [SIMD2<Float>] = [
            SIMD2(0, 0),
            SIMD2(.pi / 4, .pi / 3),
            SIMD2(-0.3, 0.85),
            SIMD2(.pi / 2, -1.2),   // north pole-ish
        ]
        for c in coords {
            let pos = SpherePlacement.position(latitudeRadians: c.x,
                                               longitudeRadians: c.y,
                                               radius: radius)
            #expect(abs(simd_length(pos) - radius) < 1e-4)
        }
    }

    @Test("Equator + zero longitude maps to +X")
    func equatorZeroLongitude() {
        let pos = SpherePlacement.position(latitudeRadians: 0,
                                           longitudeRadians: 0,
                                           radius: 1)
        #expect(abs(pos.x - 1) < 1e-5)
        #expect(abs(pos.y) < 1e-5)
        #expect(abs(pos.z) < 1e-5)
    }

    @Test("A WorldState with N props yields N placements, kinds preserved",
          arguments: [0, 1, 3, 5])
    func propPlacementCount(n: Int) {
        let props = (0..<n).map { i in
            WorldProp(kind: .tree,
                      sphereCoordinate: SIMD2<Float>(Float(i) * 0.1, Float(i) * 0.2))
        }
        let world = WorldState(props: props, vitality: 0.6)
        let placements = GlobeEntityFactory.propPlacements(world: world)
        #expect(placements.count == n)
        #expect(placements.allSatisfy { $0.kind == .tree })
    }

    @Test("Props sit just proud of the ocean surface")
    func propsAboveSurface() {
        let world = WorldState(
            props: [
                WorldProp(kind: .flowers, sphereCoordinate: SIMD2(0.2, 0.4)),
                WorldProp(kind: .building, sphereCoordinate: SIMD2(-0.2, 0.5)),
            ],
            vitality: 0.6
        )
        for placement in GlobeEntityFactory.propPlacements(world: world) {
            let r = simd_length(placement.position)
            #expect(r > GlobeEntityFactory.globeRadius)
            #expect(abs(r - GlobeEntityFactory.propRadius) < 1e-4)
        }
    }
}
