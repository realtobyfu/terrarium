//
//  GlobeEntityFactory.swift
//  Terrarium — WorldRendering
//
//  Builds the stylized Earth as layered entities (render-don't-store):
//    • surface  — textured sphere (teal ocean / sage continents / sandy coast)
//    • specimens— low-poly models planted on land, children of the surface
//    • clouds   — wispy sphere at ×1.02, spun independently for parallax
//    • halo     — radial cyan atmosphere glow (built separately, see makeHalo)
//
//  Pure placement helpers (propPlacements / SpherePlacement) stay free of
//  RealityKit so they remain unit-testable without a rendering context.
//

import RealityKit
import UIKit

enum GlobeEntityFactory {

    /// Radius of the globe surface in scene units.
    static let globeRadius: Float = 0.5
    /// Cloud shell sits just above the surface.
    static let cloudScale: Float = 1.02
    /// Atmosphere halo billboard half-extent relative to globe radius.
    static let haloScale: Float = 1.5
    /// Specimens sit just proud of the surface (radius * 1.005).
    static let propRadius: Float = globeRadius * 1.005

    // Named sublayers so WorldView can find them in its update loop.
    static let containerName = "globeContainer"
    static let surfaceName = "surface"
    static let cloudsName = "clouds"
    static let haloName = "halo"

    // MARK: - Assembly

    /// Surface sphere (with planted specimens) + cloud shell, wrapped in a
    /// container. The halo is added at scene level by WorldView, not here.
    static func make(world: WorldState) -> Entity {
        let container = Entity()
        container.name = containerName

        let surface = makeSurface(vitality: world.vitality)
        for prop in world.props {
            surface.addChild(SpecimenFactory.make(prop, surfaceRadius: propRadius))
        }
        container.addChild(surface)
        container.addChild(makeClouds())
        return container
    }

    private static func makeSurface(vitality: Double) -> ModelEntity {
        let surface = ModelEntity(
            mesh: .generateSphere(radius: globeRadius),
            materials: [surfaceMaterial(vitality: vitality)]
        )
        surface.name = surfaceName
        return surface
    }

    private static func makeClouds() -> ModelEntity {
        let clouds = ModelEntity(
            mesh: .generateSphere(radius: globeRadius * cloudScale),
            materials: [cloudMaterial()]
        )
        clouds.name = cloudsName
        return clouds
    }

    /// Camera-facing radial-glow quad standing in for a Fresnel atmosphere rim.
    /// Lives at scene level (behind the globe) so it neither spins nor orbits.
    static func makeHalo() -> ModelEntity {
        let size = globeRadius * 2 * haloScale
        let halo = ModelEntity(
            mesh: .generatePlane(width: size, height: size),
            materials: [haloMaterial()]
        )
        halo.name = haloName
        halo.position.z = -globeRadius * 0.4   // sit behind the globe's centre
        return halo
    }

    // MARK: - Materials

    private static func surfaceMaterial(vitality: Double = 0.6) -> Material {
        if let texture = GlobeTextureFactory.surface {
            var material = PhysicallyBasedMaterial()
            material.baseColor = .init(tint: .white, texture: .init(texture))
            material.roughness = 0.75
            material.metallic = 0.0
            // Lushness: a faint living glow that grows with vitality (points), so a
            // well-explored world reads as more alive. Kept subtle so oceans don't
            // wash out. (Reflected at globe (re)build; rebuilds when WorldState changes.)
            let glow = UIColor(red: 0.50, green: 0.82, blue: 0.62, alpha: 1)
            material.emissiveColor = .init(color: glow)
            material.emissiveIntensity = Float(max(0, min(1, vitality))) * 0.35
            return material
        }
        // Fallback: flat ocean tint if texture generation failed.
        return SimpleMaterial(
            color: UIColor(red: 0.329, green: 0.667, blue: 0.788, alpha: 1),
            roughness: 0.8, isMetallic: false
        )
    }

    private static func cloudMaterial() -> Material {
        guard let texture = GlobeTextureFactory.clouds else {
            var clear = UnlitMaterial(color: .clear)
            clear.blending = .transparent(opacity: 0.0)
            return clear
        }
        var material = UnlitMaterial(color: .white)
        material.color = .init(tint: .white, texture: .init(texture))
        material.blending = .transparent(opacity: 0.5)
        return material
    }

    private static func haloMaterial() -> Material {
        guard let texture = GlobeTextureFactory.halo else {
            var clear = UnlitMaterial(color: .clear)
            clear.blending = .transparent(opacity: 0.0)
            return clear
        }
        var material = UnlitMaterial(color: .white)
        material.color = .init(tint: .white, texture: .init(texture))
        material.blending = .transparent(opacity: 1.0)
        return material
    }

    // MARK: - Pure placement (unit-tested; no RealityKit entities)

    struct PropPlacement: Equatable {
        let kind: WorldProp.Kind
        let position: SIMD3<Float>
    }

    static func propPlacements(world: WorldState) -> [PropPlacement] {
        world.props.map { prop in
            PropPlacement(kind: prop.kind,
                          position: SpherePlacement.position(for: prop, radius: propRadius))
        }
    }
}
