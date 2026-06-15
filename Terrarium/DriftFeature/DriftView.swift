//
//  DriftView.swift
//  Terrarium — Prototypes
//
//  A Liquid-Glass redesign of the Drift experience ("you're out walking") in the
//  "Hidden Garden" language — cooler and mistier than the warm Anchor screen. It
//  is a drop-in alternative to DriftView: it drives the SAME, unchanged
//  `DriftViewModel` (start/end ramble · live stats · fog-of-war cells · route
//  shaping) — only the presentation changes.
//
//  Three states:
//    1. Idle / pre-ramble — "Start a ramble." hero, a fog-map preview of what
//       you've explored, DriftRouteControls, and the focal Start CTA.
//    2. Active ramble      — the fog-of-war map fills the screen with a floating
//       glass DriftStatStrip up top and a prominent End control pinned below.
//    3. Summary            — a glass card: cells lit · distance · time, with a
//       "view on globe" affordance (presented as a sheet).
//
//  iOS 26 APIs: glassEffect / glass button styles (chrome + stats + CTA),
//  .scrollEdgeEffectStyle for the floating idle bars, MeshGradient cool base,
//  and a restyled MapKit Map (see FogMapView).
//

import SwiftUI
import MapKit

struct DriftView: View {
    @State var viewModel: DriftViewModel
    /// Whether to draw this screen's own floating bottom nav. When hosted inside
    /// `ExploreShellView`, the shell supplies the real 3-tab nav, so it passes
    /// `showsNavBar: false` to avoid a duplicate bar. Defaults to `true` so the
    /// standalone screen and all previews are unchanged.
    var showsNavBar: Bool = true
    @State private var navSelection: DiscoveryNavItem = .explore
    @State private var showSummary = false
    @State private var mapPosition: MapCameraPosition = .automatic

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isActive: Bool { viewModel.session?.isActive == true }

    var body: some View {
        ZStack {
            DriftBackground().ignoresSafeArea()

            if isActive {
                activeContent
            } else {
                idleContent
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.4), value: isActive)
        .sheet(isPresented: $showSummary) {
            if let summary = viewModel.summary {
                DriftSummaryCard(
                    summary: summary,
                    onViewGlobe: {
                        showSummary = false
                        navSelection = .garden
                    },
                    onDone: { showSummary = false }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
            }
        }
        // Present the summary whenever a ramble produces one (regardless of how
        // it ended). `startRamble()` clears `summary`, so this only fires on end.
        .onChange(of: viewModel.summary) { _, summary in
            if summary != nil { showSummary = true }
        }
        // Follow the walker while a session is running.
        .onChange(of: viewModel.session?.breadcrumbs.last) { _, latest in
            guard let coord = latest else { return }
            let region = MKCoordinateRegion(
                center: coord.cl,
                latitudinalMeters: 700,
                longitudinalMeters: 700
            )
            if reduceMotion {
                mapPosition = .region(region)
            } else {
                withAnimation(.easeInOut(duration: 0.8)) { mapPosition = .region(region) }
            }
        }
    }

    // MARK: - Idle / pre-ramble

    private var idleContent: some View {
        // A fixed (non-scrolling) composition: the map fills the space between the
        // header and the controls. Deliberately NOT a ScrollView — a MapKit `Map`
        // inside one triggers a scroll-to-visible on tile load that shoves the
        // header under the floating bar.
        VStack(spacing: Theme.Spacing.l) {
            idleHeader
            mapPreview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            DriftRouteControls(viewModel: viewModel)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.s)
        .padding(.bottom, Theme.Spacing.s)
        .safeAreaInset(edge: .top) {
            DiscoveryTopBar(weatherSystemImage: "cloud.fog.fill", weatherText: dayPartText)
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.s)
        }
        .safeAreaInset(edge: .bottom) { pinnedStart }
        .safeAreaInset(edge: .bottom) {
            if showsNavBar {
                DiscoveryTabBar(selection: $navSelection)
                    .padding(.bottom, Theme.Spacing.s)
            }
        }
    }

