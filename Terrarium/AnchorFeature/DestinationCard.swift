//
//  DestinationCard.swift
//  Terrarium — AnchorFeature
//
//  Production home for the two keeper destination card variants:
//    C · CompactDestinationRow — dense horizontal row for lists
//    D · TicketDestinationCard — boarding-pass with a perforated, notched stub
//
//  These are purely presentational (no business logic). Helper shapes and shared
//  symbols are either keeper-exclusive (moved from the workshop file) or duplicated
//  here so the cut variants in DestinationCardVariants.swift keep compiling. The
//  duplication is short-lived — Phase 2 (BUILD-01) removes the workshop file.
//

import SwiftUI

// MARK: - C · Compact row (list item)

/// A dense list row in the **ticket family** — a horizontal boarding-pass stub:
/// art on the left "tab", a perforated seam with top & bottom notches, then a
/// tight text column. Pairs with `TicketDestinationCard` (D) for lists of many.
struct CompactDestinationRow: View {
    let poiRef: String
    let name: String
    let category: POICategory
    let weather: Weather
    let eyebrow: String
    let description: String?
    let openText: String
    let walkText: String?
    /// SF Symbol for the travel pill, matching the user's transport mode.
    var travelGlyph: String = "figure.walk"

    private let artWidth: CGFloat = 112
    private let notchRadius: CGFloat = 9

    private var ticket: HTicketShape {
        HTicketShape(cornerRadius: Theme.Radius.card,
                     notchRadius: notchRadius,
                     notchFromLeading: artWidth)
    }

