//
//  StressEngine.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 17/03/2026.
//

import MapKit
import Foundation

// The brain of CalmRoute. Takes a route + weather + time and returns
// a StressScore with a full breakdown of contributing factors.
//
// Designed to be stateless — every call is pure given the same inputs.
// This makes it trivially testable and safe to call from any actor.
final class StressEngine: Sendable {

    // MARK: - Main scoring function

    func score(
        route: MKRoute,
        weather: WeatherCondition,
        at date: Date = Date()
    ) -> StressScore {
        let proxy = makeProxy(from: route)
        return score(proxy: proxy, weather: weather, at: date)
    }

    // Separate proxy-based path for tests (MKRoute can't be instantiated directly)
    func score(
        proxy: MockRouteProxy,
        weather: WeatherCondition,
        at date: Date = Date()
    ) -> StressScore {
        var factors: [StressFactor] = []

        // 1. Traffic density
        let trafficRaw = TrafficDensity.score(route: proxy)
        let trafficPoints = trafficRaw * StressWeights.traffic
        if trafficPoints > 0 {
            let label = trafficRaw < 20 ? "Light traffic" :
                        trafficRaw < 50 ? "Moderate congestion" : "Heavy congestion"
            factors.append(StressFactor(
                id: UUID(), kind: .traffic,
                contribution: trafficPoints,
                description: "\(label) (+\(Int(trafficPoints)))"
            ))
        }

        // 2. Junction complexity
        let junctionRaw = JunctionComplexity.score(
            stepCount: proxy.stepCount,
            mergeCount: proxy.mergeCount,
            uTurnCount: proxy.uTurnCount
        )
        let junctionPoints = junctionRaw * StressWeights.junctions
        if junctionPoints > 0 {
            var parts: [String] = []
            if proxy.mergeCount > 0 { parts.append("\(proxy.mergeCount) merge\(proxy.mergeCount == 1 ? "" : "s")") }
            if proxy.uTurnCount > 0 { parts.append("\(proxy.uTurnCount) U-turn\(proxy.uTurnCount == 1 ? "" : "s")") }
            if parts.isEmpty { parts.append("\(proxy.stepCount) maneuvers") }
            factors.append(StressFactor(
                id: UUID(), kind: .junctions,
                contribution: junctionPoints,
                description: parts.joined(separator: ", ") + " (+\(Int(junctionPoints)))"
            ))
        }

        // 3. Weather
        let weatherPoints = weather.stressDelta * StressWeights.weather
        if weatherPoints > 0 {
            let weatherLabel: String
            switch weather.precipitation {
            case .rain:  weatherLabel = "Rain forecast"
            case .snow:  weatherLabel = "Snow forecast"
            case .hail:  weatherLabel = "Hail warning"
            case .none:  weatherLabel = "Low visibility"
            }
            factors.append(StressFactor(
                id: UUID(), kind: .weather,
                contribution: weatherPoints,
                description: "\(weatherLabel) (+\(Int(weatherPoints)))"
            ))
        }

        // 4. Time of day (rush hour)
        let rushMultiplier = RushHourSchedule.multiplier(for: date)
        let timePoints = (rushMultiplier - 1.0) * 100 * StressWeights.timeOfDay
        if timePoints > 0 {
            let hour = Calendar.current.component(.hour, from: date)
            let label = (7...9).contains(hour) ? "Morning rush" : "Evening rush"
            factors.append(StressFactor(
                id: UUID(), kind: .timeOfDay,
                contribution: timePoints,
                description: "\(label) (+\(Int(timePoints)))"
            ))
        }

        // Sum, apply rush multiplier, clamp to 0–100
        let rawTotal = factors.reduce(0) { $0 + $1.contribution }
        let total = min(max(rawTotal * rushMultiplier, 0), 100)

        return StressScore(total: total, factors: factors)
    }

    // MARK: - Route proxy builder

    private func makeProxy(from route: MKRoute) -> MockRouteProxy {
        var mergeCount = 0
        var uTurnCount = 0

        for step in route.steps {
            let instructions = step.instructions.lowercased()
            if instructions.contains("merge") || instructions.contains("ramp") {
                mergeCount += 1
            }
            if instructions.contains("u-turn") || instructions.contains("uturn") {
                uTurnCount += 1
            }
        }

        return MockRouteProxy(
            distanceMeters: route.distance,
            expectedTravelTime: route.expectedTravelTime,
            stepCount: route.steps.count,
            mergeCount: mergeCount,
            uTurnCount: uTurnCount
        )
    }
}
