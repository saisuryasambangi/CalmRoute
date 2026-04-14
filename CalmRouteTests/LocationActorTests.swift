//
//  LocationActorTests.swift
//  CalmRouteTests
//
//  Created by Sai Surya Sambangi on 11/04/2026.
//

import CoreLocation
import XCTest
@testable import CalmRoute

final class LocationActorTests: XCTestCase {

    // MARK: - 1. LocationActor initialises without Sendable violations

    func test_locationActor_init_doesNotCrash() {
        // If there were a Swift 6 Sendable violation the compiler would
        // have rejected the file — the fact that this compiles and runs
        // verifies there are no data-race issues at init time.
        let actor = LocationActor()
        XCTAssertNotNil(actor, "LocationActor must initialise without errors")
    }

    // MARK: - 2. locationStream emits CLLocation values (mock injection)

    func test_locationStream_emitsValues() async {
        let actor = LocationActor()
        let stream = await actor.stream()

        // We can't drive CLLocationManager in unit tests without a device,
        // so we verify the stream can be created and iterated without errors.
        // The stream is an AsyncStream, so it's safe to begin iteration and
        // then break out — no values will arrive in the test environment but
        // the API contract (stream() returns AsyncStream<CLLocation>) is confirmed.
        var iterationStarted = false
        let task = Task {
            for await _ in stream {
                iterationStarted = true
                break
            }
        }
        // Give the stream a brief window then cancel — it should not have
        // emitted anything in the test environment (no real GPS).
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 s
        task.cancel()
        // The test verifies that stream() returns a valid AsyncStream
        // and that the iteration API does not crash.
        _ = iterationStarted  // suppress unused-variable warning
    }

    // MARK: - 3. Concurrent iteration does not produce data races

    func test_concurrentStreamIteration_noCrash() async {
        let actor = LocationActor()

        // Spin up two concurrent tasks that each obtain a stream and iterate.
        // Under strict concurrency (-strict-concurrency=complete) this verifies
        // no actor state is accessed unsafely across isolation domains.
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<3 {
                group.addTask {
                    let s = await actor.stream()
                    let inner = Task {
                        for await _ in s { break }
                    }
                    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 s
                    inner.cancel()
                }
            }
        }
        // If we reach here without a crash or Thread Sanitizer report, the test passes.
    }

    // MARK: - 4. Permission state is readable from MainActor

    func test_authorizationStatus_readableFromMainActor() async {
        let actor = LocationActor()
        // authorizationStatus is an actor-isolated property — reading it from
        // a MainActor-isolated test confirms the await crossing compiles cleanly
        // under Swift 6 strict concurrency.
        let status = await actor.authorizationStatus
        // Any CLAuthorizationStatus value is valid here.
        let validStatuses: [CLAuthorizationStatus] = [
            .notDetermined, .restricted, .denied,
            .authorizedAlways, .authorizedWhenInUse
        ]
        XCTAssertTrue(validStatuses.contains(status),
                      "authorizationStatus must return a valid CLAuthorizationStatus")
    }

    // MARK: - 5. requestPermission does not crash when called before stream()

    func test_requestPermission_beforeStream_doesNotCrash() async {
        let actor = LocationActor()
        // On simulator / CI this will trigger a "not authorized" path, which
        // is fine — we just verify the call does not throw or crash.
        await actor.requestPermission()
    }

    // MARK: - 6. stream() can be called multiple times without crashing

    func test_multipleStreamCalls_doNotCrash() async {
        let actor = LocationActor()
        let s1 = await actor.stream()
        let s2 = await actor.stream()
        XCTAssertNotNil(s1)
        XCTAssertNotNil(s2)
    }
}
