# Paywall

How to sell a subscription with ButchKit: one configuration, one modifier, one question everywhere else.

## What it is

The paywall is for an app that earns its money through one auto-renewable subscription group, one or more lifetime unlocks sold as one-time purchases, or both. The paywall module turns that into a fixed system so an app never writes StoreKit code again:

1. **One truth.** `PaywallService.hasAccess` is the only place that knows whether the user pays. Every gate in the app asks it, nothing else. `entitlement` says whether it is a subscription or the lifetime product; only the settings row needs that. `verifiedEntitlement` is the same answer once StoreKit has confirmed it, for anything that outlasts the screen.
2. **One integration.** `.paywallEnvironment(_:texts:features:onEvent:)` on the root view. It creates the service, injects it, runs the first entitlement check, reads again on every foreground and owns the paywall sheet. An app that needs the service outside its views builds it itself and hands it to `.paywallEnvironment(_:)`.
3. **One look.** The paywall has one fixed layout: full-bleed photo pages that advance on their own, over Apple's `SubscriptionStoreView`. Apps supply pages, not views.

The paywall is not a place for experiments. If the layout has to change, it changes in ButchKit, for every app that uses it.

## The model

| Part | Meaning | Who decides |
|---|---|---|
| **`PaywallConfiguration`** | The subscription group and the lifetime products, at least one of the two, the two policy URLs and how tall the marketing pages are | You, once per app |
| **`PaywallFeature`** | One marketing page: a title, plus an optional description and photo | You, once per app, as many as you like, or none |
| **`PaywallTexts`** | Every word the paywall and the settings row show, in groups; an app words only the groups it shows | You, once per app |
| **`PaywallService`** | `hasAccess`, `entitlement` and `verifiedEntitlement`, plus `present` and `require` to show the paywall and `restorePurchases` for a settings row | ButchKit, created by the root modifier or by the app |
| **`PaywallConfiguration.LegacyCache`** | Where the app kept its answer before it adopted ButchKit, read until ButchKit has one | You, only when migrating |
| **`PaywallEntitlementCache`** | The last confirmed entitlement, readable from a widget, an extension or an App Intent | ButchKit writes, you read |
| **`PaywallEntitlement`** | `none`, `subscription` or `lifetime`, `String`-backed and ordered in that sequence | ButchKit |
| **`PaywallEvent`** | The funnel: presented, purchase started, completed, pending, failed, each with its source and the product, and with a `name` and `parameters` ready for a signal | ButchKit reports, you forward to analytics |
| **`SubscriptionPhase`** | Where an active subscriber stands: trial or paid, renewing or canceled. Carried by `PaywallEvent.subscriptionStatus` | ButchKit |
| **`PaywallPurchaseFailure`** | Why a purchase failed, by kind: `network`, `notAvailableInStorefront`, `productUnavailable`, `purchaseNotAllowed`, `ineligibleForOffer`, `invalidOffer`, `system`, `unknown`. Stable raw values | ButchKit |
| **`PaywallRequest`** | The presentation in flight, carrying its `source` and an `id` | ButchKit |
| **`PaywallRestoreOutcome`** | What `restorePurchases()` found: `restored`, `nothingToRestore`, `cancelled`, `offline` or `failed` | ButchKit |
| **`PaywallStatusRow`** | The settings row: plan, renewal date and management; the lifetime purchase; or the offer | ButchKit |
| **`PaywallStatusReader`** | What that row knows and does, as a `PaywallStatus`, for an app that draws its own row | ButchKit loads, you draw |
| **`PaywallStatus`** | The value the reader hands over: entitlement, plan name, detail, loading and Family Sharing state, and the two actions | ButchKit |
| **`SubscriptionDetail`** | The line under the plan's name: `renews(Date)`, `ends(Date)` or `billingIssue` | ButchKit |

Entitlement is decided per **subscription group**, not per product. Every tier in the group unlocks the app. Adding a monthly tier next to the yearly one is an App Store Connect change, not a code change.

The one exception is the **lifetime products**: non-consumables that each unlock the app for good. They have no group, so they are the only products named in the configuration. An app that sells any passes `lifetimeProductIDs`, in the order the paywall lists them; every other app leaves it out and nothing about it changes. Several lifetime products all grant the same thing, the whole app: a `Lifetime` next to a pricier `Lifetime Supporter`, say. A product that unlocks only part of the app is not supported.

An app that sells nothing but lifetime products leaves out the group:

```swift
let paywallConfig = PaywallConfiguration(lifetimeProductIDs: ["com.example.App.full_version"])
```

The paywall then shows the one-time purchases alone, and the settings row never offers subscription management. A configuration with neither a group nor a lifetime product sells nothing and stops a debug build; a release build logs a fault.

## Setup

Every app declares its paywall in **one dedicated file**, `Paywall.swift`. That file is the whole definition: which group, which URLs, which words, which pages.

