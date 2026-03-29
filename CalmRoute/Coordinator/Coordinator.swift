//
//  Coordinator.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 28/03/2026.
//

import SwiftUI

enum AppRoute: Hashable {
    case search
    case comparison([ScoredRoute])
    case map(ScoredRoute)
    case navigating(ScoredRoute)

    // MKRoute isn't Hashable so we implement manually using ScoredRoute.id
    static func == (lhs: AppRoute, rhs: AppRoute) -> Bool {
        switch (lhs, rhs) {
        case (.search, .search):
            return true
        case (.comparison(let a), .comparison(let b)):
            return a.map(\.id) == b.map(\.id)
        case (.map(let a), .map(let b)):
            return a.id == b.id
        case (.navigating(let a), .navigating(let b)):
            return a.id == b.id
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .search:
            hasher.combine(0)
        case .comparison(let routes):
            hasher.combine(1)
            hasher.combine(routes.map(\.id))
        case .map(let route):
            hasher.combine(2)
            hasher.combine(route.id)
        case .navigating(let route):
            hasher.combine(3)
            hasher.combine(route.id)
        }
    }
}

enum CalmRouteSheet: Identifiable {
    case routeDetail(ScoredRoute)
    case settings

    var id: String {
        switch self {
        case .routeDetail(let r): return "detail-\(r.id)"
        case .settings:           return "settings"
        }
    }
}

@MainActor
final class AppCoordinator: ObservableObject {

    @Published var navigationPath = NavigationPath()
    @Published var activeSheet: CalmRouteSheet?

    // Shared services — injected down through the environment
    let locationActor    = LocationActor()
    let routeActor       = RouteActor()
    let weatherService   = WeatherService()
    let liveActivity     = LiveActivityService()
    let backgroundTasks  = BackgroundTaskService()

    func push(_ route: AppRoute) {
        navigationPath.append(route)
    }

    func pop() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
    }

    func popToRoot() {
        navigationPath = NavigationPath()
    }

    func show(sheet: CalmRouteSheet) {
        activeSheet = sheet
    }

    func dismissSheet() {
        activeSheet = nil
    }
}
