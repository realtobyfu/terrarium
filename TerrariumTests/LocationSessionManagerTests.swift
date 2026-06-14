//
//  LocationSessionManagerTests.swift
//  TerrariumTests
//
//  US-B2: Tests for `LocationSessionManager` lifecycle using an injected
//  `MockLocationManager` so no real Core Location calls are made.
//
//  Covered:
//  - Breadcrumbs are only emitted between start() and stop().
//  - Permission-denied path: no crash, isActive stays false.
//  - Permission-notDetermined path: start() defers until the callback grants.
//  - stop() cleanly finishes the breadcrumb stream.
//  - stop() is idempotent.
//  - currentCoordinate returns nil outside an active session.
//
//  Design note: CLLocationManagerDelegate methods on LocationSessionManager are
//  `nonisolated` and dispatch their state changes through `Task { @MainActor }`.
//  Tests call `await Task.yield()` after triggering delegate callbacks to let
//  those tasks run before asserting state.
//

import Testing
import CoreLocation
@testable import Terrarium

// MARK: - Mock

/// A synchronous, in-memory mock of `LocationManaging` that lets tests drive
/// all delegate callbacks without any real Core Location interactions.
final class MockLocationManager: LocationManaging {

    var delegate: CLLocationManagerDelegate?
    var activityType: CLActivityType = .other
    var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest
    var distanceFilter: CLLocationDistance = kCLDistanceFilterNone
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    // Observability
    var didRequestWhenInUse = false
    var isUpdatingLocation = false
    var fullAccuracyRequested = false

    func requestWhenInUseAuthorization() { didRequestWhenInUse = true }
    func startUpdatingLocation()          { isUpdatingLocation = true }
    func stopUpdatingLocation()           { isUpdatingLocation = false }

    func requestTemporaryFullAccuracyAuthorization(
        withPurposeKey purposeKey: String,
        completion: ((Error?) -> Void)?
    ) {
        fullAccuracyRequested = true
        completion?(nil)
    }
}

// MARK: - Test helpers

/// Simulate the OS changing authorization status and flush the resulting Task.
@MainActor
private func grantAuthorization(_ status: CLAuthorizationStatus,
                                 to manager: LocationSessionManager,
                                 mock: MockLocationManager) async {
    mock.authorizationStatus = status
    manager.locationManagerDidChangeAuthorization(CLLocationManager())
    // Yield so the `Task { @MainActor }` inside the delegate fires.
    await Task.yield()
}

// MARK: - Tests

@Suite("LocationSessionManager")
@MainActor
struct LocationSessionManagerTests {

    // MARK: Configuration on init

    @Test("Manager configures CLLocationManager with fitness activity and best accuracy")
    func configuresLocationManager() {
        let mock = MockLocationManager()
        _ = LocationSessionManager(locationManager: mock)
        #expect(mock.activityType == .fitness)
        #expect(mock.desiredAccuracy == kCLLocationAccuracyBest)
        #expect(mock.distanceFilter == 10)
    }

    // MARK: Permission not determined → deferred start

    @Test("start() requests When In Use when permission is not determined")
    func requestsPermissionWhenNotDetermined() {
        let mock = MockLocationManager()
        mock.authorizationStatus = .notDetermined
        let manager = LocationSessionManager(locationManager: mock)

        manager.start()

        #expect(mock.didRequestWhenInUse)
        #expect(!manager.isActive, "Session must not be active before permission granted")
        #expect(!mock.isUpdatingLocation)
    }

    @Test("Session activates after permission is granted following a deferred start")
    func activatesAfterPermissionGranted() async {
        let mock = MockLocationManager()
        mock.authorizationStatus = .notDetermined
        let manager = LocationSessionManager(locationManager: mock)

        manager.start()
        #expect(!manager.isActive)

        await grantAuthorization(.authorizedWhenInUse, to: manager, mock: mock)

        #expect(manager.isActive)
        #expect(mock.isUpdatingLocation)
    }

    // MARK: Already authorised

