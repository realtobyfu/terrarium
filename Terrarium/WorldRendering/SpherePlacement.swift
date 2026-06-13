//
//  SpherePlacement.swift
//  Terrarium — WorldRendering
//
//  Pure spherical → cartesian math for placing props on the globe surface.
//  No RealityKit dependency so it is unit-testable without a device.
//

import simd

enum SpherePlacement {

    /// Convert a (latitude, longitude) in radians to a cartesian point on a
    /// sphere of the given radius. By construction ‖result‖ == radius.
    static func position(latitudeRadians lat: Float,
                         longitudeRadians lon: Float,
                         radius: Float) -> SIMD3<Float> {
        let x = radius * cos(lat) * cos(lon)
        let y = radius * sin(lat)
        let z = radius * cos(lat) * sin(lon)
        return SIMD3<Float>(x, y, z)
    }

    /// Surface position for a prop on a sphere of the given radius.
    static func position(for prop: WorldProp, radius: Float) -> SIMD3<Float> {
        position(latitudeRadians: prop.sphereCoordinate.x,
                 longitudeRadians: prop.sphereCoordinate.y,
                 radius: radius)
    }
}
