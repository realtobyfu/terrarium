//
//  GardenProgressCard.swift
//  Terrarium — HomeFeature
//
//  The Home reward surface, in the Hidden Garden / Liquid Glass language. Replaces
//  the old suggested-quest card: instead of "go do this quest → grow a tree", it
//  shows the points you've earned exploring and your garden's growth toward the
//  next level (the globe grows as you cross tiers — see WorldStore.awardPoints).
//

import SwiftUI

struct GardenProgressCard: View {
    let points: Int
    let tier: Int
    /// 0...1 toward the next tier.
    let progress: Double
    let toNext: Int
    var onOpenLog: () -> Void = {}

    var body: some View {
        Button(action: onOpenLog) {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("YOUR GARDEN")
                            .font(Theme.Typography.body(12, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(Theme.Palette.label)
                        Text("Level \(tier)")
                            .font(Theme.Typography.display(24, weight: .bold))
                            .foregroundStyle(Theme.Palette.title)
                    }
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.Garden.bloom)
                        Text("\(points)")
                            .font(Theme.Typography.body(16, weight: .semibold))
                            .foregroundStyle(Theme.Palette.title)
                            .contentTransition(.numericText())
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .glassEffect(.regular.tint(Theme.Garden.bloom.opacity(0.2)), in: .capsule)
                }

                ProgressTrack(progress: progress)

                Text("\(toNext) pts to the next bloom")
                    .font(Theme.Typography.body(13))
                    .foregroundStyle(Theme.Palette.secondary)
            }
            .padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.glass))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: points)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your garden, level \(tier), \(points) points. \(toNext) to the next level.")
        .accessibilityAddTraits(.isButton)
    }
}

/// A moss-filled progress bar with a soft leaf track.
private struct ProgressTrack: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Garden.leaf.opacity(0.35))
                Capsule()
                    .fill(
                        LinearGradient(colors: [Theme.Garden.mossLight, Theme.Garden.moss],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: max(8, geo.size.width * CGFloat(min(1, max(0, progress)))))
            }
        }
        .frame(height: 10)
    }
}

#Preview("Garden progress") {
    ZStack {
        LinearGradient(colors: [Color(hex: "BFE3F2"), Color(hex: "EAF6FB")],
                       startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        VStack {
            Spacer()
            GardenProgressCard(points: 240, tier: 2, progress: 0.4, toNext: 60)
                .padding()
        }
    }
}