    private var idleHeader: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("DRIFT")
                .font(Theme.Typography.body(13, weight: .semibold))
                .tracking(2.0)
                .foregroundStyle(Theme.Garden.dusk)
            Text("Start a ramble.")
                .font(Theme.Typography.display(32, weight: .bold))
                .foregroundStyle(Theme.Palette.title)
                .multilineTextAlignment(.center)
            Text("Wander with no destination. Light up the map as you go.")
                .font(Theme.Typography.body(15))
                .foregroundStyle(Theme.Palette.secondary)
                .multilineTextAlignment(.center)
        }
    }

    /// A clipped fog-map preview of what's been explored (+ a previewed loop).
    private var mapPreview: some View {
        FogMapView(
            newCells: viewModel.newCells,
            exploredCells: viewModel.allExploredCells,
            routeWaypoints: viewModel.routeWaypoints,
            pointSpots: viewModel.pointSpots,
            position: $mapPosition
        )
        .frame(minHeight: 200)
        // Idle preview is decorative — disable interaction (you start a ramble to
        // get the interactive, full-screen map).
        .allowsHitTesting(false)
        .clipShape(.rect(cornerRadius: Theme.Radius.heroInner))
        .overlay(alignment: .topLeading) {
            OrganicPill(systemImage: "map.fill", text: exploredCountText, tint: Theme.Garden.pine)
                .padding(Theme.Spacing.m)
        }
        .overlay(alignment: .topTrailing) {
            WashiTape(width: 84, height: 22, rotation: .degrees(5))
                .offset(x: -10, y: 8)
        }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.heroInner, style: .continuous)
                .strokeBorder(Theme.Palette.cardBorder.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 14, y: 8)
        .accessibilityLabel("Your explored map. \(exploredCountText).")
    }

    private var pinnedStart: some View {
        StartRambleButton { viewModel.startRamble() }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.m)
            .background(
                LinearGradient(
                    colors: [Theme.Garden.mist.opacity(0), Theme.Garden.mist.opacity(0.85), Theme.Garden.mist],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            )
    }

    // MARK: - Active ramble

    private var activeContent: some View {
        FogMapView(
            newCells: viewModel.newCells,
            exploredCells: viewModel.allExploredCells,
            breadcrumbs: viewModel.session?.breadcrumbs ?? [],
            routeWaypoints: viewModel.routeWaypoints,
            pointSpots: viewModel.pointSpots,
            position: $mapPosition
        )
        .ignoresSafeArea()
        .safeAreaInset(edge: .top) {
            VStack(spacing: Theme.Spacing.s) {
                DiscoveryTopBar(weatherSystemImage: "cloud.fog.fill", weatherText: "Rambling")
                DriftStatStrip(
                    elapsedSeconds: viewModel.elapsedSeconds,
                    distanceMeters: viewModel.distanceMeters,
                    cellsLit: viewModel.newCells.count,
                    points: viewModel.pointsThisSession
                )
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.s)
        }
        .safeAreaInset(edge: .bottom) {
            StartRambleButton(
                title: "End ramble",
                systemImage: "stop.circle.fill",
                tint: Theme.Garden.dusk
            ) {
                viewModel.endRamble()
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.l)
        }
    }

    // MARK: - Helpers

    private var exploredCountText: String {
        let n = viewModel.allExploredCells.count
        return n == 1 ? "1 area lit" : "\(n) areas lit"
    }

    private var dayPartText: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<21: return "Evening"
        default:      return "Night"
        }
    }
}

// MARK: - DriftBackground

/// A cool, misty MeshGradient base — keeps the warm cream identity but leans
/// sage/fog so Drift reads cooler than the Anchor screen.
struct DriftBackground: View {
    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                .init(0, 0),   .init(0.5, 0),   .init(1, 0),
                .init(0, 0.5), .init(0.5, 0.5), .init(1, 0.5),
                .init(0, 1),   .init(0.5, 1),   .init(1, 1),
            ],
            colors: [
                Color(hex: "ECEFE6"), Color(hex: "EFF1E2"), Color(hex: "E4ECEA"),
                Color(hex: "DDE7E1"), Color(hex: "D2E0DA"), Color(hex: "E0E8E1"),
                Color(hex: "D4E0D8"), Color(hex: "CAD7D0"), Color(hex: "DBE4DC"),
            ],
            smoothsColors: true
        )
    }
}

// MARK: - DriftSummaryCard

/// End-of-ramble glass summary: cells lit · distance · time, with a "view on
/// globe" affordance. Presented as a sheet over the cool base.
private struct DriftSummaryCard: View {
    let summary: RambleSummary
    let onViewGlobe: () -> Void
    let onDone: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            DriftBackground().ignoresSafeArea()

