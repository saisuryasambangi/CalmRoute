//
//  StressScoreServiceTests.swift
//  CalmRouteTests
//
//  Created by Sai Surya Sambangi on 11/04/2026.
//
//  Tests for StressScoreService. Because the Core ML model is a placeholder in
//  DEBUG builds, all calls go through StressScoreFallback. The tests cover
//  the end-to-end public API of the service, which is what matters.
//

import XCTest
@testable import CalmRoute

@MainActor
final class StressScoreServiceTests: XCTestCase {

    // StressScoreService is a shared singleton, but its score() function is
    // pure given the same inputs, so we can reuse the shared instance.
    let service = StressScoreService.shared

    // MARK: - 1. score() returns value in 0–100 range for valid inputs

    func test_score_inValidRange() async {
        let result = await service.score(
            trafficDensity: 0.5,
            junctionComplexity: 0.5,
            roadType: "arterial",
            timeOfDay: 12.0,
            weatherInput: 0.3
        )
        XCTAssertGreaterThanOrEqual(result, 0.0)
        XCTAssertLessThanOrEqual(result, 100.0)
    }

    // MARK: - 2. score() returns 0 when all inputs are 0

    func test_score_allZeroInputs_returnsZero() async {
        let result = await service.score(
            trafficDensity: 0,
            junctionComplexity: 0,
            roadType: "motorway",
            timeOfDay: 12.0,
            weatherInput: 0
        )
        XCTAssertEqual(result, 0.0, "All-zero inputs must produce a score of 0")
    }

    // MARK: - 3. score() returns ~100 for extreme inputs during rush hour

    func test_score_extremeInputsRushHour_approachesMaximum() async {
        let result = await service.score(
            trafficDensity: 1.0,
            junctionComplexity: 1.0,
            roadType: "residential",
            timeOfDay: 8.0,       // morning rush
            weatherInput: 1.0
        )
        // With residential multiplier (×1.2): base = 80, ×1.2 = 96, +10 = 100 (clamped)
        XCTAssertEqual(result, 100.0, accuracy: 1.0,
                       "Extreme inputs during rush hour should reach maximum stress")
    }

    // MARK: - 4. Fallback triggers when model is unavailable (DEBUG always uses fallback)

    func test_score_fallbackProducesConsistentResult() async {
        // In DEBUG the model is never loaded, so fallback is always used.
        // Call twice with the same inputs and verify identical output.
        let a = await service.score(
            trafficDensity: 0.6, junctionComplexity: 0.4,
            roadType: "highway", timeOfDay: 14.0, weatherInput: 0.5)
        let b = await service.score(
            trafficDensity: 0.6, junctionComplexity: 0.4,
            roadType: "highway", timeOfDay: 14.0, weatherInput: 0.5)
        XCTAssertEqual(a, b, "Fallback must be deterministic across calls")
    }

    // MARK: - 5. road_type "motorway" produces lower score than "residential"

    func test_motorway_lowerThanResidential_sameOtherInputs() async {
        let residential = await service.score(
            trafficDensity: 0.6, junctionComplexity: 0.5,
            roadType: "residential", timeOfDay: 12.0, weatherInput: 0.4)
        let motorway = await service.score(
            trafficDensity: 0.6, junctionComplexity: 0.5,
            roadType: "motorway", timeOfDay: 12.0, weatherInput: 0.4)
        XCTAssertGreaterThan(residential, motorway,
                             "Residential (×1.2) should score higher than motorway (×0.7)")
    }

    // MARK: - 6. Rush hour time adds penalty vs off-peak

    func test_rushHour_addsTimePenalty() async {
        let offPeak = await service.score(
            trafficDensity: 0.4, junctionComplexity: 0.3,
            roadType: "arterial", timeOfDay: 14.0, weatherInput: 0.2)
        let rushHour = await service.score(
            trafficDensity: 0.4, junctionComplexity: 0.3,
            roadType: "arterial", timeOfDay: 8.0, weatherInput: 0.2)
        XCTAssertGreaterThan(rushHour, offPeak,
                             "Rush hour (8am) must produce a higher score than off-peak (2pm)")
    }

