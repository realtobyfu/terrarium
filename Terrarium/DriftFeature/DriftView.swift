//
//  DriftView.swift
//  Terrarium — DriftFeature
//
//  US-E1 (session controls + live stats) + US-E2 (fog-of-war map).
//
//  Layout
//  ──────
//  • A MapKit `Map` fills the screen, showing explored cells revealed as
//    coloured overlays and unexplored area implied by their absence.
//    — newThisSession cells: accent-teal, semi-opaque.
//    — previously explored cells: cream-white, lower opacity.
//  • A route overlay draws the suggested waypoints (US-E3) when available.
//  • A bottom control panel shows live stats and the Start/End button.
//  • A post-session summary card slides up after `endRamble()`.
//
//  Fog-of-war rendering approach
//  ──────────────────────────────
//  True fog-of-war (dark overlay with holes) requires a custom `MKOverlayRenderer`
//  and is deferred to a follow-up polish phase. The pilot renders the *revealed*
//  cells as coloured tile rectangles instead — simpler, zero-UIKit-bridging, and
//  already legible on a map. The orchestrator's smoke-test can verify the cell
//  tiles appear on the map.
//
//  Constraints
//  ───────────
//  • Do NOT run Simulator screenshots (see decisions doc Wave-2 note).
//  • Do NOT edit ExploreShellView — DriftPlaceholderView references DriftViewModel
//    already; the shell just needs to swap DriftPlaceholderView → DriftView.
//    That swap happens at the integration step, not here.
//

import SwiftUI
import MapKit

// MARK: - DriftView

struct DriftView: View {

    @State var viewModel: DriftViewModel

    /// Map camera position — follows the user when a session is active.
    @State private var position: MapCameraPosition = .automatic

