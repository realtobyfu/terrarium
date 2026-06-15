//
//  QuestVerifier.swift
//  Terrarium — Domain
//
//  Tiered quest verification (§D). Honor is always available and offline;
//  location and photo verification require device capabilities. Verification
//  is async so real verifiers can do I/O.
//
//  US-F1: LocationVerifier is now a real geofence check. It resolves the target
//  POI coordinate from the catalog, reads the user's momentary location via
//  `LocationSessionProviding.currentCoordinate()`, and tests containment using
//  `Geofence.contains`. It degrades to honor-mode (returns true) when location
//  is unavailable — matching the `PhotoVerifier` optimistic pattern (decisions.md #6).
//

import Foundation

enum VerifierKind: String, Equatable, CaseIterable {
    case honor, location, photo
}

protocol QuestVerifier {
    var kind: VerifierKind { get }
    func verify(_ quest: Quest) async -> Bool
}

/// "I did it" — always succeeds. The baseline, always-available path.
struct HonorVerifier: QuestVerifier {
    let kind: VerifierKind = .honor
    func verify(_ quest: Quest) async -> Bool { true }
}

/// Momentary precise-location check that the user is inside the POI geofence.
///
/// Dependency injection:
///   - `catalog`  — resolves the quest's `poiRef` to a real-world `Coordinate`.
///   - `location` — provides a momentary current-location read.
///   - `radiusMeters` — geofence radius (default 80 m; sensible for SF blocks).
///
/// Degradation rule (decisions.md #6 — award optimistically like PhotoVerifier):
///   If `catalog` has no match for the `poiRef`, or `currentCoordinate()` returns
///   nil (permission denied / no active session / first launch), the verifier
///   returns `true` and stamps the record with `.honor` via the fallback. Callers
///   see the specimen grow; the `verifierKind` field distinguishes geofenced from
///   honor-mode arrivals for analytics.
struct LocationVerifier: QuestVerifier {
    let kind: VerifierKind = .location

    let catalog: POICatalogProviding
    let location: LocationSessionProviding
    /// Geofence radius in metres.
    let radiusMeters: Double

    init(catalog: POICatalogProviding,
         location: LocationSessionProviding,
         radiusMeters: Double = 80) {
        self.catalog = catalog
        self.location = location
        self.radiusMeters = radiusMeters
    }

    func verify(_ quest: Quest) async -> Bool {
        // 1. Look up the target coordinate from the catalog.
        guard let poi = catalog.all().first(where: { $0.poiRef == quest.poiRef }) else {
            // POI not in catalog — degrade to honor (optimistic award).
            return true
        }

        // 2. Read the user's current location.
        guard let userCoord = await location.currentCoordinate() else {
            // Location unavailable — degrade to honor (optimistic award).
            return true
        }

        // 3. Geofence containment test.
        return Geofence.contains(center: poi.coordinate,
                                 radius: radiusMeters,
                                 point:  userCoord)
    }
}

/// Photo capture with optional on-device Vision check; ambiguous cases escalate
/// to the backend and award optimistically.
/// // TODO(Phase 2): Vision quick-check + async backend escalation.
struct PhotoVerifier: QuestVerifier {
    let kind: VerifierKind = .photo
    func verify(_ quest: Quest) async -> Bool { true } // optimistic award
}
