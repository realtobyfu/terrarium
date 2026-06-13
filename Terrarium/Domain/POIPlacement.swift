//
//  POIPlacement.swift
//  Terrarium — Domain
//
//  Deterministic mapping from a POI reference to a globe surface coordinate, so
//  the same place always grows its specimen in the same spot (§D). Pure and
//  stable across launches (uses a fixed FNV-1a hash, not Swift's randomized
//  Hasher).
//

import simd

enum POIPlacement {

    /// (latitude, longitude) in radians for a given POI reference.
    /// Latitude is biased toward mid-latitudes so specimens land on plausible
    /// "ground" rather than clustering at the poles.
    static func sphereCoordinate(forPOIRef ref: String) -> SIMD2<Float> {
        let h = fnv1a(ref)
        let hi = Float(h >> 32) / Float(UInt32.max)          // 0...1
        let lo = Float(h & 0xFFFF_FFFF) / Float(UInt32.max)  // 0...1

        let latitude = (hi * 2 - 1) * (.pi / 3)   // ±60°
        let longitude = (lo * 2 - 1) * .pi        // ±180°
        return SIMD2<Float>(latitude, longitude)
    }

    /// FNV-1a 64-bit over the string's UTF-8 bytes. Deterministic.
    private static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}