    /// Whether to show the summary card.
    @State private var showSummary = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Map ──────────────────────────────────────────────────────────
            Map(position: $position) {
                // Explored cell overlays (US-E2)
                ForEach(viewModel.allExploredCells.sorted(), id: \.self) { cellID in
                    if let bounds = GeohashCell.bounds(cellID) {
                        let isNew = viewModel.newCells.contains(cellID)
                        MapPolygon(
                            coordinates: cellCorners(sw: bounds.sw, ne: bounds.ne)
                        )
                        .foregroundStyle(isNew ? cellNewColor : cellOldColor)
                        .stroke(isNew ? Theme.Palette.accent.opacity(0.6) : Color.white.opacity(0.2), lineWidth: 1)
                    }
                }

                // Route waypoints overlay (US-E3)
                if let waypoints = viewModel.routeWaypoints, waypoints.count > 1 {
                    MapPolyline(coordinates: waypoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
                        .stroke(Theme.Palette.accent, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                }

                // User location
                UserAnnotation()
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .ignoresSafeArea()

            // ── Controls ─────────────────────────────────────────────────────
            VStack(spacing: 0) {
                // Live stats strip (only while active)
                if viewModel.session?.isActive == true {
                    StatsStrip(
                        elapsed:  viewModel.elapsedSeconds,
                        distance: viewModel.distanceMeters,
                        cells:    viewModel.newCells.count
                    )
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.bottom, Theme.Spacing.s)
                }

                // Route randomness + generate button (only when idle)
                if viewModel.session?.isActive != true {
                    RouteControls(viewModel: viewModel)
                        .padding(.horizontal, Theme.Spacing.l)
                        .padding(.bottom, Theme.Spacing.s)
                }

                // Primary CTA
                if viewModel.session?.isActive == true {
                    GlowButton(title: "End Ramble") {
                        viewModel.endRamble()
                        showSummary = viewModel.summary != nil
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.bottom, Theme.Spacing.l)
                } else {
                    GlowButton(title: "Start a Ramble") {
                        viewModel.startRamble()
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.bottom, Theme.Spacing.l)
                }
            }
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.l)
        }
        // Summary sheet
        .sheet(isPresented: $showSummary) {
            if let s = viewModel.summary {
                SummaryCard(summary: s, onDismiss: { showSummary = false })
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
        // Keep camera centred on user while rambling.
        .onChange(of: viewModel.session?.breadcrumbs.last) { _, latest in
            if let c = latest {
                withAnimation(.easeInOut(duration: 0.8)) {
                    position = .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: c.latitude, longitude: c.longitude),
                        latitudinalMeters: 600,
                        longitudinalMeters: 600
                    ))
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // MARK: Helpers
    // -------------------------------------------------------------------------

    private var cellNewColor: Color {
        Theme.Palette.accent.opacity(0.35)
    }

    private var cellOldColor: Color {
        Color.white.opacity(0.18)
    }

    /// Returns four corners of a geohash cell rectangle as `CLLocationCoordinate2D`.
    private func cellCorners(sw: Coordinate, ne: Coordinate) -> [CLLocationCoordinate2D] {
        [
            CLLocationCoordinate2D(latitude: sw.latitude, longitude: sw.longitude),
            CLLocationCoordinate2D(latitude: sw.latitude, longitude: ne.longitude),
            CLLocationCoordinate2D(latitude: ne.latitude, longitude: ne.longitude),
            CLLocationCoordinate2D(latitude: ne.latitude, longitude: sw.longitude),
        ]
    }
}

// MARK: - StatsStrip

private struct StatsStrip: View {
    let elapsed:  TimeInterval
    let distance: Double
    let cells:    Int

    var body: some View {
        HStack(spacing: Theme.Spacing.xl) {
            StatItem(label: "Time",    value: formatElapsed(elapsed))
            StatItem(label: "Distance", value: formatDistance(distance))
            StatItem(label: "Cells",   value: "\(cells)")
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity)
        .background(Theme.Palette.chipSurface.opacity(0.9),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
    }

    private func formatElapsed(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func formatDistance(_ d: Double) -> String {
        d >= 1000 ? String(format: "%.1f km", d / 1000) : "\(Int(d)) m"
    }
}

private struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.Typography.display(18, weight: .medium))
                .foregroundStyle(Theme.Palette.title)
            Text(label)
                .font(Theme.Typography.body(11))
                .foregroundStyle(Theme.Palette.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - RouteControls

private struct RouteControls: View {
    @State var viewModel: DriftViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            HStack {
                Text("Duration")
                    .font(Theme.Typography.body(13))
                    .foregroundStyle(Theme.Palette.secondary)
                Spacer()
                Text("\(Int(viewModel.targetMinutes)) min")
                    .font(Theme.Typography.body(13, weight: .medium))
                    .foregroundStyle(Theme.Palette.title)
            }
            Slider(value: $viewModel.targetMinutes, in: 10...90, step: 5)
                .tint(Theme.Palette.accent)

            HStack {
                Text("Randomness")
                    .font(Theme.Typography.body(13))
                    .foregroundStyle(Theme.Palette.secondary)
                Spacer()
                Text(randomnessLabel)
                    .font(Theme.Typography.body(13, weight: .medium))
                    .foregroundStyle(Theme.Palette.title)
            }
            Slider(value: $viewModel.routeRandomness, in: 0...1)
                .tint(Theme.Palette.accent)

            Button {
                viewModel.generateRoute()
            } label: {
                Label("Suggest a route", systemImage: "arrow.triangle.turn.up.right.diamond")
                    .font(Theme.Typography.body(14, weight: .medium))
                    .foregroundStyle(Theme.Palette.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.m)
        .background(Theme.Palette.chipSurface.opacity(0.9),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
    }

    private var randomnessLabel: String {
        switch viewModel.routeRandomness {
        case 0..<0.2:  return "On the path"
        case 0.2..<0.5: return "Guided"
        case 0.5..<0.8: return "Mixed"
        default:        return "Surprise me"
        }
    }
}

// MARK: - SummaryCard

private struct SummaryCard: View {
    let summary: RambleSummary
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Text("Ramble complete")
                .font(Theme.Typography.display(24, weight: .medium))
                .foregroundStyle(Theme.Palette.title)

            HStack(spacing: Theme.Spacing.xl) {
                SummaryItem(icon: "map.fill",
                            value: "\(summary.newCellsCount)",
                            label: "New cells")
                SummaryItem(icon: "arrow.triangle.swap",
                            value: formatDistance(summary.distanceMeters),
                            label: "Distance")
                SummaryItem(icon: "clock.fill",
                            value: formatDuration(summary.durationSeconds),
                            label: "Duration")
            }
            .padding(Theme.Spacing.l)
            .background(Theme.Palette.cardSurface,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(Theme.Palette.cardBorder)
            )

            GlowButton(title: "Done", action: onDismiss)
        }
        .padding(Theme.Spacing.xl)
        .presentationBackground(Theme.Palette.chipSurface)
    }

    private func formatDistance(_ d: Double) -> String {
        d >= 1000 ? String(format: "%.1f km", d / 1000) : "\(Int(d)) m"
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        return "\(m) min"
    }
}

private struct SummaryItem: View {
    let icon:  String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(Theme.Palette.accent)
            Text(value)
                .font(Theme.Typography.display(18, weight: .medium))
                .foregroundStyle(Theme.Palette.title)
            Text(label)
                .font(Theme.Typography.body(11))
                .foregroundStyle(Theme.Palette.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview("DriftView — idle") {
    DriftView(viewModel: DriftViewModel(
        location: StubLocationSession(),
        recommender: StubRecommender(
            catalog: StubPOICatalog(),
            discoveries: InMemoryDiscoveryStore()
        ),
        discoveries: InMemoryDiscoveryStore()
    ))
}

#Preview("DriftView — with cells") {
    let store = InMemoryDiscoveryStore()
    // Seed a few cells around Dolores Park, SF
    let fixtures: [Coordinate] = [
        Coordinate(latitude: 37.7596, longitude: -122.4269),
        Coordinate(latitude: 37.7604, longitude: -122.4280),
        Coordinate(latitude: 37.7590, longitude: -122.4260),
    ]
    for coord in fixtures {
        store.record(Discovery(
            target: .cell(id: GeohashCell.encode(coord, precision: 7)),
            context: DiscoveryContext(weather: .clear, timeOfDay: .afternoon)
        ))
    }
    return DriftView(viewModel: DriftViewModel(
        location: StubLocationSession(),
        recommender: StubRecommender(
            catalog: StubPOICatalog(),
            discoveries: store
        ),
        discoveries: store
    ))
}
