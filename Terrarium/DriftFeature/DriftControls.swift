//
//  DriftControls.swift
//  Terrarium — Prototypes
//
//  The Liquid-Glass controls for the Drift redesign:
//    • DriftStatStrip     — big glanceable live stats (time · distance · cells)
//    • DriftRouteControls  — duration slider + a "Guided ↔ Surprise me" wander dial
//    • StartRambleButton   — the focal prominent-glass CTA (reused for End)
//
//  Plus the cool "fog" tokens that let Drift read cooler than the warm Anchor
//  screen. Per the frozen-kit contract these are added via `extension Theme.Garden`
//  here rather than edited into DiscoveryGlassTokens.swift.
//
//  Min target iOS 26: glass effects + glass button styles are used directly.
//

import SwiftUI

// MARK: - Cool Drift tokens (extend the frozen Garden palette, don't edit it)

extension Theme.Garden {
    /// Pale mist — the lightest cool wash for the Drift base + map mute.
    static let mist  = Color(hex: "D6E0DC")
    /// Misty sage-grey — faint previously-explored cell tiles.
    static let haze  = Color(hex: "9FB3AE")
    /// Deep cool pine-grey — the fog that closes in at the map's edge + End tint.
    static let dusk  = Color(hex: "5E7A73")
    /// A foggy weather wash for the cool base, sitting between mist and haze.
    static let fog   = Color(hex: "C4D2CD")
}

// MARK: - DriftStatStrip

/// A floating glass strip of the three live ramble stats, sized to be read at a
/// glance mid-walk. Each stat pairs an icon with its value (a11y: never hue alone).
struct DriftStatStrip: View {
    let elapsedSeconds: TimeInterval
    let distanceMeters: Double
    let cellsLit: Int

    var body: some View {
        HStack(spacing: 0) {
            stat(icon: "clock", value: elapsedText, label: "Time")
            divider
            stat(icon: "figure.walk", value: distanceText, label: "Distance")
            divider
            stat(icon: "circle.grid.2x2.fill", value: "\(cellsLit)", label: "Lit")
        }
        .padding(.vertical, Theme.Spacing.m)
        .padding(.horizontal, Theme.Spacing.l)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.glass))
    }

    private func stat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Garden.pineLight)
            Text(value)
                .font(Theme.Typography.display(26, weight: .semibold))
                .foregroundStyle(Theme.Palette.title)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label.uppercased())
                .font(Theme.Typography.body(10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.Palette.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.Palette.secondary.opacity(0.15))
            .frame(width: 1, height: 34)
    }

    private var elapsedText: String {
        let total = Int(elapsedSeconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    private var distanceText: String {
        distanceMeters >= 1000
            ? String(format: "%.1f", distanceMeters / 1000) + "km"
            : "\(Int(distanceMeters))m"
    }
}

// MARK: - DriftRouteControls

/// Idle-state route shaping: how long, and how much to wander. Bound directly to
/// the (unchanged) `DriftViewModel`; "Preview a loop" calls `generateRoute()`.
struct DriftRouteControls: View {
    @Bindable var viewModel: DriftViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text("SHAPE YOUR WALK")
                .font(Theme.Typography.body(11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.Palette.label)

            // Duration
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Label("Duration", systemImage: "clock")
                        .font(Theme.Typography.body(13))
                        .foregroundStyle(Theme.Palette.secondary)
                    Spacer()
                    Text("\(Int(viewModel.targetMinutes)) min")
                        .font(Theme.Typography.body(14, weight: .semibold))
                        .foregroundStyle(Theme.Palette.title)
                        .monospacedDigit()
                }
                Slider(value: $viewModel.targetMinutes, in: 10...90, step: 5) {
                    Text("Duration")
                } minimumValueLabel: {
                    Text("10").font(Theme.Typography.body(11)).foregroundStyle(Theme.Palette.label)
                } maximumValueLabel: {
                    Text("90").font(Theme.Typography.body(11)).foregroundStyle(Theme.Palette.label)
                }
                .tint(Theme.Garden.moss)
            }

            // Wander dial (randomness)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Label("Wandering", systemImage: "shuffle")
                        .font(Theme.Typography.body(13))
                        .foregroundStyle(Theme.Palette.secondary)
                    Spacer()
                    Text(randomnessLabel)
                        .font(Theme.Typography.body(14, weight: .semibold))
                        .foregroundStyle(Theme.Palette.title)
                }
                Slider(value: $viewModel.routeRandomness, in: 0...1) {
                    Text("Wandering")
                } minimumValueLabel: {
                    Text("Guided").font(Theme.Typography.body(11)).foregroundStyle(Theme.Palette.label)
                } maximumValueLabel: {
                    Text("Surprise").font(Theme.Typography.body(11)).foregroundStyle(Theme.Palette.label)
                }
                .tint(Theme.Garden.moss)
            }

            // Suggest a loop
            Button {
                viewModel.generateRoute()
            } label: {
                Label("Preview a loop", systemImage: "arrow.triangle.turn.up.right.diamond")
                    .font(Theme.Typography.body(15, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glass)
            .tint(Theme.Garden.mossLight)
        }
        .padding(Theme.Spacing.l)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.glass))
    }

    private var randomnessLabel: String {
        switch viewModel.routeRandomness {
        case ..<0.2:  return "On the path"
        case ..<0.5:  return "Guided"
        case ..<0.8:  return "Mixed"
        default:      return "Surprise me"
        }
    }
}

// MARK: - StartRambleButton

/// The focal prominent-glass CTA. Reused for the active "End ramble" control by
/// passing a different title / glyph / tint.
struct StartRambleButton: View {
    var title: String = "Start a ramble"
    var systemImage: String = "figure.walk.motion"
    var tint: Color = Theme.Garden.pine
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(Theme.Typography.body(17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .tint(tint)
        .controlSize(.large)
    }
}

// MARK: - Previews

#Preview("Drift controls") {
    ZStack {
        DriftBackground().ignoresSafeArea()
        VStack(spacing: Theme.Spacing.xl) {
            DriftStatStrip(elapsedSeconds: 1325, distanceMeters: 2140, cellsLit: 9)
            DriftRouteControls(viewModel: DriftViewModel(
                location: StubLocationSession(),
                recommender: StubRecommender(
                    catalog: StubPOICatalog(),
                    discoveries: InMemoryDiscoveryStore()
                ),
                discoveries: InMemoryDiscoveryStore()
            ))
            StartRambleButton(action: {})
        }
        .padding(Theme.Spacing.l)
    }
}