            VStack(spacing: Theme.Spacing.xl) {
                VStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 42))
                        .foregroundStyle(Theme.Garden.pine)
                        .symbolEffect(.bounce, value: appeared)
                    Text("Ramble complete")
                        .font(Theme.Typography.display(26, weight: .bold))
                        .foregroundStyle(Theme.Palette.title)
                }

                HStack(spacing: Theme.Spacing.m) {
                    SummaryStat(icon: "circle.grid.2x2.fill",
                                value: "\(summary.newCellsCount)", label: "Cells lit")
                    SummaryStat(icon: "figure.walk",
                                value: distanceText, label: "Distance")
                    SummaryStat(icon: "clock",
                                value: durationText, label: "Time")
                }

                VStack(spacing: Theme.Spacing.m) {
                    Button(action: onViewGlobe) {
                        Label("View on globe", systemImage: "globe.americas.fill")
                            .font(Theme.Typography.body(17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.Garden.pine)
                    .controlSize(.large)

                    Button(action: onDone) {
                        Text("Done")
                            .font(Theme.Typography.body(15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.glass)
                    .tint(Theme.Garden.mossLight)
                }
            }
            .padding(Theme.Spacing.xl)
        }
        .onAppear { if !reduceMotion { appeared = true } }
    }

    private var distanceText: String {
        summary.distanceMeters >= 1000
            ? String(format: "%.1f km", summary.distanceMeters / 1000)
            : "\(Int(summary.distanceMeters)) m"
    }

    private var durationText: String {
        let m = Int(summary.durationSeconds) / 60
        let s = Int(summary.durationSeconds) % 60
        return m > 0 ? "\(m) min" : "\(s) sec"
    }
}

/// One glass stat tile inside the summary card.
private struct SummaryStat: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Theme.Garden.pineLight)
            Text(value)
                .font(Theme.Typography.display(20, weight: .semibold))
                .foregroundStyle(Theme.Palette.title)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(Theme.Typography.body(11))
                .foregroundStyle(Theme.Palette.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.l)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.glass))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Previews

#Preview("Drift — idle") {
    DriftView(viewModel: DriftViewModel(
        location: StubLocationSession(),
        recommender: StubRecommender(
            catalog: StubPOICatalog(),
            discoveries: InMemoryDiscoveryStore()
        ),
        discoveries: InMemoryDiscoveryStore()
    ))
}

#Preview("Drift — idle, explored") {
    let store = InMemoryDiscoveryStore()
    for coord in DriftPreviewRoute.explored {
        store.record(Discovery(
            target: .cell(id: GeohashCell.encode(coord, precision: 7)),
            context: DiscoveryContext(weather: .fog, timeOfDay: .afternoon)
        ))
    }
    return DriftView(viewModel: DriftViewModel(
        location: StubLocationSession(),
        recommender: StubRecommender(catalog: StubPOICatalog(), discoveries: store),
        discoveries: store
    ))
}

#Preview("Drift — active") {
    DriftActivePreview()
}

#Preview("Drift — summary") {
    DriftSummaryCard(
        summary: RambleSummary(
            newCellsCount: 12,
            totalCellsCount: 47,
            distanceMeters: 2640,
            durationSeconds: 1925
        ),
        onViewGlobe: {},
        onDone: {}
    )
}

// MARK: - Preview support

/// Fixture coordinates around Dolores Park, spaced ~150 m+ apart so each lands in
/// a distinct precision-7 geohash cell.
private enum DriftPreviewRoute {
    static let walked: [Coordinate] = [
        Coordinate(latitude: 37.7585, longitude: -122.4292),
        Coordinate(latitude: 37.7596, longitude: -122.4269),
        Coordinate(latitude: 37.7611, longitude: -122.4250),
        Coordinate(latitude: 37.7626, longitude: -122.4231),
        Coordinate(latitude: 37.7640, longitude: -122.4250),
    ]
    static let explored: [Coordinate] = walked + [
        Coordinate(latitude: 37.7568, longitude: -122.4310),
        Coordinate(latitude: 37.7655, longitude: -122.4205),
    ]
}

/// Streams the fixture route so the active-state preview lights cells live.
private final class DriftPreviewLocationSession: LocationSessionProviding {
    private(set) var isActive = false
    func start() { isActive = true }
    func stop() { isActive = false }
    func currentCoordinate() async -> Coordinate? { DriftPreviewRoute.walked.first }
    func breadcrumbStream() -> AsyncStream<Coordinate> {
        AsyncStream { continuation in
            Task {
                for coord in DriftPreviewRoute.walked {
                    try? await Task.sleep(for: .milliseconds(500))
                    continuation.yield(coord)
                }
                continuation.finish()
            }
        }
    }
}

private struct DriftActivePreview: View {
    @State private var viewModel = DriftViewModel(
        location: DriftPreviewLocationSession(),
        recommender: StubRecommender(
            catalog: StubPOICatalog(),
            discoveries: InMemoryDiscoveryStore()
        ),
        discoveries: InMemoryDiscoveryStore()
    )

    var body: some View {
        DriftView(viewModel: viewModel)
            .onAppear { viewModel.startRamble() }
    }
}
