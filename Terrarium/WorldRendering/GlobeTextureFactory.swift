//
//  GlobeTextureFactory.swift
//  Terrarium — WorldRendering
//
//  Procedurally paints the globe's textures in-palette and bundles them as
//  RealityKit TextureResources. Generating them in code (rather than shipping
//  PNGs) keeps the app fully offline with zero asset-pipeline overhead.
//
//  - surface: equirectangular stylized Earth (teal ocean, sage continents,
//    sandy coasts, faint polar caps).
//  - clouds:  wispy white alpha map for the drifting cloud sphere.
//  - halo:    radial cyan glow for the atmosphere limb (Fresnel fallback).
//
//  Texture generation needs Metal, so these are never built inside unit tests.
//

import CoreGraphics
import RealityKit
import UIKit

enum GlobeTextureFactory {

    // MARK: - Cached resources (built once, lazily)

    static let surface: TextureResource? = try? makeColorTexture(surfaceImage())
    static let clouds: TextureResource? = try? makeColorTexture(cloudImage())
    static let halo: TextureResource? = try? makeColorTexture(haloImage())

    private static func makeColorTexture(_ image: CGImage) throws -> TextureResource {
        try TextureResource.generate(from: image,
                                     options: .init(semantic: .color))
    }

    // MARK: - Palette (matches DesignSystem tokens)

    private enum Pixel {
        static let ocean  = UIColor(red: 0.329, green: 0.667, blue: 0.788, alpha: 1) // #54AAC9 ocean blue
        static let oceanDeep = UIColor(red: 0.184, green: 0.435, blue: 0.584, alpha: 1) // #2F6F95
        static let land   = UIColor(red: 0.486, green: 0.753, blue: 0.541, alpha: 1) // #7CC08A
        static let coast  = UIColor(red: 0.918, green: 0.827, blue: 0.627, alpha: 1) // #EAD3A0
        static let cap    = UIColor(white: 0.96, alpha: 0.30)
    }

    // MARK: - Surface (equirectangular)

    /// A stylized, Earth-like landmask. Continents are blobs in (lonº, latº)
    /// with degree radii; drawn coast-first then land to leave a sandy rim.
    private struct Blob { let lon, lat, lonR, latR: CGFloat }

    private static let continents: [Blob] = [
        Blob(lon: -100, lat: 45, lonR: 32, latR: 24),  // North America
        Blob(lon: -82,  lat: 22, lonR: 12, latR: 13),  // Central America
        Blob(lon: -42,  lat: 72, lonR: 13, latR: 8),   // Greenland
        Blob(lon: -60,  lat: -18, lonR: 15, latR: 28),  // South America
        Blob(lon: 18,   lat: 4,  lonR: 22, latR: 34),  // Africa
        Blob(lon: 15,   lat: 52, lonR: 20, latR: 12),  // Europe
        Blob(lon: 95,   lat: 50, lonR: 46, latR: 27),  // Asia
        Blob(lon: 78,   lat: 22, lonR: 13, latR: 13),  // India
        Blob(lon: 120,  lat: -2, lonR: 18, latR: 9),   // SE Asia / Indonesia
        Blob(lon: 134,  lat: -25, lonR: 18, latR: 12),  // Australia
    ]

    static func surfaceImage(width: Int = 1024, height: Int = 512) -> CGImage {
        let ctx = makeContext(width: width, height: height)
        let w = CGFloat(width), h = CGFloat(height)

        // Ocean base.
        ctx.setFillColor(Pixel.ocean.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        func rect(_ b: Blob, pad: CGFloat) -> CGRect {
            let cx = (b.lon + 180) / 360 * w
            let cy = (90 - b.lat) / 180 * h
            let rw = (b.lonR + pad) / 360 * w * 2
            let rh = (b.latR + pad) / 180 * h * 2
            return CGRect(x: cx - rw / 2, y: cy - rh / 2, width: rw, height: rh)
        }

        // Continents: sandy coast underlay, then sage land.
        for b in continents {
            ctx.setFillColor(Pixel.coast.cgColor)
            ctx.fillEllipse(in: rect(b, pad: 2.5))
        }
        for b in continents {
            ctx.setFillColor(Pixel.land.cgColor)
            ctx.fillEllipse(in: rect(b, pad: 0))
        }

        // Faint polar caps — kept subtle so the poles don't dominate.
        ctx.setFillColor(Pixel.cap.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h * 0.03))
        ctx.fill(CGRect(x: 0, y: h * 0.97, width: w, height: h * 0.03))

        return ctx.makeImage()!
    }

