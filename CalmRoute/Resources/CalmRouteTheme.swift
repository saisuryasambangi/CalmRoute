//
//  CalmRouteTheme.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 28/03/2026.
//

import SwiftUI

enum CalmRouteTheme {
    // Stress palette — the main visual language of the app
    static let stressLow      = Color(hex: 0x30D158)  // green
    static let stressModerate = Color(hex: 0xFFD60A)  // amber
    static let stressHigh     = Color(hex: 0xFF453A)  // red

    static func stressColor(_ score: Double) -> Color {
        switch score {
        case ..<30:  return stressLow
        case 30..<60: return stressModerate
        default:     return stressHigh
        }
    }

    // UI
    static let surface     = Color(UIColor.secondarySystemBackground)
    static let background  = Color(UIColor.systemBackground)
    static let primary     = Color(UIColor.label)
    static let secondary   = Color(UIColor.secondaryLabel)

    // Layout
    static let radius: CGFloat    = 16
    static let radiusSM: CGFloat  = 10
    static let padding: CGFloat   = 16
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double(hex         & 0xFF) / 255
        )
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .padding(CalmRouteTheme.padding)
            .background(CalmRouteTheme.surface,
                        in: RoundedRectangle(cornerRadius: CalmRouteTheme.radius))
    }
}
