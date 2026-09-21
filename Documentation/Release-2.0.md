# Release 2.0

Tag `v2.0.0`, not `v1.7`: `hasSubscription` and the public `handleSuccessfulPurchase` are gone, `PayWallFeature` is renamed with a deprecation, `PaywallTexts` takes groups, and `onEvent` carries new associated values. An app pinning `from: "1.6.0"` must not pick this up unasked. The full list is the migration section of `Paywall.md`; every claim in it was checked against the code for this release.

## What is in it

**The paywall itself.** One integration, `.paywallEnvironment(_:texts:features:)`, which creates the service, runs the first entitlement check, reads again on every foreground and owns the sheet. Full-bleed photo pages over `SubscriptionStoreView`. Lifetime products sold next to the plans.

**The paywall comes up in the window that asked.** An app that owns its service shares it between its windows; until now the sheet appeared in whichever window opened last. Each scene carries an identity, a key-window observer reports which one the user is in, and the innermost host of that scene presents. A requirement held across the first entitlement check keeps the scene it was asked from.

**Drawing the locked state.** `isLocked` is true once it is known that the user does not pay, false while nothing is known at all, so a subscriber who just reinstalled never sees a lock flash by. For looks only; what a tap does is still `hasAccess` or `require`.

**Reacting to the entitlement outside a view.** `onVerifiedEntitlementChange` runs once StoreKit has answered and on every change after. It never runs with the cached answer, which is what made an `onChange` over `hasAccess` the wrong tool.

**Widgets.** With `appGroupID` set, every change of the answer reloads the app's widget timelines. There is no `WidgetCenter` call left to write.

### Fixed in this release

- The cache never receives an unconfirmed answer again. A purchase used to resolve against the entitlement the launch seeded from the cache, a plain editable defaults value, and could write that guess into the app group where a widget reads it as confirmed.
- Every lifetime product the user owns is marked as bought. An app selling several showed a checkmark on one and a live Buy button on the other.
- An Ask to Buy approval arriving at launch no longer loses the subscription-overlap alert, which is the only route the app offers to cancelling a now-redundant subscription.
- A `present(source:)` from an App Intent or a notification on a cold launch is no longer dropped before the first scene exists.
- A requirement replaced by a second tap before the first entitlement check is logged rather than dropped silently.

## Before tagging

Everything below needs a device or a Store account and cannot be checked by the test suite.

### Window routing

The feature rests on key-window behaviour in UIKit and AppKit that no unit test covers. The service-side bookkeeping is tested; the reporting is not.

- [ ] iPad, two windows of the same app in Split View. Trigger the paywall from the left window, then from the right. It must appear in the one that was tapped.
- [ ] **Watch for this specifically:** if both Split View windows count as key at once, the reported scene is only "whichever fired last" and the paywall can land in the wrong window. That is the exact bug the feature exists to fix, so it is worth one deliberate attempt to provoke.
- [ ] Mac, two windows plus the `Settings` scene, all on one service. The paywall must follow the focused window.
- [ ] Mac, paywall asked for from inside an app sheet. It must come from that sheet, not from the window underneath.

### Sandbox

- [ ] Buy a subscription, then a lifetime product next to it. The overlap alert appears after the sheet closes, and its button reaches subscription management.
- [ ] Ask to Buy: ask as a child, approve as a parent while the app is closed, relaunch. The purchase unlocks and the overlap alert still appears if a subscription renews.
- [ ] Restore purchases from the settings row, on a device with the purchase and on one without.
- [ ] Refund through the Xcode transaction manager; access goes away on the next foreground.
- [ ] Let a subscription expire; access goes away without a transaction to hear of.
- [ ] An app selling several lifetime products: own two, and check both cards show a checkmark.

### Widget

- [ ] An app with `appGroupID` and a widget. Buy, and the tile unlocks without waiting for its next timeline.
- [ ] Fresh install of a subscriber: the widget shows its loading state, never a locked one.

### Then

- [ ] `swift test` and the iOS job both green in CI.
- [ ] Tag `v2.0.0` and push.
