//
//  StressFactors.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 15/03/2026.
//

import Foundation

// Factor weights. Traffic density is the biggest single driver of perceived
// stress, followed by junction complexity. The three user-visible weights
// are stored in UserDefaults via SettingsSheet sliders (0-60 range, step 5).
// roadType and timeOfDay are not user-tunable and stay at their defaults.
struct StressWeightsConfig {
    var traffic:   Double
    var junctions: Double
    var roadType:  Double
    var weather:   Double
    var timeOfDay: Double

    static let defaults = StressWeightsConfig(
        traffic:   0.30,
        junctions: 0.25,
        roadType:  0.20,
        weather:   0.15,
        timeOfDay: 0.10
    )

    // Reads the three user-settable weights from UserDefaults (0-60 range),
    // normalizes them to fill the 0.70 budget left after roadType+timeOfDay,
    // so all five weights always sum to 1.0.
    static func fromUserDefaults() -> StressWeightsConfig {
        let t = UserDefaults.standard.double(forKey: "trafficWeight")
        let j = UserDefaults.standard.double(forKey: "junctionWeight")
        let w = UserDefaults.standard.double(forKey: "weatherWeight")
        let sum = t + j + w
        guard sum > 0 else { return .defaults }
        let userBudget = 1.0 - defaults.roadType - defaults.timeOfDay  // 0.70
        return StressWeightsConfig(
            traffic:   (t / sum) * userBudget,
            junctions: (j / sum) * userBudget,
            roadType:  defaults.roadType,
            weather:   (w / sum) * userBudget,
            timeOfDay: defaults.timeOfDay
        )
    }
}

// Time-of-day rush multiplier — applied on top of the base score.
// Based on standard US commute patterns.
enum RushHourSchedule {
    static func multiplier(for date: Date = Date()) -> Double {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 7...9:   return 1.4   // morning peak
        case 16...19: return 1.35  // evening peak
        case 11...13: return 1.1   // light lunch traffic
        default:      return 1.0
        }
    }
}

// Road type penalties.
// Values chosen so that a pure-freeway route with no construction
// scores around 10–15 on road type alone, while a school-zone
// route during pickup time can hit 40+.
enum RoadTypePenalty {
    static let schoolZoneActive:     Double = 25
    static let constructionZone:     Double = 20
    static let narrowUrbanStreet:    Double = 10
    static let unprotectedLeftTurn:  Double = 8
    static let highwayOnRamp:        Double = 5
    static let standard:             Double = 0
}

// Junction complexity heuristic.
// MKRoute.steps gives us each maneuver type. We scan them and score
// each one based on cognitive difficulty. Merging onto a freeway
// during traffic is significantly harder than a simple right turn.
enum JunctionComplexity {
    static func score(stepCount: Int, mergeCount: Int, uTurnCount: Int) -> Double {
        let base = Double(stepCount) * 1.5
        let mergePenalty = Double(mergeCount) * 8.0
        let uTurnPenalty = Double(uTurnCount) * 12.0
        return min(base + mergePenalty + uTurnPenalty, 100)
    }
}

// Traffic density proxy.
// MKRoute.expectedTravelTime vs. the theoretical free-flow time
// (distance / assumed 90 km/h freeway speed) gives a congestion ratio.
// Not perfect, but no paid API needed — this is all from MKDirections.
enum TrafficDensity {
    static func score(route: MockRouteProxy) -> Double {
        let distanceKm = route.distanceMeters / 1000
        let freeFlowMinutes = (distanceKm / 90) * 60
        let actualMinutes = route.expectedTravelTime / 60

        guard freeFlowMinutes > 0 else { return 0 }

        let congestionRatio = actualMinutes / freeFlowMinutes
        // 1.0 = free flow = 0 stress
        // 2.0 = double the time = 50 stress points
        // Capped at 100
        return min((congestionRatio - 1.0) * 50, 100)
    }
}

// We can't instantiate MKRoute in tests so we proxy just the fields we need.
struct MockRouteProxy {
    let distanceMeters: Double
    let expectedTravelTime: TimeInterval
    let stepCount: Int
    let mergeCount: Int
    let uTurnCount: Int
}
