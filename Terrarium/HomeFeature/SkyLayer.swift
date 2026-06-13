//
//  SkyLayer.swift
//  Terrarium — HomeFeature
//
//  Full-bleed gradient backdrop driven by SkyState. A pure render: it owns no
//  state and re-tints whenever SkyState changes. Clear nights show stars.
//

import SwiftUI

struct SkyLayer: View {
    let state: SkyState

    var body: some View {
        ZStack {
            SkyPalette.gradient(for: state)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: state)

            if SkyPalette.showsStars(for: state) {
                StarField()
                    .ignoresSafeArea()
                    .transition(.opacity)
                ShootingStars()
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
    }
}

/// A handful of meteors streaking across the night sky on staggered timers.
private struct ShootingStars: View {
    private struct Meteor: Identifiable {
        let id = UUID()
        let startX, startY: Double   // 0...1
        let dx, dy: Double           // travel direction (screen fractions)
        let period: Double           // seconds between streaks
        let phase: Double            // 0...1 offset so they don't sync
        let activeFraction: Double   // portion of the period it is visible
    }

    private let meteors: [Meteor] = {
        var g = SeededGenerator(seed: 7)
        return (0..<5).map { _ in
            let leftToRight = Bool.random(using: &g)
            return Meteor(
                startX: Double.random(in: 0.0...0.7, using: &g),
                startY: Double.random(in: 0.02...0.4, using: &g),
                dx: (leftToRight ? 1 : -1) * Double.random(in: 0.5...0.9, using: &g),
                dy: Double.random(in: 0.4...0.8, using: &g),
                period: Double.random(in: 4.5...9.0, using: &g),
                phase: Double.random(in: 0...1, using: &g),
                activeFraction: Double.random(in: 0.10...0.18, using: &g)
            )
        }
    }()

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { gc, size in
                let t = context.date.timeIntervalSinceReferenceDate
                for m in meteors {
                    let cycle = ((t / m.period) + m.phase).truncatingRemainder(dividingBy: 1)
                    guard cycle < m.activeFraction else { continue }
                    let p = cycle / m.activeFraction               // 0...1 across its arc
                    let opacity = sin(p * .pi)                      // fade in then out

                    let head = CGPoint(x: (m.startX + m.dx * p) * size.width,
                                       y: (m.startY + m.dy * p) * size.height)
                    let tail = CGPoint(x: head.x - m.dx * size.width * 0.10,
                                       y: head.y - m.dy * size.height * 0.10)

                    var path = Path()
                    path.move(to: tail)
                    path.addLine(to: head)
                    gc.stroke(path,
                              with: .color(.white.opacity(opacity * 0.9)),
                              style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    gc.fill(
                        Path(ellipseIn: CGRect(x: head.x - 2, y: head.y - 2, width: 4, height: 4)),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
        }
    }
}

/// A deterministic scattering of star dots (clear nights only).
private struct StarField: View {
    // Fixed seed so the field doesn't twinkle/relayout on every redraw.
    private let stars: [Star] = {
        var generator = SeededGenerator(seed: 42)
        return (0..<60).map { _ in
            Star(
                x: Double.random(in: 0...1, using: &generator),
                y: Double.random(in: 0...0.7, using: &generator),
                size: Double.random(in: 1...2.5, using: &generator),
                opacity: Double.random(in: 0.4...1, using: &generator)
            )
        }
    }()

    var body: some View {
        GeometryReader { geo in
            ForEach(stars) { star in
                Circle()
                    .fill(.white)
                    .frame(width: star.size, height: star.size)
                    .opacity(star.opacity)
                    .position(x: star.x * geo.size.width,
                              y: star.y * geo.size.height)
            }
        }
    }

    struct Star: Identifiable {
        let id = UUID()
        let x, y, size, opacity: Double
    }
}

/// Tiny deterministic RNG so the star field is stable across redraws.
private struct SeededGenerator: RandomNumberGenerator {
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

#Preview("Night · clear") {
    SkyLayer(state: SkyState(sunElevationDegrees: -20,
                             weather: .clear,
                             locationName: "SF",
                             localTimeLabel: "11:15pm"))
}
