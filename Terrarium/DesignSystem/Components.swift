//
//  Components.swift
//  Terrarium — DesignSystem
//
//  Pure, stateless, preview-driven components. No business logic, no state.
//

import SwiftUI

// MARK: - SoftPanel

/// A cream rounded surface with a soft border and shadow — the base "island".
struct SoftPanel<Content: View>: View {
    var cornerRadius: CGFloat = Theme.Radius.panel
    var fill: Color = Theme.Palette.cardSurface
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.Palette.cardBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}

// MARK: - GlowButton

/// Accent-filled capsule button with a soft glow. The brand call-to-action.
struct GlowButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typography.body(16, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.m)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule().fill(Theme.Palette.accent)
                )
                .shadow(color: Theme.Palette.accent.opacity(0.45), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Wordmark

/// Serif app wordmark for the top-left of the overlay.
struct Wordmark: View {
    var body: some View {
        Text("Terrarium")
            .font(Theme.Typography.display(20, weight: .medium))
            .foregroundStyle(Theme.Palette.title)
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
            .background(
                Capsule().fill(Theme.Palette.chipSurface)
            )
            .overlay(
                Capsule().strokeBorder(Theme.Palette.cardBorder, lineWidth: 1)
            )
    }
}

// MARK: - LocationChip

/// Top-right chip showing place + weather, bound to SkyState.
struct LocationChip: View {
    let sky: SkyState

    private var weatherLabel: String {
        switch sky.weather {
        case .clear:  return "clear"
        case .cloudy: return "cloudy"
        case .fog:    return "foggy"
        case .rain:   return "rain"
        case .snow:   return "snow"
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Circle()
                .fill(Theme.Palette.accent)
                .frame(width: 6, height: 6)
            Text("\(sky.locationName) · \(weatherLabel)")
                .font(Theme.Typography.body(14, weight: .medium))
                .foregroundStyle(Theme.Palette.secondary)
            Text(sky.localTimeLabel)
                .font(Theme.Typography.body(13))
                .foregroundStyle(Theme.Palette.label)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .background(
            Capsule().fill(Theme.Palette.chipSurface)
        )
        .overlay(
            Capsule().strokeBorder(Theme.Palette.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - QuestCard

/// Bottom suggested-quest card with a Begin call-to-action.
struct QuestCard: View {
    let quest: Quest
    let onBegin: () -> Void

    var body: some View {
        SoftPanel(cornerRadius: Theme.Radius.card) {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                Text(quest.placeName.uppercased())
                    .font(Theme.Typography.body(12, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(Theme.Palette.label)

                Text(quest.title)
                    .font(Theme.Typography.display(24, weight: .medium))
                    .foregroundStyle(Theme.Palette.title)

                Text(quest.prompt)
                    .font(Theme.Typography.body(15))
                    .foregroundStyle(Theme.Palette.secondary)

                GlowButton(title: "Begin", action: onBegin)
                    .padding(.top, Theme.Spacing.s)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.l)
        }
    }
}

// MARK: - Previews

#Preview("Components") {
    ZStack {
        SkyPalette.gradient(for: SkyState(sunElevationDegrees: 6,
                                          weather: .fog,
                                          locationName: "SF",
                                          localTimeLabel: "6:48pm"))
        .ignoresSafeArea()

        VStack {
            HStack {
                Wordmark()
                Spacer()
                LocationChip(sky: SkyState(sunElevationDegrees: 6,
                                           weather: .fog,
                                           locationName: "SF",
                                           localTimeLabel: "6:48pm"))
            }
            Spacer()
            QuestCard(
                quest: Quest(title: "Ocean Beach at dusk",
                             prompt: "Walk the shore, name three sounds",
                             placeName: "Ocean Beach"),
                onBegin: {}
            )
        }
        .padding()
    }
}
