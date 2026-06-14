//
//  FogMapView.swift
//  Terrarium — Prototypes
//
//  The fog-of-war map for the Liquid-Glass Drift redesign. Restyles a SwiftUI
//  `Map` to feel "terrarium": the standard map is muted by a cool wash, fog
//  closes in at the periphery (a radial vignette — the "fog of war" atmosphere),
//  and the cells you've lit are drawn as soft glowing tiles on top.
//
//  Two cell tiers are rendered distinctly (a11y: distinguished by brightness +
//  stroke weight, never hue alone):
//    • previously explored cells → faint cool haze tiles
//    • cells lit this session     → bright mint tiles with a leaf stroke
//
//  Cells are precision-7 geohash ids; we decode each to its bounding box
//  (`GeohashCell.bounds`) and render a polygon. The breadcrumb trail and the
//  suggested loop are drawn as polylines. It's a prototype — a convincing fog /
//  lit-cell look matters more than exact geohash geometry.
//
//  Min target iOS 26: the Map content builder + map styling APIs are used directly.
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

    @Binding var position: MapCameraPosition
    var showsUserLocation: Bool = true

    var body: some View {
        Map(position: $position) {
            // Previously explored cells — faint, cool, recede into the fog.
            ForEach(oldCells, id: \.self) { id in
                if let b = GeohashCell.bounds(id) {
                    MapPolygon(coordinates: Self.corners(of: b))
                        .foregroundStyle(Theme.Garden.haze.opacity(0.20))
                        .stroke(Theme.Garden.mist.opacity(0.35), lineWidth: 0.5)
                }
            }

            // Cells lit this session — bright, glowing, "freshly revealed".
            ForEach(newCells.sorted(), id: \.self) { id in
                if let b = GeohashCell.bounds(id) {
                    MapPolygon(coordinates: Self.corners(of: b))
                        .foregroundStyle(Theme.Garden.mint.opacity(0.55))
                        .stroke(Theme.Garden.leaf, lineWidth: 1.5)
                }
            }

            // The path walked this session.
            if breadcrumbs.count > 1 {
                MapPolyline(coordinates: breadcrumbs.map(\.cl))
                    .stroke(
                        Theme.Garden.leaf,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
            }

            // The suggested loop (idle preview / route shaping).
            if let waypoints = routeWaypoints, waypoints.count > 1 {
                MapPolyline(coordinates: waypoints.map(\.cl))
                    .stroke(
                        Theme.Garden.pine.opacity(0.85),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [9, 7])
                    )
            }

            if showsUserLocation {
                UserAnnotation()
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .tint(Theme.Garden.pine)
        .overlay { fogOverlay }
    }

    /// Old cells only (so the bright new tier never double-draws under the faint one).
    private var oldCells: [String] {
        exploredCells.subtracting(newCells).sorted()
    }

    /// The fog: a subtle cool mute over the whole map plus a vignette that closes
    /// in at the edges. Scales to the view, so it reads right in both the idle
    /// card preview and the full-screen active map.
    private var fogOverlay: some View {
        GeometryReader { geo in
            let maxDim = max(geo.size.width, geo.size.height)
            ZStack {
                Theme.Garden.mist.opacity(0.10)
                    .blendMode(.softLight)
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .clear, location: 0.45),
                        .init(color: Theme.Garden.dusk.opacity(0.42), location: 1.0),
                    ]),
                    center: .center,
                    startRadius: maxDim * 0.12,
                    endRadius: maxDim * 0.72
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

// MARK: - Coordinate bridging

extension Coordinate {
    /// Bridge the Domain `Coordinate` (degrees) to CoreLocation at the MapKit edge.
    var cl: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Preview

#Preview("FogMapView — lit cells") {
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
        return FogMapView(
            newCells: newCells,
            exploredCells: explored,
            breadcrumbs: Self.route,
            routeWaypoints: nil,
            position: $position
        )
        .ignoresSafeArea()
    }
}
