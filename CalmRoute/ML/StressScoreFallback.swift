//
//  StressScoreFallback.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 11/04/2026.
//
//  Pure-formula fallback used when the Core ML model is unavailable or
//  when inputs are outside the expected range. Implements the same
//  weighted formula used to generate StressTrainingData.csv.
//

import Foundation

struct StressScoreFallback {

    // MARK: - Road multipliers (must match training data generation)

    private enum RoadMultiplier {
        static func value(for roadType: String) -> Double {
            switch roadType.lowercased() {
            case "residential": return 1.2
            case "arterial":    return 1.0
            case "highway":     return 0.8
            case "motorway":    return 0.7
            default:            return 1.0
            }
        }
    }

    // MARK: - Scoring

    /// Returns a stress score 0–100 using the same weighted formula used
    /// during training data generation. No noise is added here — the fallback
    /// is deterministic so callers can reason about its output.
    ///
    /// - Parameters:
    ///   - trafficDensity:     0.0 (no traffic) – 1.0 (gridlock)
    ///   - junctionComplexity: 0.0 (straight road) – 1.0 (very complex)
    ///   - roadType:           "residential" | "arterial" | "highway" | "motorway"
    ///   - timeOfDay:          0.0–23.99 (hour of day as a float)
    ///   - weatherInput:       0.0 (clear) – 1.0 (severe weather)
    static func score(
        trafficDensity: Double,
        junctionComplexity: Double,
        roadType: String,
        timeOfDay: Double,
        weatherInput: Double
    ) -> Double {
        let base = (trafficDensity * 35.0)
                 + (junctionComplexity * 25.0)
                 + (weatherInput * 20.0)

        let multiplier = RoadMultiplier.value(for: roadType)

        let hour = Int(timeOfDay)
        let timePenalty: Double = (7...9).contains(hour) || (17...19).contains(hour) ? 10.0 : 0.0

        let raw = (base * multiplier) + timePenalty
        return min(100.0, max(0.0, raw))
    }
}