    // MARK: - Clouds (white, alpha-varying)

    static func cloudImage(width: Int = 1024, height: Int = 512) -> CGImage {
        let ctx = makeContext(width: width, height: height)
        let w = CGFloat(width), h = CGFloat(height)
        var rng = SeededRNG(seed: 1972)

        // Fewer, larger, more-defined cloud masses with clear sky between them so
        // they read as distinct clouds rather than uniform haze.
        for _ in 0..<22 {
            let cx = CGFloat.random(in: 0...w, using: &rng)
            let lat = CGFloat.random(in: -1...1, using: &rng)
            let cy = (0.5 + lat * 0.42) * h
            let r = CGFloat.random(in: w * 0.035...w * 0.075, using: &rng)
            let peak = CGFloat.random(in: 0.55...0.9, using: &rng)
            // A few overlapping lobes give each mass an irregular, wispy edge.
            let lobes = Int.random(in: 2...4, using: &rng)
            for _ in 0..<lobes {
                let ox = CGFloat.random(in: -r...r, using: &rng)
                let oy = CGFloat.random(in: -r * 0.4...r * 0.4, using: &rng)
                drawSoftPuff(ctx, center: CGPoint(x: cx + ox, y: cy + oy),
                             radiusX: r * CGFloat.random(in: 1.0...1.8, using: &rng),
                             radiusY: r * CGFloat.random(in: 0.6...1.0, using: &rng),
                             peakAlpha: peak)
            }
        }
        return ctx.makeImage()!
    }

    private static func drawSoftPuff(_ ctx: CGContext, center: CGPoint,
                                     radiusX: CGFloat, radiusY: CGFloat,
                                     peakAlpha: CGFloat) {
        let space = CGColorSpaceCreateDeviceRGB()
        let colors = [
            UIColor(white: 1, alpha: peakAlpha).cgColor,
            UIColor(white: 1, alpha: 0).cgColor,
        ] as CFArray
        guard let gradient = CGGradient(colorsSpace: space, colors: colors,
                                        locations: [0, 1]) else { return }
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.scaleBy(x: radiusX / radiusY, y: 1)
        ctx.drawRadialGradient(gradient,
                               startCenter: .zero, startRadius: 0,
                               endCenter: .zero, endRadius: radiusY,
                               options: [])
        ctx.restoreGState()
    }

    // MARK: - Halo (radial cyan glow)

    static func haloImage(size: Int = 512) -> CGImage {
        let ctx = makeContext(width: size, height: size)
        let s = CGFloat(size)
        let space = CGColorSpaceCreateDeviceRGB()
        let cyan = UIColor(red: 0.36, green: 0.82, blue: 0.90, alpha: 1) // saturated cyan
        let colors = [
            cyan.withAlphaComponent(0).cgColor,    // center: clear (globe shows through)
            cyan.withAlphaComponent(0).cgColor,
            cyan.withAlphaComponent(0.34).cgColor, // limb: soft broad glow
            cyan.withAlphaComponent(0).cgColor,    // wide outer fade
        ] as CFArray
        guard let gradient = CGGradient(colorsSpace: space, colors: colors,
                                        locations: [0.0, 0.30, 0.40, 0.80]) else {
            return ctx.makeImage()!
        }
        ctx.drawRadialGradient(gradient,
                               startCenter: CGPoint(x: s / 2, y: s / 2), startRadius: 0,
                               endCenter: CGPoint(x: s / 2, y: s / 2), endRadius: s / 2,
                               options: [])
        return ctx.makeImage()!
    }

    // MARK: - Context helper (top-left origin)

    private static func makeContext(width: Int, height: Int) -> CGContext {
        let ctx = CGContext(
            data: nil,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        // Flip to a top-left origin so equirectangular math (north at top) reads
        // naturally.
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)
        return ctx
    }
}

/// Small deterministic RNG so generated textures are stable across launches.
private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
