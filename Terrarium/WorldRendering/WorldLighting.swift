//
//  WorldLighting.swift
//  Terrarium — WorldRendering
//
//  Maps SkyState → directional sun lighting. The mapping (`keyConfig`) is a
//  pure function so it is unit-testable without RealityKit: golden hour yields a
//  warm, low-angled sun; midday a bright neutral overhead sun; night a cool,
//  dim, below-horizon sun.
//

import RealityKit
import UIKit
import simd

/// Device-independent description of a light, derived purely from SkyState.
struct LightConfig: Equatable {
    var color: SIMD3<Float>        // linear-ish rgb, 0...1
    var intensity: Float           // lumens
    var sunDirection: SIMD3<Float> // unit vector from origin toward the sun
}

enum WorldLighting {
    static let keyName = "keyLight"
    static let fillName = "fillLight"

    /// Fixed azimuth until real solar azimuth arrives (Phase 1b §B).
    private static let azimuthDegrees: Float = 35

    // MARK: - Pure mapping

    static func keyConfig(for sky: SkyState) -> LightConfig {
        let e = Float(sky.sunElevationDegrees)

        // Intensity: dim at night → bright at midday. The curve reaches a
        // workable brightness by mid-elevations so golden hour still reads.
        let dayT = smoothstep(-8, 25, e)
        let intensity = mix(420, 3400, dayT)

        // Colour: warm near the horizon, neutral high, cool below it.
        let color: SIMD3<Float>
        if e >= 25 {
            color = SIMD3(1.0, 0.98, 0.95)
        } else if e >= 0 {
            // 0º warm → 25º neutral.
            let warm = SIMD3<Float>(1.0, 0.66, 0.42)
            let neutral = SIMD3<Float>(1.0, 0.98, 0.95)
            color = mix(warm, neutral, e / 25)
        } else {
            // Below horizon: cool moonlight.
            color = SIMD3(0.55, 0.62, 0.85)
        }

        let elevation = e * .pi / 180
        let azimuth = azimuthDegrees * .pi / 180
        let sunDirection = simd_normalize(SIMD3<Float>(
            cos(elevation) * cos(azimuth),
            sin(elevation),
            cos(elevation) * sin(azimuth)
        ))

        return LightConfig(color: color, intensity: intensity, sunDirection: sunDirection)
    }

    // MARK: - RealityKit construction / application

    static func makeKeyLight() -> DirectionalLight {
        let light = DirectionalLight()
        light.name = keyName
        light.light.isRealWorldProxy = false
        return light
    }

    static func makeFillLight() -> DirectionalLight {
        let light = DirectionalLight()
        light.name = fillName
        return light
    }

    static func apply(sky: SkyState, to light: DirectionalLight) {
        let config = keyConfig(for: sky)
        light.light.intensity = config.intensity
        light.light.color = uiColor(config.color)
        // Shine from the sun toward the globe centre.
        light.look(at: .zero, from: config.sunDirection * 8, relativeTo: nil)
    }

    /// A soft, cool fill that lifts the shadow side; scales with daylight.
    static func applyFill(sky: SkyState, to light: DirectionalLight) {
        let config = keyConfig(for: sky)
        light.light.intensity = max(180, config.intensity * 0.22)
        light.light.color = uiColor(SIMD3(0.78, 0.85, 0.95))
        light.look(at: .zero, from: SIMD3<Float>(-0.6, 0.7, -0.4) * 8, relativeTo: nil)
    }

    // MARK: - Helpers

    private static func uiColor(_ c: SIMD3<Float>) -> UIColor {
        UIColor(red: CGFloat(c.x), green: CGFloat(c.y), blue: CGFloat(c.z), alpha: 1)
    }
}

// MARK: - Scalar / vector interpolation

private func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
    let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)
}

private func mix(_ a: Float, _ b: Float, _ t: Float) -> Float {
    a + (b - a) * max(0, min(1, t))
}

private func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> {
    let tt = max(0, min(1, t))
    return a + (b - a) * tt
}