```swift
// Paywall.swift — the one place the paywall is defined
import ButchKit

#if DEBUG
private let groupID = "11111111"   // the group in Products.storekit
#else
private let groupID = "00000000"   // the group in App Store Connect
#endif

let paywallConfig = PaywallConfiguration(
    subscriptionGroupID: groupID,
    lifetimeProductIDs: ["com.example.App.full_version"],   // only for an app that sells any
    privacyPolicyURL: "https://example.com/privacy",
    termsOfServiceURL: "https://example.com/terms",
    featureAreaHeight: 0.62,  // share of the sheet the pages take: 0 hides them, 1 fills it
    appGroupID: "group.com.example.App"   // only for an app with a widget or an extension
)

// Every word the paywall and the settings row show. Written here, so Xcode extracts each key
// into the app's catalogs; see Localization below.
let paywallTexts = PaywallTexts(
    // The paywall itself. Always needed.
    sheet: .init(
        dismiss: "button.dismissSheet",
        privacyPolicyTitle: "webView.privacyPolicy.title",
        termsOfServiceTitle: "webView.termsOfUse.title",
        purchaseFailedTitle: String(localized: "error.paywall.purchaseFailed.title", table: "Errors"),
        purchaseFailedMessage: String(localized: "error.paywall.purchaseFailed.message", table: "Errors"),
        restorePurchases: "button.paywall.restorePurchases",
        restoreSucceededTitle: String(localized: "alert.paywall.restore.succeeded.title"),
        nothingToRestoreTitle: String(localized: "alert.paywall.restore.nothingFound.title"),
        restoreFailedTitle: String(localized: "error.paywall.restoreFailed.title", table: "Errors"),
        restoreFailedMessage: String(localized: "error.paywall.restoreFailed.message", table: "Errors")
    ),
    // The segmented control. Only for an app that sells lifetime products next to a subscription.
    offerTabs: .init(
        subscription: "paywall.segment.subscription",
        oneTime: "paywall.segment.oneTime"
    ),
    // The settings row. Only for an app that uses PaywallStatusRow, or wants its words.
    statusRow: .init(
        offer: "button.settings.subscribe",
        offerLabel: String(localized: "accessibility.button.settings.subscribe.label", table: "Accessibility"),
        offerHint: String(localized: "accessibility.button.settings.subscribe", table: "Accessibility"),
        fallbackPlanName: "label.settings.subscription.plan",
        manage: "button.settings.manageSubscription",
        manageLabel: String(localized: "accessibility.button.settings.manageSubscription.label", table: "Accessibility"),
        manageHint: String(localized: "accessibility.button.settings.manageSubscription", table: "Accessibility"),
        renews: { Text("label.settings.subscription.renews \($0, format: .dateTime.day().month().year())") },
        ends: { Text("label.settings.subscription.ends \($0, format: .dateTime.day().month().year())") },
        billingIssue: String(localized: "error.settings.subscription.billingIssue", table: "Errors")
    )
)

let paywallFeatures: [PaywallFeature] = [
    PaywallFeature(title: "paywall.feature.1.title",
                   description: "paywall.feature.1.description",
                   image: .payWallFeature1),
    PaywallFeature(title: "paywall.feature.2.title",
                   description: "paywall.feature.2.description",
                   image: .payWallFeature2),
]
```

All three are `Sendable`, so they stand at file scope as plain `let` constants under Swift 6, built once. Never make them computed properties: the root would rebuild every word on every render.

Only the title is required. Leave out `image` and the page shows its text centred, on a dark ground when another page carries a photo and following the device otherwise; leave out `description` and the title stands on its own. A page with a photo keeps its text at the bottom, where the photo has faded out.

The pages themselves are optional too. An app that has no marketing photos yet leaves `features` out entirely:

```swift
RootView()
    .paywallEnvironment(paywallConfig, texts: paywallTexts)
```

Then the paywall shows Apple's own storefront instead: app icon, app name and the subscription group's description from App Store Connect, over the same subscription controls. Nothing to write and nothing to design, and it sells from the first build. An empty array does the same thing, so a `features` list that ends up empty is a valid state rather than a broken paywall.

An app with lifetime products next to a subscription supplies at least one page. The segmented control lives in the same slot as the pages, and once that slot is in use StoreKit no longer draws its own header, so the control alone would sit under an empty top.

Then one modifier on the root view, above everything that might gate a feature or show the paywall:

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .paywallEnvironment(paywallConfig, texts: paywallTexts, features: paywallFeatures)
        }
    }
}
```

That is the complete setup. There is nothing to call at launch and no service to store.

Put the modifier on a view whose body does not re-evaluate often. Inside `WindowGroup` as shown is right; `@State` inside the modifier keeps one service alive for the life of the scene.

### Owning the service

The modifier above makes one service per scene. That is right for an iPhone app and wrong in two cases: an app with **several windows** (any Mac app, where Cmd-N opens a second one, and iPad apps with multiple scenes) would run one service, one StoreKit listener and one launch report per window; and **code outside the view hierarchy**, a background service or a sync engine, cannot read the environment at all. Such an app builds the service once and hands it in:

```swift
@main
struct MyApp: App {
    @State private var paywall: PaywallService

    init() {
        let paywall = PaywallService(configuration: paywallConfig, texts: paywallTexts, features: paywallFeatures)
        paywall.onEvent = { TelemetryDeck.signal($0.name, parameters: $0.parameters) }
        _paywall = State(initialValue: paywall)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .paywallEnvironment(paywall)
        }
    }
}
```

Everything else stays the same: views read `@Environment(PaywallService.self)`, and the modifier starts the service, however many scenes carry it. The paywall comes up in the window that asked for it: each scene's root modifier and every `.paywallSheet()` know their window, and the one the user is in presents. A Mac app's `Settings` scene takes the same `.paywallEnvironment(paywall)` as its windows, not a second service. What needs it outside a view gets it through its initializer, like any other dependency.

An owned service is started by the first `.paywallEnvironment(paywall)` that appears. Code that runs without any view, a test or a command-line tool, calls `await paywall.initialize()` itself; further calls do nothing. `refresh()` re-reads the entitlements on demand, `dismissPaywall()` closes the paywall, and `presentedRequest` is the presentation in flight. `report(_:)` hands an event to `onEvent` as if the service had raised it; the service calls it itself, and an app has no reason to.

### Widgets, extensions and App Intents

These run in another process and cannot reach the service. Name an app group in the configuration and the last confirmed entitlement is cached there instead of in the app's own defaults:

```swift
let entitlement = PaywallEntitlementCache(appGroupID: "group.com.example.App").entitlement
```

`nil` means not known yet, never "does not pay": the app has not run since the install. Treat it as the app treats its own loading state, not as a locked feature. The value is as old as the app's last entitlement check, so a subscription that ran out since still reads as one until the app is opened again. Only confirmed answers are ever written, so the extension never finds a guess. An app that adopts a group in an update keeps the answer it cached before.

With a group named, every change of the answer also reloads the app's widget timelines, so a widget unlocks the moment the purchase goes through rather than at its next refresh. There is no `WidgetCenter` call to write.

An extension that does not link ButchKit reads the same value by hand: the string under `design.heuser.ButchKit.paywall.entitlement` (`PaywallEntitlementCache.key`) in the group's `UserDefaults`, one of `none`, `subscription` or `lifetime`. Both are a stable contract.

```swift
let raw = UserDefaults(suiteName: "group.com.example.App")?.string(forKey: "design.heuser.ButchKit.paywall.entitlement")
let pays = raw.map { $0 != "none" }   // nil: not known yet, never "does not pay"
```

### Coming from purchase code of the app's own

An app that adopts ButchKit in an update kept its answer under a key of its own, and ButchKit's cache is empty on the first launch after it: a paying user would see the paywall flash. Name that key once and it is read until ButchKit has an answer:

```swift
legacyCache: .init(key: "isPremium", suiteName: "group.com.example.App")   // suiteName only if it was not the standard defaults
```

Only a `true` there counts, and it is read as a subscription, also in an app that sells only lifetime products; a `false` says as little as a missing key. ButchKit's own cache from before 2.0, a Bool under `design.heuser.ButchKit.paywall.hasSubscription` in the standard defaults, is read the same way. It only draws the interface for that one moment. StoreKit's answer replaces it, and nothing is unlocked on it for good.

Never build a mirror of your own next to this. A mirror written before StoreKit has answered is how a paying user gets locked out of an extension.

The group identifier differs between the local `.storekit` file and App Store Connect, hence the `#if DEBUG`. Keep the `.storekit` file wired into the Run scheme so the paywall works in the simulator.

