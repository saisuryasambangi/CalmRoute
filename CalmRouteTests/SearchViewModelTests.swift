//
//  SearchViewModelTests.swift
//  CalmRouteTests
//
//  Created by Sai Surya Sambangi on 23/05/2026.
//

import MapKit
import XCTest
@testable import CalmRoute

// SearchViewModel is @MainActor, so the whole class runs on the main actor.
// setUp/tearDown use the async overrides so actor isolation is respected.
@MainActor
final class SearchViewModelTests: XCTestCase {

    private var vm: SearchViewModel!

    override func setUp() async throws {
        vm = SearchViewModel(locationActor: LocationActor())
    }

    override func tearDown() async throws {
        vm = nil
    }

    // search() short-circuits before spawning any Task when count < 2,
    // so the assert is synchronous — no waiting needed.
    func test_query_belowMinLength_clearsSuggestions() {
        vm.suggestions = [MKMapItem()]   // seed so we can prove it gets wiped
        vm.query = "a"
        vm.search()
        XCTAssertTrue(vm.suggestions.isEmpty,
                      "A single-character query must clear suggestions immediately")
    }

    // The guard `query.count >= 2` fires before the Task is created,
    // so isSearching can never become true for an empty query.
    func test_query_empty_doesNotSearch() {
        vm.query = ""
        vm.search()
        XCTAssertFalse(vm.isSearching,
                       "An empty query must not start a search")
    }

    // userLocation is nil right after init (no location stream has fired).
    // The ViewModel's routeToDestination guard catches this and writes errorMessage.
    func test_routeToDestination_nilLocation_setsErrorMessage() async {
        XCTAssertNil(vm.userLocation, "Precondition: userLocation must be nil after init")
        await vm.routeToDestination(MKMapItem())
        XCTAssertNotNil(vm.errorMessage,
                        "errorMessage must be set when userLocation is nil")
    }
}
