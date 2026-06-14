//
//  RewardOverlayGlass.swift
//  Terrarium — Prototypes
//
//  The celebratory "your terrarium grew" beat, rebuilt in the Hidden Garden /
//  Liquid Glass language. `AnchorView.ArrivalCard` was a rough first cut;
//  this promotes it to a reusable overlay that any screen (Anchor / Drift) can
//  present on `specimenGrown == true` via the `.rewardOverlay(…)` modifier.
//
//  The grown specimen icon springs in (a `phaseAnimator` grow + `.symbolEffect`
//  bounce) over a soft glass card on a dimmed scrim, with deterministic twinkling
//  sparkles and a pulsing halo. The whole thing honors the specimen `variant`
//  ("foggy" reads cooler, "clear" warmer — like the sky) and respects Reduce
//  Motion (a quiet cross-fade with no spring/sparkle motion).
//
//  iOS 26 APIs: glassEffect / GlassEffectContainer (card + actions),
//  .buttonStyle(.glassProminent / .glass), phaseAnimator, .symbolEffect,
//  TimelineView + Canvas sparkles.
//

import SwiftUI

// MARK: - Specimen presentation

extension WorldProp.Kind {
    /// SF Symbol representing a grown specimen across the reward + journal UI.
    var rewardSymbol: String {
        switch self {
        case .tree:     return "tree.fill"
        case .building: return "building.2.fill"
        case .flowers:  return "camera.macro"
        }
    }

    /// Human-readable label for the specimen kind.
    var gardenLabel: String {
        switch self {
        case .tree:     return "Tree"
        case .building: return "Building"
        case .flowers:  return "Flowers"
        }
    }
}

// MARK: - RewardOverlay

/// A brief celebratory beat shown when a new specimen lands in the terrarium.
/// Standalone & context-agnostic so it previews in isolation; the owning screen
/// presents it with the `.rewardOverlay(…)` modifier below.
struct RewardOverlay: View {
    let poiName: String
    let specimenKind: WorldProp.Kind
    /// Appearance variant ("clear" warmer / "foggy" cooler), like the sky.
    var variant: String = "clear"
    var onViewOnGlobe: () -> Void = {}
    var onDismiss: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Animation drivers (no-ops under Reduce Motion).
    @State private var grow = false
    @State private var bounce = false
    @State private var haloScale: CGFloat = 0.9

    private var palette: RewardPalette { .make(variant: variant) }

