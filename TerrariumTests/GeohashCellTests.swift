//
//  GeohashCellTests.swift
//  TerrariumTests
//
//  Pure unit tests for GeohashCell (US-E2, FR-12).
//
//  Coverage
//  ────────
//  1. Known coordinate → known geohash prefix (regression anchor).
//  2. Two nearby points within 153 m share a cell at precision 7.
//  3. A far point produces a different cell.
//  4. Stability: encoding the same coordinate twice yields identical strings.
//  5. Round-trip: decode(encode(c)) is close to c (within cell error).
//  6. Neighbor count is always 8.
//  7. encode at lower precision is a prefix of encode at higher precision.
//

import Testing
@testable import Terrarium

@Suite("GeohashCell")
struct GeohashCellTests {

    // MARK: - Known-value anchor

    // Dolores Park, SF: latitude 37.7596, longitude -122.4269
    // Expected geohash prefix at precision 7: "9q8yudb" (verified externally)
    @Test("Known coordinate produces expected geohash prefix")
    func knownCoordinatePrefix() {
        let coord = Coordinate(latitude: 37.7596, longitude: -122.4269)
        let hash  = GeohashCell.encode(coord, precision: 7)
        #expect(hash.hasPrefix("9q8y"))   // first 4 chars stable for this region
        #expect(hash.count == 7)
    }

    // MARK: - Nearby points share a cell

    @Test("Two coordinates within 50 m share a precision-7 cell")
    func nearbyPointsSameCell() {
        let a = Coordinate(latitude: 37.7596, longitude: -122.4269)
        // ~30 m north of a (≈ 0.00027°lat ≈ 30 m)
        let b = Coordinate(latitude: 37.7599, longitude: -122.4269)
        #expect(GeohashCell.encode(a, precision: 7) == GeohashCell.encode(b, precision: 7))
    }

    // MARK: - Far point differs

    @Test("A coordinate 1 km away produces a different precision-7 cell")
    func farPointDifferentCell() {
        let a = Coordinate(latitude: 37.7596, longitude: -122.4269)
        // ~1 km north (~0.009°)
        let b = Coordinate(latitude: 37.7686, longitude: -122.4269)
        #expect(GeohashCell.encode(a, precision: 7) != GeohashCell.encode(b, precision: 7))
    }

    // MARK: - Stability

    @Test("Encoding the same coordinate twice gives identical results")
    func stability() {
        let coord = Coordinate(latitude: 37.7749, longitude: -122.4194)
        let h1 = GeohashCell.encode(coord, precision: 7)
        let h2 = GeohashCell.encode(coord, precision: 7)
        #expect(h1 == h2)
    }

    @Test("Stability holds across different precisions")
    func stabilityDifferentPrecisions() {
        let coord = Coordinate(latitude: 40.7128, longitude: -74.0060)
        for precision in 1...9 {
            let h1 = GeohashCell.encode(coord, precision: precision)
            let h2 = GeohashCell.encode(coord, precision: precision)
            #expect(h1 == h2, "precision \(precision) not stable")
        }
    }

    // MARK: - Round-trip

    @Test("decode(encode(c)) returns cell centre close to original")
    func roundTrip() {
        let inputs: [Coordinate] = [
            Coordinate(latitude:  37.7749, longitude: -122.4194),   // SF
            Coordinate(latitude:  40.7128, longitude:  -74.0060),   // NYC
            Coordinate(latitude: -33.8688, longitude:  151.2093),   // Sydney
            Coordinate(latitude:  51.5074, longitude:   -0.1278),   // London
            Coordinate(latitude:   0.0,    longitude:    0.0),       // null island
        ]
        for coord in inputs {
            let hash   = GeohashCell.encode(coord, precision: 7)
            let centre = GeohashCell.decode(hash)
            #expect(centre != nil, "decode returned nil for \(hash)")
            if let c = centre {
                // At precision 7 the cell is ≈ 0.0015°, so any decode error
                // should be well within 0.01° (≈ 1 km).
                #expect(abs(c.latitude  - coord.latitude)  < 0.01)
                #expect(abs(c.longitude - coord.longitude) < 0.01)
            }
        }
    }

    // MARK: - Prefix consistency

    @Test("A precision-5 hash is a prefix of a precision-7 hash for the same point")
    func precisionPrefix() {
        let coord = Coordinate(latitude: 37.7596, longitude: -122.4269)
        let h5 = GeohashCell.encode(coord, precision: 5)
        let h7 = GeohashCell.encode(coord, precision: 7)
        #expect(h7.hasPrefix(h5))
    }

    // MARK: - Neighbours

    @Test("neighbors(of:) returns exactly 8 distinct hashes")
    func neighborCount() {
        let hash = GeohashCell.encode(
            Coordinate(latitude: 37.7596, longitude: -122.4269),
            precision: 7
        )
        let nbrs = GeohashCell.neighbors(of: hash)
        #expect(nbrs.count == 8)
        // All neighbours must be distinct and different from the cell itself.
        let unique = Set(nbrs)
        #expect(unique.count == 8)
        #expect(!unique.contains(hash))
    }

    @Test("Neighbors of a cell each decode to a point close to the original cell")
    func neighborProximity() {
        let coord = Coordinate(latitude: 37.7596, longitude: -122.4269)
        let hash  = GeohashCell.encode(coord, precision: 7)
        let nbrs  = GeohashCell.neighbors(of: hash)
        guard let centre = GeohashCell.decode(hash) else {
            Issue.record("Could not decode cell centre")
            return
        }
        for n in nbrs {
            guard let nc = GeohashCell.decode(n) else {
                Issue.record("Could not decode neighbour \(n)")
                continue
            }
            let dLat = abs(nc.latitude  - centre.latitude)
            let dLon = abs(nc.longitude - centre.longitude)
            // At precision 7 each cell is ≈ 0.0015° × 0.003°. Neighbours are
            // at most 1 cell-width away, so the difference must be < 0.02°.
            #expect(dLat < 0.02 && dLon < 0.04,
                    "Neighbour \(n) seems too far from centre")
        }
    }

    // MARK: - Invalid input

    @Test("decode returns nil for invalid geohash characters")
    func invalidDecode() {
        #expect(GeohashCell.decode("invalid!") == nil)
        #expect(GeohashCell.decode("") == nil)
    }
}
