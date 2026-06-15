//
//  PointSpot.swift
//  Terrarium — Domain
//
//  Deterministic "point spots" for Drift: scattered bonus locations the user can
//  walk into to earn a jackpot of points (vs the small trickle for an ordinary new
//  cell). Pure value math — no CoreLocation, no RNG state leaking across launches:
//  spots are seeded from a coarsely-rounded center so they stay put as you move a
//  little, and reproduce exactly for tests/previews.
//

import Foundation

/// One bonus point spot: a world coordinate and the geohash cell it sits in
/// (collection is detected when a breadcrumb lights that cell).
struct PointSpot: Equatable, Identifiable {
    let id: String          // == cellID (stable, unique per cell)
    let coordinate: Coordinate
    let cellID: String
    var collected: Bool = false
}

enum PointSpotField {
    /// Deterministic bonus spots within `radiusMeters` of `center`. Seeded from the
    /// center rounded to ~hundreds of metres so small movements don't reshuffle them.
    static func spots(near center: Coordinate,
                      radiusMeters: Double = 1300,
                      count: Int = 5,
                      cellPrecision: Int = 7) -> [PointSpot] {
        let key = "\(Int((center.latitude * 100).rounded()))," +
                  "\(Int((center.longitude * 100).rounded()))"
        var rng = SpotRNG(seed: fnv1a("pointspot." + key))

        let metersPerDegLat = 111_320.0
        let metersPerDegLon = max(1, 111_320.0 * cos(center.latitude * .pi / 180))

        var seen = Set<String>()
        var result: [PointSpot] = []
        // Try a few extra so distinct cells fill `count` even if some collide.
        for _ in 0..<(count * 3) where result.count < count {
            let r = (0.30 + 0.70 * rng.unitInterval()) * radiusMeters
            let theta = rng.unitInterval() * 2 * .pi
            let dLat = (r * sin(theta)) / metersPerDegLat
            let dLon = (r * cos(theta)) / metersPerDegLon
            let coord = Coordinate(latitude: center.latitude + dLat,
                                   longitude: center.longitude + dLon)
            let cell = GeohashCell.encode(coord, precision: cellPrecision)
            guard !seen.contains(cell) else { continue }
            seen.insert(cell)
            result.append(PointSpot(id: cell, coordinate: coord, cellID: cell))
        }
        return result
    }

    // FNV-1a — same discipline as POIPlacement / AnchorViewModel (no Swift Hasher).
    private static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 { hash ^= UInt64(byte); hash = hash &* 0x100000001b3 }
        return hash
    }
}

/// Tiny deterministic generator, self-contained so Domain stays dependency-free.
private struct SpotRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
    mutating func unitInterval() -> Double { Double(next() >> 11) * (1.0 / 9007199254740992.0) }
}
