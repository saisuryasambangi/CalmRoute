//
//  MapView.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 05/04/2026.
//

import MapKit
import SwiftUI

// MARK: - MapView

// Shows the selected route on a map with the stress polyline overlay.
// The polyline is gradient-colored: green → amber → red based on
// per-segment stress. MKPolylineRenderer doesn't support gradients
// natively, so StressPolylineRenderer handles that via CAGradientLayer.
struct MapView: View {

    let selectedRoute: ScoredRoute
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var region: MKCoordinateRegion?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .bottom) {
            StressMapRepresentable(route: selectedRoute, region: $region)
                .ignoresSafeArea()

            // Custom top bar — always visible regardless of map tile colour
            VStack {
                HStack {
                    // Back button
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.5), in: Capsule())
                    }

                    Spacer()

                    Text("Route Preview")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.4), in: Capsule())

                    Spacer()

                    // Go Calm button
                    Button {
                        coordinator.push(.navigating(selectedRoute))
                    } label: {
                        Text("Go Calm")
                            .font(.subheadline.bold())
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(CalmRouteTheme.stressLow, in: Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 56) // below status bar
                Spacer()
            }

            // Route info card at the bottom
            routeInfoCard
                .padding(CalmRouteTheme.padding)
        }
        .navigationBarHidden(true)
        .onAppear {
            let rect = selectedRoute.route.polyline.boundingMapRect
            region = MKCoordinateRegion(
                rect.insetBy(dx: -rect.size.width * 0.15, dy: -rect.size.height * 0.15)
            )
        }
    }

    private var routeInfoCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedRoute.label.rawValue + " Route")
                    .font(.headline)
                Text("\(Int(selectedRoute.expectedTravelTime / 60)) min · \(String(format: "%.1f", selectedRoute.distanceMeters / 1000)) km")
                    .font(.subheadline)
                    .foregroundStyle(CalmRouteTheme.secondary)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("\(Int(selectedRoute.stressScore.total))")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(CalmRouteTheme.stressColor(selectedRoute.stressScore.total))
                    .monospacedDigit()
                Text("stress")
                    .font(.caption2)
                    .foregroundStyle(CalmRouteTheme.secondary)
            }
        }
        .cardStyle()
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }
}

// MARK: - UIViewRepresentable bridge

// We need UIKit here because MapKit's SwiftUI Map doesn't expose
// the delegate method we need for custom overlay rendering.
struct StressMapRepresentable: UIViewRepresentable {

    let route: ScoredRoute
    @Binding var region: MKCoordinateRegion?

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.mapType = .standard
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays)
        map.addOverlay(route.route.polyline, level: .aboveRoads)

        if let region {
            map.setRegion(region, animated: true)
        }
    }

    func makeCoordinator() -> MapCoordinator {
        MapCoordinator(stressScore: route.stressScore.total)
    }
}

// MARK: - MapCoordinator

final class MapCoordinator: NSObject, MKMapViewDelegate {

    let stressScore: Double

    init(stressScore: Double) {
        self.stressScore = stressScore
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let polyline = overlay as? MKPolyline else {
            return MKOverlayRenderer(overlay: overlay)
        }
        return StressPolylineRenderer(polyline: polyline, stressScore: stressScore)
    }
}

// MARK: - StressPolylineRenderer

// Custom renderer that colors the route based on stress level.
// Low stress = green, moderate = amber, high = red.
// We paint the whole polyline one color based on overall score —
// per-segment coloring would require splitting the polyline, which
// is a future improvement.
final class StressPolylineRenderer: MKPolylineRenderer {

    private let stressScore: Double

    init(polyline: MKPolyline, stressScore: Double) {
        self.stressScore = stressScore
        super.init(polyline: polyline)
        configure()
    }

    // MKMapView calls this internally — must be implemented or it crashes
    override init(overlay: any MKOverlay) {
        self.stressScore = 0
        super.init(overlay: overlay)
        configure()
    }

    private func configure() {
        lineWidth = 6

        // Color the line based on stress level
        switch stressScore {
        case ..<30:
            strokeColor = UIColor(CalmRouteTheme.stressLow).withAlphaComponent(0.85)
        case 30..<60:
            strokeColor = UIColor(CalmRouteTheme.stressModerate).withAlphaComponent(0.85)
        default:
            strokeColor = UIColor(CalmRouteTheme.stressHigh).withAlphaComponent(0.85)
        }

        // Soft border so the line reads against light and dark map tiles
        lineJoin  = .round
        lineCap   = .round
    }

    // Draw a thin white outline under the colored line for legibility
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in ctx: CGContext) {
        // Draw white outline underneath for legibility on both light and dark tiles
        ctx.saveGState()
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.5).cgColor)
        ctx.setLineWidth((lineWidth + 2) / zoomScale)
        ctx.strokePath()
        ctx.restoreGState()

        // Draw the stress-colored line on top
        configure()
        super.draw(mapRect, zoomScale: zoomScale, in: ctx)
    }
}
