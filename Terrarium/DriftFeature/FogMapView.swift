//
//  FogMapView.swift
//  Terrarium — DriftFeature
//
//  The fog-of-war map for the Drift redesign. A real fog mask: the whole map is
//  blanketed in a cool fog, and the cells you've lit *carve feathered clearings*
//  out of it (a `Canvas` over a `MapReader`, erasing holes at each explored cell's
//  projected screen point with `.destinationOut`). New-this-session cells clear a
//  larger, brighter window than older ones — so the world genuinely "opens up" as
//  you walk, instead of a static vignette.
//
//  On top: the walked breadcrumb trail, an optional suggested loop, the user
//  location, and collectible **point spots** (glinting bonuses; a check once
//  collected). Cells are precision-7 geohash ids (decoded to centers/boxes via
//  `GeohashCell`). It's a prototype — a convincing fog reveal matters more than
//  exact geohash geometry.
//
//  Min target iOS 26: MapReader + MapProxy.convert + the Map content builder.
//

import SwiftUI
import MapKit

// MARK: - FogMapView

struct FogMapView: View {
    /// Cells lit during the current session — the bright "just discovered" tier.
    let newCells: Set<String>
    /// Every cell the user has ever lit (union of past + current sessions).
    let exploredCells: Set<String>
    /// The walked path this session, drawn as a glowing trail.
    var breadcrumbs: [Coordinate] = []
    /// Suggested loop (US-E3), drawn as a dashed line when present.
    var routeWaypoints: [Coordinate]? = nil
    /// Bonus point spots to collect (glint when open, check when collected).
    var pointSpots: [PointSpot] = []

    @Binding var position: MapCameraPosition
    var showsUserLocation: Bool = true

    var body: some View {
        MapReader { proxy in
            Map(position: $position) {
                // New-this-session cells get a bright tinted fill on top of the
                // cleared fog, so the freshest discoveries pop.
                ForEach(newCells.sorted(), id: \.self) { id in
                    if let b = GeohashCell.bounds(id) {
                        MapPolygon(coordinates: Self.corners(of: b))
                            .foregroundStyle(Theme.Garden.mint.opacity(0.45))
                            .stroke(Theme.Garden.leaf, lineWidth: 1.5)
                    }
                }

                // The path walked this session.
                if breadcrumbs.count > 1 {
                    MapPolyline(coordinates: breadcrumbs.map(\.cl))
                        .stroke(Theme.Garden.leaf,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }

                // Suggested loop (idle preview / route shaping).
                if let waypoints = routeWaypoints, waypoints.count > 1 {
                    MapPolyline(coordinates: waypoints.map(\.cl))
                        .stroke(Theme.Garden.pine.opacity(0.85),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [9, 7]))
                }

                // Collectible bonus spots.
                ForEach(pointSpots) { spot in
                    Annotation("Bonus spot", coordinate: spot.coordinate.cl) {
                        PointSpotMarker(collected: spot.collected)
                    }
                    .annotationTitles(.hidden)
                }

                if showsUserLocation { UserAnnotation() }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .tint(Theme.Garden.pine)
            // The fog mask sits above the map, carved open at explored cells.
            .overlay { fogMask(proxy: proxy) }
        }
    }

    // MARK: Fog mask

    /// Blankets the map in fog, then erases feathered holes at every explored
    /// cell's projected point. New cells clear wider/brighter than old ones.
    private func fogMask(proxy: MapProxy) -> some View {
        Canvas { context, size in
            // 1. Lay down the fog over the whole map.
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Theme.Garden.dusk.opacity(0.55))
            )
            // 2. Punch feathered clearings at each explored cell.
            context.blendMode = .destinationOut
            for id in exploredCells {
                guard let center = GeohashCell.decode(id),
                      let p = proxy.convert(center.cl, to: .local) else { continue }
                let isNew = newCells.contains(id)
                let r: CGFloat = isNew ? 58 : 40
                let core: CGFloat = isNew ? 0.95 : 0.8
                let gradient = Gradient(stops: [
                    .init(color: .black.opacity(core), location: 0),
                    .init(color: .black.opacity(core * 0.7), location: 0.55),
                    .init(color: .black.opacity(0), location: 1),
                ])
                context.fill(
                    Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                    with: .radialGradient(gradient, center: p, startRadius: 0, endRadius: r)
                )
            }
        }
        .allowsHitTesting(false)
    }

    /// Four corners of a geohash cell's bounding box as map coordinates.
    private static func corners(of b: (sw: Coordinate, ne: Coordinate)) -> [CLLocationCoordinate2D] {
        [
            CLLocationCoordinate2D(latitude: b.sw.latitude, longitude: b.sw.longitude),
            CLLocationCoordinate2D(latitude: b.sw.latitude, longitude: b.ne.longitude),
            CLLocationCoordinate2D(latitude: b.ne.latitude, longitude: b.ne.longitude),
            CLLocationCoordinate2D(latitude: b.ne.latitude, longitude: b.sw.longitude),
        ]
    }
}

// MARK: - PointSpotMarker

/// A glinting bonus marker — pulses while open, settles to a check once collected.
/// State is conveyed with icon + shape, never hue alone (a11y).
private struct PointSpotMarker: View {
    let collected: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(collected ? Theme.Garden.pine.opacity(0.9) : Theme.Garden.bloom)
                .frame(width: 30, height: 30)
                .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 2))
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            Image(systemName: collected ? "checkmark" : "sparkles")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .scaleEffect(collected ? 1.0 : (pulse ? 1.12 : 0.96))
        .animation(reduceMotion || collected ? nil
                   : .easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
        .accessibilityLabel(collected ? "Bonus spot collected" : "Uncollected bonus spot")
    }
}

// MARK: - Coordinate bridging

extension Coordinate {
    /// Bridge the Domain `Coordinate` (degrees) to CoreLocation at the MapKit edge.
    var cl: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Preview

#Preview("FogMapView — lit cells + spots") {
    FogMapPreviewHarness()
}

private struct FogMapPreviewHarness: View {
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7596, longitude: -122.4269),
            latitudinalMeters: 1200,
            longitudinalMeters: 1200
        )
    )

    private static let route: [Coordinate] = [
        Coordinate(latitude: 37.7585, longitude: -122.4290),
        Coordinate(latitude: 37.7596, longitude: -122.4269),
        Coordinate(latitude: 37.7610, longitude: -122.4250),
        Coordinate(latitude: 37.7625, longitude: -122.4262),
    ]

    var body: some View {
        let newCells = Set(Self.route.map { GeohashCell.encode($0, precision: 7) })
        let explored = newCells.union([
            GeohashCell.encode(Coordinate(latitude: 37.7570, longitude: -122.4305), precision: 7),
            GeohashCell.encode(Coordinate(latitude: 37.7640, longitude: -122.4230), precision: 7),
        ])
        let spots = PointSpotField.spots(near: Coordinate(latitude: 37.7596, longitude: -122.4269))
        return FogMapView(
            newCells: newCells,
            exploredCells: explored,
            breadcrumbs: Self.route,
            routeWaypoints: nil,
            pointSpots: spots,
            position: $position
        )
        .ignoresSafeArea()
    }
}