Give every subscription a display name, in the `.storekit` file and in App Store Connect, in every language the app ships. Apple's plan cards show it above the price; without one a card shows a blank line and the price alone.

## Reading the state

Anywhere below the root, the service is a native environment value:

```swift
struct EditorView: View {
    @Environment(PaywallService.self) private var paywall

    var body: some View {
        if paywall.hasAccess {
            EditableContent()
        } else {
            LockedContent { paywall.present(source: "lockedItem") }
        }
    }
}
```

`hasAccess` is `@Observable`. A view that reads it re-renders when the subscription changes, including a restore or a renewal that lands while the view is on screen. It is `true` for a subscriber and for a lifetime owner alike.

`isInitialized` turns `true` after the first entitlement check. Hold a launch gate on it only if the very first screen depends on the subscription. Because the last known state is cached, a subscriber sees no paywall flash even before it turns `true`.

### Provisional and verified

Until that first check, `hasAccess` and `entitlement` answer from the cache. That is what stops the flash, and it is a guess: a plain `UserDefaults` value, which is empty after a reinstall and which anyone can edit, on a Mac with one `defaults write`. So there are two answers, and each call site picks by what it does with it:

| Reads | For |
|---|---|
| `hasAccess`, `entitlement` | Drawing the interface. Wrong for a moment at worst, and corrected on its own. |
| `hasVerifiedAccess`, `verifiedEntitlement` | Anything that outlasts the screen: a value written for an extension or synced, a request to a server, an analytics property, an unlock that cannot be taken back. |

`verifiedEntitlement` is `nil` until StoreKit has answered, and `nil` means "not known yet", never "free". Code that stores it waits for a value rather than writing `none`.

`require(source:_:)` decides on the verified answer by itself. Called before the first check is done, it waits for it, a moment at launch, and then either runs the action or shows the paywall. An edited cache opens nothing, and a subscriber on a fresh install is not shown a paywall. Two taps in that moment keep the last, exactly as they do afterwards, and the dropped one is logged.

### Drawing the locked state

Lock badges, banners and read-only content follow `isLocked`, not `!hasAccess`. It is `true` once it is known that the user does not pay, from StoreKit or from the answer the last launch left behind, and `false` while nothing is known at all. A returning free user sees the lock at once; a subscriber who just reinstalled never sees one flash by. It is for looks only: what a tap does is still `hasAccess` or `require`.

```swift
if paywall.isLocked { UnlockBanner() }
```

### Reacting to the entitlement

Whatever has to follow the entitlement outside the screen hangs on one modifier: a limit in a service of the app's own, a TipKit parameter, scheduled notifications, a value of the app's own for an extension.

```swift
RootView()
    .onVerifiedEntitlementChange { entitlement in
        exporter.limit = entitlement == .none ? .free : .unlimited
    }
    .paywallEnvironment(paywallConfig, texts: paywallTexts)
```

It runs once StoreKit has answered and again on every change: a purchase, a restore, a subscription running out, a refund. It never runs with the cached answer. Do not write an `onChange` over `hasAccess` for this: before the first check it reports the cache, and a subscriber on a fresh install would be written down as not paying.

The cache is not a trust boundary, and there is no server behind any of this: StoreKit 2's on-device verification is the source of truth. That is the right weight for apps whose paid features run on the device. A feature that costs money to serve needs its own server-side check.

## Showing the paywall

Two calls, both from anywhere:

```swift
// Show it. The user decides what to do next.
paywall.present(source: "settings")

// Gate an action. Runs now when subscribed; otherwise shows the paywall and runs the
// action right after the purchase, so the user lands where they were going.
Button("button.newItem", systemImage: "plus") {
    paywall.require(source: "newItem") { addItem() }
}
```

`require` is the default for anything the user *does*. `present` is for places that only *show* the offer: a Settings row, a locked hint. Closing the paywall without buying drops the deferred action, nothing runs behind the user's back.

A request that no sheet picks up within five seconds is dropped and logged as an error. The five seconds start with the first sheet host, not with the request, so a `present(source:)` from an App Intent or a notification on a cold launch waits for the scene rather than being dropped before it exists. That is always the same mistake, a `present` from inside a sheet that lacks `.paywallSheet()`, see below. Dropping it matters: left standing, the request would bring the paywall up out of nowhere once that sheet closes.

`source` is the app's own short name for where the user hit the lock: `newItem`, `lockedItem`, `export`, `settings`. It is carried on every event, so analytics can tell which entry point earns the conversions. Use `lowerCamelCase`, keep the set small, and keep it stable across releases.

No view declares a sheet. The root modifier owns it.

### Views that are sheets themselves

SwiftUI presents one sheet per view. While a Settings sheet is open, the root sheet cannot appear on top of it, so a `present` from inside Settings would go nowhere. Apply `.paywallSheet()` once to the content of any sheet that can trigger the paywall:

```swift
.sheet(isPresented: $showsSettings) {
    SettingsView()
        .paywallSheet()
}
```

Views pushed onto a `NavigationStack` need nothing. Only full sheets and covers do.

The innermost host on screen presents, in the window that asked: every request remembers the
scene the user was in, and the innermost host of that scene takes it. Only when that scene has no
host, its window closed in the meantime, does the innermost host of any window present, so the
paywall still comes up rather than not at all.

### The settings row

Every app needs one place that says what the user is paying for. Apple expects a path to the
system's subscription management, and a subscriber who cannot find out what they bought writes
to support instead of looking it up.

