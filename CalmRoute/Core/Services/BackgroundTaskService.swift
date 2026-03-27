//
//  BackgroundTaskService.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 26/03/2026.
//

import BackgroundTasks
import Foundation

final class BackgroundTaskService: Sendable {

    static let refreshTaskID = "com.saisuryasambangi.calmroute.refresh"

    static func registerTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: refreshTaskID,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            BackgroundTaskService.handleRefresh(task: refreshTask)
        }
    }

    func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("[BackgroundTaskService] schedule failed: \(error)")
        }
    }

    // MARK: - Task handler

    private static func handleRefresh(task: BGAppRefreshTask) {
        // Re-schedule before doing any work so the chain never breaks
        BackgroundTaskService().scheduleRefresh()

        // Set expiration handler first — if iOS kills us mid-run we still
        // mark the task completed so the system doesn't penalise us.
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        // In production this would fetch the saved destination from
        // the App Group store, compute stress, and write the result back
        // for the widget to read. For the portfolio we complete immediately —
        // the important thing is the correct BGTask lifecycle pattern.
        task.setTaskCompleted(success: true)
    }
}