    var body: some View {
        HStack(spacing: 0) {
            ScenicArtBand(poiRef: poiRef, category: category, weather: weather)
                .frame(width: artWidth)
                .overlay(alignment: .topLeading) {
                    CategoryBadge(glyph: glyph(for: category)).padding(8)
                }

            VStack(alignment: .leading, spacing: 5) {
                Text(eyebrow.uppercased())
                    .font(Theme.Typography.body(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.Palette.label)

                Text(name)
                    .font(Theme.Typography.display(20, weight: .semibold))
                    .foregroundStyle(Theme.Palette.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let description {
                    Text(description)
                        .font(Theme.Typography.body(13))
                        .foregroundStyle(Theme.Palette.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    OrganicPill(systemImage: "leaf.fill", text: openText, tint: Theme.Garden.moss)
                    if let walkText {
                        OrganicPill(systemImage: travelGlyph, text: walkText, tint: Theme.Garden.bloom)
                    }
                }
                .padding(.top, 1)
            }
            .padding(Theme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 112)
        .background(ticket.fill(Theme.Palette.cardSurface))
        .clipShape(ticket)
        .overlay(ticket.stroke(Theme.Palette.cardBorder, lineWidth: 1))
        .overlay(alignment: .leading) {
            VDashedRule()
                .padding(.vertical, notchRadius + 5)
                .offset(x: artWidth)
        }
        .shadow(color: .black.opacity(0.10), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - D · Ticket (boarding pass)

/// A boarding-pass take: art header with the name, a perforated seam with side
/// notches, then a "stub" of trip details. Playful, on-theme for an Explore tab.
struct TicketDestinationCard: View {
    let poiRef: String
    let name: String
    let category: POICategory
    let weather: Weather
    let eyebrow: String
    let description: String?
    let openText: String
    let walkText: String?
    /// Caption for the travel field, matching the user's transport mode.
    var travelCaption: String = "ON FOOT"

    private let corner: CGFloat = Theme.Radius.hero
    private let notchRadius: CGFloat = 11
    private let stubHeight: CGFloat = 66
    private let perfHeight: CGFloat = 22

    private var ticket: TicketShape {
        TicketShape(cornerRadius: corner,
                    notchRadius: notchRadius,
                    notchFromBottom: stubHeight + perfHeight / 2)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            DashedRule()
                .frame(height: perfHeight)
                .padding(.horizontal, notchRadius + 6)
            stub
        }
        .background(ticket.fill(Theme.Palette.cardSurface))
        .clipShape(ticket)
        .overlay(ticket.stroke(Theme.Palette.cardBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(eyebrow)")
    }

    private var header: some View {
        ScenicArtBand(poiRef: poiRef, category: category, weather: weather)
            .aspectRatio(1.5, contentMode: .fit)
            .overlay(alignment: .topTrailing) {
                PostageStamp(glyph: glyph(for: category))
                    .padding(Theme.Spacing.m)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(eyebrow.uppercased())
                        .font(Theme.Typography.body(11, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.88))
                    Text(name)
                        .font(Theme.Typography.display(28, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)

                    // Optional vibe line — surfaced on the hero (Anchor) but left
                    // off the terse list/compact uses, which pass `nil`.
                    if let description {
                        Text(description)
                            .font(Theme.Typography.body(14))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                }
                .padding(Theme.Spacing.l)
                .padding(.top, Theme.Spacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.75)],
                                   startPoint: .top, endPoint: .bottom)
                )
            }
    }

    private var stub: some View {
        HStack(spacing: Theme.Spacing.l) {
            ticketField(caption: "STATUS", value: openText)
            Spacer(minLength: 0)
            if let walkText {
                ticketField(caption: travelCaption, value: walkText)
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .frame(height: stubHeight)
    }

    private func ticketField(caption: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(caption)
                .font(Theme.Typography.body(9, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(Theme.Palette.label)
            Text(value)
                .font(Theme.Typography.body(15, weight: .semibold))
                .foregroundStyle(Theme.Palette.title)
                .lineLimit(1)
        }
    }
}

// MARK: - Keeper-exclusive shapes (moved from DestinationCardVariants.swift)

/// Rounded-rect ticket outline with a circular notch punched out of each side.
private struct TicketShape: Shape {
    var cornerRadius: CGFloat = 24
    var notchRadius: CGFloat = 11
    /// Vertical position of the notch centers, measured up from the bottom edge.
    var notchFromBottom: CGFloat = 76

    func path(in rect: CGRect) -> Path {
        let base = Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous)
        let y = rect.maxY - notchFromBottom
        let left = Path(ellipseIn: CGRect(x: rect.minX - notchRadius, y: y - notchRadius,
                                          width: notchRadius * 2, height: notchRadius * 2))
        let right = Path(ellipseIn: CGRect(x: rect.maxX - notchRadius, y: y - notchRadius,
                                           width: notchRadius * 2, height: notchRadius * 2))
        return base.subtracting(left).subtracting(right)
    }
}

/// Horizontal ticket outline — a notch punched out of the top and bottom edges
/// at `notchFromLeading`, making the art "tab" tear away from the detail column.
private struct HTicketShape: Shape {
    var cornerRadius: CGFloat = 18
    var notchRadius: CGFloat = 9
    /// X position of the notch centers, measured from the leading edge.
    var notchFromLeading: CGFloat = 112

    func path(in rect: CGRect) -> Path {
        let base = Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous)
        let x = rect.minX + notchFromLeading
        let top = Path(ellipseIn: CGRect(x: x - notchRadius, y: rect.minY - notchRadius,
                                         width: notchRadius * 2, height: notchRadius * 2))
        let bottom = Path(ellipseIn: CGRect(x: x - notchRadius, y: rect.maxY - notchRadius,
                                            width: notchRadius * 2, height: notchRadius * 2))
        return base.subtracting(top).subtracting(bottom)
    }
}

/// Small frosted category badge for the row's art tab (echoes D's stamp).
private struct CategoryBadge: View {
    let glyph: String
    var body: some View {
        Image(systemName: glyph)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.Palette.title)
            .padding(7)
            .background(.ultraThinMaterial, in: .circle)
            .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
    }
}

/// A centered vertical dashed line — the row's perforated seam.
private struct VDashedRule: View {
    var body: some View {
        VLine()
            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
            .foregroundStyle(Theme.Palette.cardBorder)
            .frame(width: 1)
    }
}

private struct VLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return p
    }
}

// MARK: - Shared symbols (duplicated verbatim from DestinationCardVariants.swift)
// The originals remain in the workshop file so PostcardDestinationCard keeps
// compiling. This duplication disappears in Phase 2 when the workshop file is removed.

/// The little perforated stamp in the ticket card's corner.
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

// MARK: - POICategory display label (file-private copy — matches AnchorView.swift exactly)

private extension POICategory {
    var label: String {
        switch self {
        case .park:       return "Park"
        case .coffee:     return "Coffee"
        case .bookstore:  return "Bookstore"
        case .restaurant: return "Restaurant"
        case .viewpoint:  return "Viewpoint"
        case .market:     return "Market"
        case .museum:     return "Museum"
        case .bar:        return "Bar"
        case .other:      return "Spot"
        }
    }
}

// MARK: - Real-data Previews (D-03 / CARD-02)
// Driven by StubPOICatalog + StubRecommender — never hardcoded demo literals.

private final class PreviewLocationSession: LocationSessionProviding {
    private(set) var isActive = false
    func start() { isActive = true }
    func stop() { isActive = false }
    func breadcrumbStream() -> AsyncStream<Coordinate> { AsyncStream { $0.finish() } }
    func currentCoordinate() async -> Coordinate? {
        Coordinate(latitude: 37.7686, longitude: -122.4269)
    }
}

private struct PreviewClearWeather: WeatherProviding {
    func current() async -> Weather { .clear }
}

private func makeCardPreviewVM() -> AnchorViewModel {
    let store = InMemoryDiscoveryStore()
    let catalog = StubPOICatalog()
    return AnchorViewModel(
        catalog: catalog,
        weather: PreviewClearWeather(),
        recommender: StubRecommender(catalog: catalog, discoveries: store),
        location: PreviewLocationSession(),
        discoveries: store
    )
}

private struct TicketCardPreview: View {
    @State private var vm = makeCardPreviewVM()
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "F2E8D2"), Color(hex: "FBF2E0")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            if let poi = vm.pick {
                TicketDestinationCard(
                    poiRef: poi.poiRef,
                    name: poi.name,
                    category: poi.category,
                    weather: vm.context?.weather ?? .clear,
                    eyebrow: "\(poi.category.label) · \(poi.neighborhood)",
                    description: vm.vibeLine,
                    openText: vm.pickIsLikelyOpen ? "Open Now" : "Hours vary",
                    walkText: vm.travelInfo.map { "\($0.minutes) min" },
                    travelCaption: (vm.travelInfo?.mode ?? .walk).ticketCaption
                )
                .padding()
            }
        }
        .task { await vm.refresh() }
    }
}

private struct CompactRowPreview: View {
    @State private var vm = makeCardPreviewVM()
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "F2E8D2"), Color(hex: "FBF2E0")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            if let poi = vm.pick {
                CompactDestinationRow(
                    poiRef: poi.poiRef,
                    name: poi.name,
                    category: poi.category,
                    weather: vm.context?.weather ?? .clear,
                    eyebrow: "\(poi.category.label) · \(poi.neighborhood)",
                    description: vm.vibeLine,
                    openText: vm.pickIsLikelyOpen ? "Open Now" : "Hours vary",
                    walkText: vm.travelInfo.map { "\($0.minutes) min" },
                    travelGlyph: (vm.travelInfo?.mode ?? .walk).systemImage
                )
                .padding()
            }
        }
        .task { await vm.refresh() }
    }
}

#Preview("D · Ticket (real data)") {
    TicketCardPreview()
}

#Preview("C · Compact row (real data)") {
    CompactRowPreview()
}
