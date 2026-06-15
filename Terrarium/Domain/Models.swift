//
//  Models.swift
//  Terrarium — Domain
//
//  Pure value types. The 3D scene and sky are *renders* of this state;
//  state never lives in the scene graph. Keep everything Equatable so
//  view updates and tests stay deterministic.
//

import Foundation
import simd

/// Coarse weather classification used to modulate the sky palette.
/// `Codable` so it can ride along in the POI tag schema (`weatherFit`) and the
/// `Discovery` context snapshot (§Explore).
enum Weather: String, Equatable, CaseIterable, Codable {
    case clear, cloudy, fog, rain, snow
}

/// Everything the SkyLayer (and, later, RealityKit lighting) needs to render.
struct SkyState: Equatable {
    /// -90...90. Drives palette selection now; drives light angle in Phase 1b.
    var sunElevationDegrees: Double
    var weather: Weather
    /// e.g. "SF"
    var locationName: String
    /// e.g. "6:48pm"
    var localTimeLabel: String
}

/// A single placed object on the globe surface.
struct WorldProp: Identifiable, Equatable {
    enum Kind: String, Equatable, CaseIterable, Codable {
        case tree, building, flowers
    }

    let id: UUID
    let kind: Kind
    /// (latitude, longitude) in radians.
    let sphereCoordinate: SIMD2<Float>
    /// Appearance variant key (US-F2): "clear" (default) or "foggy".
    /// SpecimenFactory reads this to apply a subtle visual difference.
    let variant: String

    init(id: UUID = UUID(), kind: Kind, sphereCoordinate: SIMD2<Float>,
         variant: String = "clear") {
        self.id = id
        self.kind = kind
        self.sphereCoordinate = sphereCoordinate
        self.variant = variant
    }
}

/// The state of the player's little world. Later: vitality drives lushness/glow.
struct WorldState: Equatable {
    var props: [WorldProp]
    /// 0...1. Stub: 0.6.
    var vitality: Double
}

/// A suggested thing to go do. Transient/cached — never persisted (§G).
struct Quest: Identifiable, Equatable {
    let id: UUID
    let title: String
    let prompt: String
    let placeName: String
    /// Reference to the real POI this quest is grounded on (§C). Empty for the
    /// bundled offline fallback quests.
    let poiRef: String
    /// The kind of specimen this quest grows on completion (§D).
    let suggestedKind: WorldProp.Kind

    init(id: UUID = UUID(),
         title: String,
         prompt: String,
         placeName: String,
         poiRef: String = "",
         suggestedKind: WorldProp.Kind = .flowers) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.placeName = placeName
        self.poiRef = poiRef
        self.suggestedKind = suggestedKind
    }
}
