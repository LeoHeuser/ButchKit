# ButchKit

A lean SwiftUI component library extending native Apple platform patterns.

ButchKit collects the small pieces that most apps end up rebuilding: view modifiers, colour helpers, and services that wrap system frameworks in a way that stays close to the platform. Everything is built on native APIs — the library adds ergonomics, never a layer you have to learn instead of Apple's.

Platform support: iOS/iPadOS 17.0+ and macOS 14.0+. Builds with Swift 6.2 or newer (Xcode 26+).

## Documents

Prose that applies across the library. These are binding for how ButchKit is built and used, not descriptions of what exists.

- [Logging Strategy](LoggingStrategy.md) — where, what, and at which level an app and ButchKit log.
- [Paywall](Paywall.md) — how an app sells its subscription: setup, gating, presenting, analytics.
- [External packages](ExternalPackages.md) — how an app lists its external packages with their licenses and lets the user turn the optional ones off: setup, gating, reacting to the switch, with an analytics SDK as the worked example.

## Localization

ButchKit words its own components. Each component that shows words keeps them in a String
Catalog of its own, next to its code, and looks them up in ButchKit's resource bundle. An app
hands in no words for them, and nothing of ButchKit's appears in the app's catalogs.

| Catalog | Component |
|---|---|
| `Paywall.xcstrings` | Paywall: the sheet, its alerts, the segmented control and the settings row |
| `ExternalPackages.xcstrings` | External packages: the list, the package pages, the switch and the settings row |

How it is built:

- A word is looked up where it is shown, by key, in the component's table and ButchKit's
  bundle: `Text("button.paywall.dismiss", tableName: "Paywall", bundle: .module)`. Where an API
  takes a resource rather than a `Text`, the same as
  `LocalizedStringResource("…", table: "Paywall", bundle: .module)`. There is no file of strings
  in between.
- `bundle: .module` cannot be left out. SwiftUI has no default bundle to set, so a lookup
  without it searches the app's catalogs and shows the raw key. For the same reason a
  `.navigationTitle("key")` or `Button("key")` without `Text` cannot show a ButchKit word.
- Xcode extracts each key into the component's catalog when it builds the package. The English,
  every translation and the comment for translators are written in the catalog, never in code.
- English is the development language, so a language the catalogs lack falls back to it.
- A package's bundle follows the language the app has chosen. ButchKit therefore never shows a
  language the app does not support. The reverse is the one rule to keep: an app language
  missing from these catalogs shows ButchKit's words in English. The catalogs carry every
  language a consuming app ships; an app that adds a language needs a ButchKit release with it.
- Translations are reviewed in Xcode's catalog editor. A draft is marked "Needs Review" there
  until someone has checked it.
- `LocalizationTests` fails on a key the code looks up but the catalog lacks, a lookup without
  `bundle: .module`, a missing translation and a broken placeholder.

What stays with the app is what only the app can word: the paywall's marketing pages
(`PaywallFeature`), the name of what it sells (`PaywallConfiguration.planName`), each package's
description and note (`ExternalPackage`), its own errors, and the close words of the general
utilities, which take a `LocalizedStringKey` as before. Those are written in the app's code and
extracted into the app's catalogs.

A license text in `ExternalPackage.License` is a legal text, not an interface word, so ButchKit
ships the standard ones in their original English, and nobody translates them.

For the app's own strings the convention ButchKit assumes is three tables:

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

The library ships as one target, but it is organised as components that each live in their own
folder and can be read, used and eventually split out on their own. Each component below states
what it **uses** from the rest of ButchKit. Nothing in a component is specific to one app: every
app-specific text, identifier, product and URL comes from the app that uses it.

| Component | Uses from ButchKit | Resources |
|---|---|---|
| Logging | nothing | none |
| User-facing errors | Logging, `StringTable` | none |
| Paywall | Logging, `GatedWebView`, `Device`, the sheet close button | `Paywall.xcstrings`, preview images and a preview StoreKit file |
| External packages | nothing | `ExternalPackages.xcstrings` |
| Web views (`GatedWebView`, `WebViewSheet`, `WebViewButton`) | the sheet close button | none |
| Everything else in General and Token utility | nothing | none |

The paywall reaches the sheet close button through the internal `DismissSheetButton`, not the
public `sheetDismissButton(_:)`, because it passes a `LocalizedStringResource`. That is the one
internal type shared across components: split into separate targets, it has to become `package`.

### Logging

`Sources/ButchKit/Services/LoggerService/`

- `Logger.init(category:subsystem:)` — how an app declares a category. Resolves the subsystem itself.
- `LoggerService` — binds a group of loggers to one subsystem, for app extensions, tests and export.
- `LogCategory` — the area of the app a message belongs to.
- `LogSession` — a short identifier that ties one flow together across categories.
- `LogMirror`, `View.logMirror(_:)`, `EnvironmentValues.logMirror` — keeping the app's persisted logs across launches, and exporting them for a bug report. `harvest()` copies the latest entries in on demand.
- `LogExport`, `LogEntry`, `LogLevel`, `LogExportError` — reading the running launch's own logs back, without a file behind them.
- `Error.logCode` — `domain=… code=…` for a log line, in place of a description that may quote a file name.
- `EnvironmentValues.log` — the logger inside a SwiftUI view.

