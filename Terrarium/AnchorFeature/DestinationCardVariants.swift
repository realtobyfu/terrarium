//
//  DestinationCardVariants.swift
//  Terrarium — Prototypes / workshop
//
//  Visual-design explorations for the Anchor destination card. The shipping card
//  is `TicketDestinationCard` (now in DestinationCard.swift). These are two
//  alternative *looks* for the same information — same inputs as the shipping card,
//  so any of them can drop into AnchorView behind the same view-model wiring:
//
//    A · ImmersiveDestinationCard — full-bleed art, text on a bottom scrim
//    B · PostcardDestinationCard  — framed photo + postage stamp, stationery feel
//
//  C · CompactDestinationRow and D · TicketDestinationCard have been promoted to
//  the production file DestinationCard.swift (Phase 1, D-01). The previews for
//  those two keepers are now in that file. This workshop file remains for Phase 2
//  (BUILD-01) cleanup.
//
//  All pure & context-agnostic (pre-formatted strings in, no business logic), so
//  they preview in isolation. Sample copy reuses the approved blurbs.
//

import SwiftUI

// MARK: - A · Immersive (full-bleed)

/// Edge-to-edge art with the title and blurb floating on a bottom gradient scrim.
/// The most "photographic / modern travel app" of the set — no cream frame.
struct ImmersiveDestinationCard: View {
    let poiRef: String
    let name: String
    let category: POICategory
    let weather: Weather
    let eyebrow: String
    let description: String?
    let openText: String
    let walkText: String?

    var body: some View {
        ScenicArtBand(poiRef: poiRef, category: category, weather: weather)
            .aspectRatio(0.82, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topTrailing) {
                pills.padding(Theme.Spacing.l)
            }
            .overlay(alignment: .bottom) { scrim }
            .clipShape(.rect(cornerRadius: Theme.Radius.hero, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.22), radius: 22, y: 12)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(name), \(eyebrow)")
    }

    private var pills: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                OrganicPill(systemImage: "leaf.fill", text: openText, tint: Theme.Garden.moss)
                if let walkText {
                    OrganicPill(systemImage: "figure.walk", text: walkText, tint: Theme.Garden.bloom)
                }
            }
        }
    }

    private var scrim: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(eyebrow.uppercased())
                .font(Theme.Typography.body(12, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.85))

            Text(name)
                .font(Theme.Typography.display(34, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            if let description {
                Text(description)
                    .font(Theme.Typography.body(15))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.35), .black.opacity(0.82)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }
}

// MARK: - B · Postcard (stationery)

/// A framed photo with a corner "postage stamp", a postmark eyebrow, and the
/// blurb under a dashed mailing rule. Leans into the travel-journal identity.
struct PostcardDestinationCard: View {
    let poiRef: String
    let name: String
    let category: POICategory
    let weather: Weather
    let eyebrow: String
    let description: String?
    let openText: String
    let walkText: String?

    var body: some View {
        SoftPanel(cornerRadius: Theme.Radius.hero) {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                framedPhoto
                textBlock
            }
            .padding(Theme.Spacing.l)
        }
    }

    private var framedPhoto: some View {
        ScenicArtBand(poiRef: poiRef, category: category, weather: weather)
            .aspectRatio(1.5, contentMode: .fit)
            .clipShape(.rect(cornerRadius: Theme.Radius.chip))
            .padding(7)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.chip + 7, style: .continuous)
                    .fill(.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.chip + 7, style: .continuous)
                    .strokeBorder(Theme.Palette.cardBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
            .overlay(alignment: .bottomLeading) {
                pills.padding(12)
            }
            .overlay(alignment: .topTrailing) {
                PostageStamp(glyph: glyph(for: category))
                    .rotationEffect(.degrees(4))
                    .offset(x: -2, y: -10)
            }
    }

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(eyebrow.uppercased())
                .font(Theme.Typography.body(11, weight: .semibold))
                .tracking(2.0)
                .foregroundStyle(Theme.Palette.label)

            Text(name)
                .font(Theme.Typography.display(28, weight: .semibold))
                .foregroundStyle(Theme.Palette.title)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            DashedRule()
                .frame(height: 1)
                .padding(.vertical, 2)

            if let description {
                Text(description)
                    .font(Theme.Typography.body(15))
                    .foregroundStyle(Theme.Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pills: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                OrganicPill(systemImage: "leaf.fill", text: openText, tint: Theme.Garden.moss)
                if let walkText {
                    OrganicPill(systemImage: "figure.walk", text: walkText, tint: Theme.Garden.bloom)
                }
            }
        }
    }
}

