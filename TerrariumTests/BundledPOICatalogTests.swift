//
//  BundledPOICatalogTests.swift
//  TerrariumTests
//
//  Stream A / US-A1 + US-A3 validation.
//
//  Coverage
//  ────────
//  (a) parse(_:) succeeds on valid JSON → returns expected POIs
//  (b) parse(_:) returns [] on malformed JSON — no crash
//  (c) missing resource bundle path → all() returns [], allowedRefs() returns []
//  (d) structural validation of the shipped sf-pois.json:
//       • decodes into [POI] without errors (enum validity enforced by Codable)
//       • non-empty
//       • no duplicate poiRef
//       • all coordinates within SF bounds (lat 37.70–37.83, lon -122.52 to -122.35)
//

import Foundation
import Testing
@testable import Terrarium

// MARK: - Helpers

private let sfLatRange: ClosedRange<Double> = 37.70...37.83
private let sfLonRange: ClosedRange<Double> = -122.52 ... -122.35

// MARK: - (a) + (b): BundledPOICatalog.parse(_:)

@Suite("BundledPOICatalog.parse")
struct BundledPOICatalogParseTests {

    // Minimal valid JSON exercising every enum + field in POI (Codable contract).
    private let validJSON = """
    [
      {
        "poiRef": "poi.test-park.sf",
        "name": "Test Park",
        "category": "park",
        "neighborhood": "SoMa",
        "coordinate": { "latitude": 37.78, "longitude": -122.41 },
        "indoorOutdoor": "outdoor",
        "bestTime": ["morning", "afternoon"],
        "weatherFit": ["clear", "fog"],
        "goodFor": ["solo", "date"],
        "vibe": ["scenic", "quiet"],
        "price": "free",
        "hoursRef": null,
        "specimenKind": "tree",
        "source": "curated"
      },
      {
        "poiRef": "poi.test-cafe.sf",
        "name": "Test Cafe",
        "category": "coffee",
        "neighborhood": "Mission",
        "coordinate": { "latitude": 37.76, "longitude": -122.42 },
        "indoorOutdoor": "indoor",
        "bestTime": ["morning"],
        "weatherFit": ["rain", "cloudy"],
        "goodFor": ["solo"],
        "vibe": ["cozy"],
        "price": "$$",
        "hoursRef": "hours.test-cafe",
        "specimenKind": "building",
        "source": "curated"
      }
    ]
    """.data(using: .utf8)!

    @Test("parse returns decoded POIs on valid JSON")
    func parseValidJSON() {
        let pois = BundledPOICatalog.parse(validJSON)
        #expect(pois.count == 2)
        #expect(pois[0].poiRef == "poi.test-park.sf")
        #expect(pois[0].category == .park)
        #expect(pois[0].specimenKind == .tree)
        #expect(pois[0].price == .free)
        #expect(pois[1].poiRef == "poi.test-cafe.sf")
        #expect(pois[1].indoorOutdoor == .indoor)
        #expect(pois[1].hoursRef == "hours.test-cafe")
        #expect(pois[1].price == .medium)
    }

    @Test("parse handles all POICategory values")
    func parseAllCategories() throws {
        let categories: [String] = ["park", "coffee", "bookstore", "restaurant",
                                    "viewpoint", "market", "museum", "bar", "other"]
        for cat in categories {
            let json = """
            [{
              "poiRef": "poi.cat-test.sf", "name": "T", "category": "\(cat)",
              "neighborhood": "N",
              "coordinate": {"latitude": 37.78, "longitude": -122.41},
              "indoorOutdoor": "indoor",
              "bestTime": ["morning"], "weatherFit": ["clear"],
              "goodFor": ["solo"], "vibe": ["quiet"],
              "price": "free", "specimenKind": "tree", "source": "curated"
            }]
            """.data(using: .utf8)!
            let pois = BundledPOICatalog.parse(json)
            #expect(pois.count == 1, "category '\(cat)' should parse")
        }
    }

    @Test("parse handles all PriceTier raw values")
    func parsePriceTiers() {
        let cases: [(String, PriceTier)] = [
            ("free", .free), ("$", .low), ("$$", .medium), ("$$$", .high)
        ]
        for (raw, expected) in cases {
            let escapedRaw = raw.replacingOccurrences(of: "$", with: "$")
            let json = """
            [{
              "poiRef": "poi.price-test.sf", "name": "T", "category": "park",
              "neighborhood": "N",
              "coordinate": {"latitude": 37.78, "longitude": -122.41},
              "indoorOutdoor": "outdoor",
              "bestTime": ["afternoon"], "weatherFit": ["clear"],
              "goodFor": ["group"], "vibe": ["lively"],
              "price": "\(escapedRaw)", "specimenKind": "tree", "source": "curated"
            }]
            """.data(using: .utf8)!
            let pois = BundledPOICatalog.parse(json)
            #expect(pois.count == 1, "price '\(raw)' should parse")
            #expect(pois.first?.price == expected)
        }
    }

    @Test("parse returns empty array on completely malformed data")
    func parseMalformedData() {
        let garbage = Data([0xFF, 0xFE, 0x00, 0x01, 0x42])
        let pois = BundledPOICatalog.parse(garbage)
        #expect(pois.isEmpty)
    }

    @Test("parse returns empty array on valid JSON that is not an array of POIs")
    func parseWrongShape() {
        let wrongShape = #"{"key": "value"}"#.data(using: .utf8)!
        let pois = BundledPOICatalog.parse(wrongShape)
        #expect(pois.isEmpty)
    }

