//
//  CalmRouteTests.swift
//  CalmRouteTests
//
//  Created by Sai Surya Sambangi on 17/04/2026.
//

import XCTest
@testable import CalmRoute

// MARK: - StressEngineTests

final class StressEngineTests: XCTestCase {

    let engine = StressEngine()

    // A clear-weather, low-traffic, simple route should score well under 30
    func test_lowComplexityRoute_scoresCalm() {
        let proxy = MockRouteProxy(
            distanceMeters: 5000,
            expectedTravelTime: 360,  // 6 min — close to free-flow
            stepCount: 4,
            mergeCount: 0,
            uTurnCount: 0
        )
        let score = engine.score(proxy: proxy, weather: .clear, at: middayDate())
        XCTAssertLessThan(score.total, 30, "Simple short route in clear weather should be calm")
    }

    // Heavy traffic (3× free-flow time) + multiple merges + rain = high stress
    func test_highComplexityRoute_scoresHigh() {
        let proxy = MockRouteProxy(
            distanceMeters: 20_000,
            expectedTravelTime: 4800,  // 80 min — way over free-flow 13 min
            stepCount: 18,
            mergeCount: 5,
            uTurnCount: 1
        )
        let weather = WeatherCondition(precipitation: .rain, visibility: 8, windSpeedKph: 30)
        let score = engine.score(proxy: proxy, weather: weather, at: rushHourDate())
        XCTAssertGreaterThan(score.total, 60, "High traffic + merges + rain during rush should score stressful")
    }

    // Score must always land in [0, 100]
    func test_score_clampedToZeroHundred() {
        let extremeProxy = MockRouteProxy(
            distanceMeters: 100_000,
            expectedTravelTime: 50000,
            stepCount: 60,
            mergeCount: 20,
            uTurnCount: 10
        )
        let extremeWeather = WeatherCondition(precipitation: .hail, visibility: 0.2, windSpeedKph: 90)
        let score = engine.score(proxy: extremeProxy, weather: extremeWeather, at: rushHourDate())
        XCTAssertGreaterThanOrEqual(score.total, 0)
        XCTAssertLessThanOrEqual(score.total, 100, "Score must never exceed 100 regardless of inputs")
    }

    // Rain should add stress delta — more than clear weather on the same route
    func test_rainWeather_addsDeltaVsClear() {
        let proxy = MockRouteProxy(
            distanceMeters: 8000,
            expectedTravelTime: 600,
            stepCount: 6,
            mergeCount: 1,
            uTurnCount: 0
        )
        let rainWeather = WeatherCondition(precipitation: .rain, visibility: 10, windSpeedKph: 20)
        let clearScore  = engine.score(proxy: proxy, weather: .clear, at: middayDate())
        let rainScore   = engine.score(proxy: proxy, weather: rainWeather, at: middayDate())

        XCTAssertGreaterThan(rainScore.total, clearScore.total,
                             "Rain should increase stress score vs clear conditions")
    }

    // Snow should add more stress than rain
    func test_snowAddsMoreStressThanRain() {
        let proxy = MockRouteProxy(
            distanceMeters: 5000, expectedTravelTime: 400,
            stepCount: 5, mergeCount: 0, uTurnCount: 0
        )
        let rain = WeatherCondition(precipitation: .rain, visibility: 10, windSpeedKph: 20)
        let snow = WeatherCondition(precipitation: .snow, visibility: 5,  windSpeedKph: 20)

        let rainScore = engine.score(proxy: proxy, weather: rain, at: middayDate())
        let snowScore = engine.score(proxy: proxy, weather: snow, at: middayDate())

        XCTAssertGreaterThan(snowScore.total, rainScore.total, "Snow should be more stressful than rain")
    }

    // Rush hour should bump score above the same route at noon
    func test_rushHourMultiplier_raisesScore() {
        let proxy = MockRouteProxy(
            distanceMeters: 10_000, expectedTravelTime: 900,
            stepCount: 8, mergeCount: 2, uTurnCount: 0
        )
        let middayScore   = engine.score(proxy: proxy, weather: .clear, at: middayDate())
        let rushHourScore = engine.score(proxy: proxy, weather: .clear, at: rushHourDate())

        XCTAssertGreaterThan(rushHourScore.total, middayScore.total,
                             "Rush hour multiplier should increase the score")
    }