/// The little perforated stamp in the postcard's corner.
private struct PostageStamp: View {
    let glyph: String

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: glyph)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.Garden.pine)
            Text("SF")
                .font(Theme.Typography.body(9, weight: .heavy))
                .tracking(1)
                .foregroundStyle(Theme.Palette.label)
        }
        .frame(width: 44, height: 52)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Theme.Palette.chipSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [2, 2.4]))
                .foregroundStyle(Theme.Palette.label.opacity(0.7))
        )
        .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
    }
}

// MARK: - Shared bits

/// A centered horizontal dashed line — the "mailing rule" / perforation.
private struct DashedRule: View {
    var body: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
            .foregroundStyle(Theme.Palette.cardBorder)
            .frame(height: 1)
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

/// Category → SF Symbol, for stamps and badges.
private func glyph(for category: POICategory) -> String {
    switch category {
    case .park:       return "tree.fill"
    case .coffee:     return "cup.and.saucer.fill"
    case .bookstore:  return "books.vertical.fill"
    case .restaurant: return "fork.knife"
    case .viewpoint:  return "binoculars.fill"
    case .market:     return "basket.fill"
    case .museum:     return "building.columns.fill"
    case .bar:        return "wineglass.fill"
    case .other:      return "sparkles"
    }
}

// MARK: - Previews

private struct PageBackdrop<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "F2E2C4"), Color(hex: "FBF2E0")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            content.padding()
        }
    }
}

#Preview("A · Immersive") {
    PageBackdrop {
        ImmersiveDestinationCard(
            poiRef: "poi.sutro-baths.sf", name: "Sutro Baths", category: .viewpoint, weather: .fog,
            eyebrow: "Ocean Ruins · Lands End",
            description: "The concrete bones of a Victorian swimming palace, half-claimed by the Pacific. Time it for sunset and the tide pools below catch fire.",
            openText: "Open · Dusk", walkText: "12 min")
    }
}

#Preview("B · Postcard") {
    PageBackdrop {
        PostcardDestinationCard(
            poiRef: "poi.wave-organ.sf", name: "Wave Organ", category: .other, weather: .fog,
            eyebrow: "Sound Sculpture · Marina",
            description: "Lean an ear to the pipes and the bay answers — a tide-powered organ built from salvaged cemetery marble. Come an hour before high tide and let the swell do the playing.",
            openText: "Always Open", walkText: "9 min")
    }
}

/// The money shot: A and B designs, for picking a direction.
#Preview("Compare · 4 designs") {
    StyleComparePreview()
}

private struct StyleComparePreview: View {
    private let poiRef = "poi.sutro-baths.sf"
    private let name = "Sutro Baths"
    private let category = POICategory.viewpoint
    private let weather = Weather.fog
    private let eyebrow = "Ocean Ruins · Lands End"
    private let blurb = "The concrete bones of a Victorian swimming palace, half-claimed by the Pacific. Time it for sunset and the tide pools below catch fire."
    private let openText = "Open · Dusk"
    private let walk: String? = "12 min"

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                tag("A · Immersive")
                ImmersiveDestinationCard(poiRef: poiRef, name: name, category: category, weather: weather,
                                         eyebrow: eyebrow, description: blurb, openText: openText, walkText: walk)
                tag("B · Postcard")
                PostcardDestinationCard(poiRef: poiRef, name: name, category: category, weather: weather,
                                        eyebrow: eyebrow, description: blurb, openText: openText, walkText: walk)
                tag("C · Compact row")
                CompactDestinationRow(poiRef: poiRef, name: name, category: category, weather: weather,
                                      eyebrow: eyebrow, description: blurb, openText: openText, walkText: walk)
                tag("D · Ticket")
                TicketDestinationCard(poiRef: poiRef, name: name, category: category, weather: weather,
                                      eyebrow: eyebrow, description: blurb, openText: openText, walkText: walk)
            }
            .padding()
        }
        .background(
            LinearGradient(colors: [Color(hex: "F2E2C4"), Color(hex: "FBF2E0")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.body(12, weight: .heavy))
            .tracking(1.5)
            .foregroundStyle(Theme.Palette.label)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
