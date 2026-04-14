//
//  BackgroundRefreshManager.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 11/04/2026.
//
//  BGTaskScheduler integration specifically for WeatherKit stress recalculation.
//  Called once at app startup from CalmRouteApp.init().
//
//  Info.plist requirement:
//    Key:   BGTaskSchedulerPermittedIdentifiers (Array)
//    Item:  com.saisuryasambangi.calmroute.weatherrefresh
//

import BackgroundTasks
import Foundation

final class BackgroundRefreshManager: Sendable {

    static let taskIdentifier = "com.saisuryasambangi.calmroute.weatherrefresh"

    // MARK: - Registration

    /// Register the background refresh handler. Must be called before the
    /// app finishes launching (i.e. in CalmRouteApp.init()).
    static func registerTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            Task { await Self.handleWeatherRefresh(task: refreshTask) }
        }
    }

    // MARK: - Scheduling

    /// Schedule the next background refresh approximately 15 minutes from now.
    static func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("[BackgroundRefreshManager] Failed to schedule: \(error.localizedDescription)")
        }
    }

    // MARK: - Task handler

    private static func handleWeatherRefresh(task: BGAppRefreshTask) async {
        // Re-schedule before doing work so the chain never breaks if we're killed.
        scheduleNextRefresh()

        // Ensure iOS doesn't penalise us if time runs out.
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        do {
            try await refreshWeatherStressScores()
            task.setTaskCompleted(success: true)
            print("[BackgroundRefreshManager] Weather refresh completed")
        } catch {
            print("[BackgroundRefreshManager] Weather refresh failed: \(error.localizedDescription)")
            task.setTaskCompleted(success: false)
        }
    }

    // MARK: - Work

    private static func refreshWeatherStressScores() async throws {
        // 1. Read saved route destination from shared App Group store.
        let defaults = UserDefaults(suiteName: "group.com.saisuryasambangi.calmroute")
        guard let destination = defaults?.string(forKey: "savedRouteDestination"),
              !destination.isEmpty
        else {
            // No saved route — nothing to refresh.
            return
        }

        // 2. Fetch weather for the saved destination.
        //    WeatherService falls back to mock data when the WeatherKit
        //    entitlement is unavailable (e.g. in the simulator).
        let weather = await WeatherService().currentWeather()

        // 3. Derive a time-of-day float for the current hour.
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay = Double(hour)

        // 4. Compute an updated stress score using StressScoreFallback so we
        //    don't need to load the full Core ML stack in the background.
        //    Use a representative "arterial" road type for the saved route.
        let score = StressScoreFallback.score(
            trafficDensity: 0.5,          // default — no live traffic in background
            junctionComplexity: 0.3,
            roadType: "arterial",
            timeOfDay: timeOfDay,
            weatherInput: weather.stressDelta / 80.0  // normalise to 0–1
        )

        // 5. Write back to shared store so the widget reads it on next refresh.
        defaults?.set(Int(score), forKey: "lastStressScore")
        defaults?.set(Date(), forKey: "lastWeatherRefreshDate")
    }
}
