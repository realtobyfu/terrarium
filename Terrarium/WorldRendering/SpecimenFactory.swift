//
//  SpecimenFactory.swift
//  Terrarium — WorldRendering
//
//  Builds small low-poly specimen models (tree / building / flowers) from
//  primitive meshes, placed on the globe surface and oriented to the surface
//  normal so they stand upright. Each gets a soft contact shadow.
//

import RealityKit
import UIKit

enum SpecimenFactory {

    /// A planted specimen: model container positioned on the surface and rotated
    /// so its local +Y points along the surface normal.
    /// Prefix used to encode the prop id in the entity name (for tap routing).
    static let namePrefix = "specimen."

    static func make(_ prop: WorldProp, surfaceRadius: Float) -> Entity {
        let normal = simd_normalize(SpherePlacement.position(for: prop, radius: 1))
        let model = makeModel(prop.kind, variant: prop.variant)
        model.position = normal * surfaceRadius
        // Align the model's up (+Y) with the outward surface normal.
        model.orientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: normal)
        // Encode the prop id so a tap can be routed back to its journal entry.
        model.name = namePrefix + prop.id.uuidString
        // Make the specimen tappable.
        model.components.set(InputTargetComponent())
        model.components.set(CollisionComponent(
            shapes: [.generateBox(size: SIMD3<Float>(0.07, 0.09, 0.07))]
        ))
        return model
    }

    /// Extract a prop id from a specimen entity name, if it is one.
    static func propID(fromEntityName name: String) -> UUID? {
        guard name.hasPrefix(namePrefix) else { return nil }
        return UUID(uuidString: String(name.dropFirst(namePrefix.count)))
    }

    // MARK: - Models (local space: base at y = 0, growing +Y)

    /// Builds the specimen model, applying a variant-appropriate colour shift.
    ///
    /// US-F2 variant rendering (no new geometry):
    /// - `"foggy"`: desaturated palette (HSB saturation reduced ~40%, luminance
    ///   raised ~15%) mimicking Karl the Fog's grey-soft aesthetic.
    /// - `"clear"` (default): vivid original palette.
    ///
    /// The `isFoggy` flag is threaded into helper factories rather than patching
    /// geometry after the fact, keeping the child entities immutable once built.
    private static func makeModel(_ kind: WorldProp.Kind, variant: String = "clear") -> Entity {
        let isFoggy = variant == "foggy"
        let container = Entity()
        container.addChild(contactShadow(radius: 0.05, isFoggy: isFoggy))
        // A little patch of land so each specimen stands on ground; clustered
        // specimens' patches overlap and read as one continuous landmass.
        container.addChild(landPatch(isFoggy: isFoggy))
        switch kind {
        case .tree:     buildTree(into: container, isFoggy: isFoggy)
        case .building: buildBuilding(into: container, isFoggy: isFoggy)
        case .flowers:  buildFlowers(into: container, isFoggy: isFoggy)
        }
        return container
    }

    // MARK: - Fog desaturation helper

    /// Returns a fog-shifted version of `color` when `isFoggy` is true:
    /// saturation reduced by 40%, brightness raised by 15%, alpha preserved.
    /// No-op when `isFoggy` is false so clear specimens stay vivid.
    private static func fogged(_ color: UIColor, isFoggy: Bool) -> UIColor {
        guard isFoggy else { return color }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h,
                       saturation: max(0, s * 0.60),
                       brightness: min(1, b * 1.15),
                       alpha: a)
    }

    /// Sandy-rimmed green ground disc sitting on the ocean surface.
    private static func landPatch(isFoggy: Bool = false) -> Entity {
        let patch = Entity()
        let coast = ModelEntity(
            mesh: .generateSphere(radius: 0.062),
            materials: [SimpleMaterial(
                color: fogged(UIColor(red: 0.918, green: 0.827, blue: 0.627, alpha: 1),
                              isFoggy: isFoggy), // sandy
                roughness: 0.95, isMetallic: false)]
        )
        coast.scale = SIMD3(1, 0.10, 1)
        coast.position.y = 0.001

        let grass = ModelEntity(
            mesh: .generateSphere(radius: 0.052),
            materials: [SimpleMaterial(
                color: fogged(UIColor(red: 0.486, green: 0.753, blue: 0.541, alpha: 1),
                              isFoggy: isFoggy), // sage #7CC08A
                roughness: 0.9, isMetallic: false)]
        )
        grass.scale = SIMD3(1, 0.12, 1)
        grass.position.y = 0.006

        patch.addChild(coast)
        patch.addChild(grass)
        return patch
    }

    private static func buildTree(into c: Entity, isFoggy: Bool = false) {
        let trunk = box(size: SIMD3(0.012, 0.035, 0.012),
                        color: fogged(UIColor(red: 0.45, green: 0.32, blue: 0.22, alpha: 1),
                                      isFoggy: isFoggy))
        trunk.position.y = 0.0175
        // Two stacked foliage spheres for a rounded canopy.
        let lower = sphere(radius: 0.028,
                           color: fogged(UIColor(red: 0.30, green: 0.62, blue: 0.36, alpha: 1),
                                         isFoggy: isFoggy))
        lower.position.y = 0.05
        let upper = sphere(radius: 0.020,
                           color: fogged(UIColor(red: 0.38, green: 0.70, blue: 0.42, alpha: 1),
                                         isFoggy: isFoggy))
        upper.position.y = 0.072
        c.addChild(trunk); c.addChild(lower); c.addChild(upper)
    }

    private static func buildBuilding(into c: Entity, isFoggy: Bool = false) {
        let body = box(size: SIMD3(0.034, 0.05, 0.034),
                       color: fogged(UIColor(red: 0.86, green: 0.79, blue: 0.66, alpha: 1),
                                     isFoggy: isFoggy))
        body.position.y = 0.025
        let roof = box(size: SIMD3(0.04, 0.014, 0.04),
                       color: fogged(UIColor(red: 0.74, green: 0.46, blue: 0.40, alpha: 1),
                                     isFoggy: isFoggy))
        roof.position.y = 0.057
        c.addChild(body); c.addChild(roof)
    }

    private static func buildFlowers(into c: Entity, isFoggy: Bool = false) {
        let mound = box(size: SIMD3(0.05, 0.01, 0.05),
                        color: fogged(UIColor(red: 0.36, green: 0.62, blue: 0.38, alpha: 1),
                                      isFoggy: isFoggy))
        mound.position.y = 0.005
        c.addChild(mound)
        let blooms: [(SIMD3<Float>, UIColor)] = [
            (SIMD3(-0.012, 0.022, 0.006), UIColor(red: 0.93, green: 0.45, blue: 0.62, alpha: 1)),
            (SIMD3(0.010, 0.026, -0.008), UIColor(red: 0.97, green: 0.78, blue: 0.35, alpha: 1)),
            (SIMD3(0.004, 0.020, 0.014), UIColor(red: 0.78, green: 0.55, blue: 0.90, alpha: 1)),
        ]
        for (pos, color) in blooms {
            let stem = box(size: SIMD3(0.004, 0.018, 0.004),
                           color: fogged(UIColor(red: 0.30, green: 0.55, blue: 0.32, alpha: 1),
                                         isFoggy: isFoggy))
            stem.position = SIMD3(pos.x, pos.y - 0.012, pos.z)
            let bloom = sphere(radius: 0.008, color: fogged(color, isFoggy: isFoggy))
            bloom.position = pos
            c.addChild(stem); c.addChild(bloom)
        }
    }

    // MARK: - Primitives

    private static func box(size: SIMD3<Float>, color: UIColor) -> ModelEntity {
        ModelEntity(mesh: .generateBox(size: size, cornerRadius: 0.002),
                    materials: [SimpleMaterial(color: color, roughness: 0.85, isMetallic: false)])
    }

    private static func sphere(radius: Float, color: UIColor) -> ModelEntity {
        ModelEntity(mesh: .generateSphere(radius: radius),
                    materials: [SimpleMaterial(color: color, roughness: 0.8, isMetallic: false)])
    }

    /// A flattened dark translucent disc sitting at the base.
    /// For foggy variants the shadow is slightly lighter (less contrast).
    private static func contactShadow(radius: Float, isFoggy: Bool = false) -> ModelEntity {
        let alpha: CGFloat = isFoggy ? 0.13 : 0.22
        var material = UnlitMaterial(color: UIColor(white: 0, alpha: alpha))
        material.blending = .transparent(opacity: .init(floatLiteral: Float(alpha)))
        let shadow = ModelEntity(mesh: .generateSphere(radius: radius),
                                 materials: [material])
        shadow.scale = SIMD3(1, 0.08, 1)  // squash into a disc
        shadow.position.y = 0.001
        return shadow
    }
}