### User-facing errors

`Sources/ButchKit/Services/UFEService/`

- `UFEService` — collects errors from anywhere and surfaces them through one native alert.
- `UFError`, `UFErrorLevel` — the shape an error needs to be presentable.
- `View.userFacingErrors(_:dismissTitle:)` — root-level integration.
- `View.userFacingErrors(dismissTitle:)` — reinforcement for views that are themselves sheets.

### Paywall

`Sources/ButchKit/Services/PaywallService/`

- `View.paywallEnvironment(_:features:onEvent:)` — root-level integration. Creates the service, injects it, refreshes on foreground and attaches the paywall sheet.
- `View.paywallEnvironment(_:)` — the same for a `PaywallService` the app owns: several windows, or code outside the views that needs the answer.
- `PaywallService` — `hasAccess` and `entitlement`, fed by StoreKit 2, `verifiedEntitlement` once StoreKit has confirmed them, `isLocked` for drawing the locked state, `onVerifiedEntitlementChange` for whatever follows the entitlement outside a view, `present(source:)` and `require(source:_:)` to show the paywall from anywhere, and `restorePurchases()` for a settings row.
- `PaywallConfiguration` — the subscription group and the lifetime products, at least one of the two, policy URLs, the marketing pages' height, the app group for the cache and the optional `planName`.
- `PaywallEntitlementCache` — the last confirmed entitlement, readable from a widget, an extension or an App Intent.
- `PaywallEntitlement` — `none`, `subscription` or `lifetime`.
- `PaywallFeature` — one marketing page: title, description, image, and whether it shows only to a user who can still get the introductory offer.
- `PaywallEvent` — the funnel, forwarded through `PaywallService.onEvent` to the app's analytics, each with a stable `name` and `parameters`.
- `PaywallPurchaseFailure` — the kind of a failed purchase, what `PaywallEvent.purchaseFailed` carries in place of the error's text.
- `PaywallRestoreOutcome` — how `restorePurchases()` ended.
- `SubscriptionPhase` — trial or paid, renewing or canceled: the once-per-service snapshot `PaywallEvent.subscriptionStatus` carries.
- `PaywallRequest` — the presentation in flight.
- `PaywallStatusRow` — the settings row: plan name, renewal date and management; the lifetime purchase, with management while a subscription still renews; or the offer.
- `PaywallStatusReader` — the same status, actions and words as a `PaywallStatus`, for an app that draws its own row.
- `View.paywallSheet()` — reinforcement for views that are themselves sheets.

### External packages

`Sources/ButchKit/General Utility/ExternalPackagesView/` — setup in [ExternalPackages.md](ExternalPackages.md).

- `ExternalPackagesView` — the app's external packages, one section each, with a switch under every package the user may turn off. Each row opens the package's page with its license text. Opened from wherever the app likes, with the app's `ExternalPackage.all`.
- `ExternalPackagesLink` — the settings row that opens it: pushed on iPhone and iPad, its own window on the Mac.
- `ExternalPackagesWindow` — that window, declared once in the app's body (macOS only).
- `ExternalPackageToggle` — one package's switch, for a second place such as a privacy screen.
- `ExternalPackage` — one package: name, license, purpose, source, a note under its switch, and what the app does when the switch flips. `issues(in:)` checks the app's list in its tests.
- `ExternalPackage.License` — MIT, Apache 2.0, BSD 2- and 3-Clause with their standard texts, or a license of the package's own.
- `ExternalPackage.ID` — the name a package is switched under, its `Availability` (`required`, `optOut`, `optIn`), the app group the decision is stored in, and `isEnabled`, the gate the app asks before it runs the package.

### General utility

`Sources/ButchKit/General Utility/`

- `GatedWebView` — a web view for fixed, trusted content; `WebBrowsing` decides which tapped links stay in it.
- `WebBrowsing` — `.none`, `.onSameDomain` or `.everywhere`: how far a web view follows links before Safari takes over.
- `WebViewButton` — a button that presents one.
- `View.webViewSheet(isPresented:url:dismissTitle:title:allowsBrowsing:)`, `View.webViewSheet(item:url:dismissTitle:title:allowsBrowsing:)` — a web page in a sheet: Safari by default (`.everywhere`), or a `GatedWebView` for `.onSameDomain` and `.none`.
- `View.sheetDismissButton(_:)` — a native close button for sheets, named by the app.
- `View.useContentHeightPresentationDetent`, `ContentHeightPresentationDetentModifier` — sizes a sheet to its content.
- `View.onShake(isEnabled:respectsShakeToUndoSetting:perform:)` — runs an action when the device is shaken (iOS only). `Notification.Name.deviceDidShake` is the same signal for code without a view.
- `StringTable`, `Text.init(error:)` — which catalog a string resolves in.
- `Device` — iPhone, iPad or Mac: `@Environment(\.device)` in views, `Device.current` everywhere else. A hardware answer, not a layout one.

### Token utility

`Sources/ButchKit/Token Utility/`

- `Color.adaptiveColor(light:dark:)` — a colour that resolves to one value in light appearance and another in dark.
