//
//  RouteActor.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 24/03/2026.
//

@preconcurrency import MapKit
import Foundation

// Wraps [MKRoute] so it can cross Swift 6 task/actor boundaries safely.
// MKRoute is an ObjC class Apple never marked Sendable — @unchecked Sendable
// is safe here because we only ever read routes after construction.
private struct RouteBox: @unchecked Sendable {
    let routes: [MKRoute]
    init(_ routes: [MKRoute]) { self.routes = routes }
}

actor RouteActor {

    private let engine = StressEngine()
    private var cache: [CacheKey: CachedRoutes] = [:]
    private let cacheTTL: TimeInterval = 5 * 60

    // MARK: - Main fetch

    func fetchScoredRoutes(
        from origin: CLLocationCoordinate2D,
        to destination: MKMapItem,
        weather: WeatherCondition,
        at date: Date = Date()
    ) async throws -> [ScoredRoute] {

        let key = CacheKey(origin: origin, destination: destination.placemark.coordinate)
        if let cached = cache[key], cached.isValid(ttl: cacheTTL) {
            return scored(routes: cached.routes, weather: weather, at: date)
        }

        let routes = try await fetchRoutes(from: origin, to: destination)
        cache[key] = CachedRoutes(routes: routes, fetchedAt: Date())
        return scored(routes: routes, weather: weather, at: date)
    }

    // MARK: - Private

    private func fetchRoutes(
        from origin: CLLocationCoordinate2D,
        to destination: MKMapItem
    ) async throws -> [MKRoute] {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = destination
        request.transportType = .automobile
        request.requestsAlternateRoutes = true

        let directions = MKDirections(request: request)
        do {
            // MKRoute isn't Sendable, so box it before crossing the task boundary.
            let box = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<RouteBox, Error>) in
                directions.calculate { response, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let routes = response?.routes, !routes.isEmpty {
                        continuation.resume(returning: RouteBox(Array(routes.prefix(3))))
                    } else {
                        continuation.resume(throwing: CalmRouteError.noRoutesFound)
                    }
                }
            }
            return box.routes
        } catch let error as CalmRouteError {
            throw error
        } catch {
            throw CalmRouteError.routeCalculationFailed
        }
    }

    private func scored(
        routes: [MKRoute],
        weather: WeatherCondition,
        at date: Date
    ) -> [ScoredRoute] {
        var result = routes.map { route in
            ScoredRoute(
                id: UUID(),
                route: route,
                stressScore: engine.score(route: route, weather: weather, at: date),
                label: .balanced
            )
        }

        result.sort { $0.stressScore.total < $1.stressScore.total }

        let fastestIdx = result.indices.min {
            result[$0].expectedTravelTime < result[$1].expectedTravelTime
        } ?? 0

        return result.enumerated().map { i, route in
            var label: ScoredRoute.RouteLabel = .balanced
            if i == 0 { label = .calmest }
            else if i == fastestIdx { label = .fastest }
            return ScoredRoute(
                id: route.id,
                route: route.route,
                stressScore: route.stressScore,
                label: label
            )
        }
    }

    func clearCache() { cache.removeAll() }
}

// MARK: - Cache helpers

private struct CacheKey: Hashable {
    let originLat: Double
    let originLon: Double
    let destLat: Double
    let destLon: Double

    init(origin: CLLocationCoordinate2D, destination: CLLocationCoordinate2D) {
        originLat = (origin.latitude  * 1000).rounded() / 1000
        originLon = (origin.longitude * 1000).rounded() / 1000
        destLat   = (destination.latitude  * 1000).rounded() / 1000
        destLon   = (destination.longitude * 1000).rounded() / 1000
    }
}

private struct CachedRoutes {
    let routes: [MKRoute]
    let fetchedAt: Date

    func isValid(ttl: TimeInterval) -> Bool {
        Date().timeIntervalSince(fetchedAt) < ttl
    }
}
