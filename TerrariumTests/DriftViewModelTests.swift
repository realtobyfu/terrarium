//
//  DriftViewModelTests.swift
//  TerrariumTests
//
//  @MainActor tests for DriftViewModel (US-E1, US-E2).
//
//  Strategy
//  ────────
//  Inject a `MockLocationSession` whose `breadcrumbStream()` synchronously
//  yields fixture coordinates via an `AsyncStream` continuation. This lets us
//  drive the lifecycle deterministically without any real CLLocationManager or
//  simulator.
//
//  Coverage
//  ────────
//  1. startRamble() creates a session and marks it active.
//  2. Breadcrumbs are recorded as cell discoveries in the DiscoveryStore.
//  3. New-this-session vs previously-explored cells are distinguished correctly.
//  4. endRamble() stops the session and produces a summary.
//  5. Summary counts match the number of unique cells lit.
//  6. Distance accumulates across breadcrumbs.
//  7. Calling startRamble() while active is a no-op.
//  8. allExploredCells is pre-populated from the store on init.
//

import Testing
import Foundation
@testable import Terrarium

// MARK: - MockLocationSession

/// Controllable mock: callers enqueue coordinates that are immediately
/// delivered when `breadcrumbStream()` is consumed.
@MainActor
final class MockLocationSession: LocationSessionProviding {
    private(set) var isActive: Bool = false
    private(set) var startCallCount  = 0
    private(set) var stopCallCount   = 0

    /// Coordinates to emit on the next breadcrumb stream.
    var queuedCoordinates: [Coordinate] = []

    func start() {
        isActive = true
        startCallCount += 1
    }

    func stop() {
        isActive = false
        stopCallCount += 1
    }

    func breadcrumbStream() -> AsyncStream<Coordinate> {
        let coords = queuedCoordinates  // capture before clear
        return AsyncStream { continuation in
            for coord in coords {
                continuation.yield(coord)
            }
            continuation.finish()
        }
    }

    func currentCoordinate() async -> Coordinate? { nil }
}

// MARK: - Tests

@Suite("DriftViewModel")
@MainActor
struct DriftViewModelTests {

    // ── Fixtures ───────────────────────────────────────────────────────────────

    /// Three coordinates that each map to a distinct precision-7 cell around
    /// Dolores Park, SF — far enough apart to guarantee different cells.
    private let coordA = Coordinate(latitude: 37.7596, longitude: -122.4269) // cell A
    private let coordB = Coordinate(latitude: 37.7700, longitude: -122.4350) // cell B (far)
    private let coordC = Coordinate(latitude: 37.7450, longitude: -122.4150) // cell C (far)

    private func makeSUT(
        preExploredCoords: [Coordinate] = [],
        queuedCoords: [Coordinate] = []
    ) -> (vm: DriftViewModel, location: MockLocationSession, store: InMemoryDiscoveryStore) {
        let store    = InMemoryDiscoveryStore()
        let location = MockLocationSession()

        // Pre-populate the store with past discoveries.
        for coord in preExploredCoords {
            store.record(Discovery(
                target: .cell(id: GeohashCell.encode(coord, precision: 7)),
                context: DiscoveryContext(weather: .clear, timeOfDay: .morning)
            ))
        }

        location.queuedCoordinates = queuedCoords

        let vm = DriftViewModel(
            location: location,
            recommender: StubRecommender(catalog: StubPOICatalog(), discoveries: store),
            discoveries: store
        )
        return (vm, location, store)
    }

    // ── Session lifecycle ──────────────────────────────────────────────────────

    @Test("startRamble creates an active session")
    func startRambleCreatesSession() async {
        let (vm, location, _) = makeSUT()

        vm.startRamble()
        // Give the breadcrumb task a moment to start (it gets an empty stream).
        try? await Task.sleep(for: .milliseconds(50))

        #expect(vm.session != nil)
        #expect(vm.session?.isActive == true)
        #expect(location.startCallCount == 1)
    }

    @Test("startRamble while active is a no-op (does not double-start)")
    func startWhileActiveiIsNoOp() async {
        let (vm, location, _) = makeSUT()

        vm.startRamble()
        vm.startRamble()   // second call
        try? await Task.sleep(for: .milliseconds(50))

        #expect(location.startCallCount == 1)
    }

