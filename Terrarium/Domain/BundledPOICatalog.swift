//
//  BundledPOICatalog.swift
//  Terrarium — Domain
//
//  Stream A / US-A1: loads the bundled sf-pois.json and conforms to
//  `POICatalogProviding` so QuestGrounding, the ranker (Stream C), and Anchor /
//  Drift (Streams D/E) all share one offline source of truth.
//
//  Design rules
//  ────────────
//  • Malformed or missing JSON → empty catalog, never a crash (US-A1 AC).
//  • `parse(_:)` is `static` and `public` so tests can exercise the decoder
//    with inline fixtures, independent of the bundle.
//  • `bundle` and `resourceName` are injectable for tests that need a
//    missing-resource scenario without touching the real bundle.
//  • The type is a `struct` (value type) because the catalog is immutable after
//    init; the POIs array is built once on first access.
//

import Foundation

/// A POI catalog loaded from a bundled JSON file (`sf-pois.json` by default).
///
/// Conforms to `POICatalogProviding` so it slots directly into `AppContainer`
/// in place of `StubPOICatalog` once Stream A lands. The catalog is loaded
/// lazily on first call to `all()` or `allowedRefs()` and cached in memory.
///
/// ```swift
/// let catalog = BundledPOICatalog()          // production: .main bundle
/// let testCatalog = BundledPOICatalog(       // test: custom fixture file
///     bundle: .module,
///     resourceName: "test-pois"
/// )
/// ```
struct BundledPOICatalog: POICatalogProviding {

    // MARK: - Configuration

    private let bundle: Bundle
    private let resourceName: String

    // MARK: - Init

    init(bundle: Bundle = .main, resourceName: String = "sf-pois") {
        self.bundle = bundle
        self.resourceName = resourceName
    }

    // MARK: - POICatalogProviding

    func all() -> [POI] { loadedPOIs }

    func allowedRefs() -> Set<String> {
        Set(loadedPOIs.map(\.poiRef))
    }

    // MARK: - Public static parse (testable without a bundle)

    /// Decodes a JSON `[POI]` array from raw data.
    ///
    /// Returns an empty array — never throws — if the data is malformed or does
    /// not decode into `[POI]`. This keeps the catalog safe on the hot path and
    /// lets tests assert the degrade-to-empty contract directly.
    static func parse(_ data: Data) -> [POI] {
        do {
            return try JSONDecoder().decode([POI].self, from: data)
        } catch {
            // Intentionally silent: a malformed catalog is bad curator data,
            // not a programmer error. The app degrades to an empty catalog rather
            // than crashing or throwing, matching the offline-first discipline.
            return []
        }
    }

    // MARK: - Private

    /// Lazily resolved on first access; repeated calls return the same array.
    /// Because `BundledPOICatalog` is a value type the result is recomputed if
    /// the struct is copied, but in practice `AppContainer` holds one instance.
    private var loadedPOIs: [POI] {
        guard
            let url = bundle.url(forResource: resourceName, withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else {
            // Missing or unreadable resource → degrade gracefully (US-A1 AC).
            return []
        }
        return Self.parse(data)
    }
}