```swift
Form {
    Section {
        PaywallStatusRow(source: "settings")
    }
}
```

One row, two states, both of which lead somewhere. Its words come from the `statusRow` group of
the app's `PaywallTexts`; beyond that there is nothing to configure and no state to pass in.
Without that group the row stays empty and logs a fault.

On the first launch after an install, with nothing cached and StoreKit still to answer, the row
shows a spinner rather than the offer: a subscriber who just reinstalled is not asked to subscribe.

- **Not subscribed:** one button that opens the paywall through `present`. Name it after what
  the paywall shows rather than after one plan: `See subscription plans` stays true however many
  plans the group holds.
- **Subscribed:** the plan's name as App Store Connect spells it, localized per storefront, so it
  follows an upgrade or a downgrade on its own. Under it the next step: `Renews on …`,
  `Ends on …` once auto-renew is off, or a billing issue during the grace period after a failed
  renewal. Beside it a Manage button. Until StoreKit has answered, the row shows
  `fallbackPlanName` and no second line.
- **Lifetime:** the name of the lifetime product held, from App Store Connect. A one-time
  purchase has no renewal, no end and no plan to change, so there is nothing to manage. A user who
  holds both a subscription and a lifetime product sees this row: the subscription is not what
  their access depends on. While that subscription still renews, the row carries the same Manage
  button, so the user finds the way to cancel what they no longer need. It goes away once
  auto-renew is off.

Without a grace period set in App Store Connect, access ends with the failed payment, and the
row shows the offer again: StoreKit no longer counts the subscription, and iOS asks for new
payment details on its own.

Which row shows is `entitlement`, the same answer behind `hasAccess` that every gate in
the app reads. The status behind the second line only adds detail, so the row cannot disagree
with what the app unlocks.

On iOS, Manage opens `manageSubscriptionsSheet` on the configured group. macOS has no such
sheet, and neither has an iPhone or iPad app running on a Mac, so there the button opens the
App Store's subscription page. Which of the two it is comes from ButchKit's `\.device`, so a
preview that sets `.environment(\.device, .mac)` shows the Mac behaviour.

One group with several plans (monthly and yearly, or Plus and Pro) is the case this row is
built for: Apple's sheet handles every change between them. Subscriptions a user holds side by
side would need a second group, which Apple advises against and ButchKit does not support.

### A row of your own

`PaywallStatusRow` is plain text, which fits a settings screen of plain rows. For rows that all
carry a symbol, `PaywallStatusRow(source: "settings", systemImage: "crown")` puts one in front, the
same in every state. An app whose rows look different beyond that draws its own on
`PaywallStatusReader`. The reader loads
and follows everything the row above shows and owns both ways on, so the app writes no StoreKit
code and cannot get the rules wrong:

```swift
PaywallStatusReader(source: "settings") { status in
    switch status.entitlement {
    case .none where status.isLoading:
        ProgressView()
    case .none:
        Button(action: status.showPaywall) {
            Label { Text(rowTexts.offer) } icon: { Image(systemName: "crown") }
        }
    case .subscription, .lifetime:
        LabeledContent {
            if status.canManageSubscription {
                Button(rowTexts.manage, action: status.manageSubscription)
            }
        } label: {
            rowTexts.planName(status.planName)
            if let detail = status.detail {
                rowTexts.detail(detail)
            }
        }
    }
}
```

`rowTexts` is a `PaywallTexts.StatusRow` the app declares as a constant of its own in
`Paywall.swift`, and passes as `statusRow:` too if it also uses the plain row anywhere. What each
value means is documented on `PaywallStatus`. `planName(_:)` and `detail(_:)` turn the name and
the detail into the same words the plain row shows, as `Text` the app styles freely.

`status.isFamilyShared` says that what the user holds is another family member's, shared through
Family Sharing. They cannot manage or cancel it, so a row or a support screen says "your family's
plan" rather than "your plan". A billing issue needs no route of the app's own: Manage opens the
system's sheet, which is where the payment method is fixed, and iOS asks for it on its own as well.

The plan, its name and the lifetime product live in the service, which follows StoreKit for the
life of the app. A settings screen opened for the tenth time shows them at once, nothing loads in.

In a preview, a row of the app's own gets its status from
`PaywallStatus(previewEntitlement:planName:detail:canManageSubscription:isFamilyShared:isLoading:)`,
every state without a StoreKit file. Like the service's own preview initializers,
`PaywallService(configuration:texts:previewEntitlement:)` and `(…previewSubscribed:)`, it exists in
debug builds only.

### Restore in the settings

The paywall has its restore button. Users who just reinstalled, and App Review, also look for one
in the settings, and `restorePurchases()` is the same restore from there:

```swift
Button("button.settings.restorePurchases") {
    Task {
        switch await paywall.restorePurchases() {
        case .restored: alert = .restored
        case .nothingToRestore: alert = .nothingToRestore
        case .failed: alert = .restoreFailed
        case .offline: alert = .noConnection
        case .cancelled: break   // backed out of the sign-in, nothing to say
        }   // no `default`: a new outcome should stop the build until it has words
    }
}
```

The app words and shows the outcome itself; the entitlement is already updated by the time it
returns. It asks for the App Store sign-in, so it only ever runs from a button. Disable that
button while it runs.

## What the user sees

The paywall is fixed, the same in every app that uses it:

