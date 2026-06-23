# Terrarium

[![CI](https://github.com/realtobyfu/terrarium/actions/workflows/ci.yml/badge.svg)](https://github.com/realtobyfu/terrarium/actions/workflows/ci.yml)

A native iOS app (iOS 26+, SwiftUI + RealityKit) that turns real-world exploration into a living terrarium you grow. Three tabs:

- **Home** — a 3D globe/terrarium that grows and gains vitality as you explore.
- **Drift** — a location-tracked walking "ramble" with a breadcrumb stream and geohash fog-of-war map.
- **Anchor** — a concierge that recommends a nearby place, lets you re-roll, shows distance + travel time in your preferred mode, and verifies arrival to award a specimen.

The core loop — **recommend → arrive → grow** — is the thing that has to feel rewarding.

## Tech

- Swift 5, SwiftUI + RealityKit + SwiftData + CoreLocation + WeatherKit
- iOS 26.0+, Xcode 26.0.1+
- System frameworks only — no SPM/CocoaPods dependencies
- MainActor default isolation, strict concurrency

## Build & test

```bash
xcodebuild build -project Terrarium.xcodeproj -scheme Terrarium \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0'

xcodebuild test -project Terrarium.xcodeproj -scheme Terrarium \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0'
```

## CI

Every pull request runs [`.github/workflows/ci.yml`](.github/workflows/ci.yml) on a `macos-26` runner:
builds, runs the test suite, launches the app on a dynamically-selected iOS 26 simulator, and
captures screenshots + a screen recording. Results (with the `.xcresult` and screenshots) are
posted as a sticky comment on the PR and uploaded as build artifacts.
