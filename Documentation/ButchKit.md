# ButchKit

A lean SwiftUI component library extending native Apple platform patterns.

ButchKit collects the small pieces that most apps end up rebuilding: view modifiers, colour helpers, and services that wrap system frameworks in a way that stays close to the platform. Everything is built on native APIs — the library adds ergonomics, never a layer you have to learn instead of Apple's.

Platform support: iOS/iPadOS 17.0+ and macOS 14.0+. Builds with Swift 6.2 or newer (Xcode 26+).

## Documents

Prose that applies across the library. These are binding for how we build, not descriptions of what exists.

- [Logging Strategy](LoggingStrategy.md) — where, what, and at which level we log.
- [Paywall](Paywall.md) — how an app sells its subscription: setup, gating, presenting, analytics.
- [External packages](ExternalPackages.md) — how an app lists its external packages and lets the user turn the optional ones off: setup, gating, reacting to the switch, TelemetryDeck.

## Localization

ButchKit ships no strings and names no keys. Every text a ButchKit view shows is handed in by the
app: as a `LocalizedStringKey`, as a `String` the app resolved from its own table, or as a
closure that builds a `Text`. The key is therefore written in the app's code, where Xcode finds
it and extracts it into the app's catalog like any other string. The app owns the wording, the
keys and the translations, nothing is added to a catalog by hand, and a ButchKit surface speaks
every language the app does.

Which table a key lives in is the app's choice. The convention across our apps:

| Table | For |
|---|---|
| `Localizable` | Everything by default, buttons included. SwiftUI's own default, so it is never named in code. |
| `Errors` | Anything the user reads because something went wrong. Rendered with `Text(error:)`. |
| `Accessibility` | Labels, hints and values only assistive technologies read. |

A key looked up in the wrong table has no match and renders as the key itself, which is what the
user then reads.

A button stays on `Localizable` even when it sits in an alert: it is a button, not an error. The
table follows what the string *is*, not where it appears.

## What's in the library

Every type is documented in code. This is the map.

### Logging

`Sources/ButchKit/Services/LoggerService/`

- `Logger.init(category:subsystem:)` — how an app declares a category. Resolves the subsystem itself.
- `LoggerService` — binds a group of loggers to one subsystem, for app extensions, tests and export.
- `LogCategory` — the area of the app a message belongs to.
- `LogSession` — a short identifier that ties one flow together across categories.
- `LogMirror`, `View.logMirror(_:)`, `EnvironmentValues.logMirror` — keeping the app's persisted logs across launches, and exporting them for a bug report.
- `LogExport`, `LogEntry`, `LogLevel` — reading the running launch's own logs back, without a file behind them.
- `Error.logCode` — `domain=… code=…` for a log line, in place of a description that may quote a file name.
- `EnvironmentValues.log` — the logger inside a SwiftUI view.

### User-facing errors

`Sources/ButchKit/Services/UFEService/`

- `UFEService` — collects errors from anywhere and surfaces them through one native alert.
- `UFError`, `UFErrorLevel` — the shape an error needs to be presentable.
- `View.userFacingErrors(_:dismissTitle:)` — root-level integration.

### Paywall

`Sources/ButchKit/Services/PaywallService/`

- `View.paywallEnvironment(_:texts:features:)` — root-level integration. Creates the service, injects it and attaches the paywall sheet.
- `PaywallService` — `hasAccess` and `entitlement`, fed by StoreKit 2, plus `present(source:)` and `require(source:_:)` to show the paywall from anywhere.
- `PaywallConfiguration` — the subscription group, the optional lifetime products, policy URLs and the marketing pages' height.
- `PaywallEntitlement` — `none`, `subscription` or `lifetime`.
- `PaywallTexts` — every word the paywall and the settings row show, handed in by the app.
- `PayWallFeature` — one marketing page: title, description, image.
- `PaywallEvent` — the funnel, forwarded through `PaywallService.onEvent` to the app's analytics.
- `PaywallRequest` — the presentation in flight.
- `PaywallStatusRow` — the settings row: plan name, renewal date and management; the lifetime purchase, with management while a subscription still renews; or the offer.
- `View.paywallSheet()` — reinforcement for views that are themselves sheets.

### External packages

`Sources/ButchKit/General Utility/ExternalPackagesView/` — setup in [ExternalPackages.md](ExternalPackages.md).

- `ExternalPackagesView` — the app's external packages, one section each, with a switch under every package the user may turn off. Opened from wherever the app likes, with the app's `ExternalPackage.all` and `externalPackagesTexts`.
- `ExternalPackage` — one package: name, license, purpose, source, whether it is optional, and what the app does when its switch flips.
- `ExternalPackage.ID` — the name a package is switched under, and `isEnabled`, the gate the app asks before it runs the package. On until the user turns it off.
- `ExternalPackagesTexts` — every word the list shows, handed in by the app.

### General utility

`Sources/ButchKit/General Utility/`

- `GatedWebView` — a web view for fixed, trusted content; `WebBrowsing` decides which tapped links stay in it.
- `WebBrowsing` — `.none`, `.onSameDomain` or `.everywhere`: how far a web view follows links before Safari takes over.
- `WebViewButton` — a button that presents one.
- `View.webViewSheet(isPresented:url:dismissTitle:title:allowsBrowsing:)`, `View.webViewSheet(item:url:dismissTitle:title:allowsBrowsing:)` — a web page in a sheet: Safari by default (`.everywhere`), or a `GatedWebView` for `.onSameDomain` and `.none`.
- `View.sheetDismissButton(_:)` — a native close button for sheets, named by the app.
- `View.useContentHeightPresentationDetent` — sizes a sheet to its content.
- `View.onShake(isEnabled:respectsShakeToUndoSetting:perform:)` — runs an action when the device is shaken (iOS only).
- `StringTable`, `Text.init(error:)` — which catalog a string resolves in.

### Token utility

`Sources/ButchKit/Token Utility/`

- `Color.adaptiveColor(...)` — a colour that resolves per platform.