- Photo pages from `paywallFeatures`, swipeable, advancing every five seconds, pausing for fifteen after a swipe. With Reduce Motion on, they move only when the user moves them. Page dots show whenever there is more than one page. On a Mac, which has neither a paged view nor a swipe, the pages cross-fade and the dots are what moves them. The pages take a share of the sheet's height at the top, `featureAreaHeight` (62 % unless the app sets it), and never scroll away; everything below them scrolls on its own when it does not fit. That share is an upper bound. The purchases keep a minimum height, enough for a plan, the Subscribe button and the policy line, and it grows with the text size; on a short sheet (iPhone SE, landscape) or at a large Dynamic Type size the pages give way, so the Subscribe button stays in view. At the largest accessibility sizes they give way entirely, and the paywall falls back to its plain layout with a navigation bar rather than floating buttons over nothing. On a regular iPhone at the default text size nothing changes. A page marked `introOfferOnly` shows only to a user who can still get the introductory offer, see below.
- Title in `.title.bold`, description in `.headline`. On a page with a photo the text sits at the bottom, over a gradient that fades the photo out; on a page without one it centres.
- With lifetime products, a segmented control under the pages: the subscription first and selected, the one-time purchases second. Switching changes only what sits below it; the pages and the control keep their place. The one-time side lists one card per product across the full width, Apple's `ProductView` in a ButchKit style: name and description from App Store Connect, and a Buy button carrying the price. `SubscriptionStoreView` shows nothing but subscriptions, which is why the one-time purchases need a side of their own. Without lifetime products there is no control, and the paywall is the subscription side alone. Without a group there is no control either, and the paywall is the one-time side alone; with no pages that list sits right under the toolbar.
- Apple's subscription controls below, as Apple's picker: one card per plan, one Subscribe button under them, starting right under the pages. Adding a tier in App Store Connect needs no code change. Before iOS 18 and macOS 15 StoreKit picks the shape itself, a single Subscribe button for a group with one plan. Introductory offers are shown by StoreKit either way.
- One restore button for everything, subscriptions and lifetime products alike, as text at the top right opposite the close button. With pages it floats over the photo in the same style as the close button; without pages, and on the Mac, both sit in the toolbar. Apple's own restore button is hidden: it only syncs, without reading the entitlements again or saying how it went. While ours asks the App Store it shows a spinner and cannot be tapped again; then an alert says how it went: the purchase is back, there is nothing to restore, the App Store could not be reached, or the restore failed. The offline case has its own optional words, the `restoreOffline` group, and reads as a failed restore without them. Title and message come together, so a "No Connection" heading can never end up over the generic failure message. Backing out of the App Store sign-in shows nothing. After a restore the sheet stays open until its alert is closed, and OK after a success closes the paywall.
- Privacy Policy plus Terms of Service when both URLs are configured. Policies open in `GatedWebView` inside the sheet. StoreKit draws its line with the subscription controls and nowhere else, so over the lifetime products ButchKit draws the same line itself, in the same place and the same look: a paywall without a group has it too. Word `sheet.policyConnector` and the two read as one sentence, terms first, exactly as StoreKit words it over the plans; without it they stand side by side. Either way the links take the tint the app gives the paywall, which is where StoreKit's own line takes its colour from.
- With `showsRedeemCode`, Apple's "Redeem Code" button with the subscription controls, for offer codes from a campaign, a press kit or a support case. On a Mac from macOS 15.
- A lifetime product the user already owns shows a checkmark in place of its price and cannot be bought again. VoiceOver reads the optional `purchasedLabel`. An app selling several of them marks every one the user owns, including a second one bought while the first already granted lifetime access.
- When none of the lifetime products load, without a connection or during a store outage, that side says so and offers a retry, in the words of the optional `productsUnavailable` group. Without the group it stays empty and only the log says why. One product of several that does not load is a wrong identifier: the others are sold as usual, and the log names it.
- A round close button floating over the photo, top left, with no navigation bar behind it: a bar would inset the pages and band the photos off at the top.
- Dark appearance regardless of the device setting as soon as one page carries a photo: the photos are shot for a dark ground, with white text on them. Pages of text alone follow the device, light or dark, like any other sheet.
- On success the sheet closes on its own, a subscriber buying a lifetime product included; a restore waits for its alert first. On failure, a purchase that fails verification included, a native alert.

Shoot or grade the photos for a dark ground; text is white on them.

### The introductory offer

A page that says "One month free" is untrue for everyone who has had that month. Mark it, and it shows only while the App Store says the user can still get the offer:

```swift
PaywallFeature(title: "paywall.feature.trial.title", image: .payWallFeatureTrial, introOfferOnly: true)
```

`paywall.isEligibleForIntroOffer` is the same answer for the app's own copy, a banner or an onboarding page. It is `nil` until the App Store has said, in an app without a subscription group, and for a user who already pays; treat `nil` like `false` and promise nothing. The plan cards themselves are Apple's and always show the right offer.

### Ask to Buy

A child's purchase waits for a parent. Apple's sheet says so, the paywall stays as it is and reports `purchasePending`. The approval comes through `Transaction.updates`, minutes or days later: the app unlocks, `purchaseApproved` closes the funnel with the source it opened with, and the action handed to `require` runs, so the user still lands where they were going. The event is reported on whichever launch the approval arrives, because the request is kept across launches: a child asks, quits the app, and the parent approves in the evening. The action is not, since code does not survive a launch; it runs only while the app keeps running, and asking for something else in the meantime drops it. A request older than two days is forgotten, as Apple has dropped it by then, so a later ordinary purchase never reads as an approval. A purchase that went through at once is `purchaseCompleted` and never both.

### Lifetime next to a subscription

A subscriber who buys a lifetime product keeps paying for the subscription, and no app can cancel it for them. With the `subscriptionOverlap` group in `PaywallTexts`, an alert says so once the paywall has closed, and its button opens the system's subscription management. Without the group nothing shows, and the Manage button in the settings row remains the only way there. Only an app that sells both needs the words. The alert shows once, on the purchase, never for a purchase the App Store merely replays at launch, and not when the subscription already ends on its own. An Ask to Buy approval that arrives before the app has read the subscription stays armed until it has, so the alert survives a parent approving overnight.

### Without pages

With no `features`, the paywall hands the sheet to StoreKit:

- Apple's own header: app icon, app name and the group's App Store Connect description. No swiping, no page dots.
- The same subscription controls and policy buttons below it, and the restore button in the toolbar, behaving exactly as above.
- The same close button in the same place.
- Light or dark following the device, not forced dark: there is no photo to protect.

Everything else is identical. The same events fire, the sheet closes on success the same way, and a later `features` list turns the photo layout on with no other change.

## Hiding or paywalling

Not everything that needs a subscription belongs behind the paywall. The rule:

- **Paywall** the thing the subscription sells. Creating and editing.
- **Hide** what would trap a free user. Rename and delete of their own data are hidden, not paywalled: deleting your only document and then being unable to create one is no reason to be sold a subscription.
- **Read-only** instead of disabled. Locked content stays scrollable and selectable; a disabled `TextEditor` would make a long text unreadable.

## The free tier

What a non-subscriber may still do is a rule about **scope**, never a counter.

Not "ten documents free, then pay". A month is free and the year is paid; one project is free and
the library is paid. A scope rule reads the data and answers. It stores nothing, so there is
nothing to keep in step, nothing to migrate, and nothing that can drift out of agreement with
what the user sees.

