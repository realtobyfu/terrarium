//
//  DiscoveryHeroCard.swift
//  Terrarium — Prototypes
//
//  The editorial "QuestCard POI" from the mockup: a tactile cream island holding
//  a painterly art well (ScenicArtBand), a floating frosted-glass name card taped
//  down with washi, the organic status pills, and a warm description line.
//
//  Pure & context-agnostic: it takes already-formatted strings so it carries no
//  business logic and previews in isolation. The owning screen
//  (AnchorView) feeds it from AnchorViewModel.
//

import SwiftUI

struct DiscoveryHeroCard: View {
    let poiRef: String
    let name: String
    let category: POICategory
    let weather: Weather

    /// "Park · Mission" eyebrow.
    let eyebrow: String
    /// Weather-aware vibe sentence from the view model.
    let description: String?
    /// "Open Now" / "Hours vary".
    let openText: String
    /// "12 min" walk estimate, when location is known.
    let walkText: String?

    var body: some View {
        SoftPanel(cornerRadius: Theme.Radius.hero) {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                artWell
                textBlock
            }
            .padding(Theme.Spacing.l)
        }
    }

    // MARK: Art well

    private var artWell: some View {
        ScenicArtBand(poiRef: poiRef, category: category, weather: weather)
            .aspectRatio(1.2, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay { nameCard }
            .overlay(alignment: .bottomLeading) { statusPills }
            .overlay(alignment: .topTrailing) {
                WashiTape(width: 92, height: 22, rotation: .degrees(-4))
                    .offset(x: -10, y: 8)
            }
            .overlay(alignment: .leading) {
                WashiTape(width: 60, height: 26, rotation: .degrees(82))
                    .offset(x: -14)
            }
            .clipShape(.rect(cornerRadius: Theme.Radius.heroInner))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.heroInner, style: .continuous)
                    .strokeBorder(Theme.Palette.cardBorder.opacity(0.5), lineWidth: 1)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(name), \(eyebrow). Illustrated.")
    }

    private var nameCard: some View {
        ZStack {
            // Criss-cross tape holding the card down.
            WashiTape(width: 150, height: 26, rotation: .degrees(-15), opacity: 0.7)
            WashiTape(width: 150, height: 22, rotation: .degrees(70), opacity: 0.7)

            VStack(alignment: .leading) {
                Text(name)
                    .font(Theme.Typography.display(26, weight: .bold))
                    .foregroundStyle(Theme.Garden.moss)
                    .minimumScaleFactor(0.6)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 8)

                HStack {
                    Spacer()
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.Palette.secondary.opacity(0.7))
                }
            }
            .padding(Theme.Spacing.l)
        }
        .frame(width: 168, height: 210)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .rotationEffect(.degrees(1.5))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
    }

    private var statusPills: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                OrganicPill(systemImage: "leaf.fill", text: openText, tint: Theme.Garden.moss)
                if let walkText {
                    OrganicPill(systemImage: "figure.walk", text: walkText, tint: Theme.Garden.bloom)
                }
            }
        }
        .padding(12)
    }

    // MARK: Text block

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(eyebrow.uppercased())
                .font(Theme.Typography.body(12, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(Theme.Palette.label)

            if let description {
                Text(description)
                    .font(Theme.Typography.body(16))
                    .foregroundStyle(Theme.Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview("Hero card") {
    ZStack {
        LinearGradient(colors: [Color(hex: "F2E2C4"), Color(hex: "FBF2E0")],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

        DiscoveryHeroCard(
            poiRef: "poi.dolores-park.sf",
            name: "Dolores Park",
            category: .park,
            weather: .clear,
            eyebrow: "Park · Mission",
            description: "Perfect day for it · lively · scenic",
            openText: "Open Now",
            walkText: "12 min"
        )
        .padding()
    }
}
