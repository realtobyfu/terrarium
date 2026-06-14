//
//  LocationSessionManager.swift
//  Terrarium — Domain
//
//  US-B2 (FR-6): Session-scoped location tracking. The manager only starts
//  emitting breadcrumbs after `start()` and ceases after `stop()`. It uses
//  `When In Use` authorisation, `.fitness` activity type, and best accuracy.
//
//  Unit-testability: `CLLocationManager` is hidden behind `LocationManaging` so
//  tests inject `MockLocationManager` without touching the real Core Location
//  framework. The production path injects `CLLocationManager` directly.
//
//  Permission-denied path: if the user denies or restricts location access the
//  manager surfaces `authorizationStatus == .denied / .restricted` via the
//  `authorizationStatus` published property. Callers should observe this and
//  show a recoverable "open Settings" prompt — no crash, no silent failure.
//
//  DEPLOY NOTE:
//    The Info.plist key `NSLocationWhenInUseUsageDescription` must be present.
//    It is injected via the build setting
//    `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` in project.pbxproj
//    (Stream B is the only Wave-1 stream authorised to edit that file).
//

import Foundation
import CoreLocation
import Combine

// MARK: - Testability seam

/// The subset of `CLLocationManager` that `LocationSessionManager` actually
/// uses, expressed as a protocol so tests can inject a pure mock.
protocol LocationManaging: AnyObject {
    var delegate: CLLocationManagerDelegate? { get set }
    var activityType: CLActivityType { get set }
    var desiredAccuracy: CLLocationAccuracy { get set }
    var distanceFilter: CLLocationDistance { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestWhenInUseAuthorization()
    func startUpdatingLocation()
    func stopUpdatingLocation()
    /// Full accuracy (iOS 14+). Implementations that don't need it can be no-ops.
    func requestTemporaryFullAccuracyAuthorization(withPurposeKey purposeKey: String,
                                                   completion: ((Error?) -> Void)?)
}

/// Make the real `CLLocationManager` conform to the seam.
extension CLLocationManager: LocationManaging {
    func requestTemporaryFullAccuracyAuthorization(
        withPurposeKey purposeKey: String,
        completion: ((Error?) -> Void)?
    ) {
        requestTemporaryFullAccuracyAuthorization(withPurposeKey: purposeKey,
                                                  completion: completion)
    }
}

// MARK: - Session manager

/// Concrete `LocationSessionProviding` backed by Core Location.
///
/// Thread-safety: all `CLLocationManagerDelegate` callbacks arrive on the main
/// thread; the breadcrumb continuation is also resumed on main, which is fine
/// for the Combine-style consumers (Drift map, verifier). `@MainActor` pins the
/// entire class so Swift concurrency doesn't introduce data races.
@MainActor
final class LocationSessionManager: NSObject, LocationSessionProviding {

    // MARK: State

    private(set) var isActive: Bool = false

    /// Exposed so the UI can observe permission state and show "open Settings".
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    // MARK: Private

    private let locationManager: LocationManaging
    /// The continuation that feeds the breadcrumb stream.
    private var breadcrumbContinuation: AsyncStream<Coordinate>.Continuation?
    /// Stored until either `start()` or a permission change arrives.
    private var pendingStart: Bool = false
    /// The most recent location fix delivered by the delegate.
    /// Retained so `currentCoordinate()` can return it as a one-shot read
    /// without needing an active breadcrumb stream consumer (US-F1, FR-15).
    private var lastKnownCoordinate: Coordinate?

    // MARK: Init

    init(locationManager: LocationManaging = CLLocationManager()) {
        self.locationManager = locationManager
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()

        // Wire delegate BEFORE calling any methods.
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // Emit every ~10 m so breadcrumbs have reasonable granularity while
        // sparing the battery and the fog-of-war cell resolution.
        locationManager.distanceFilter = 10
    }

    // MARK: LocationSessionProviding

    func start() {
        guard !isActive else { return }
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            // Ask first; `locationManagerDidChangeAuthorization` will call back.
            pendingStart = true
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            activateSession()
        case .denied, .restricted:
            // Caller should observe `authorizationStatus` and show Settings prompt.
            break
        @unknown default:
            break
        }
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        pendingStart = false
        locationManager.stopUpdatingLocation()
        breadcrumbContinuation?.finish()
        breadcrumbContinuation = nil
    }

    func breadcrumbStream() -> AsyncStream<Coordinate> {
        // If a stream is already live, finish it cleanly and hand out a new one.
        breadcrumbContinuation?.finish()
        breadcrumbContinuation = nil
        return AsyncStream { [weak self] continuation in
            self?.breadcrumbContinuation = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.breadcrumbContinuation = nil
                }
            }
        }
    }

    func currentCoordinate() async -> Coordinate? {
        // US-F1 (FR-15): return the last known fix so the geofence verifier can
        // make a one-shot read without a full breadcrumb-stream consumer.
        //
        // Strategy:
        // • If a session is active AND we have a recent breadcrumb, return it
        //   immediately (zero-latency path used by AnchorViewModel distance calc
        //   and LocationVerifier).
        // • If the manager is authorised but no session is active (e.g. the user
        //   taps "I'm here" before starting a Drift) we still return the last fix
        //   so the geofence verifier can award optimistically rather than
        //   silently failing.
        // • If lastKnownCoordinate is nil (no fix yet / permission denied) the
        //   verifier receives nil and degrades to honor-mode per decisions.md #6.
        return lastKnownCoordinate
    }

    // MARK: Private helpers

    private func activateSession() {
        isActive = true
        pendingStart = false
        // Request temporary full accuracy if the user granted reduced accuracy.
        requestFullAccuracyIfNeeded()
        locationManager.startUpdatingLocation()
    }

    private func requestFullAccuracyIfNeeded() {
        // `accuracyAuthorization` lives on CLLocationManager (iOS 14+) only.
        // We gate on the real type to avoid mock complexity.
        guard let clm = locationManager as? CLLocationManager else { return }
        if clm.accuracyAuthorization == .reducedAccuracy {
            clm.requestTemporaryFullAccuracyAuthorization(
                withPurposeKey: "ExploreAccuracy"
            ) { _ in /* errors are non-fatal; best effort */ }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationSessionManager: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Read status from the injected locationManager (which may be a mock),
        // not from the passed-in `manager` parameter which could be a different
        // CLLocationManager instance (e.g. when calling the delegate directly
        // in tests).
        Task { @MainActor [weak self] in
            guard let self else { return }
            let status = self.locationManager.authorizationStatus
            self.authorizationStatus = status
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                if self.pendingStart {
                    self.activateSession()
                }
            case .denied, .restricted:
                self.pendingStart = false
                if self.isActive { self.stop() }
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coord = Coordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Always update lastKnownCoordinate (even outside an active session)
            // so the geofence verifier can do a one-shot read (US-F1).
            self.lastKnownCoordinate = coord
            // Breadcrumbs are only emitted while a session is active (FR-6).
            guard self.isActive else { return }
            self.breadcrumbContinuation?.yield(coord)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        // Location errors are non-fatal: the session stays alive,
        // breadcrumbs simply pause until the signal returns.
    }
}