- **Nothing is counted locally.** Not uses, launches, days, documents or exports. Anything a
  reinstall can reset is not a paywall, and a meter that behaves differently on a second device
  reads as a broken app rather than as a fair one.
- **Trials come only from Apple's introductory offer.** Eligibility hangs on the Apple ID and
  the subscription group, so deleting the app changes nothing and no app-side state is involved.
  An app never invents a trial of its own.
- **That eligibility is spent once.** A user who starts the trial at a moment the product cannot
  prove itself has none left when it could. Cut the free tier so nobody needs the trial before
  the paid thing is worth having.
- **The free tier always reaches the user's own data.** An expired subscription may take features
  away; it may never lock up what somebody put in. In practice the free scope is also the way
  out, which is what keeps a lapsed subscriber from feeling held.

The free scope itself is the app's, not ButchKit's: only the app knows what a meaningful
narrower slice of its own subject is. ButchKit answers `hasAccess`, and the app decides
what the other answer still allows.

## Analytics

ButchKit has no analytics dependency. Hand the root modifier a handler, its `onEvent` parameter, and forward to whatever analytics the app uses (TelemetryDeck here, as an example):

```swift
RootView()
    .paywallEnvironment(paywallConfig, texts: paywallTexts, features: paywallFeatures) { event in
        TelemetryDeck.signal(event.name, parameters: event.parameters)
    }
```

Every event names itself and what it carries, under strings that stay the same across releases:

| `name` | `parameters` |
|---|---|
| `paywall.presented` | `source` |
| `paywall.purchaseStarted` | `source`, `productID` |
| `paywall.purchaseCompleted` | `source`, `productID`, `isIntroductoryOffer` |
| `paywall.purchasePending` | `source`, `productID` |
| `paywall.purchaseApproved` | `source`, `productID` |
| `paywall.purchaseFailed` | `source`, `productID`, `reason` |
| `paywall.verificationFailed` | none |
| `paywall.subscriptionStatus` | `phase`, `productID` |

This is the bridge to prefer: an event added by a later ButchKit flows through it untouched. An app that needs signal names of its own switches over the cases, and then always with a `default` that falls back to `event.name`. Without one, every new case stops the app from compiling on the next update.

The handler is in place before the first entitlement check. Assigning `PaywallService.onEvent` later from a view still works, but misses what the launch already reported. An app that owns its service assigns it in its `init`, see Setup.

`reason` is a `PaywallPurchaseFailure`, the kind of failure (`network`, `purchaseNotAllowed`, `productUnavailable`, …), never the error's own text: events are forwarded to a third party as they are, and a system description is whatever the system put in it. The error itself is in the log, by its code.

`presented` is the funnel's denominator, `purchaseCompleted` the numerator. A free trial start counts as completed, and `isIntroductoryOffer` tells it from a paid purchase, so a funnel does not read every free week as revenue. Restores and renewals are deliberately not events: they arrive through `Transaction.updates`, not through the paywall, and would inflate the conversion rate. A restore from the paywall's button sends no event either; only a purchase it finds that fails verification reports `.verificationFailed`, a diagnostic rather than a conversion. `productID` tells the plans apart, and the lifetime products from all of them, so a paywall with several offers can say which one sells.

`purchaseApproved` is the second half of an Ask to Buy purchase. Count it with `purchaseCompleted` for conversions; it is never reported for a purchase that completed at once.

`subscriptionStatus` stands apart from the funnel. It costs no query of its own: the service holds the plan anyway, for the settings row. It is a snapshot, reported once per service, which is once per launch for an app with one window or one that owns its service, and only for a user whose access rests on a running subscription. Its `SubscriptionPhase` is one of four stable values: `trialRenewing`, `trialCanceled`, `paidRenewing`, `paidCanceled`. Charted over active subscribers it answers how many have already canceled their free trial, the earliest sign of what the trial converts. Non-subscribers and lifetime owners report nothing, and neither does a subscription with an open payment problem, which is neither renewing nor canceled.

## Localization

ButchKit ships no strings and names no keys. Every word the paywall and the settings row show is
handed in through `PaywallTexts`, and every page through `PaywallFeature`. Each key is therefore
written in the app's own code, where Xcode finds it and extracts it into the app's catalog like
any other string: nothing is added by hand, and the paywall speaks every language the app does.

That is also why `PaywallTexts` has no default words. A default would be a string in none of the
app's catalogs, shown in English in every language, and nobody would notice. Instead the words
come in groups and an app supplies only the groups it shows: `sheet` always, `offerTabs` and
`subscriptionOverlap` with lifetime products next to a subscription, `statusRow` with the settings
row. Inside `sheet`, the `restoreOffline` and `productsUnavailable` groups and `purchasedLabel` and `policyConnector` are optional. A later ButchKit
that needs a new word adds a new optional group or falls back to a word that is already there;
it never adds a required parameter to an existing group, so an update does not stop an app from
compiling.

