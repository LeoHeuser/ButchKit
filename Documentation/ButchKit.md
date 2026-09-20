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
app: as a `LocalizedStringKey` (a `LocalizedStringResource` in the paywall, whose values are
`Sendable`), as a `String` the app resolved from its own table, or as a
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

- `View.paywallEnvironment(_:texts:features:)` — root-level integration. Creates the service, injects it, refreshes on foreground and attaches the paywall sheet.
- `View.paywallEnvironment(_:)` — the same for a `PaywallService` the app owns: several windows, or code outside the views that needs the answer.
- `PaywallService` — `hasAccess` and `entitlement`, fed by StoreKit 2, `verifiedEntitlement` once StoreKit has confirmed them, `isLocked` for drawing the locked state, `onVerifiedEntitlementChange` for whatever follows the entitlement outside a view, `present(source:)` and `require(source:_:)` to show the paywall from anywhere, and `restorePurchases()` for a settings row.
- `PaywallConfiguration` — the subscription group and the lifetime products, at least one of the two, policy URLs, the marketing pages' height and the app group for the cache.
- `PaywallEntitlementCache` — the last confirmed entitlement, readable from a widget, an extension or an App Intent.
- `PaywallEntitlement` — `none`, `subscription` or `lifetime`.
- `PaywallTexts` — every word the paywall and the settings row show, handed in by the app in groups: `Sheet`, `OfferTabs`, `StatusRow`, `SubscriptionOverlap`.
- `PaywallFeature` — one marketing page: title, description, image, and whether it shows only to a user who can still get the introductory offer.
- `PaywallEvent` — the funnel, forwarded through `PaywallService.onEvent` to the app's analytics, each with a stable `name` and `parameters`.
- `PaywallPurchaseFailure` — the kind of a failed purchase, what `PaywallEvent.purchaseFailed` carries in place of the error's text.
- `PaywallRestoreOutcome` — how `restorePurchases()` ended.
- `SubscriptionPhase` — trial or paid, renewing or canceled: the once-per-launch snapshot `PaywallEvent.subscriptionStatus` carries.
- `PaywallRequest` — the presentation in flight.
- `PaywallStatusRow` — the settings row: plan name, renewal date and management; the lifetime purchase, with management while a subscription still renews; or the offer.
- `PaywallStatusReader` — the same status and actions as a `PaywallStatus`, for an app that draws its own row.
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
- `Device` — iPhone, iPad or Mac: `@Environment(\.device)` in views, `Device.current` everywhere else. A hardware answer, not a layout one.

### Token utility

`Sources/ButchKit/Token Utility/`

- `Color.adaptiveColor(...)` — a colour that resolves per platform.
