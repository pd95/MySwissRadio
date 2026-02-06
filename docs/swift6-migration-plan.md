# Swift 6 Migration Plan

This document tracks the migration from legacy Swift/SwiftUI settings to a modern Swift 6 codebase.

## Current Status

- Date: 2026-02-06
- Build baseline: `xcodebuild -project MyRadio.xcodeproj -scheme MyRadio -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO -quiet build`
- Result: build succeeds under Swift 6 with strict concurrency set to `minimal`

## Completed

1. Switched project settings to Swift 6 (`SWIFT_VERSION = 6.0`) with `SWIFT_STRICT_CONCURRENCY = minimal`.
2. Removed Swift 5.0 per-target pins and aligned build settings in the project file.
3. Resolved blocking Swift 6 concurrency errors in app, widget extension, and intent extension.
4. Refactored `LivestreamStore+Networking` to remove Swift 6 sendability/data-race violations from nested task groups.
5. Updated singleton/shared-state declarations (`ImageCache`, `SettingsStore`, `NetworkClient`, `URLRequest` base URL) to pass Swift 6 checks.
6. Updated widget provider to remove mutable static shared state.
7. Updated app intent handling path for Swift 6 compatibility and restored green build.

## Next Steps (Recommended)

1. Remove remaining Swift 6 warnings in `MyRadio/Model/AudioController.swift`.
   - Add explicit actor isolation where required.
   - Resolve non-Sendable capture in callback closures.
2. Modernize SwiftUI navigation.
   - Replace `NavigationView` with `NavigationStack` in `MyRadio/ContentView.swift`.
   - Replace `NavigationView` in `MyRadio/WhatsPlayingToolbar.swift` preview.
3. Modernize previews.
   - Migrate `PreviewProvider` declarations to `#Preview` macros where practical.
4. Revisit Siri `INPlayMediaIntentHandling` behavior.
   - Validate `.handleInApp` flow on device and with Siri/Shortcuts.
   - Decide whether to keep compatibility bridge or implement a stricter main-actor handoff.
5. Tighten concurrency checks incrementally.
   - Move from `minimal` to `targeted`.
   - Fix newly surfaced issues.
   - Move from `targeted` to `complete` once clean.
6. Optional platform modernization.
   - Evaluate raising deployment target from iOS 15.6 to iOS 16/17.
   - If raised, simplify compatibility code and adopt newer APIs more broadly.

## Working Rules

- Keep changes small and commit per step.
- Re-run build after each step.
- Treat warnings as backlog items; no new warnings should be introduced.