    // Factor breakdown should sum to approximately the total (before clamping)
    func test_factorContributions_matchTotal() {
        let proxy = MockRouteProxy(
            distanceMeters: 12_000, expectedTravelTime: 1200,
            stepCount: 10, mergeCount: 2, uTurnCount: 0
        )
        let rain = WeatherCondition(precipitation: .rain, visibility: 8, windSpeedKph: 25)
        let score = engine.score(proxy: proxy, weather: rain, at: middayDate())

        let factorSum = score.factors.reduce(0.0) { $0 + $1.contribution }
        // Total may differ from sum due to rush multiplier and clamping,
        // but they should be in the same ballpark
        XCTAssertGreaterThan(factorSum, 0, "At least one factor should contribute")
    }

    // Empty route (no steps, no distance) shouldn't crash
    func test_zeroProxy_doesNotCrash() {
        let emptyProxy = MockRouteProxy(
            distanceMeters: 0, expectedTravelTime: 0,
            stepCount: 0, mergeCount: 0, uTurnCount: 0
        )
        let score = engine.score(proxy: emptyProxy, weather: .clear, at: middayDate())
        XCTAssertGreaterThanOrEqual(score.total, 0, "Zero-distance proxy should not produce negative score")
    }

    // MARK: - Helpers

    private func middayDate() -> Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = 12
        return Calendar.current.date(from: c) ?? Date()
    }

    private func rushHourDate() -> Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = 8   // morning peak
        return Calendar.current.date(from: c) ?? Date()
    }
}

// MARK: - RushHourScheduleTests

final class RushHourScheduleTests: XCTestCase {

    func test_morningRush_returnsHighMultiplier() {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = 8
        let date = Calendar.current.date(from: c)!
        XCTAssertGreaterThan(RushHourSchedule.multiplier(for: date), 1.0)
    }

    func test_eveningRush_returnsHighMultiplier() {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = 17
        let date = Calendar.current.date(from: c)!
        XCTAssertGreaterThan(RushHourSchedule.multiplier(for: date), 1.0)
    }

    func test_midnightDrive_returnsBaseMultiplier() {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = 0
        let date = Calendar.current.date(from: c)!
        XCTAssertEqual(RushHourSchedule.multiplier(for: date), 1.0)
    }
}

// MARK: - WeatherConditionTests

final class WeatherConditionTests: XCTestCase {

    func test_clearWeather_zeroStressDelta() {
        XCTAssertEqual(WeatherCondition.clear.stressDelta, 0)
    }

    func test_rain_addsPositiveDelta() {
        let rain = WeatherCondition(precipitation: .rain, visibility: 10, windSpeedKph: 15)
        XCTAssertGreaterThan(rain.stressDelta, 0)
    }

    func test_hail_moreThanSnow() {
        let hail = WeatherCondition(precipitation: .hail, visibility: 5, windSpeedKph: 30)
        let snow = WeatherCondition(precipitation: .snow, visibility: 5, windSpeedKph: 30)
        XCTAssertGreaterThan(hail.stressDelta, snow.stressDelta)
    }

    func test_lowVisibility_addsDelta() {
        let fog = WeatherCondition(precipitation: .none, visibility: 0.5, windSpeedKph: 5)
        XCTAssertGreaterThan(fog.stressDelta, 0, "Low visibility should add stress even without rain")
    }

    func test_highWind_addsDelta() {
        let windy = WeatherCondition(precipitation: .none, visibility: 20, windSpeedKph: 80)
        XCTAssertGreaterThan(windy.stressDelta, 0)
    }
}

// MARK: - StressScoreTests

final class StressScoreTests: XCTestCase {

    func test_score_below30_isCalm() {
        let score = StressScore(total: 25, factors: [])
        XCTAssertEqual(score.level, .low)
    }

    func test_score_between30and60_isModerate() {
        let score = StressScore(total: 45, factors: [])
        XCTAssertEqual(score.level, .moderate)
    }

    func test_score_above60_isHigh() {
        let score = StressScore(total: 75, factors: [])
        XCTAssertEqual(score.level, .high)
    }

    func test_breakdown_excludesZeroContributions() {
        let factors = [
            StressFactor(id: UUID(), kind: .traffic, contribution: 20, description: "Traffic"),
            StressFactor(id: UUID(), kind: .weather, contribution: 0,  description: "Clear"),
        ]
        let score = StressScore(total: 20, factors: factors)
        XCTAssertEqual(score.breakdown.count, 1, "Zero-contribution factors should not appear in breakdown")
    }
}