    var body: some View {
        ZStack {
            // Dimmed scrim — tap outside the card to dismiss.
            Rectangle()
                .fill(.black.opacity(0.38))
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }
                .accessibilityHidden(true)

            card.padding(Theme.Spacing.xl)
        }
        .accessibilityAddTraits(.isModal)
        .onAppear {
            guard !reduceMotion else { return }
            grow.toggle()
            bounce.toggle()
            haloScale = 1.06
        }
    }

    // MARK: Card

    private var card: some View {
        VStack(spacing: Theme.Spacing.xl) {
            announcement
            actions
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: 360)
        .glassEffect(.regular.tint(palette.glassTint),
                     in: .rect(cornerRadius: Theme.Radius.glass))
        .overlay(alignment: .topTrailing) {
            WashiTape(width: 88, height: 22, rotation: .degrees(-8))
                .offset(x: -16, y: 12)
        }
        .contentShape(.rect(cornerRadius: Theme.Radius.glass))
        .shadow(color: .black.opacity(0.20), radius: 26, y: 14)
    }

    /// Icon + headline + place — collapsed into one VoiceOver announcement.
    private var announcement: some View {
        VStack(spacing: Theme.Spacing.l) {
            iconStack

            VStack(spacing: Theme.Spacing.s) {
                Text("Your terrarium grew!")
                    .font(Theme.Typography.display(27, weight: .bold))
                    .foregroundStyle(Theme.Palette.title)
                    .multilineTextAlignment(.center)

                Text("A new \(specimenKind.gardenLabel.lowercased()) sprouted at \(poiName).")
                    .font(Theme.Typography.body(15))
                    .foregroundStyle(Theme.Palette.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel(
            "Your terrarium grew. A new \(specimenKind.gardenLabel.lowercased()) sprouted at \(poiName)."
        )
    }

    private var iconStack: some View {
        ZStack {
            // Pulsing radial halo behind the specimen.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette.halo.opacity(0.55), palette.halo.opacity(0)],
                        center: .center, startRadius: 6, endRadius: 92
                    )
                )
                .frame(width: 184, height: 184)
                .scaleEffect(reduceMotion ? 1 : haloScale)
                .animation(reduceMotion ? nil
                           : .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                           value: haloScale)
                .accessibilityHidden(true)

            // Deterministic twinkling sparkles (still + soft under Reduce Motion).
            SparkleField(tint: palette.sparkle, animated: !reduceMotion, seed: Scenic.seed(poiName))
                .frame(width: 204, height: 204)

            grownIcon
                .frame(width: 100, height: 100)
        }
        .frame(width: 204, height: 204)
    }

    @ViewBuilder
    private var grownIcon: some View {
        if reduceMotion {
            specimenImage
        } else {
            specimenImage
                .phaseAnimator([GrowPhase.seed, .pop, .rest], trigger: grow) { view, phase in
                    view.scaleEffect(phase.scale).opacity(phase.opacity)
                } animation: { phase in
                    phase == .pop
                        ? .spring(response: 0.40, dampingFraction: 0.52)
                        : .spring(response: 0.52, dampingFraction: 0.72)
                }
        }
    }

    private var specimenImage: some View {
        Image(systemName: specimenKind.rewardSymbol)
            .font(.system(size: 70, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(palette.icon)
            .symbolEffect(.bounce, options: .nonRepeating, value: bounce)
            .shadow(color: palette.icon.opacity(0.35), radius: 12, y: 6)
    }

    private var actions: some View {
        GlassEffectContainer(spacing: Theme.Spacing.m) {
            VStack(spacing: Theme.Spacing.m) {
                Button {
                    onViewOnGlobe()
                } label: {
                    Label("View on globe", systemImage: "globe.americas.fill")
                        .font(Theme.Typography.body(17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.Garden.moss)
                .controlSize(.large)

                Button {
                    onDismiss()
                } label: {
                    Text("Maybe later")
                        .font(Theme.Typography.body(15, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glass)
                .tint(Theme.Garden.mossLight)
            }
        }
    }
}

// MARK: - Variant palette

/// Warm ("clear") vs cool ("foggy") colour set for the reward, mirroring the
/// sky/scenic weather wash so a foggy discovery feels of-a-piece with its place.
private struct RewardPalette {
    let glassTint: Color
    let icon: Color
    let halo: Color
    let sparkle: Color

    static func make(variant: String) -> RewardPalette {
        if variant == "foggy" {
            return RewardPalette(
                glassTint: Theme.Garden.mint.opacity(0.20),
                icon: Theme.Garden.pineLight,
                halo: Theme.Garden.mint,
                sparkle: .white
            )
        } else {
            return RewardPalette(
                glassTint: Theme.Garden.leaf.opacity(0.22),
                icon: Theme.Garden.moss,
                halo: Theme.Garden.leafFixed,
                sparkle: Theme.Garden.bloom
            )
        }
    }
}

// MARK: - Grow phases

/// The three beats of the specimen "grow": a hidden seed, an overshoot pop, then
/// a settle. Fed to `phaseAnimator` so the icon springs in and stays at rest.
private struct GrowPhase: Equatable {
    var scale: CGFloat
    var opacity: Double

    static let seed = GrowPhase(scale: 0.4, opacity: 0)
    static let pop  = GrowPhase(scale: 1.16, opacity: 1)
    static let rest = GrowPhase(scale: 1.0, opacity: 1)
}

// MARK: - SparkleField

/// A handful of deterministic four-point sparkles that twinkle around the
/// specimen. Animated via `TimelineView` when motion is allowed; a soft static
/// render otherwise (Reduce Motion).
private struct SparkleField: View {
    let tint: Color
    let animated: Bool
    private let sparks: [Spark]

    init(tint: Color, animated: Bool, seed: UInt64) {
        self.tint = tint
        self.animated = animated
        var rng = ScenicRNG(seed: seed)
        self.sparks = (0..<9).map { _ in
            Spark(
                x: rng.unitInterval(),
                y: rng.unitInterval(),
                radius: rng.unitInterval() * 6 + 4,
                phase: rng.unitInterval() * 6.283,
                speed: rng.unitInterval() * 1.4 + 0.7
            )
        }
    }

    var body: some View {
        if animated {
            TimelineView(.animation) { timeline in
                canvas(time: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            canvas(time: 0)
        }
    }

    private func canvas(time: TimeInterval) -> some View {
        Canvas { context, size in
            for spark in sparks {
                let twinkle = animated ? (0.5 + 0.5 * sin(time * spark.speed + spark.phase)) : 0.8
                let r = spark.radius * (0.6 + 0.4 * twinkle)
                let center = CGPoint(x: spark.x * size.width, y: spark.y * size.height)
                var layer = context
                layer.addFilter(.blur(radius: 0.5))
                layer.opacity = 0.2 + 0.65 * twinkle
                layer.fill(Self.sparklePath(center: center, radius: r), with: .color(tint))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A four-point sparkle (concave star) centred at `center`.
    private static func sparklePath(center: CGPoint, radius r: CGFloat) -> Path {
        var path = Path()
        let inner = r * 0.32
        for i in 0..<8 {
            let angle = Double(i) * .pi / 4 - .pi / 2
            let radius = i.isMultiple(of: 2) ? r : inner
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * radius,
                                y: center.y + CGFloat(sin(angle)) * radius)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    private struct Spark {
        let x: Double
        let y: Double
        let radius: CGFloat
        let phase: Double
        let speed: Double
    }
}

// MARK: - View modifier

extension View {
    /// Presents the celebratory `RewardOverlay` when `isPresented` is true.
    /// Wire it on Anchor/Drift to fire on `specimenGrown == true`.
    func rewardOverlay(isPresented: Binding<Bool>,
                       poiName: String,
                       specimenKind: WorldProp.Kind,
                       variant: String = "clear",
                       onViewOnGlobe: @escaping () -> Void = {}) -> some View {
        modifier(RewardOverlayModifier(
            isPresented: isPresented,
            poiName: poiName,
            specimenKind: specimenKind,
            variant: variant,
            onViewOnGlobe: onViewOnGlobe
        ))
    }
}

private struct RewardOverlayModifier: ViewModifier {
    @Binding var isPresented: Bool
    let poiName: String
    let specimenKind: WorldProp.Kind
    let variant: String
    let onViewOnGlobe: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    RewardOverlay(
                        poiName: poiName,
                        specimenKind: specimenKind,
                        variant: variant,
                        onViewOnGlobe: { onViewOnGlobe(); isPresented = false },
                        onDismiss: { isPresented = false }
                    )
                    .transition(reduceMotion
                                ? .opacity
                                : .opacity.combined(with: .scale(scale: 0.9)))
                    .zIndex(1)
                }
            }
            .animation(reduceMotion
                       ? .easeInOut(duration: 0.25)
                       : .spring(response: 0.42, dampingFraction: 0.82),
                       value: isPresented)
    }
}

// MARK: - Previews

private struct RewardPreviewHarness: View {
    let variant: String
    let kind: WorldProp.Kind
    let name: String

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "F2E8D2"), Color(hex: "FBF2E0"), Color(hex: "EFF1E2")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            RewardOverlay(poiName: name, specimenKind: kind, variant: variant)
        }
    }
}

#Preview("Reward — clear") {
    RewardPreviewHarness(variant: "clear", kind: .tree, name: "Dolores Park")
}

#Preview("Reward — foggy") {
    RewardPreviewHarness(variant: "foggy", kind: .flowers, name: "Ocean Beach")
}

#Preview("Reward — modifier flow") {
    RewardModifierPreview()
}

private struct RewardModifierPreview: View {
    @State private var show = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "F2E8D2"), Color(hex: "FBF2E0")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            Button {
                show = true
            } label: {
                Label("Grow a specimen", systemImage: "sparkles")
                    .padding(.vertical, 6).padding(.horizontal, 12)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.Garden.moss)
            .controlSize(.large)
        }
        .rewardOverlay(isPresented: $show,
                       poiName: "Sightglass Coffee",
                       specimenKind: .building,
                       variant: "clear")
    }
}
