//
//  WorldView.swift
//  Terrarium — WorldRendering
//
//  SwiftUI wrapper around RealityView. Renders a WorldState as the layered
//  globe and lights the scene from SkyState (sun colour/intensity/angle).
//  Surface and clouds spin at different idle rates for parallax; drag orbits
//  the whole globe. Lights + halo live at scene level so they stay sun-fixed.
//

import SwiftUI
import RealityKit

struct WorldView: View {
    let world: WorldState
    let sky: SkyState
    /// Called with a specimen's prop id when it is tapped (§E).
    var onTapSpecimen: (UUID) -> Void = { _ in }

    /// Accumulated drag committed on gesture end.
    @State private var committedYaw: Float = 0
    @State private var committedPitch: Float = 0
    @State private var dragYaw: Float = 0
    @State private var dragPitch: Float = 0

    private let surfaceSpin: Float = 0.13   // rad/s — clearly self-rotating
    private let cloudSpin: Float = 0.17      // rad/s (faster → parallax)
    private let containerName = GlobeEntityFactory.containerName

    /// The globe takes up a little less of the screen and sits slightly low.
    private let globeScale: Float = 0.8
    private let globeOffsetY: Float = -0.03

    var body: some View {
        TimelineView(.animation) { context in
            let t = Float(context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 100_000))

            RealityView { content in
                let container = GlobeEntityFactory.make(world: world)
                container.scale = SIMD3(repeating: globeScale)
                container.position = SIMD3(0, globeOffsetY, 0)
                content.add(container)

                let halo = GlobeEntityFactory.makeHalo()
                halo.scale = SIMD3(repeating: globeScale)
                halo.position = SIMD3(0, globeOffsetY, halo.position.z * globeScale)
                content.add(halo)

                content.add(WorldLighting.makeKeyLight())
                content.add(WorldLighting.makeFillLight())
            } update: { content in
                guard let container = content.entities
                    .first(where: { $0.name == containerName }) else { return }

                // User orbit on the whole globe.
                container.orientation =
                    simd_quatf(angle: clampPitch(committedPitch + dragPitch),
                               axis: SIMD3<Float>(1, 0, 0)) *
                    simd_quatf(angle: committedYaw + dragYaw,
                               axis: SIMD3<Float>(0, 1, 0))

                // Independent idle spin for parallax.
                if let surface = container.findEntity(named: GlobeEntityFactory.surfaceName) {
                    surface.orientation = simd_quatf(angle: t * surfaceSpin,
                                                     axis: SIMD3<Float>(0, 1, 0))
                }
                if let clouds = container.findEntity(named: GlobeEntityFactory.cloudsName) {
                    clouds.orientation = simd_quatf(angle: t * cloudSpin,
                                                    axis: SIMD3<Float>(0, 1, 0))
                }

                // Sun-driven lighting.
                for entity in content.entities {
                    if let key = entity as? DirectionalLight, key.name == WorldLighting.keyName {
                        WorldLighting.apply(sky: sky, to: key)
                    }
                    if let fill = entity as? DirectionalLight, fill.name == WorldLighting.fillName {
                        WorldLighting.applyFill(sky: sky, to: fill)
                    }
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragYaw = Float(value.translation.width) * 0.01
                        dragPitch = Float(value.translation.height) * 0.01
                    }
                    .onEnded { _ in
                        committedYaw += dragYaw
                        committedPitch = clampPitch(committedPitch + dragPitch)
                        dragYaw = 0
                        dragPitch = 0
                    }
            )
            .simultaneousGesture(
                SpatialTapGesture()
                    .targetedToAnyEntity()
                    .onEnded { value in
                        var entity: Entity? = value.entity
                        while let current = entity {
                            if let id = SpecimenFactory.propID(fromEntityName: current.name) {
                                onTapSpecimen(id)
                                return
                            }
                            entity = current.parent
                        }
                    }
            )
        }
    }

    private func clampPitch(_ pitch: Float) -> Float {
        let limit = Float.pi / 2 * 0.9
        return min(max(pitch, -limit), limit)
    }
}
