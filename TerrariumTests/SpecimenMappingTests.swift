//
//  SpecimenMappingTests.swift
//  TerrariumTests
//
//  Unit tests for the pure SpecimenMapping helpers (US-F2, FR-21, FR-22).
//  All inputs are static values — no device dependency.
//

import Testing
import Foundation
@testable import Terrarium

@Suite("SpecimenMapping")
struct SpecimenMappingTests {

    // MARK: - Category → kind (FR-21)

    @Test("park maps to tree")
    func parkMapsToTree() {
        #expect(SpecimenMapping.kind(for: .park) == .tree)
    }

    @Test("viewpoint maps to tree")
    func viewpointMapsToTree() {
        #expect(SpecimenMapping.kind(for: .viewpoint) == .tree)
    }

    @Test("coffee maps to building")
    func coffeeMapsToBuilding() {
        #expect(SpecimenMapping.kind(for: .coffee) == .building)
    }

    @Test("restaurant maps to building")
    func restaurantMapsToBuilding() {
        #expect(SpecimenMapping.kind(for: .restaurant) == .building)
    }

    @Test("bookstore maps to building")
    func bookstoreMapsToBuilding() {
        #expect(SpecimenMapping.kind(for: .bookstore) == .building)
    }

    @Test("market maps to building")
    func marketMapsToBuilding() {
        #expect(SpecimenMapping.kind(for: .market) == .building)
    }

    @Test("museum maps to building")
    func museumMapsToBuilding() {
        #expect(SpecimenMapping.kind(for: .museum) == .building)
    }

    @Test("bar maps to building")
    func barMapsToBuilding() {
        #expect(SpecimenMapping.kind(for: .bar) == .building)
    }

    @Test("other maps to flowers")
    func otherMapsToFlowers() {
        #expect(SpecimenMapping.kind(for: .other) == .flowers)
    }

    @Test("All categories produce a valid kind")
    func allCategoriesProduceValidKind() {
        let validKinds: Set<WorldProp.Kind> = [.tree, .building, .flowers]
        for category in POICategory.allCases {
            let kind = SpecimenMapping.kind(for: category)
            #expect(validKinds.contains(kind),
                    "Category \(category) produced unexpected kind \(kind)")
        }
    }

    // MARK: - Weather → variant (decisions.md #5)

    @Test("fog produces foggy variant")
    func fogProducesFoggyVariant() {
        #expect(SpecimenMapping.variant(for: .fog) == "foggy")
    }

    @Test("clear produces clear variant")
    func clearProducesClearVariant() {
        #expect(SpecimenMapping.variant(for: .clear) == "clear")
    }

    @Test("cloudy produces clear variant")
    func cloudyProducesClearVariant() {
        #expect(SpecimenMapping.variant(for: .cloudy) == "clear")
    }

    @Test("rain produces clear variant")
    func rainProducesClearVariant() {
        #expect(SpecimenMapping.variant(for: .rain) == "clear")
    }

    @Test("snow produces clear variant")
    func snowProducesClearVariant() {
        #expect(SpecimenMapping.variant(for: .snow) == "clear")
    }

    @Test("Only fog maps to foggy; all others map to clear")
    func onlyFogIsFoggy() {
        for weather in Weather.allCases {
            let variant = SpecimenMapping.variant(for: weather)
            if weather == .fog {
                #expect(variant == "foggy",
                        "Expected 'foggy' for .fog but got '\(variant)'")
            } else {
                #expect(variant == "clear",
                        "Expected 'clear' for .\(weather) but got '\(variant)'")
            }
        }
    }
}
