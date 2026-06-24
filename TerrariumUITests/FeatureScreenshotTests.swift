//
//  FeatureScreenshotTests.swift
//  TerrariumUITests
//
//  A lightweight, CI-only UI test that walks the app to the specific feature
//  screens we want to show off in the PR comment — the transport-mode
//  onboarding step and the Settings sheet — and attaches a named screenshot at
//  each stop. The named attachments are extracted from the .xcresult in CI and
//  rendered inline in the sticky PR comment.
//
//  This test is intentionally excluded from the main test scope (CI runs
//  `-only-testing:TerrariumTests` for speed); it is invoked on its own as a
//  best-effort capture step that never gates the build.
//
//  Determinism: we force the onboarding flow to appear by overriding the
//  persisted "onboarding completed" flag through the UserDefaults argument
//  domain (`-<key> <value>`), which takes precedence over any stored value.
//

import XCTest

final class FeatureScreenshotTests: XCTestCase {

    /// Generous timeout — hosted simulators are slow to settle on first launch.
    private let timeout: TimeInterval = 30

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureFeatureScreens() throws {
        let app = XCUIApplication()
        // Force onboarding regardless of any persisted state (argument domain
        // wins over the standard domain for `defaults.bool(forKey:)`).
        app.launchArguments += ["-terrarium.onboardingCompleted.v1", "NO"]
        app.launch()

        let continueButton = app.buttons["onboarding.continue"]
        XCTAssertTrue(
            continueButton.waitForExistence(timeout: timeout),
            "Onboarding Continue button never appeared — is onboarding being shown?"
        )

        // Interests → Vibe → Radius → Transport: tap Continue until the transport
        // step appears (persona is auto-skipped, so it's three taps from the first
        // visible step — we loop with a margin to stay resilient). The transport
        // chips set `.accessibilityElement(children: .ignore)`, which drops the
        // button trait, so we anchor on the unique "Transit" chip label via a
        // type-agnostic descendant query rather than `app.buttons`.
        let transportAnchor = app.descendants(matching: .any)["Transit"]
        for _ in 0..<5 {
            if transportAnchor.waitForExistence(timeout: 2) { break }
            if continueButton.exists && continueButton.isHittable { continueButton.tap() }
        }
        XCTAssertTrue(
            transportAnchor.waitForExistence(timeout: timeout),
            "Never reached the transport onboarding step."
        )

        capture(app, named: "01-Onboarding-Transport")

        // Finish onboarding straight from the transport step via Skip, landing on
        // Home (the gear lives on the Home top bar).
        let skip = app.buttons["onboarding.skip"]
        if skip.waitForExistence(timeout: timeout) {
            skip.tap()
        }

        // Open Settings via the gear.
        let gear = app.buttons["home.settingsButton"]
        XCTAssertTrue(
            gear.waitForExistence(timeout: timeout),
            "Home gear button never appeared after onboarding."
        )
        gear.tap()

        // The Settings sheet shows an inline "Settings" navigation title.
        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(
            settingsNav.waitForExistence(timeout: timeout),
            "Settings sheet never appeared."
        )

        capture(app, named: "02-Settings")
    }

    /// Attach a full-screen screenshot under a stable name so CI can pull it out
    /// of the .xcresult by attachment name.
    @MainActor
    private func capture(_ app: XCUIApplication, named name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
