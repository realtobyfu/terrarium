//
//  GeohashCell.swift
//  Terrarium — Domain
//
//  Pure, zero-dependency geohash encoder / decoder for fog-of-war cell math
//  (FR-12, US-E2, decisions §1: geohash precision 7 ≈ 153 × 153 m cells).
//
//  Design choices
//  ──────────────
//  • Standard base32 alphabet (not extended-hex). Compatible with every other
//    geohash library, so cell ids are portable strings.
//  • Precision 7 is the default (the locked decision). The encode/decode pair
//    is symmetric: decode(encode(c, 7)) returns the *cell centre*, not the
//    original coordinate. That's intentional — it is the canonical canonical
//    position for rendering a cell polygon.
//  • Neighbours (8-directional) are computed algebraically so the fog-of-war
//    map can find adjacent cells without encoding/decoding round-trips.
//  • All entry points are pure static functions: no stored state, no RNG, no
//    clock. Fully deterministic and safe to call from any isolation context.
//
//  Stability guarantee
//  ───────────────────
//  The algorithm uses only arithmetic on the geohash bit interleaving
//  and the fixed base32 character set — both of which are independent of
//  Swift's randomised `Hasher`. The same coordinate always produces the same
//  String, making cell ids safe to persist in the on-device store (FR-8).
//

import Foundation

// MARK: - GeohashCell

/// Namespace for geohash cell operations.
enum GeohashCell {

    // -------------------------------------------------------------------------
    // MARK: Base32 alphabet (standard)
    // -------------------------------------------------------------------------

    private static let base32: [Character] =
        Array("0123456789bcdefghjkmnpqrstuvwxyz")

    private static let base32Index: [Character: Int] = {
        var m = [Character: Int](minimumCapacity: 32)
        for (i, c) in base32.enumerated() { m[c] = i }
        return m
    }()

    // -------------------------------------------------------------------------
    // MARK: Public API
    // -------------------------------------------------------------------------

    /// Encodes a coordinate to a geohash string of the given precision.
    ///
    /// - Parameters:
    ///   - coord:     Real-world coordinate in degrees.
    ///   - precision: Number of base32 characters (1–12). Default is **7**
    ///                (≈ 153 × 153 m), the locked pilot decision.
    /// - Returns:     A lowercase geohash string, e.g. `"9q8yy7k"`.
    static func encode(_ coord: Coordinate, precision: Int = 7) -> String {
        assert((1...12).contains(precision), "precision must be 1–12")

        var lat = (-90.0, 90.0)    // (min, max)
        var lon = (-180.0, 180.0)  // (min, max)

        var isLon = true           // geohash alternates lon/lat bits
        var bits  = 0
        var bitsAccumulated = 0
        var result = ""
        result.reserveCapacity(precision)

        let totalBits = precision * 5

        for _ in 0 ..< totalBits {
            if isLon {
                let mid = (lon.0 + lon.1) / 2
                if coord.longitude >= mid {
                    bits = (bits << 1) | 1
                    lon.0 = mid
                } else {
                    bits = bits << 1
                    lon.1 = mid
                }
            } else {
                let mid = (lat.0 + lat.1) / 2
                if coord.latitude >= mid {
                    bits = (bits << 1) | 1
                    lat.0 = mid
                } else {
                    bits = bits << 1
                    lat.1 = mid
                }
            }
            isLon.toggle()
            bitsAccumulated += 1
            if bitsAccumulated == 5 {
                result.append(base32[bits])
                bits = 0
                bitsAccumulated = 0
            }
        }
        return result
    }

    /// Decodes a geohash to the **centre** coordinate of its cell.
    ///
    /// - Returns: `nil` if the string is empty or contains characters outside
    ///            the base32 alphabet.
    static func decode(_ geohash: String) -> Coordinate? {
        guard !geohash.isEmpty else { return nil }
        var lat = (-90.0, 90.0)
        var lon = (-180.0, 180.0)
        var isLon = true

        for ch in geohash.lowercased() {
            guard let value = base32Index[ch] else { return nil }
            for shift in stride(from: 4, through: 0, by: -1) {
                let bit = (value >> shift) & 1
                if isLon {
                    let mid = (lon.0 + lon.1) / 2
                    if bit == 1 { lon.0 = mid } else { lon.1 = mid }
                } else {
                    let mid = (lat.0 + lat.1) / 2
                    if bit == 1 { lat.0 = mid } else { lat.1 = mid }
                }
                isLon.toggle()
            }
        }
        return Coordinate(
            latitude:  (lat.0 + lat.1) / 2,
            longitude: (lon.0 + lon.1) / 2
        )
    }

    /// Returns the bounding box (SW corner, NE corner) for a geohash string.
    static func bounds(_ geohash: String) -> (sw: Coordinate, ne: Coordinate)? {
        guard !geohash.isEmpty else { return nil }
        var lat = (-90.0, 90.0)
        var lon = (-180.0, 180.0)
        var isLon = true

        for ch in geohash.lowercased() {
            guard let value = base32Index[ch] else { return nil }
            for shift in stride(from: 4, through: 0, by: -1) {
                let bit = (value >> shift) & 1
                if isLon {
                    let mid = (lon.0 + lon.1) / 2
                    if bit == 1 { lon.0 = mid } else { lon.1 = mid }
                } else {
                    let mid = (lat.0 + lat.1) / 2
                    if bit == 1 { lat.0 = mid } else { lat.1 = mid }
                }
                isLon.toggle()
            }
        }
        return (
            sw: Coordinate(latitude: lat.0, longitude: lon.0),
            ne: Coordinate(latitude: lat.1, longitude: lon.1)
        )
    }

    /// Returns all 8 orthogonal + diagonal neighbours of a geohash cell.
    ///
    /// Neighbour computation works by decoding the cell centre, nudging by a
    /// fraction of the cell size in each cardinal direction, and re-encoding.
    /// This is O(8 × precision) and plenty fast for fog-of-war updates.
    static func neighbors(of geohash: String, precision: Int? = nil) -> [String] {
        let p = precision ?? geohash.count
        guard let centre = decode(geohash),
              let b = bounds(geohash) else { return [] }

        let latStep = (b.ne.latitude  - b.sw.latitude)  * 0.6
        let lonStep = (b.ne.longitude - b.sw.longitude) * 0.6

        let offsets: [(Double, Double)] = [
            ( latStep,  0),        // N
            (-latStep,  0),        // S
            ( 0,        lonStep),  // E
            ( 0,       -lonStep),  // W
            ( latStep,  lonStep),  // NE
            ( latStep, -lonStep),  // NW
            (-latStep,  lonStep),  // SE
            (-latStep, -lonStep),  // SW
        ]
        return offsets.map { (dLat, dLon) in
            encode(
                Coordinate(latitude:  centre.latitude  + dLat,
                           longitude: centre.longitude + dLon),
                precision: p
            )
        }
    }
}
