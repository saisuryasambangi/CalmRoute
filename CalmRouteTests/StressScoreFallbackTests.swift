//
//  StressScoreFallbackTests.swift
//  CalmRouteTests
//
//  Created by Sai Surya Sambangi on 11/04/2026.
//

import XCTest
@testable import CalmRoute

final class StressScoreFallbackTests: XCTestCase {

    // MARK: - 1. Formula matches expected output for known inputs

    func test_knownInputs_matchExpectedOutput() {
        // base = (0.5 * 35) + (0.4 * 25) + (0.3 * 20) = 17.5 + 10 + 6 = 33.5
        // multiplier (arterial) = 1.0
        // time_penalty (12:00) = 0
        // expected ≈ 33.5
        let result = StressScoreFallback.score(
            trafficDensity: 0.5,
            junctionComplexity: 0.4,
            roadType: "arterial",
            timeOfDay: 12.0,
            weatherInput: 0.3
        )
        XCTAssertEqual(result, 33.5, accuracy: 0.01)
    }

    // MARK: - 2. Output is within ±5 of deterministic formula (no noise in fallback)

    func test_fallbackIsDeterministic_noNoise() {
        let a = StressScoreFallback.score(
            trafficDensity: 0.7,
            junctionComplexity: 0.6,
            roadType: "residential",
            timeOfDay: 14.0,
            weatherInput: 0.5
        )
        let b = StressScoreFallback.score(
            trafficDensity: 0.7,
            junctionComplexity: 0.6,
            roadType: "residential",
            timeOfDay: 14.0,
            weatherInput: 0.5
        )
        XCTAssertEqual(a, b, "Fallback must be deterministic — same inputs → same output")
    }

    // MARK: - 3. min(100) clamp works for extreme inputs

    func test_extremeInputs_clampedTo100() {
        let score = StressScoreFallback.score(
            trafficDensity: 1.0,
            junctionComplexity: 1.0,
            roadType: "residential",
            timeOfDay: 8.0,   // rush hour
            weatherInput: 1.0
        )
        XCTAssertLessThanOrEqual(score, 100.0, "Score must never exceed 100")
    }

    // MARK: - 4. road_multiplier applied correctly for each road type

    func test_roadMultipliers_residential_highest() {
        // Identical inputs, only road type varies.
        let base = (trafficDensity: 0.6, junction: 0.5, weather: 0.4, time: 12.0)

        let residential = StressScoreFallback.score(
            trafficDensity: base.trafficDensity, junctionComplexity: base.junction,
            roadType: "residential", timeOfDay: base.time, weatherInput: base.weather)
        let arterial = StressScoreFallback.score(
            trafficDensity: base.trafficDensity, junctionComplexity: base.junction,
            roadType: "arterial", timeOfDay: base.time, weatherInput: base.weather)
        let highway = StressScoreFallback.score(
            trafficDensity: base.trafficDensity, junctionComplexity: base.junction,
            roadType: "highway", timeOfDay: base.time, weatherInput: base.weather)
        let motorway = StressScoreFallback.score(
            trafficDensity: base.trafficDensity, junctionComplexity: base.junction,
            roadType: "motorway", timeOfDay: base.time, weatherInput: base.weather)

        XCTAssertGreaterThan(residential, arterial, "residential (×1.2) > arterial (×1.0)")
        XCTAssertGreaterThan(arterial, highway,    "arterial (×1.0) > highway (×0.8)")
        XCTAssertGreaterThan(highway, motorway,    "highway (×0.8) > motorway (×0.7)")
    }

    // MARK: - 5. time_penalty applied for 7–9 and 17–19, not for midnight

    func test_timePenalty_appliedDuringRushHours() {
        let inputs = (traffic: 0.4, junction: 0.3, road: "arterial", weather: 0.2)

        let morningRush = StressScoreFallback.score(
            trafficDensity: inputs.traffic, junctionComplexity: inputs.junction,
            roadType: inputs.road, timeOfDay: 8.0, weatherInput: inputs.weather)
        let eveningRush = StressScoreFallback.score(
            trafficDensity: inputs.traffic, junctionComplexity: inputs.junction,
            roadType: inputs.road, timeOfDay: 18.0, weatherInput: inputs.weather)
        let midnight = StressScoreFallback.score(
            trafficDensity: inputs.traffic, junctionComplexity: inputs.junction,
            roadType: inputs.road, timeOfDay: 0.0, weatherInput: inputs.weather)

        XCTAssertGreaterThan(morningRush, midnight, "Morning rush should add 10 pts over midnight")
        XCTAssertGreaterThan(eveningRush, midnight, "Evening rush should add 10 pts over midnight")
        XCTAssertEqual(morningRush, eveningRush, accuracy: 0.01,
                       "Both rush hours apply the same 10pt penalty")
    }

    // MARK: - 6. Zero inputs produce zero score

    func test_zeroInputs_produceZeroScore() {
        let score = StressScoreFallback.score(
            trafficDensity: 0, junctionComplexity: 0,
            roadType: "motorway", timeOfDay: 12.0, weatherInput: 0)
        XCTAssertEqual(score, 0.0, "All-zero inputs should yield a stress score of 0")
    }

    // MARK: - 7. Unknown road type falls back to arterial (×1.0) multiplier

    func test_unknownRoadType_usesDefaultMultiplier() {
        let unknown = StressScoreFallback.score(
            trafficDensity: 0.5, junctionComplexity: 0.4,
            roadType: "unpaved_track", timeOfDay: 12.0, weatherInput: 0.3)
        let arterial = StressScoreFallback.score(
            trafficDensity: 0.5, junctionComplexity: 0.4,
            roadType: "arterial", timeOfDay: 12.0, weatherInput: 0.3)
        XCTAssertEqual(unknown, arterial, accuracy: 0.01,
                       "Unknown road types should use the arterial (×1.0) multiplier")
    }

    // MARK: - 8. Weather input scales linearly (higher weather → higher score)

    func test_weatherInput_scalesScore() {
        let low = StressScoreFallback.score(
            trafficDensity: 0.3, junctionComplexity: 0.3,
            roadType: "arterial", timeOfDay: 12.0, weatherInput: 0.1)
        let high = StressScoreFallback.score(
            trafficDensity: 0.3, junctionComplexity: 0.3,
            roadType: "arterial", timeOfDay: 12.0, weatherInput: 0.9)
        XCTAssertGreaterThan(high, low, "Higher weather input should produce a higher stress score")
    }
}