    // MARK: - 7. weather_input=1.0 increases score vs weather_input=0.0

    func test_severeWeather_increasesScore() async {
        let clear = await service.score(
            trafficDensity: 0.4, junctionComplexity: 0.3,
            roadType: "arterial", timeOfDay: 14.0, weatherInput: 0.0)
        let severe = await service.score(
            trafficDensity: 0.4, junctionComplexity: 0.3,
            roadType: "arterial", timeOfDay: 14.0, weatherInput: 1.0)
        XCTAssertGreaterThan(severe, clear,
                             "Severe weather (1.0) should increase the stress score")
    }

    // MARK: - 8. Concurrent calls return consistent results (actor isolation)

    func test_concurrentCalls_returnConsistentResults() async {
        // Fire 20 concurrent score requests with the same inputs.
        let inputs = (traffic: 0.5, junction: 0.5, road: "highway", time: 12.0, weather: 0.3)
        async let r1  = service.score(trafficDensity: inputs.traffic, junctionComplexity: inputs.junction, roadType: inputs.road, timeOfDay: inputs.time, weatherInput: inputs.weather)
        async let r2  = service.score(trafficDensity: inputs.traffic, junctionComplexity: inputs.junction, roadType: inputs.road, timeOfDay: inputs.time, weatherInput: inputs.weather)
        async let r3  = service.score(trafficDensity: inputs.traffic, junctionComplexity: inputs.junction, roadType: inputs.road, timeOfDay: inputs.time, weatherInput: inputs.weather)
        async let r4  = service.score(trafficDensity: inputs.traffic, junctionComplexity: inputs.junction, roadType: inputs.road, timeOfDay: inputs.time, weatherInput: inputs.weather)
        async let r5  = service.score(trafficDensity: inputs.traffic, junctionComplexity: inputs.junction, roadType: inputs.road, timeOfDay: inputs.time, weatherInput: inputs.weather)
        async let r6  = service.score(trafficDensity: inputs.traffic, junctionComplexity: inputs.junction, roadType: inputs.road, timeOfDay: inputs.time, weatherInput: inputs.weather)
        async let r7  = service.score(trafficDensity: inputs.traffic, junctionComplexity: inputs.junction, roadType: inputs.road, timeOfDay: inputs.time, weatherInput: inputs.weather)
        async let r8  = service.score(trafficDensity: inputs.traffic, junctionComplexity: inputs.junction, roadType: inputs.road, timeOfDay: inputs.time, weatherInput: inputs.weather)
        async let r9  = service.score(trafficDensity: inputs.traffic, junctionComplexity: inputs.junction, roadType: inputs.road, timeOfDay: inputs.time, weatherInput: inputs.weather)
        async let r10 = service.score(trafficDensity: inputs.traffic, junctionComplexity: inputs.junction, roadType: inputs.road, timeOfDay: inputs.time, weatherInput: inputs.weather)

        let results = await [r1, r2, r3, r4, r5, r6, r7, r8, r9, r10]

        let allEqual = results.dropFirst().allSatisfy { $0 == results[0] }
        XCTAssertTrue(allEqual, "All concurrent calls with the same inputs must return the same score")
    }

    // MARK: - 9. Score is non-negative for any non-negative input combination

    func test_score_alwaysNonNegative() async {
        let inputSets: [(Double, Double, String, Double, Double)] = [
            (0.0, 0.0, "motorway", 0.0, 0.0),
            (0.1, 0.1, "highway", 3.5, 0.1),
            (0.0, 0.0, "residential", 23.5, 0.0)
        ]
        for (traffic, junction, road, time, weather) in inputSets {
            let score = await service.score(
                trafficDensity: traffic, junctionComplexity: junction,
                roadType: road, timeOfDay: time, weatherInput: weather)
            XCTAssertGreaterThanOrEqual(score, 0.0,
                "Score must never be negative (inputs: \(traffic),\(junction),\(road),\(time),\(weather))")
        }
    }
}