The app also picks each string's table. Plain labels are `LocalizedStringResource`s, written as
string literals, on the default `Localizable` table. Accessibility text and error text are `String`s the app resolves itself,
naming the table: the purchase and restore failure alerts and the billing issue from `Errors`, the
restore success and nothing-to-restore titles from `Localizable`, the two accessibility labels and
the two VoiceOver hints from `Accessibility`. See [ButchKit.md](ButchKit.md#localization) for the rule.

Suggested English for the settings row: `See subscription plans` for the offer, `Renews on %@` and
`Ends on %@` for the dated lines, `Payment didn't go through.` for the billing issue. For the
paywall: `Subscription` and `One-Time Purchase` for the two segments, `Restore` for the button at
the top right, short enough to sit opposite the close button. For the restore alerts: `Purchase Restored`, `No Purchase to Restore`, and
`Restore Failed` with `Your purchase could not be restored. Try again in a moment.`, and for the
optional `restoreOffline` group `No Connection` with `The App Store could not be reached. Check your
internet connection and try again.` Without that group the failure message has to cover a missing
connection too, so word it to. For the optional rest: `Purchased` for an owned lifetime product,
`Purchases Unavailable` with `Check your connection and try again.` and `Try Again` for the
`productsUnavailable` group,
and for the overlap alert `Your subscription is still running` with `Your purchase unlocks
everything for good. The subscription renews until you cancel it.`, `Manage Subscription` and `Later`.

Product names and prices come from App Store Connect, localized per storefront. Never hardcode a price in a marketing page.

## What happens underneath

- **Launch.** The cached answer from the last run is restored immediately. `Transaction.currentEntitlements` is then read once; a verified transaction in the configured group means subscribed, one for a lifetime product means lifetime, and the stronger of the two wins. `isInitialized` turns `true`, `verifiedEntitlement` gets its value, and a `require` that was waiting is decided. Only answers from StoreKit are ever written to the cache.
- **While running.** From `initialize()` on, a `Transaction.updates` listener finishes every verified transaction and updates the state: purchase, renewal, restore, Ask to Buy approval, and refund or revocation. A revocation re-reads the entitlements rather than clearing them: a refunded lifetime purchase leaves a running subscription in place, and the other way round. A subscription that runs out produces no transaction, so in an app with a subscription group a second listener on `Product.SubscriptionInfo.Status.updates` re-reads on every status change: an app left open locks when the plan ends.
- **Refresh.** Every read runs in a task of its own, one behind the other. A caller that is cancelled, a `.task` on a view the user just left, cannot cut a read short: a read cut short comes back empty and would lock a paying user out. Overlapping reads land in the order they were asked for.
- **Purchases from the paywall.** Finished right there, in the completion handler, and granted at once so the sheet closes without waiting for StoreKit to list the transaction. For ten seconds after, no refresh takes that access away again: StoreKit lists a fresh transaction a moment late, exactly when the app returns from the payment sheet and reads on foreground.
- **Restore.** `AppStore.sync()`, then `Transaction.currentEntitlements` read afresh: a purchase that was already finished does not come back through `Transaction.updates`. A verified entitlement means restored, even when the sync threw, so the paywall never calls a restore failed while the app is unlocked. Backing out of the sign-in means cancelled, a network error means offline. Any other error, or a purchase that fails verification, means failed. Otherwise there is nothing to restore. The service only decides the outcome; the paywall holds its own restore state, so it goes with the sheet. From the first tap until the alert is closed, an unlock does not close the sheet on its own.
- **Foreground.** The root modifier re-reads the entitlements each time the scene becomes active, so a subscription that ran out in the background locks the app at once. One local StoreKit read. The app writes no `scenePhase` handler for this; `refreshesOnForeground: false` in the configuration turns it off.
- **Offline.** StoreKit 2 answers entitlement checks from its own local cache, so a subscriber keeps access without a network. Online, StoreKit's answer is definitive: no entitlement means no access.
- **Verification failures.** Unverified transactions are not finished, as Apple recommends. They are logged and reported as `.verificationFailed`.
- **Logging.** Under the app's own subsystem, category `Purchase`; `PaywallService(configuration:texts:features:subsystem:)` takes another subsystem. `notice` for a cleared or revoked subscription, a kept fresh purchase, a pending and an approved Ask to Buy purchase, a `require` replaced before the first check, and a restore that succeeded, found nothing, was cancelled or went offline; `error` for a failed purchase, a failed restore, a transaction that failed verification, a subscription status that could not be loaded, a paywall request no sheet picked up, and a lifetime product that does not load, with its identifier; `fault` for a setup that cannot work: a configuration that sells nothing, or missing words for the segments or the settings row; `debug` for each resolved check. See `LoggingStrategy.md`.

## What the paywall uses from ButchKit

The paywall is the largest part of ButchKit and the one with the most dependencies on other components (see the component table in [ButchKit.md](ButchKit.md#whats-in-the-library)). Everything it needs ships in the same package, so an app adds nothing:

- **Logging.** `LoggerService` under the category `Purchase`, and `Error.logCode` for every error, see [LoggingStrategy.md](LoggingStrategy.md).
- **`GatedWebView`** for the Privacy Policy and Terms of Service, with its defaults: JavaScript off, the cache bypassed, and only links on the same domain followed.
- **`Device`**, read from `\.device`, to decide whether Manage opens Apple's sheet or the App Store, see [The settings row](#the-settings-row).
- **The close button** of `sheetDismissButton(_:)`, on the policy sheet of the one-time side. Through its internal type, as the paywall's words are `LocalizedStringResource`s.

From the system it uses StoreKit, SwiftUI and OSLog, and WidgetKit to reload the app's widget timelines when an app group is set. It is also the only part of ButchKit that ships resources: the placeholder photos of its own previews. Their `.storekit` file sits next to them but is excluded from the bundle.

## What it does not do

Deliberately, to stay one system:

- **No consumables, and no partial unlocks.** At most one auto-renewable group, plus any number of non-consumables that each unlock everything. Anything sold by the piece, or a product that unlocks only part of the app, is a different business, not a paywall.
- **No custom grace period.** Billing retry and grace belong to App Store Connect (Subscription Group settings), not to the app.
- **No product loading for the app.** The paywall and the settings row fetch what they show themselves. An app that needs a product anywhere else calls `Product.products(for:)` itself.
- **No promo or win-back offers of its own.** Add them in App Store Connect; StoreKit surfaces the eligible ones in the paywall on its own. Offer codes are the exception, because a code someone was handed has no other way in: `showsRedeemCode` adds Apple's button.
- **No paywall outside its sheet.** Not inline in an onboarding, not pushed onto a stack.

## Testing

- **Unit tests** cover the service's presentation logic: `present`, `require`, deferred actions and the request no sheet picks up; the refresh under cancellation, in overlap and right after a purchase; provisional against verified; the cache with and without an app group; the events' names and parameters; and the restore: its decision and every outcome with the App Store replaced. That the sheet stays open until the restore alert is read lives in the view and is checked in the app. StoreKit itself is not reachable from a package test.
- **In the app**, run with the `.storekit` file: buy, check the sheet closes and the gate opens, relaunch and confirm there is no flash, and refund in Xcode's Transactions manager to see access clear. Restore from the button at the top right in all three outcomes, on both segments: buy a lifetime product and restore; delete the transactions in the Transactions manager and restore; simulate an App Store Sync error in the `.storekit` file's settings and restore. Back out of the sign-in and expect no alert.
- **Sheet-in-sheet**: open the paywall from a root view and from inside a presented sheet with `.paywallSheet()`. Both must appear.
- **Running out while open**: with the `.storekit` file's renewals sped up, cancel the subscription in the Transactions manager and leave the app in the foreground. The gate must close when the period ends, without leaving the app.

## Migrating from 1.x to 2.0

2.0 collects every breaking change in one release, so that later ones need none. Per app, in `Paywall.swift` unless said otherwise:

1. **`PaywallTexts`**: wrap the same arguments in groups. `sheet: .init(…)` takes the paywall's ten, `statusRow: .init(…)` the row's ten. `subscriptionTab` and `oneTimeTab` become `offerTabs: .init(subscription:oneTime:)`; an app without lifetime products next to a subscription deletes them, and their two keys from its catalogs. The keys themselves do not change. If `paywallTexts` was a computed property or marked `@MainActor`, make it a plain file-scope `let`.
2. **`PayWallFeature`** is `PaywallFeature`. The old spelling still compiles, with a deprecation and a fix-it.
3. **`onEvent`**: replace the `switch` with `signal(event.name, parameters: event.parameters)`, or add a `default` and the new associated values: the new `.purchaseApproved`, `productID` on `.purchasePending` and `.purchaseFailed`, `isIntroductoryOffer` on `.purchaseCompleted`, and `reason` as a `PaywallPurchaseFailure` instead of a `String`. Mind that the parameter keys are now `source` and `productID`; keep a `switch` if the dashboards depend on the old names.
4. **Custom rows on `PaywallStatusReader`**: `paywall.texts.offer` and its siblings moved to `paywall.texts.statusRow`, or to a `PaywallTexts.StatusRow` constant of the app's own. Add the `status.isLoading` case.
5. **Delete what the SDK now does.** A `scenePhase` handler that calls `refresh()`. A detached or unstructured task around `refresh()`. A window of grace after a purchase. A `subscriptionStatusTask` that triggers a refresh. A mirror of the entitlement into an app group: set `appGroupID` and read `PaywallEntitlementCache` in the extension instead. Any `isInitialized && hasAccess` of the app's own: that is `hasVerifiedAccess`. An `onChange` that pushes the entitlement into a service, a tip or an extension: that is `onVerifiedEntitlementChange`. A `WidgetCenter` reload on the flip: automatic with `appGroupID`. An `isInitialized && !hasAccess` that decides whether a banner or a lock shows: that is `isLocked`. A second `paywallEnvironment(config, …)` on a Mac app's `Settings` scene: own the service and hand the same one to both.
6. **Removed**: `hasSubscription` (use `hasAccess`), and `handleSuccessfulPurchase` from the public API. No app has a reason to call it; it granted access on two strings.
7. **Several windows, or a pipeline that needs the answer**: own the service, see Setup.
8. **Optional**: a "Restore Purchases" row in the settings, see above. An app that sells lifetime products words `sheet.productsUnavailable`, or that side is empty when nothing loads.

## Rules for agents

A compact checklist for anyone, human or AI, touching the paywall in an app that uses ButchKit:

- The paywall is defined in `Paywall.swift` and installed once with `.paywallEnvironment(_:texts:features:onEvent:)` on the root. Nowhere else.
- Views read the service with `@Environment(PaywallService.self)`. Only an app with several windows, or with code outside its views that needs the answer, constructs one: once, in the `App`, handed to `.paywallEnvironment(_:)` on every scene and passed on by initializer. Never a second instance, never a global.
- Gate views on `paywall.hasAccess`. Never read StoreKit or `Transaction` for the subscription state.
- Draw locks, banners and read-only states from `paywall.isLocked`, never from `!hasAccess` or an `isInitialized` check of the app's own.
- Whatever follows the entitlement outside a view, a service's limit, a tip parameter, notifications, hangs on `.onVerifiedEntitlementChange`. Never an `onChange` over `hasAccess`.
- Anything that outlasts the screen reads `verifiedEntitlement` or `hasVerifiedAccess`: what is stored, synced, sent to a server or reported. `nil` means not known yet; never write it down as "free".
- A widget, an extension or an App Intent reads `PaywallEntitlementCache` with the configuration's `appGroupID`. Never mirror the entitlement into a key of the app's own, and never reload widget timelines for it: the service does.
- Never write a `scenePhase` handler that refreshes the paywall, and never wrap `refresh()` in a detached task. The root modifier refreshes on foreground, and `refresh()` is safe under cancellation.
- Declare `paywallConfig`, `paywallTexts` and `paywallFeatures` as file-scope `let` constants, never as computed properties.
- Forward analytics with `event.name` and `event.parameters`. A `switch` over `PaywallEvent` always has a `default`.
- A "Restore Purchases" row in the settings calls `paywall.restorePurchases()` from a button and shows the outcome.
- Use `require(source:_:)` for actions, `present(source:)` for offers. Never declare a paywall sheet in a view.
- Apply `.paywallSheet()` inside every sheet or cover that can trigger the paywall. Nothing on pushed views.
- Hide what would trap a free user; paywall only what the subscription sells.
- The free tier is a rule about scope, never a counter. Never store a use, day or document count.
- Trials come from Apple's introductory offer only. Never build one out of `UserDefaults`.
- Configure by subscription group, never by product identifier. The only products ever named are the lifetime unlocks. Debug and Release group IDs differ. An app that sells only lifetime unlocks leaves the group out.
- An app with lifetime products next to a subscription supplies at least one marketing page, and the `offerTabs` and `subscriptionOverlap` words.
- A page that mentions a free trial or any introductory price is `introOfferOnly: true`. App copy that mentions one checks `isEligibleForIntroOffer == true`.
- Never load the plan, its name or the subscription status in app code. `PaywallStatusReader` has them.
- Never tune `featureAreaHeight` to make the Subscribe button fit a small screen. The paywall does that.
- Marketing pages are `PaywallFeature` values, never custom views. The layout is fixed in ButchKit.
- Pages are optional. With none, Apple's storefront takes over; never build a placeholder page to fill the gap.
- Every paywall string is written in the app's code, in `PaywallTexts` and the feature pages, so Xcode extracts it into the app's catalogs. Never add a key to a catalog by hand.
- Forward `PaywallEvent` to analytics from one place, the `onEvent` handler of `.paywallEnvironment`. Never track a restore or renewal as a conversion.
- Never add consumables, a non-consumable that unlocks only part of the app, a grace period, or network checks to the service.
