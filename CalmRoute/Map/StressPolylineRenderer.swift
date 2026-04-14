//
//  StressPolylineRenderer.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 11/04/2026.
//
//  Custom MKPolylineRenderer that colors the route based on the stress score
//  associated with its RouteStressOverlay. When the overlay is a plain
//  MKPolyline the renderer falls back to a neutral blue.
//
//  Color scale:
//    0–33  → green  (#4CAF50)
//    34–66 → amber  (#FFC107)
//    67–100 → red   (#F44336)
//

import MapKit
import UIKit

final class StressPolylineRenderer: MKPolylineRenderer {

    // 0–100; set before the renderer draws.
    var stressScore: Double = 0 {
        didSet { applyStrokeColor() }
    }

    // MARK: - Colours

    private enum StressColor {
        static let low    = UIColor(red: 0.298, green: 0.686, blue: 0.314, alpha: 1) // #4CAF50
        static let medium = UIColor(red: 1.000, green: 0.757, blue: 0.027, alpha: 1) // #FFC107
        static let high   = UIColor(red: 0.957, green: 0.263, blue: 0.212, alpha: 1) // #F44336
    }

    // MARK: - Init

    /// Designated initialiser used by MapCoordinator when the overlay is a RouteStressOverlay.
    init(overlay: RouteStressOverlay) {
        super.init(overlay: overlay)
        stressScore = overlay.stressScore
        applyStrokeColor()
    }

    /// Fallback initialiser for plain MKPolyline overlays.
    override init(overlay: any MKOverlay) {
        super.init(overlay: overlay)
        applyStrokeColor()
    }

    // MARK: - Drawing

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in ctx: CGContext) {
        // White under-stroke for legibility on both light and dark map tiles.
        ctx.saveGState()
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.5).cgColor)
        ctx.setLineWidth((lineWidth + 2) / zoomScale)
        ctx.strokePath()
        ctx.restoreGState()

        super.draw(mapRect, zoomScale: zoomScale, in: ctx)
    }

    // MARK: - Helpers

    private func applyStrokeColor() {
        lineWidth = 5
        let color: UIColor
        switch stressScore {
        case ..<34:  color = StressColor.low
        case 34..<67: color = StressColor.medium
        default:      color = StressColor.high
        }
        strokeColor = color.withAlphaComponent(0.85)
        lineJoin = .round
        lineCap  = .round
    }
}
