# Technology Stack

**Analysis Date:** 2026-06-17

## Languages

**Primary:**
- Swift 5.0 - All application code, UI, domain logic, and testing

## Runtime

**Environment:**
- iOS 26.0+ (deployment target)
- Xcode 26.0.1 (minimum toolchain)

**Architecture:**
- Native iOS app using SwiftUI + Swift 5 concurrency (async/await)
- MainActor isolation enforced throughout for UI safety

## Frameworks

**Core UI & Framework:**
- SwiftUI - Declarative UI framework for all screens and views
- Combine - Reactive stream support for view model bindings and location updates

**3D Graphics & Rendering:**
- RealityKit - 3D globe rendering, scene composition, entity management
  - Used in: `WorldRendering/` module
  - Globe surface, specimens (3D models), clouds, atmosphere halo

**Data Storage & Persistence:**
- SwiftData - On-device database for world state, props, quests, journal entries
  - Models: `WorldStateRecord`, `WorldPropRecord`, `CompletedQuest`, `JournalEntry`
  - Location: `Terrarium/Domain/PersistenceModels.swift`, `Terrarium/App/AppContainer.swift`

**Location & Weather:**
- CoreLocation - Device location tracking (When In Use authorization)
  - Session-scoped tracking via `LocationSessionManager`
  - One-shot coordinate reads for geofence verification
- WeatherKit - Real-time weather conditions via Apple's weather service
  - Requires: WeatherKit capability + developer.apple.com entitlement
  - Maps conditions to app's `Weather` enum
  - Implementation: `Terrarium/Domain/WeatherKitProvider.swift`

**Maps & Navigation:**
- MapKit - Map rendering and display
  - Used in Drift and Anchor features for map views

**Math & Geometry:**
- SIMD (Swift SIMD) - Vector math for 3D positioning and sphere coordinates
  - Handles latitude/longitude→radians conversion for globe placement
  - Used throughout domain layer for coordinate calculations

**Observation & State Management:**
- Observation framework - SwiftUI @Observable decorator for view models
  - Used in: `AnchorViewModel`, `DriftViewModel`, `HomeViewModel`, `OnboardingViewModel`

**Testing:**
- Swift Testing framework - New Apple testing framework
  - Used throughout `TerrariumTests/` suite
  - Async test support with `@Test` macro

**Graphics & Rendering Utilities:**
- UIKit - UIColor, UIImage, and Core Graphics integration points
  - Used in `WorldRendering/` for texture generation and rendering setup
- CoreGraphics - Texture drawing and image composition

## Configuration

**Build Settings:**
- `IPHONEOS_DEPLOYMENT_TARGET`: 26.0
- `SWIFT_VERSION`: 5.0
- `SWIFT_APPROACHABLE_CONCURRENCY`: YES (strict concurrency checking enabled)
- `SWIFT_DEFAULT_ACTOR_ISOLATION`: MainActor (default isolation)
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY`: YES (future language feature)
- `CODE_SIGN_STYLE`: Automatic
- `DEVELOPMENT_TEAM`: 679K683SQ5 (Tobias Fu personal team)

**Entitlements:**
- Location services (When In Use)
- Background location updates (for Drift sessions)
- WeatherKit capability (when entitlement is enabled)

**Info.plist Settings:**
- `NSLocationWhenInUseUsageDescription`: "Terrarium draws your map and grows your terrarium while you explore. Location is only used during an active session."
- Background modes: location

**Project Structure:**
- Uses Xcode's file system synchronization (PBXFileSystemSynchronizedRootGroup)
- No external package dependencies (SPM or CocoaPods) - all functionality via system frameworks

## Key Dependencies

**Critical System Frameworks:**
- SwiftData (persistence) - Mandatory for world state durability
- CoreLocation (location) - Required for Explore feature (Drift/Anchor)
- WeatherKit (weather) - When entitled; graceful fallback to `.clear` if missing

**Internal Modules:**
- `Terrarium/Domain/` - Pure business logic, providers, algorithms
- `Terrarium/App/` - Dependency injection container (composition root)
- `Terrarium/WorldRendering/` - 3D globe and visualization
- `Terrarium/AnchorFeature/` - POI discovery and quest system
- `Terrarium/DriftFeature/` - Map-based exploration with breadcrumb tracking
- `Terrarium/HomeFeature/` - Home screen and globe view
- `Terrarium/DesignSystem/` - Design tokens and reusable components

## Optional Dependencies

**When Available (graceful degradation):**
- WeatherKit - Falls back to stub provider (`.clear` condition) if entitlement absent
- CoreLocation - Full accuracy requests optional; `.fitness` activity type for efficiency
- CLGeocoder - Location reverse-geocoding (future wiring)

## Platform Requirements

**Development:**
- macOS with Xcode 26.0.1+
- Swift 5.0 toolchain
- iOS 26.0 or later on device/simulator

**Production:**
- iOS 26.0+ devices
- Apple Developer Program account (required for location/WeatherKit entitlements)
- iCloud sync optional (SwiftData CloudKit integration available but not wired)

**Permissions Required:**
- Location services (NSLocationWhenInUseUsageDescription)
- (Optional) Camera/microphone if future journal video recording is added

---

*Stack analysis: 2026-06-17*
