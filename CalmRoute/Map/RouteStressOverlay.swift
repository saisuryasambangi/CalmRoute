//
//  RouteStressOverlay.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 11/04/2026.
//
//  MKPolyline subclass that carries a stress score alongside its geometry.
//  MapCoordinator reads stressScore when creating the renderer so the line
//  colour reflects the route's computed stress level.
//

import CoreLocation
import MapKit

final class RouteStressOverlay: MKPolyline {

    /// The pre-computed stress score for this route segment (0–100).
    var stressScore: Double = 0

    // MARK: - Convenience init

    /// Creates an overlay from an array of coordinates and tags it with the
    /// given stress score. The overlay can be added directly to MKMapView.
    convenience init(coordinates: [CLLocationCoordinate2D], stressScore: Double) {
        // MKPolyline's designated convenience initialiser takes a mutable pointer.
        var coords = coordinates
        self.init(coordinates: &coords, count: coords.count)
        self.stressScore = stressScore
    }
}