    @Test("parse returns empty array on JSON array with invalid enum value")
    func parseInvalidEnum() {
        let badEnum = """
        [{
          "poiRef": "poi.bad-cat.sf", "name": "Bad", "category": "INVALID_CATEGORY",
          "neighborhood": "N",
          "coordinate": {"latitude": 37.78, "longitude": -122.41},
          "indoorOutdoor": "outdoor",
          "bestTime": ["morning"], "weatherFit": ["clear"],
          "goodFor": ["solo"], "vibe": ["quiet"],
          "price": "free", "specimenKind": "tree", "source": "curated"
        }]
        """.data(using: .utf8)!
        let pois = BundledPOICatalog.parse(badEnum)
        #expect(pois.isEmpty)
    }

    @Test("parse returns empty array on empty data")
    func parseEmptyData() {
        let pois = BundledPOICatalog.parse(Data())
        #expect(pois.isEmpty)
    }

    @Test("allowedRefs matches the set of poiRefs from all()")
    func allowedRefsMatchesAll() {
        let data = validJSON
        let pois = BundledPOICatalog.parse(data)
        let refs = Set(pois.map(\.poiRef))
        // Build a catalog using the parsed data to verify the protocol surface.
        // We create a temp bundle by writing to a temp directory.
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let jsonURL = tmpDir.appendingPathComponent("fixture.json")
        try? data.write(to: jsonURL)
        let catalog = BundledPOICatalog(bundle: Bundle(url: tmpDir) ?? .main,
                                        resourceName: "fixture")
        #expect(catalog.allowedRefs() == refs)
    }
}

// MARK: - (c): Missing-resource path

@Suite("BundledPOICatalog missing resource")
struct BundledPOICatalogMissingResourceTests {

    @Test("all() returns empty array when resource does not exist in bundle")
    func missingResourceReturnsEmpty() {
        // Point at a bundle that has no JSON file named "nonexistent".
        let catalog = BundledPOICatalog(
            bundle: Bundle(for: BundledPOICatalogMissingResourceTests.self as AnyClass),
            resourceName: "nonexistent-pois-file-that-does-not-exist"
        )
        #expect(catalog.all().isEmpty)
    }

    @Test("allowedRefs() returns empty set when resource does not exist")
    func missingResourceAllowedRefsIsEmpty() {
        let catalog = BundledPOICatalog(
            bundle: Bundle(for: BundledPOICatalogMissingResourceTests.self as AnyClass),
            resourceName: "nonexistent-pois-file-that-does-not-exist"
        )
        #expect(catalog.allowedRefs().isEmpty)
    }
}

// MARK: - (d): Structural validation of shipped sf-pois.json

@Suite("sf-pois.json structural validation")
struct SFPOIsStructuralTests {

    // Load the shipped file through the real app bundle (.main).
    private let catalog = BundledPOICatalog()

    @Test("sf-pois.json decodes into a non-empty [POI]")
    func catalogIsNonEmpty() {
        #expect(!catalog.all().isEmpty,
                "sf-pois.json must contain at least one POI")
    }

    @Test("sf-pois.json has no duplicate poiRef")
    func noDuplicatePoiRefs() {
        let allRefs = catalog.all().map(\.poiRef)
        let uniqueRefs = Set(allRefs)
        #expect(allRefs.count == uniqueRefs.count,
                "Duplicate poiRefs found: \(findDuplicates(allRefs))")
    }

    @Test("all coordinates are within San Francisco bounds")
    func coordinatesWithinSFBounds() {
        let outOfBounds = catalog.all().filter { poi in
            !sfLatRange.contains(poi.coordinate.latitude) ||
            !sfLonRange.contains(poi.coordinate.longitude)
        }
        #expect(outOfBounds.isEmpty,
                "POIs with coordinates outside SF bounds: \(outOfBounds.map(\.poiRef))")
    }

    @Test("allowedRefs() mirrors the poiRef set from all()")
    func allowedRefsMatchesPOIs() {
        let fromAll = Set(catalog.all().map(\.poiRef))
        #expect(catalog.allowedRefs() == fromAll)
    }

    @Test("catalog covers multiple categories")
    func multipleCategories() {
        let categories = Set(catalog.all().map(\.category))
        // We ship all 9 categories; at minimum require 5 in the starter dataset.
        #expect(categories.count >= 5,
                "Expected ≥5 categories, found: \(categories.map(\.rawValue))")
    }

    @Test("catalog covers multiple neighborhoods")
    func multipleNeighborhoods() {
        let neighborhoods = Set(catalog.all().map(\.neighborhood))
        #expect(neighborhoods.count >= 8,
                "Expected ≥8 neighborhoods, found \(neighborhoods.count): \(neighborhoods)")
    }

    @Test("every POI has non-empty vibe, bestTime, weatherFit, and goodFor arrays")
    func tagArraysAreNonEmpty() {
        let violations = catalog.all().filter { poi in
            poi.vibe.isEmpty || poi.bestTime.isEmpty ||
            poi.weatherFit.isEmpty || poi.goodFor.isEmpty
        }
        #expect(violations.isEmpty,
                "POIs with empty tag arrays: \(violations.map(\.poiRef))")
    }

    // MARK: - Private helpers

    private func findDuplicates(_ items: [String]) -> [String] {
        var seen = Set<String>()
        var duplicates = [String]()
        for item in items {
            if !seen.insert(item).inserted {
                duplicates.append(item)
            }
        }
        return duplicates
    }
}
