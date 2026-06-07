//
//  BackgroundTaskService.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 26/03/2026.
//

import Foundation

final class BackgroundTaskService: Sendable {

    static func registerTasks() {
        BackgroundRefreshManager.registerTasks()
    }

    func scheduleRefresh() {
        BackgroundRefreshManager.scheduleNextRefresh()
    }
}
