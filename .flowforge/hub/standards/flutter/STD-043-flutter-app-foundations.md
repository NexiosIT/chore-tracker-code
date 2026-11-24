---
id: STD-043
name: "Flutter App Foundations"
version: "0.1.0"
category: flutter
status: active
last_reviewed: "2026-11-23"
discovery_layer: "manual"
---

# Flutter App Foundations

> The Flutter app MUST use Material 3 theming driven by the hub design system, a feature-first folder layout, one typed API client generated from the backend contracts, and local notifications plus background checks instead of an external push service.

## Motivation

This starter standard sets the few decisions made during bootstrap that every generated screen depends on. Without it, each feature would pick its own theme values, folder layout, HTTP calls and notification approach. The rules are deliberately few: more Flutter standards are expected to come out of the pathfinder feature.

## Rules

1. **Material 3 theming.** The app MUST set `useMaterial3: true` and build one `ThemeData` (light and dark) from the hub's `design-system/` tokens. Widgets MUST read colours, typography and shapes from `Theme.of(context)`, never from hard-coded values (see STD-017).

2. **Feature-first layout.** Code under `lib/` MUST be grouped by spec domain: `lib/features/{domain}/` for `family`, `chores`, `rewards` and `notifications`. Shared code goes in `lib/core/` (API client, theme, routing, notifications). A feature folder MUST NOT import from another feature folder's internals.

3. **One typed API client.** All calls to `chore-tracker-api` MUST go through a single API client in `lib/core/api/`. Its request and response types MUST be generated from, or checked against, the OpenAPI contracts the specs produce (see STD-024). Widgets MUST NOT make HTTP calls directly.

4. **Notifications without an external push service.** "Chore due soon" reminders MUST be scheduled as local Android notifications as soon as the app knows a chore's timer. Other events (chore assigned, chore needs approval, chore completed) MUST be picked up by a periodic background check against the API. The app MUST NOT depend on Firebase Cloud Messaging or another push service unless this standard is amended.

5. **Android support.** The Android `minSdk` MUST be 29 (Android 10). Any plugin added to the app MUST support API level 29.

6. **Widget tests.** Every screen MUST have widget tests that drive it through the API client interface with a fake. Tests live next to the code under `test/features/{domain}/` and follow the scenario-key naming in STD-035.

## Notes

- The code repository `NexiosIT/chore-tracker-code` holds both this app and the backend. Keep the Flutter project in its own top-level folder so Flutter and Gradle tooling for the backend do not interfere.
- Rule 4 records the bootstrap decision (trace BST-028). Switching to instant push notifications is a change to this standard, not a per-feature choice.
