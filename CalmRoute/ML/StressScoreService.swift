//
//  StressScoreService.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 11/04/2026.
//
//  @MainActor service that performs on-device stress score inference.
//  Uses the compiled StressRouteClassifier Core ML model when available;
//  falls back to StressScoreFallback (same formula) when the model cannot
//  be loaded or when a prediction throws.
//

import CoreML
import Foundation

@MainActor
final class StressScoreService: ObservableObject {

    static let shared = StressScoreService()

    // MARK: - State

    /// True once the Core ML model has been loaded successfully.
    @Published private(set) var isModelReady = false

    // The model is accessed only on @MainActor, so no extra Sendable boxing needed.
    private var model: MLModel?

    // MARK: - Init

    private init() {
        Task { await loadModel() }
    }

    // MARK: - Model loading

    private func loadModel() async {
        // The .mlmodel placeholder will fail to compile as a real model —
        // that's expected until the training script is run. In DEBUG builds
        // we skip loading so tests and previews always use the fallback path.
#if DEBUG
        isModelReady = false
        return
#else
        guard let modelURL = Bundle.main.url(
            forResource: "StressRouteClassifier",
            withExtension: "mlmodelc"
        ) else {
            print("[StressScoreService] StressRouteClassifier.mlmodelc not found in bundle — using fallback")
            isModelReady = false
            return
        }

        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine
            model = try MLModel(contentsOf: modelURL, configuration: config)
            isModelReady = true
            print("[StressScoreService] Core ML model loaded successfully")
        } catch {
            print("[StressScoreService] Model load error: \(error.localizedDescription) — using fallback")
            isModelReady = false
        }
#endif
    }

    // MARK: - Inference

    /// Returns a stress score in 0–100 for the given route inputs.
    /// Automatically falls back to the weighted formula if the model is
    /// unavailable or throws during prediction.
    func score(
        trafficDensity: Double,
        junctionComplexity: Double,
        roadType: String,
        timeOfDay: Double,
        weatherInput: Double
    ) async -> Double {
        if let model {
            do {
                return try predict(
                    model: model,
                    trafficDensity: trafficDensity,
                    junctionComplexity: junctionComplexity,
                    roadType: roadType,
                    timeOfDay: timeOfDay,
                    weatherInput: weatherInput
                )
            } catch {
                print("[StressScoreService] Prediction error: \(error.localizedDescription) — using fallback")
            }
        }
        return StressScoreFallback.score(
            trafficDensity: trafficDensity,
            junctionComplexity: junctionComplexity,
            roadType: roadType,
            timeOfDay: timeOfDay,
            weatherInput: weatherInput
        )
    }

    // MARK: - Private prediction helper

    private func predict(
        model: MLModel,
        trafficDensity: Double,
        junctionComplexity: Double,
        roadType: String,
        timeOfDay: Double,
        weatherInput: Double
    ) throws -> Double {
        let featureDict: [String: MLFeatureValue] = [
            "traffic_density":     MLFeatureValue(double: trafficDensity),
            "junction_complexity": MLFeatureValue(double: junctionComplexity),
            "road_type":           MLFeatureValue(string: roadType),
            "time_of_day":         MLFeatureValue(double: timeOfDay),
            "weather_input":       MLFeatureValue(double: weatherInput)
        ]

        let provider = try MLDictionaryFeatureProvider(dictionary: featureDict)
        let prediction = try model.prediction(from: provider)

        guard let scoreValue = prediction.featureValue(for: "stress_score")?.doubleValue else {
            throw StressScoreError.missingOutputFeature
        }

        return min(100.0, max(0.0, scoreValue))
    }
}

// MARK: - Errors

private enum StressScoreError: Error {
    case missingOutputFeature
}
