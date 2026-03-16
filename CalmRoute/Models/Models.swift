//
//  Models.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 15/03/2026.
//

import CoreLocation
@preconcurrency import MapKit
import Foundation

// MARK: - Route

// A route paired with its computed stress score.
// MKRoute gives us geometry and steps; we compute the rest.
struct ScoredRoute: @unchecked Sendable, Identifiable {
    let id: UUID
    let route: MKRoute
    let stressScore: StressScore
    let label: RouteLabel

    // Convenience
    var expectedTravelTime: TimeInterval { route.expectedTravelTime }
    var distanceMeters: CLLocationDistance { route.distance }

    enum RouteLabel: String, Sendable {
        case fastest = "Fastest"
        case calmest = "Calmest"
        case balanced = "Balanced"
    }
}

// MARK: - StressScore

struct StressScore: Sendable {
    let total: Double          // 0–100
    let factors: [StressFactor]

    var level: StressLevel {
        switch total {
        case ..<30: return .low
        case 30..<60: return .moderate
        default: return .high
        }
    }

    // Human-readable breakdown shown under the route card
    var breakdown: [String] {
        factors.filter { $0.contribution > 0 }.map { $0.description }
    }

    enum StressLevel: String, Sendable {
        case low      = "Calm"
        case moderate = "Moderate"
        case high     = "Stressful"

        var color: String {
            switch self {
            case .low:      return "#30D158"
            case .moderate: return "#FFD60A"
            case .high:     return "#FF453A"
            }
        }
    }
}

// MARK: - StressFactor

struct StressFactor: Sendable, Identifiable {
    let id: UUID
    let kind: Kind
    let contribution: Double   // points added to total score
    let description: String    // e.g. "3 complex merges (+12)"

    enum Kind: Sendable {
        case traffic
        case junctions
        case roadType
        case weather
        case timeOfDay
    }
}

// MARK: - WeatherCondition

// Subset of WeatherKit data we actually use for stress scoring.
// Keeping it simple — we don't need the full WeatherKit model in domain types.
struct WeatherCondition: Sendable {
    let precipitation: PrecipitationType
    let visibility: Double     // km
    let windSpeedKph: Double

    var stressDelta: Double {
        var delta = 0.0
        switch precipitation {
        case .rain:   delta += 15
        case .snow:   delta += 25
        case .hail:   delta += 30
        case .none:   break
        }
        if visibility < 1.0 { delta += 20 }
        if windSpeedKph > 60 { delta += 10 }
        return delta
    }

    enum PrecipitationType: Sendable {
        case none, rain, snow, hail
    }

    static let clear = WeatherCondition(precipitation: .none, visibility: 20, windSpeedKph: 10)
}

// MARK: - NavigationState

enum NavigationState: Sendable, Equatable {
    case idle
    case searching
    case comparing([ScoredRoute])
    case navigating(ScoredRoute)
    case arrived

    static func == (lhs: NavigationState, rhs: NavigationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.searching, .searching), (.arrived, .arrived):
            return true
        case (.comparing(let a), .comparing(let b)):
            return a.map(\.id) == b.map(\.id)
        case (.navigating(let a), .navigating(let b)):
            return a.id == b.id
        default:
            return false
        }
    }
}

// MARK: - Errors

enum CalmRouteError: Error, Sendable {
    case locationUnavailable
    case routeCalculationFailed
    case weatherUnavailable
    case noRoutesFound
    case backgroundTaskFailed
}

// MARK: - Mock helpers

// Used in previews and tests — not in production paths.
enum MockRouteData {
    static func makeScoredRoute(
        label: ScoredRoute.RouteLabel = .fastest,
        stress: Double = 65,
        travelMinutes: Double = 22
    ) -> ScoredRoute {
        let score = StressScore(
            total: stress,
            factors: [
                StressFactor(id: UUID(), kind: .junctions, contribution: 25,
                             description: "3 complex merges"),
                StressFactor(id: UUID(), kind: .traffic, contribution: 20,
                             description: "Moderate congestion"),
                StressFactor(id: UUID(), kind: .weather, contribution: 15,
                             description: "Rain forecast"),
                StressFactor(id: UUID(), kind: .timeOfDay, contribution: 5,
                             description: "Rush hour nearby"),
            ]
        )
        // MKRoute can't be instantiated directly in tests — we wrap it lazily.
        // In real flow this comes from MKDirections.calculate().
        return ScoredRoute(
            id: UUID(),
            route: MKRoute(),   // placeholder; tests use RouteActor mocks
            stressScore: score,
            label: label
        )
    }
}