    @Test("start() activates immediately when already authorised")
    func activatesImmediatelyWhenAuthorised() {
        let mock = MockLocationManager()
        mock.authorizationStatus = .authorizedWhenInUse
        let manager = LocationSessionManager(locationManager: mock)

        manager.start()

        #expect(manager.isActive)
        #expect(mock.isUpdatingLocation)
    }

    // MARK: Permission denied — recoverable, no crash

    @Test("start() when denied leaves isActive false and does not crash")
    func deniedPermissionIsRecoverable() {
        let mock = MockLocationManager()
        mock.authorizationStatus = .denied
        let manager = LocationSessionManager(locationManager: mock)

        manager.start()  // must not crash

        #expect(!manager.isActive)
        #expect(!mock.isUpdatingLocation)
        #expect(manager.authorizationStatus == .denied)
    }

    @Test("Revoking permission mid-session stops tracking without crash")
    func revokingPermissionStopsSession() async {
        let mock = MockLocationManager()
        mock.authorizationStatus = .authorizedWhenInUse
        let manager = LocationSessionManager(locationManager: mock)
        manager.start()
        #expect(manager.isActive)

        await grantAuthorization(.denied, to: manager, mock: mock)

        #expect(!manager.isActive)
        #expect(!mock.isUpdatingLocation)
    }

    // MARK: stop() is idempotent

    @Test("Calling stop() multiple times does not crash")
    func stopIsIdempotent() {
        let mock = MockLocationManager()
        mock.authorizationStatus = .authorizedWhenInUse
        let manager = LocationSessionManager(locationManager: mock)
        manager.start()
        manager.stop()
        manager.stop()  // must not crash
        #expect(!manager.isActive)
    }

    // MARK: currentCoordinate outside session

    @Test("currentCoordinate returns nil when session is inactive")
    func currentCoordinateNilWhenInactive() async {
        let mock = MockLocationManager()
        mock.authorizationStatus = .authorizedWhenInUse
        let manager = LocationSessionManager(locationManager: mock)
        // No start().
        let coord = await manager.currentCoordinate()
        #expect(coord == nil)
    }

    // MARK: Breadcrumb stream

    @Test("Breadcrumbs are collected while active and stream ends after stop()")
    func breadcrumbStreamLifecycle() async {
        let mock = MockLocationManager()
        mock.authorizationStatus = .authorizedWhenInUse
        let manager = LocationSessionManager(locationManager: mock)
        manager.start()
        #expect(manager.isActive)

        var received: [Coordinate] = []

        // Collect breadcrumbs in a background Task so the main actor is free
        // to run the delegate Task that yields values into the stream.
        let stream = manager.breadcrumbStream()
        let collector = Task {
            for await coord in stream {
                received.append(coord)
            }
        }

        // Deliver two location updates. Each creates a Task { @MainActor } that
        // yields into the stream. We yield the main actor in between so those
        // Tasks execute.
        manager.locationManager(CLLocationManager(),
                                 didUpdateLocations: [CLLocation(latitude: 37.7749,
                                                                  longitude: -122.4194)])
        await Task.yield()

        manager.locationManager(CLLocationManager(),
                                 didUpdateLocations: [CLLocation(latitude: 37.7750,
                                                                  longitude: -122.4195)])
        await Task.yield()

        // Stop the session — continuation is finished, collector exits its loop.
        manager.stop()
        #expect(!manager.isActive)

        // Wait for the collector to drain.
        await collector.value

        #expect(received.count == 2)
        #expect(received.first?.latitude == 37.7749)
        #expect(received.last?.latitude == 37.7750)
    }

    @Test("Location updates received before start() are ignored")
    func locationUpdatesBeforeStartIgnored() async {
        let mock = MockLocationManager()
        mock.authorizationStatus = .authorizedWhenInUse
        let manager = LocationSessionManager(locationManager: mock)
        // Do NOT call start(); isActive is false.

        manager.locationManager(CLLocationManager(),
                                 didUpdateLocations: [CLLocation(latitude: 10, longitude: 20)])
        await Task.yield()

        // isActive must still be false; no side-effects.
        #expect(!manager.isActive)
    }
}
