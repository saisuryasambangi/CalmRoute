//
//  LocationActor.swift
//  CalmRoute
//
//  Created by Sai Surya Sambangi on 19/03/2026.
//

import CoreLocation
import Foundation

actor LocationActor: NSObject {

    private var manager: CLLocationManager?
    private var continuation: AsyncStream<CLLocation>.Continuation?

    // Swift 5.9+ makeStream API avoids creating Tasks inside the AsyncStream
    // closure, which is what triggered the Swift 6 Sendable race warning.
    func stream() -> AsyncStream<CLLocation> {
        let (stream, continuation) = AsyncStream<CLLocation>.makeStream()
        start(continuation: continuation)
        return stream
    }

    func requestPermission() {
        if manager == nil {
            manager = CLLocationManager()
            manager?.delegate = self
        }
        manager?.requestWhenInUseAuthorization()
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager?.authorizationStatus ?? .notDetermined
    }

    // MARK: - Private

    private func start(continuation: AsyncStream<CLLocation>.Continuation) {
        self.continuation = continuation
        if manager == nil {
            manager = CLLocationManager()
            manager?.delegate = self
        }
        manager?.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager?.distanceFilter = 20
        manager?.startUpdatingLocation()

        continuation.onTermination = { [weak self] _ in
            Task { await self?.stop() }
        }
    }

    private func stop() {
        manager?.stopUpdatingLocation()
        continuation?.finish()
        continuation = nil
    }

    private func yield(_ location: CLLocation) {
        continuation?.yield(location)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationActor: CLLocationManagerDelegate {

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let latest = locations.last else { return }
        Task { await yield(latest) }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        print("[LocationActor] location error: \(error.localizedDescription)")
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {}
}
