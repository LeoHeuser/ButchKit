# ButchKit

A lean SwiftUI component library extending native Apple platform patterns.

**Platform Support**: iOS/iPadOS 17.0+ and macOS 14.0+
**Toolchain**: Swift 6.2 or newer (Xcode 26+)

## Installation

### Swift Package Manager

In Xcode:
1. **File** → **Add Package Dependencies…**
2. Enter the URL: `https://github.com/LeoHeuser/ButchKit`
3. Click **Add Package**

Or add it to your `Package.swift` dependencies:

```swift
dependencies: [
.package(url: "https://github.com/LeoHeuser/ButchKit", from: "2.0.0")
]
```

## Documentation

Each component or element in this SDK is documented in code.

Prose that applies across the library lives in [`Documentation/`](Documentation/ButchKit.md):

- [Logging Strategy](Documentation/LoggingStrategy.md) — where, what, and at which level an app and ButchKit log.
- [Paywall](Documentation/Paywall.md) — how an app sells its subscription: setup, gating, presenting, analytics.
- [External packages](Documentation/ExternalPackages.md) — how an app lists its external packages and lets the user turn the optional ones off.

## Localization

ButchKit ships no strings. Every text it shows is handed in by your app, so each key is written
in your code and Xcode extracts it into your catalogs like any other string.
See [Localization](Documentation/ButchKit.md#localization) for which string goes where.

## Development

Work on ButchKit's previews in [`Development/ButchKit.xcworkspace`](Development/ButchKit.xcworkspace)
with the **ButchKit Previews** scheme. Only that scheme selects the StoreKit file the paywall
previews load their products from. The package's own scheme stays free of it, so an app workspace
that includes a local ButchKit checkout sees no StoreKit settings of ButchKit's. Close that app
workspace first: Xcode opens a package in one window at a time.

### Changing main

`main` only changes through a pull request that is rebased onto it once the **CI passed** check
is green. Direct pushes, force pushes and deleting `main` are refused.

1. Commit on a branch and push it.
2. Open a pull request into `main`: "Compare & pull request" on GitHub, or
   `gh pr create --fill`.
3. Click "Enable auto-merge", or run `gh pr merge --auto --rebase`. GitHub merges once CI is
   green and deletes the branch.

### Releasing

A release is such a pull request from a branch named after its version, such as `2.1.0` or
`2.0.24`. The version must be higher than every release so far. Merging it starts the
**Release** workflow, which builds and tests the merge commit on macOS and iOS and only then tags
`v2.1.0` and publishes the GitHub release, with the commit subjects as notes. A failing test
leaves no tag. A pull request from any other branch is merged but not released.

By hand: "Run workflow" on the Release workflow in GitHub, or
`gh workflow run release.yml -f version=2.1.0`.
