//
//  ScenicArtBand.swift
//  Terrarium — Prototypes
//
//  Generative "painterly meadow" art for the discovery hero card. The pilot POI
//  catalog has no photography (see explore-design-spec §10), so instead of a flat
//  placeholder we render an impressionistic `MeshGradient` keyed to the place's
//  category, washed by the current weather, with soft deterministic bokeh so the
//  same place always looks the same. This is the "magical, oil-painting" feel the
//  mockup leans on — no asset pipeline required.
//
//  Pure & deterministic: seeded from `poiRef` so previews and re-rolls are stable.
//

import SwiftUI

// MARK: - ScenicArtBand

struct ScenicArtBand: View {
    let poiRef: String
    let category: POICategory
    let weather: Weather

    private var family: ScenicFamily { ScenicFamily(category: category) }

    var body: some View {
        ZStack {
            MeshGradient(
                width: 3,
                height: 3,
                points: ScenicArtBand.meshPoints(seed: Scenic.seed(poiRef)),
                colors: family.meshColors,
                smoothsColors: true
            )

            // Soft bokeh "wildflowers / light" — deterministic per place.
            BokehLayer(seed: Scenic.seed(poiRef + "#bokeh"), accent: family.bokehAccent)

            // Weather wash — foggy reads cooler/softer, clear warmer (FR-17 vibe).
            family.weatherWash(weather)
                .blendMode(.plusLighter)
                .opacity(0.9)
        }
        .drawingGroup() // flatten the mesh + blurs into one layer for cheap compositing
    }

    /// A 3×3 normalised point grid. Corners/edges stay pinned (so the art fills the
    /// frame cleanly); only the centre point drifts, seeded per place.
    static func meshPoints(seed: UInt64) -> [SIMD2<Float>] {
        var rng = ScenicRNG(seed: seed)
        let jx = Float(rng.unitInterval() * 0.18 - 0.09)
        let jy = Float(rng.unitInterval() * 0.18 - 0.09)
        return [
            .init(0, 0),   .init(0.5, 0),        .init(1, 0),
            .init(0, 0.5), .init(0.5 + jx, 0.5 + jy), .init(1, 0.5),
            .init(0, 1),   .init(0.5, 1),        .init(1, 1),
        ]
    }
}

// MARK: - BokehLayer

/// A handful of blurred, low-opacity circles evoking dappled light / wildflowers.
private struct BokehLayer: View {
    let seed: UInt64
    let accent: Color

    var body: some View {
        Canvas { context, size in
            var rng = ScenicRNG(seed: seed)
            let count = 6
            for _ in 0..<count {
                let r = CGFloat(rng.unitInterval() * 0.10 + 0.04) * size.width
                let x = CGFloat(rng.unitInterval()) * size.width
                let y = CGFloat(rng.unitInterval()) * size.height
                let alpha = rng.unitInterval() * 0.35 + 0.12
                let useAccent = rng.unitInterval() > 0.5
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                var inner = context
                inner.addFilter(.blur(radius: r * 0.9))
                inner.fill(
                    Path(ellipseIn: rect),
                    with: .color((useAccent ? accent : .white).opacity(alpha))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - ScenicFamily

/// Three painterly moods. Category picks the family; weather tints it.
enum ScenicFamily {
    case meadow   // park, viewpoint — green + pastel sky ("Soft Spring")
    case hearth   // coffee, bookstore, restaurant, bar — warm amber/cream
    case gallery  // museum, market — cool teal/mint

    init(category: POICategory) {
        switch category {
        case .park, .viewpoint:               self = .meadow
        case .coffee, .bookstore, .restaurant, .bar: self = .hearth
        case .museum, .market:                self = .gallery
        case .other:                          self = .meadow
        }
    }

    /// Row-major 3×3 (top → bottom) colours for the mesh.
    var meshColors: [Color] {
        switch self {
        case .meadow:
            return [
                Color(hex: "CFE8F2"), Color(hex: "E9D7E8"), Color(hex: "F3E2C9"),
                Color(hex: "D7EAB0"), Color(hex: "BBCD96"), Color(hex: "A5D0BE"),
                Color(hex: "5D6D3E"), Color(hex: "455528"), Color(hex: "3D4C20"),
            ]
        case .hearth:
            return [
                Color(hex: "FBE7CE"), Color(hex: "F6D9B8"), Color(hex: "EFE3CE"),
                Color(hex: "F0C9A0"), Color(hex: "E8B98A"), Color(hex: "D9B48C"),
                Color(hex: "B98A5E"), Color(hex: "8A5A34"), Color(hex: "6E4626"),
            ]
        case .gallery:
            return [
                Color(hex: "DDEFF0"), Color(hex: "CDE6E6"), Color(hex: "E6F0EC"),
                Color(hex: "A5D0BE"), Color(hex: "7FC0C0"), Color(hex: "C0ECDA"),
                Color(hex: "476F60"), Color(hex: "2F5749"), Color(hex: "264E41"),
            ]
        }
    }

    var bokehAccent: Color {
        switch self {
        case .meadow:  return Theme.Garden.leafFixed
        case .hearth:  return Theme.Garden.petal
        case .gallery: return Theme.Garden.mint
        }
    }

    /// A translucent wash that shifts the whole band toward the weather mood.
    func weatherWash(_ weather: Weather) -> some View {
        let color: Color
        switch weather {
        case .clear:  color = Color(hex: "FFD27A").opacity(0.10)
        case .cloudy: color = Color(hex: "C9CFC7").opacity(0.14)
        case .fog:    color = Color(hex: "B9C7CC").opacity(0.26)
        case .rain:   color = Color(hex: "8FA3B0").opacity(0.24)
        case .snow:   color = Color.white.opacity(0.28)
        }
        return LinearGradient(
            colors: [color.opacity(0.4), color],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Deterministic seeding

enum Scenic {
    /// FNV-1a over the ref — same discipline as POIPlacement / AnchorViewModel.
    static func seed(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 { hash ^= UInt64(byte); hash = hash &* 0x100000001b3 }
        return hash
    }
}

/// Tiny SplitMix64-style PRNG so the art is stable across launches (no Swift Hasher).
struct ScenicRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }

    /// A Double in 0..<1.
    mutating func unitInterval() -> Double {
        Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }
}

// MARK: - Preview

#Preview("Scenic families") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(["poi.dolores-park.sf", "poi.sightglass-coffee.sf", "poi.ocean-beach.sf"], id: \.self) { ref in
                ScenicArtBand(
                    poiRef: ref,
                    category: ref.contains("coffee") ? .coffee : (ref.contains("beach") ? .viewpoint : .park),
                    weather: ref.contains("beach") ? .fog : .clear
                )
                .frame(height: 220)
                .clipShape(.rect(cornerRadius: 22))
            }
        }
        .padding()
    }
}
