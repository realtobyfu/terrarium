//
//  PersistenceModels.swift
//  Terrarium — Domain
//
//  SwiftData @Model persistence (§G). These are the source of truth; the
//  `WorldState` / `WorldProp` value types are *derived* from them for rendering
//  (render-don't-store). SIMD coordinates are stored as two Floats since
//  SwiftData has no native SIMD support.
//
//  Relationships are kept deliberately minimal (one one-to-many) — the journal
//  links to its specimen by a plain `propID` rather than a one-to-one relation,
//  which SwiftData handles far more reliably.
//

import Foundation
import SwiftData
import simd

/// There is a single WorldStateRecord; WorldPropRecords are linked to it
/// implicitly (one world) and fetched directly rather than via a SwiftData
/// relationship — relationships trapped on this SDK, and a flat model is both
/// simpler and more robust.
@Model
final class WorldStateRecord {
    /// 0...1 — lushness / glow. This is "progress," not a score.
    var vitality: Double
    var createdAt: Date

    init(vitality: Double = 0.6, createdAt: Date = .now) {
        self.vitality = vitality
        self.createdAt = createdAt
    }
}

@Model
final class WorldPropRecord {
    var id: UUID
    var kindRaw: String
    /// (latitude, longitude) in radians.
    var latitude: Float
    var longitude: Float
    var poiRef: String?
    var createdAt: Date

    init(id: UUID = UUID(),
         kind: WorldProp.Kind,
         coordinate: SIMD2<Float>,
         poiRef: String? = nil,
         createdAt: Date = .now) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.latitude = coordinate.x
        self.longitude = coordinate.y
        self.poiRef = poiRef
        self.createdAt = createdAt
    }

    var kind: WorldProp.Kind { WorldProp.Kind(rawValue: kindRaw) ?? .flowers }

    var renderProp: WorldProp {
        WorldProp(id: id, kind: kind, sphereCoordinate: SIMD2<Float>(latitude, longitude))
    }
}

@Model
final class CompletedQuest {
    /// Idempotency key (§D). Dedup is enforced in WorldStore via a count query.
    var questId: UUID
    var verifiedAt: Date
    var verifierKindRaw: String

    init(questId: UUID, verifiedAt: Date = .now, verifierKind: VerifierKind) {
        self.questId = questId
        self.verifiedAt = verifiedAt
        self.verifierKindRaw = verifierKind.rawValue
    }
}

@Model
final class JournalEntry {
    var id: UUID
    var questId: UUID
    /// The specimen this reflection is attached to (linked by id, not relation).
    var propID: UUID
    var text: String
    var photoRef: String?
    var date: Date
    var placeName: String

    init(id: UUID = UUID(),
         questId: UUID,
         propID: UUID,
         text: String,
         photoRef: String? = nil,
         date: Date = .now,
         placeName: String) {
        self.id = id
        self.questId = questId
        self.propID = propID
        self.text = text
        self.photoRef = photoRef
        self.date = date
        self.placeName = placeName
    }
}
