//
//  QuestVerifier.swift
//  Terrarium — Domain
//
//  Tiered quest verification (§D). Honor is always available and offline;
//  location and photo verification require device capabilities and are stubbed
//  for now. Verification is async so real verifiers can do I/O.
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

/// Momentary precise-location check that you were inside the POI geofence.
/// // TODO(Phase 2): request temporary full accuracy + CLLocation geofence test.
struct LocationVerifier: QuestVerifier {
    let kind: VerifierKind = .location
    func verify(_ quest: Quest) async -> Bool { false }
}

/// Photo capture with optional on-device Vision check; ambiguous cases escalate
/// to the backend and award optimistically.
/// // TODO(Phase 2): Vision quick-check + async backend escalation.
struct PhotoVerifier: QuestVerifier {
    let kind: VerifierKind = .photo
    func verify(_ quest: Quest) async -> Bool { true } // optimistic award
}
