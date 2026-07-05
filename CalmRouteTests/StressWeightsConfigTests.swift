//
//  StressWeightsConfigTests.swift
//  CalmRouteTests
//
//  Created by Sai Surya Sambangi on 23/05/2026.
//

import XCTest
@testable import CalmRoute

final class StressWeightsConfigTests: XCTestCase {

    // UserDefaults keys that SettingsSheet writes and fromUserDefaults() reads.
    private let trafficKey  = "trafficWeight"
    private let junctionKey = "junctionWeight"
    private let weatherKey  = "weatherWeight"

    override func tearDown() {
        // Remove keys after every test so they never bleed into the next one.
        UserDefaults.standard.removeObject(forKey: trafficKey)
        UserDefaults.standard.removeObject(forKey: junctionKey)
        UserDefaults.standard.removeObject(forKey: weatherKey)
        super.tearDown()
    }

    // All five hardcoded default weights must add up to exactly 1.0.
    // If someone adjusts a constant and forgets to rebalance, this fails.
    func test_defaults_sumToOne() {
        let d = StressWeightsConfig.defaults
        let total = d.traffic + d.junctions + d.roadType + d.weather + d.timeOfDay
        XCTAssertEqual(total, 1.0, accuracy: 0.001,
                       "All five default weights must sum to 1.0")
    }

    // When all three slider keys are 0 (sum == 0), fromUserDefaults() must
    // fall back to the hardcoded defaults rather than divide-by-zero.
    func test_fromUserDefaults_withZeroValues_returnsDefaults() {
        UserDefaults.standard.set(0.0, forKey: trafficKey)
        UserDefaults.standard.set(0.0, forKey: junctionKey)
        UserDefaults.standard.set(0.0, forKey: weatherKey)
        let config = StressWeightsConfig.fromUserDefaults()
        XCTAssertEqual(config.traffic, StressWeightsConfig.defaults.traffic, accuracy: 0.001,
                       "All-zero slider values must fall back to defaults")
    }

    // Regardless of what the sliders are set to, the five weights must
    // always sum to 1.0 so the scoring math stays consistent.
    func test_fromUserDefaults_customValues_sumToOne() {
        UserDefaults.standard.set(60.0, forKey: trafficKey)
        UserDefaults.standard.set(10.0, forKey: junctionKey)
        UserDefaults.standard.set(20.0, forKey: weatherKey)
        let config = StressWeightsConfig.fromUserDefaults()
        let total = config.traffic + config.junctions + config.roadType + config.weather + config.timeOfDay
        XCTAssertEqual(total, 1.0, accuracy: 0.001,
                       "Weights must sum to 1.0 for any valid slider combination")
    }

    // The slider defaults (30 / 25 / 15) were chosen to reproduce the
    // original hardcoded weights exactly. This test locks that contract.
    func test_fromUserDefaults_defaultSliderValues_matchHardcodedDefaults() {
        UserDefaults.standard.set(30.0, forKey: trafficKey)
        UserDefaults.standard.set(25.0, forKey: junctionKey)
        UserDefaults.standard.set(15.0, forKey: weatherKey)
        let config = StressWeightsConfig.fromUserDefaults()
        XCTAssertEqual(config.traffic,   0.30, accuracy: 0.001,
                       "Default slider value for traffic must reproduce 0.30")
        XCTAssertEqual(config.junctions, 0.25, accuracy: 0.001,
                       "Default slider value for junctions must reproduce 0.25")
        XCTAssertEqual(config.weather,   0.15, accuracy: 0.001,
                       "Default slider value for weather must reproduce 0.15")
    }
}