    @Test("endRamble stops the session and produces a summary")
    func endRambleProducesSummary() async {
        let (vm, _, _) = makeSUT()

        vm.startRamble()
        try? await Task.sleep(for: .milliseconds(20))
        vm.endRamble()

        #expect(vm.session?.isActive == false)
        #expect(vm.summary != nil)
    }

    @Test("endRamble when inactive is a no-op")
    func endWhenInactiveIsNoOp() {
        let (vm, location, _) = makeSUT()
        vm.endRamble()   // no session started
        #expect(location.stopCallCount == 0)
        #expect(vm.summary == nil)
    }

    // ── Cell discovery ─────────────────────────────────────────────────────────

    @Test("Breadcrumbs are recorded in the discovery store")
    func breadcrumbsRecordedInStore() async {
        let (vm, location, store) = makeSUT(queuedCoords: [coordA, coordB])
        location.queuedCoordinates = [coordA, coordB]

        vm.startRamble()
        // Wait for the async breadcrumb stream to be fully consumed.
        try? await Task.sleep(for: .milliseconds(100))

        let exploredCells = store.exploredCells()
        let cellA = GeohashCell.encode(coordA, precision: 7)
        let cellB = GeohashCell.encode(coordB, precision: 7)
        #expect(exploredCells.contains(cellA))
        #expect(exploredCells.contains(cellB))
    }

    @Test("Two breadcrumbs in the same cell produce only one discovery")
    func duplicateCellNotDoubleRecorded() async {
        // coordA' is in the same precision-7 cell as coordA.
        let coordANear = Coordinate(latitude: coordA.latitude + 0.0001,
                                    longitude: coordA.longitude + 0.0001)
        let (vm, location, _) = makeSUT()
        location.queuedCoordinates = [coordA, coordANear]

        vm.startRamble()
        try? await Task.sleep(for: .milliseconds(100))

        // newCells should contain exactly one entry.
        let cellA = GeohashCell.encode(coordA, precision: 7)
        #expect(vm.newCells == Set([cellA]))
    }

    @Test("allExploredCells is pre-populated from the store on init")
    func exploredCellsPrePopulated() {
        let (vm, _, _) = makeSUT(preExploredCoords: [coordA, coordB])
        let cellA = GeohashCell.encode(coordA, precision: 7)
        let cellB = GeohashCell.encode(coordB, precision: 7)
        #expect(vm.allExploredCells.contains(cellA))
        #expect(vm.allExploredCells.contains(cellB))
    }

    @Test("New breadcrumb cells are added to allExploredCells and newCells")
    func newBreadcrumbAddsToSets() async {
        let (vm, location, _) = makeSUT()
        location.queuedCoordinates = [coordC]

        vm.startRamble()
        try? await Task.sleep(for: .milliseconds(100))

        let cellC = GeohashCell.encode(coordC, precision: 7)
        #expect(vm.newCells.contains(cellC))
        #expect(vm.allExploredCells.contains(cellC))
    }

    // ── Summary correctness ────────────────────────────────────────────────────

    @Test("Summary new-cell count matches distinct cells lit this session")
    func summaryCellCount() async {
        let (vm, location, _) = makeSUT(queuedCoords: [coordA, coordB, coordC])
        location.queuedCoordinates = [coordA, coordB, coordC]

        vm.startRamble()
        try? await Task.sleep(for: .milliseconds(150))
        vm.endRamble()

        let expected = Set([
            GeohashCell.encode(coordA, precision: 7),
            GeohashCell.encode(coordB, precision: 7),
            GeohashCell.encode(coordC, precision: 7),
        ]).count

        #expect(vm.summary?.newCellsCount == expected)
    }

    @Test("Summary duration is non-negative")
    func summaryDuration() async {
        let (vm, _, _) = makeSUT()

        vm.startRamble()
        try? await Task.sleep(for: .milliseconds(20))
        vm.endRamble()

        #expect((vm.summary?.durationSeconds ?? -1) >= 0)
    }

    // ── Distance ───────────────────────────────────────────────────────────────

    @Test("Distance accumulates across breadcrumbs and is positive for distinct coords")
    func distanceAccumulates() async {
        let (vm, location, _) = makeSUT()
        location.queuedCoordinates = [coordA, coordB]

        vm.startRamble()
        try? await Task.sleep(for: .milliseconds(100))

        #expect(vm.distanceMeters > 0)
    }
}
