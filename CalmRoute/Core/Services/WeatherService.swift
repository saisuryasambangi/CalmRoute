//
//  WeatherService.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 22/03/2026.
//
//  WeatherKit requires a paid Apple Developer account.
//  This returns mock data so the app builds on a free account.
//

import CoreLocation
import Foundation

final class WeatherService: Sendable {

    func condition(at coordinate: CLLocationCoordinate2D) async -> WeatherCondition {
        try? await Task.sleep(nanoseconds: 200_000_000)
        return mockCondition()
    }

    private func mockCondition() -> WeatherCondition {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<9:
            return WeatherCondition(precipitation: .rain, visibility: 12, windSpeedKph: 18)
        case 9..<17:
            return .clear
        case 17..<20:
            return WeatherCondition(precipitation: .none, visibility: 20, windSpeedKph: 12)
        default:
            return .clear
        }
    }
}
