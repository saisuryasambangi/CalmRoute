//
//  NavigationSessionActor.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 24/03/2026.
//

import CoreLocation
import MapKit
import Foundation

// Owns the active navigation session. Tracks position, current step,
// arrival geofence, and drives Live Activity updates.
//
// One instance lives for the duration of a single navigation run —
// created when user taps "Go", torn down when they arrive or cancel.
actor NavigationSessionActor {

    // MARK: - Published state (read from MainActor views via await)

    private(set) var currentStepIndex: Int = 0
    private(set) var distanceToNextStep: CLLocationDistance = 0
    private(set) var isArrived = false
    private(set) var currentStressScore: Double = 0

    private let route: ScoredRoute
    private let liveActivityService: LiveActivityService
    private var locationTask: Task<Void, Never>?

    init(route: ScoredRoute, liveActivityService: LiveActivityService) {
        self.route = route
        self.liveActivityService = liveActivityService
        self.currentStressScore = route.stressScore.total
    }

    // MARK: - Session lifecycle

    func start(locationStream: AsyncStream<CLLocation>) async {
        let firstInstruction = route.route.steps.first?.instructions ?? "Starting navigation"
        await liveActivityService.start(
            routeName: route.label.rawValue,
            destination: route.route.name,
            instruction: firstInstruction,
            stressScore: Int(currentStressScore),
            eta: formattedETA(route.expectedTravelTime)
        )

        locationTask = Task { [weak self] in
            for await location in locationStream {
                guard !Task.isCancelled else { break }
                await self?.processLocation(location)
            }
        }
    }

    func stop() async {
        locationTask?.cancel()
        locationTask = nil
        await liveActivityService.stop()
    }

    // MARK: - Private

    private func processLocation(_ location: CLLocation) async {
        let steps = route.route.steps
        guard currentStepIndex < steps.count else { return }

        let stepCoordinate = steps[currentStepIndex].polyline.coordinate
        let stepLocation = CLLocation(
            latitude: stepCoordinate.latitude,
            longitude: stepCoordinate.longitude
        )
        let distance = location.distance(from: stepLocation)
        distanceToNextStep = distance

        // Advance step when we're within 30m
        if distance < 30, currentStepIndex < steps.count - 1 {
            currentStepIndex += 1
        }

        // Arrival check — within 50m of route endpoint
        if let lastStep = steps.last {
            let dest = CLLocation(
                latitude: lastStep.polyline.coordinate.latitude,
                longitude: lastStep.polyline.coordinate.longitude
            )
            if location.distance(from: dest) < 50 {
                isArrived = true
                await liveActivityService.stop()
                locationTask?.cancel()
                return
            }
        }

        // Update Live Activity every ~200m to avoid hammering it
        if Int(distanceToNextStep) % 200 == 0 {
            let steps = route.route.steps
            let instruction = currentStepIndex < steps.count
                ? steps[currentStepIndex].instructions
                : "Arriving"
            await liveActivityService.update(
                instruction: instruction,
                distanceToNext: formattedDistance(distanceToNextStep),
                stressScore: Int(currentStressScore),
                eta: formattedETA(route.expectedTravelTime)
            )
        }
    }

    private func formattedDistance(_ meters: CLLocationDistance) -> String {
        meters < 1000
            ? "\(Int(meters)) m"
            : String(format: "%.1f km", meters / 1000)
    }

    private func formattedETA(_ seconds: TimeInterval) -> String {
        "\(Int(seconds / 60)) min"
    }
}
