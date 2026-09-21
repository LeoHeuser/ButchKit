import Foundation
import StoreKit
import Testing
@testable import ButchKit

private struct SomeError: Error {}

@Suite("PaywallConfiguration")
struct PaywallConfigurationTests {
    @Test("Leaves the policy URLs empty by default")
    func defaults() {
        let config = PaywallConfiguration(subscriptionGroupID: "1")
        #expect(config.privacyPolicyURL == nil)
        #expect(config.termsOfServiceURL == nil)
        #expect(!config.hasPolicies)
    }

    @Test("Gives the pages 62 % of the paywall by default")
    func defaultFeatureAreaHeight() {
        #expect(PaywallConfiguration(subscriptionGroupID: "1").featureAreaHeight == 0.62)
    }

    /// Outside 0...1 the pages would claim negative room or more than the sheet has.
    @Test("Clamps the feature area height to the paywall")
    func clampsFeatureAreaHeight() {
        #expect(PaywallConfiguration(subscriptionGroupID: "1", featureAreaHeight: -0.2).featureAreaHeight == 0)
        #expect(PaywallConfiguration(subscriptionGroupID: "1", featureAreaHeight: 1.4).featureAreaHeight == 1)
        #expect(PaywallConfiguration(subscriptionGroupID: "1", featureAreaHeight: 0.7).featureAreaHeight == 0.7)
    }

    /// StoreKit shows the privacy and terms buttons as a pair, so one missing URL must hide both
    /// rather than leave a button that leads nowhere.
    @Test("Shows policies only when both URLs are set")
    func policiesNeedBothURLs() {
        #expect(!PaywallConfiguration(subscriptionGroupID: "1", privacyPolicyURL: "a.com").hasPolicies)
        #expect(!PaywallConfiguration(subscriptionGroupID: "1", termsOfServiceURL: "b.com").hasPolicies)
        #expect(PaywallConfiguration(subscriptionGroupID: "1", privacyPolicyURL: "a.com", termsOfServiceURL: "b.com").hasPolicies)
    }

    @Test("Sells no lifetime product by default")
    func noLifetimeByDefault() {
        let config = PaywallConfiguration(subscriptionGroupID: "1")
        #expect(config.lifetimeProductIDs.isEmpty)
        #expect(config.entitlement(productID: "lifetime", subscriptionGroupID: nil) == .none)
    }

    /// A lifetime product carries no group, and a member of the group is never a lifetime
    /// product, so the two questions cannot answer each other.
    @Test("Decides the entitlement per transaction")
    func decidesEntitlement() {
        let config = PaywallConfiguration(subscriptionGroupID: "1", lifetimeProductIDs: ["lifetime", "supporter"])
        #expect(config.entitlement(productID: "lifetime", subscriptionGroupID: nil) == .lifetime)
        #expect(config.entitlement(productID: "supporter", subscriptionGroupID: nil) == .lifetime)
        #expect(config.entitlement(productID: "yearly", subscriptionGroupID: "1") == .subscription)
        #expect(config.entitlement(productID: "other", subscriptionGroupID: "2") == .none)
        #expect(config.entitlement(productID: "other", subscriptionGroupID: nil) == .none)
    }

    /// Without a group of its own, a product without a group must not count as a member of it:
    /// `nil` matching `nil` would unlock the app for any unknown non-consumable.
    /// The share is an upper bound: the Subscribe button staying in view is worth more than the
    /// last of the photo.
    @Test("Gives the pages their share, less what the purchases need")
    func featureHeight() {
        let config = PaywallConfiguration(subscriptionGroupID: "TEST")
        // A tall sheet: 62 % leaves more than the purchases need, so the share stands.
        #expect(config.featureHeight(in: 800, reserving: 280) == 800 * 0.62)
        // A short one: the pages give way.
        #expect(config.featureHeight(in: 600, reserving: 280) == 320)
        // Never negative, at a text size where the purchases want more than there is.
        #expect(config.featureHeight(in: 300, reserving: 500) == 0)
    }

    @Test("Sells lifetime products without a subscription")
    func lifetimeOnly() {
        let config = PaywallConfiguration(lifetimeProductIDs: ["lifetime"])
        #expect(config.subscriptionGroupID == nil)
        #expect(config.entitlement(productID: "lifetime", subscriptionGroupID: nil) == .lifetime)
        #expect(config.entitlement(productID: "other", subscriptionGroupID: nil) == .none)
        #expect(config.entitlement(productID: "yearly", subscriptionGroupID: "1") == .none)
    }
}

@Suite("PaywallEntitlement")
struct PaywallEntitlementTests {
    /// Several transactions reduce with `max()`, so the order has to put the lifetime purchase on top.
    @Test("Ranks lifetime above a subscription above nothing")
    func ordering() {
        #expect(PaywallEntitlement.none < .subscription)
        #expect(PaywallEntitlement.subscription < .lifetime)
        #expect(max(PaywallEntitlement.lifetime, .subscription) == .lifetime)
    }
}

@Suite("PaywallPolicyLine")
struct PaywallPolicyLineTests {
    /// StoreKit words the line over the plans "Terms of Service and Privacy Policy". The lifetime
    /// side draws its own and has to say it in the same order, or the two halves of one paywall
    /// read differently.
    @Test("Names the terms first, then the privacy policy")
    func order() {
        let sentence = PaywallOneTimeStore.policySentence(terms: "TERMS", privacy: "PRIVACY", connector: "AND")
        #expect(String(sentence.characters) == "TERMS AND PRIVACY")
    }

    /// Both halves are links, or one of the two pages cannot be opened at all. They carry a scheme
    /// of ours, which the line catches itself rather than letting it leave for a browser.
    @Test("Makes both titles links, and only the titles")
    func links() {
        let sentence = PaywallOneTimeStore.policySentence(terms: "TERMS", privacy: "PRIVACY", connector: "AND")
        let links = sentence.runs.compactMap(\.link)
        #expect(links == [PaywallOneTimeStore.termsURL, PaywallOneTimeStore.privacyURL])

        // The connecting word is not a link, and is set apart from the two that are.
        let word = sentence.runs.first { $0.link == nil }
        #expect(word?.foregroundColor == .secondary)
    }
}

@Suite("PaywallEntitlementSnapshot")
struct PaywallEntitlementSnapshotTests {
    private let config = PaywallConfiguration(subscriptionGroupID: "TEST", lifetimeProductIDs: ["lifetime"])

    @Test("Keeps the strongest verified entitlement, whatever the order")
    func strongestWins() {
        var snapshot = PaywallEntitlementSnapshot()
        snapshot.add(productID: "lifetime", subscriptionGroupID: nil, isVerified: true, under: config)
        snapshot.add(productID: "yearly", subscriptionGroupID: "TEST", isVerified: true, under: config)
        #expect(snapshot.strongest == .lifetime)
    }

    @Test("Names the first verified lifetime product, never an unverified one")
    func lifetimeProductID() {
        let config = PaywallConfiguration(subscriptionGroupID: "TEST", lifetimeProductIDs: ["lifetime", "supporter"])
        var snapshot = PaywallEntitlementSnapshot()
        snapshot.add(productID: "supporter", subscriptionGroupID: nil, isVerified: false, under: config)
        snapshot.add(productID: "yearly", subscriptionGroupID: "TEST", isVerified: true, under: config)
        snapshot.add(productID: "lifetime", subscriptionGroupID: nil, isVerified: true, under: config)
        snapshot.add(productID: "supporter", subscriptionGroupID: nil, isVerified: true, under: config)
        #expect(snapshot.lifetimeProductID == "lifetime")
    }

    /// An app that sells several lifetime unlocks: a user who owns two must see both marked as
    /// bought, not only whichever StoreKit happened to list first.
    @Test("Collects every verified lifetime product, and still names one")
    func ownedLifetimeProductIDs() {
        let config = PaywallConfiguration(subscriptionGroupID: "TEST", lifetimeProductIDs: ["lifetime", "supporter"])
        var snapshot = PaywallEntitlementSnapshot()
        snapshot.add(productID: "supporter", subscriptionGroupID: nil, isVerified: false, under: config)
        snapshot.add(productID: "lifetime", subscriptionGroupID: nil, isVerified: true, under: config)
        snapshot.add(productID: "supporter", subscriptionGroupID: nil, isVerified: true, under: config)
        #expect(snapshot.ownedLifetimeProductIDs == ["lifetime", "supporter"])
        #expect(snapshot.lifetimeProductID == "lifetime")
    }

    /// A purchase that fails verification must never unlock the app, but a restore has to know
    /// it exists to say it could not be restored.
    @Test("Notes an unverified purchase without granting it")
    func unverifiedGrantsNothing() {
        var snapshot = PaywallEntitlementSnapshot()
        snapshot.add(productID: "lifetime", subscriptionGroupID: nil, isVerified: false, under: config)
        #expect(snapshot.strongest == .none)
        #expect(snapshot.hasUnverified)
    }

    @Test("Ignores products the configuration does not sell", arguments: [true, false])
    func ignoresUnknownProducts(isVerified: Bool) {
        var snapshot = PaywallEntitlementSnapshot()
        snapshot.add(productID: "other", subscriptionGroupID: "OTHER", isVerified: isVerified, under: config)
        #expect(snapshot == PaywallEntitlementSnapshot())
    }
}

@Suite("PaywallRestoreOutcome")
struct PaywallRestoreOutcomeTests {
    private let found = PaywallEntitlementSnapshot(strongest: .lifetime)
    private let nothing = PaywallEntitlementSnapshot()
    private let unverified = PaywallEntitlementSnapshot(hasUnverified: true)
    private let offline = StoreKitError.networkError(URLError(.notConnectedToInternet))

    /// Once the app is unlocked, the paywall must not claim the restore failed, whatever the sync
    /// threw on the way.
    @Test("Restored whenever a verified entitlement is there")
    func entitlementWins() {
        #expect(PaywallRestoreOutcome.decide(syncError: nil, snapshot: found) == .restored)
        #expect(PaywallRestoreOutcome.decide(syncError: StoreKitError.userCancelled, snapshot: found) == .restored)
        #expect(PaywallRestoreOutcome.decide(syncError: offline, snapshot: found) == .restored)
    }

    @Test("Cancelled when the user backs out of the sign-in")
    func cancelled() {
        #expect(PaywallRestoreOutcome.decide(syncError: StoreKitError.userCancelled, snapshot: nothing) == .cancelled)
    }

    @Test("Failed when the sync throws anything else")
    func syncFailed() {
        #expect(PaywallRestoreOutcome.decide(syncError: SomeError(), snapshot: nothing) == .failed)
    }

    /// The usual case right after a reinstall, and one the user can do something about, so it
    /// gets words of its own.
    @Test("Offline when the App Store could not be reached")
    func offlineOutcome() {
        #expect(PaywallRestoreOutcome.decide(syncError: offline, snapshot: nothing) == .offline)
        // Not every path wraps the connection error in StoreKit's own.
        #expect(PaywallRestoreOutcome.decide(syncError: URLError(.timedOut), snapshot: nothing) == .offline)
    }

    @Test("Failed when the only purchase found is unverified")
    func unverifiedFailed() {
        #expect(PaywallRestoreOutcome.decide(syncError: nil, snapshot: unverified) == .failed)
    }

    @Test("Nothing to restore when the App Store knows no purchase")
    func nothingToRestore() {
        #expect(PaywallRestoreOutcome.decide(syncError: nil, snapshot: nothing) == .nothingToRestore)
    }
}

@Suite("PaywallService", .serialized)
@MainActor
struct PaywallServiceTests {
    private let config = PaywallConfiguration(subscriptionGroupID: "TEST", lifetimeProductIDs: ["lifetime", "supporter"])

    /// The cache survives between test runs in the host's defaults; every test starts unsubscribed.
    /// Past its first entitlement check unless told otherwise, as an app is by the time anyone
    /// taps anything.
    private func makeService(initialized: Bool = true) -> PaywallService {
        clearCache()
        let service = PaywallService(configuration: config, texts: .preview)
        if initialized { _ = service.markInitialized() }
        return service
    }

    private func clearCache() {
        UserDefaults.standard.removeObject(forKey: PaywallEntitlementCache.key)
        UserDefaults.standard.removeObject(forKey: PaywallEntitlementCache.legacyKey)
        UserDefaults.standard.removeObject(forKey: PaywallEntitlementCache.pendingPurchaseKey)
    }

    @Test("Starts uninitialized with its configuration")
    func initialState() {
        let service = makeService(initialized: false)
        #expect(!service.isInitialized)
        #expect(service.entitlement == .none)
        #expect(!service.hasAccess)
        #expect(service.configuration == config)
        #expect(service.features.isEmpty)
        #expect(service.presentedRequest == nil)
    }

    @Test("The root modifier's holder builds the service once")
    func holderBuildsOnce() {
        let holder = PaywallServiceHolder()
        var builds = 0
        let make = {
            builds += 1
            return makeService()
        }
        let first = holder.service(make)
        let second = holder.service(make)
        #expect(first === second)
        #expect(builds == 1)
    }

    @Test("Forwards events to onEvent")
    func reportsEvents() {
        let service = makeService()
        var received: [PaywallEvent] = []
        service.onEvent = { received.append($0) }
        service.report(.presented(source: "settings"))
        #expect(received == [.presented(source: "settings")])
    }

    @Test("Presents and dismisses")
    func presentAndDismiss() {
        let service = makeService()
        service.present(source: "settings")
        #expect(service.presentedRequest?.source == "settings")
        service.dismissPaywall()
        #expect(service.presentedRequest == nil)
    }

    @Test("Defers the action and presents when unsubscribed")
    func requireDefersWhenUnsubscribed() {
        let service = makeService()
        var ran = false
        service.require(source: "newItem") { ran = true }
        #expect(!ran)
        #expect(service.presentedRequest?.source == "newItem")
    }

    /// Closing the paywall without buying must not run the gated action later by accident.
    @Test("Drops the deferred action when dismissed without a subscription")
    func dismissWithoutUnlockDropsAction() {
        let service = makeService()
        var ran = false
        service.require(source: "newItem") { ran = true }
        service.dismissPaywall()
        service.paywallDidDismiss()
        #expect(!ran)
    }

    /// A `require` whose sheet never showed (a sheet without `.paywallSheet()`) must not fire its
    /// action from an unrelated later paywall.
    @Test("Drops a deferred action when a new request replaces it")
    func newRequestDropsStaleAction() {
        let service = makeService()
        var ran = false
        service.require(source: "newItem") { ran = true }
        service.present(source: "settings")
        service.handleSuccessfulPurchase(productID: "yearly", subscriptionGroupID: "TEST")
        service.paywallDidDismiss()
        #expect(!ran)
    }

    @Test("Runs the deferred action once the purchase went through")
    func dismissAfterUnlockRunsAction() {
        let service = makeService()
        var ran = false
        service.require(source: "newItem") { ran = true }
        service.handleSuccessfulPurchase(productID: "yearly", subscriptionGroupID: "TEST")
        service.paywallDidDismiss()
        #expect(ran)
    }

    @Test("Runs the action immediately when subscribed")
    func requireRunsImmediatelyWhenSubscribed() {
        let service = makeService()
        service.handleSuccessfulPurchase(productID: "yearly", subscriptionGroupID: "TEST")
        var ran = false
        service.require(source: "newItem") { ran = true }
        #expect(ran)
        #expect(service.presentedRequest == nil)
    }

    @Test("Grants a subscription for any product but the lifetime ones")
    func subscriptionPurchase() {
        let service = makeService()
        service.handleSuccessfulPurchase(productID: "yearly", subscriptionGroupID: "TEST")
        #expect(service.entitlement == .subscription)
        #expect(service.hasAccess)
    }

    @Test("Grants the lifetime entitlement for every lifetime product", arguments: ["lifetime", "supporter"])
    func lifetimePurchase(productID: String) {
        let service = makeService()
        service.handleSuccessfulPurchase(productID: productID, subscriptionGroupID: nil)
        #expect(service.entitlement == .lifetime)
        #expect(service.hasAccess)
    }

    /// A subscription bought, or renewed, next to a lifetime purchase must not talk the row into
    /// showing a plan the user does not depend on.
    @Test("Never downgrades a lifetime owner to a subscriber")
    func lifetimeStays() {
        let service = makeService()
        service.handleSuccessfulPurchase(productID: "lifetime", subscriptionGroupID: nil)
        service.handleSuccessfulPurchase(productID: "yearly", subscriptionGroupID: "TEST")
        #expect(service.entitlement == .lifetime)
    }

    /// The cache is a plain defaults value the user can edit, and the launch reads it into
    /// ``PaywallService/entitlement`` before StoreKit has said anything. A purchase must not carry
    /// that guess back into the cache: a widget reads it as confirmed.
    @Test("Never writes a cached answer back as a confirmed one")
    func purchaseWritesOnlyWhatStoreKitConfirmed() {
        clearCache()
        UserDefaults.standard.set(PaywallEntitlement.lifetime.rawValue, forKey: PaywallEntitlementCache.key)
        let service = PaywallService(configuration: config, texts: .preview)

        // A verified subscription replayed by `Transaction.updates` at launch, before the first
        // entitlement read has landed.
        service.handleSuccessfulPurchase(productID: "yearly", subscriptionGroupID: "TEST")
        #expect(UserDefaults.standard.string(forKey: PaywallEntitlementCache.key) == PaywallEntitlement.subscription.rawValue)
        clearCache()
    }

    /// The other half of the rule: what StoreKit confirmed in this launch still counts, so a
    /// replay of a lifetime purchase followed by a subscription does not downgrade the owner.
    @Test("Keeps what StoreKit confirmed in this launch")
    func purchaseKeepsWhatWasConfirmed() {
        let service = makeService(initialized: false)
        service.handleSuccessfulPurchase(productID: "lifetime", subscriptionGroupID: nil)
        service.handleSuccessfulPurchase(productID: "yearly", subscriptionGroupID: "TEST")
        #expect(service.entitlement == .lifetime)
        #expect(UserDefaults.standard.string(forKey: PaywallEntitlementCache.key) == PaywallEntitlement.lifetime.rawValue)
        clearCache()
    }

    /// A lifetime owner buying a second lifetime product: the entitlement cannot rise, so the
    /// paywall stays open on the very card that has to flip to a checkmark.
    @Test("Owns a second lifetime product the moment it is bought")
    func secondLifetimePurchaseIsOwned() {
        let service = makeService()
        service.handleSuccessfulPurchase(productID: "lifetime", subscriptionGroupID: nil, isDirectPurchase: true)
        service.handleSuccessfulPurchase(productID: "supporter", subscriptionGroupID: nil, isDirectPurchase: true)
        #expect(service.ownedLifetimeProductIDs == ["lifetime", "supporter"])
        #expect(service.entitlement == .lifetime)
        clearCache()
    }

    /// Bought while a family member's copy already granted access: the row must name what this
    /// user paid for, and stop calling it the family's.
    @Test("Names the user's own lifetime purchase over a family member's copy")
    func ownPurchaseReplacesTheSharedCopy() async {
        let service = makeService()
        await service.refresh { config in
            var snapshot = PaywallEntitlementSnapshot()
            snapshot.add(productID: "lifetime", subscriptionGroupID: nil, isVerified: true, isFamilyShared: true, under: config)
            return snapshot
        }
        #expect(service.lifetimeProductID == "lifetime")
        #expect(service.lifetimeIsFamilyShared)

        service.handleSuccessfulPurchase(productID: "supporter", subscriptionGroupID: nil, isDirectPurchase: true)
        #expect(service.lifetimeProductID == "supporter")
        #expect(!service.lifetimeIsFamilyShared)
        clearCache()
    }

    /// The launch reads `.lifetime` from the cache, so a purchase inside the grace period lifts
    /// nothing, and used to name nothing either.
    @Test("Names a lifetime purchase made while the cached answer already read as lifetime")
    func namesPurchaseOverACachedEntitlement() {
        clearCache()
        PaywallEntitlementCache().write(.lifetime)
        let service = PaywallService(configuration: config, texts: .preview)
        #expect(service.lifetimeProductID == nil)
        service.handleSuccessfulPurchase(productID: "supporter", subscriptionGroupID: nil, isDirectPurchase: true)
        #expect(service.lifetimeProductID == "supporter")
        clearCache()
    }

    @Test("Restores the cached entitlement on launch", arguments: ["yearly", "lifetime"])
    func restoresCache(productID: String) {
        let first = makeService()
        first.handleSuccessfulPurchase(productID: productID, subscriptionGroupID: config.lifetimeProductIDs.contains(productID) ? nil : "TEST")
        let second = PaywallService(configuration: config, texts: .preview)
        #expect(second.entitlement == first.entitlement)
        clearCache()
    }

    /// The cache before the lifetime product was one Bool. A subscriber updating the app reads
    /// it once and sees no paywall flash.
    @Test("Reads the Bool cache of earlier versions as a subscription")
    func restoresLegacyCache() {
        clearCache()
        UserDefaults.standard.set(true, forKey: PaywallEntitlementCache.legacyKey)
        let service = PaywallService(configuration: config, texts: .preview)
        #expect(service.entitlement == .subscription)
        clearCache()
    }

    // MARK: Refresh

    /// A `.task` that reads on foreground is cancelled when the user swipes to the app switcher.
    /// A cancelled read of StoreKit ends early and empty, which must never reach the entitlement.
    @Test("Finishes a refresh whose caller was cancelled")
    func refreshSurvivesCancellation() async {
        let service = makeService()
        let caller = Task {
            await service.refresh { _ in
                await Task.yield()
                // What StoreKit's sequence does under cancellation: it ends before its first element.
                return PaywallEntitlementSnapshot(strongest: Task.isCancelled ? .none : .subscription)
            }
        }
        caller.cancel()
        await caller.value
        #expect(service.entitlement == .subscription)
        clearCache()
    }

    @Test("Applies overlapping refreshes in the order they were asked for")
    func refreshesInOrder() async {
        let service = makeService()
        async let slow: Void = service.refresh { _ in
            try? await Task.sleep(for: .milliseconds(50))
            return PaywallEntitlementSnapshot(strongest: .subscription)
        }
        // Started second and answered at once, yet it must land last.
        async let fast: Void = service.refresh { _ in PaywallEntitlementSnapshot(strongest: .lifetime) }
        _ = await (slow, fast)
        #expect(service.entitlement == .lifetime)
        clearCache()
    }

    /// StoreKit lists a fresh purchase a moment late, right when the app returns from the payment
    /// sheet and reads on foreground.
    @Test("Keeps a fresh purchase that StoreKit does not list yet")
    func refreshKeepsFreshPurchase() async {
        let service = makeService()
        service.handleSuccessfulPurchase(productID: "yearly", subscriptionGroupID: "TEST")
        await service.refresh(currentEntitlements: entitlements(.none))
        #expect(service.entitlement == .subscription)

        service.purchaseGracePeriod = .zero
        await service.refresh(currentEntitlements: entitlements(.none))
        #expect(service.entitlement == .none)
    }

    // MARK: Verified

    @Test("Knows no verified entitlement until StoreKit has answered")
    func verifiedEntitlement() async {
        let first = makeService()
        first.handleSuccessfulPurchase(productID: "yearly", subscriptionGroupID: "TEST")

        let second = PaywallService(configuration: config, texts: .preview)
        #expect(second.hasAccess)
        #expect(second.verifiedEntitlement == nil)
        #expect(!second.hasVerifiedAccess)

        second.purchaseGracePeriod = .zero
        await second.refresh(currentEntitlements: entitlements(.lifetime))
        _ = second.markInitialized()
        #expect(second.verifiedEntitlement == .lifetime)
        #expect(second.hasVerifiedAccess)
        clearCache()
    }

    /// The cache is a defaults value anyone can edit. It may draw the interface, never open a gate.
    @Test("Holds a requirement until StoreKit has answered, then shows the paywall")
    func requireWaitsThenPresents() async {
        clearCache()
        UserDefaults.standard.set(PaywallEntitlement.lifetime.rawValue, forKey: PaywallEntitlementCache.key)
        let service = PaywallService(configuration: config, texts: .preview)
        var ran = false
        service.require(source: "export") { ran = true }
        #expect(!ran)
        #expect(service.presentedRequest == nil)

        await service.refresh(currentEntitlements: entitlements(.none))
        _ = service.markInitialized()
        #expect(!ran)
        #expect(service.presentedRequest?.source == "export")
    }

    /// Two taps before StoreKit has answered. The last is the one the user is waiting on, exactly
    /// as it is once initialized, where `present` clears the earlier action. Pinned so nobody
    /// turns the held slot into a queue: that would run an action the user has long left behind.
    @Test("Keeps the last requirement made before StoreKit answered")
    func lastHeldRequirementWins() {
        let service = makeService(initialized: false)
        var ran: [String] = []
        service.require(source: "first") { ran.append("first") }
        service.require(source: "second") { ran.append("second") }
        _ = service.markInitialized()
        #expect(service.presentedRequest?.source == "second")

        service.handleSuccessfulPurchase(productID: "yearly", subscriptionGroupID: "TEST")
        service.paywallDidDismiss()
        #expect(ran == ["second"])
        clearCache()
    }

    /// A subscriber on a fresh install has nothing cached and must not be shown a paywall.
    @Test("Holds a requirement until StoreKit has answered, then runs it")
    func requireWaitsThenRuns() async {
        let service = makeService(initialized: false)
        var ran = false
        service.require(source: "export") { ran = true }
        await service.refresh(currentEntitlements: entitlements(.subscription))
        _ = service.markInitialized()
        #expect(ran)
        #expect(service.presentedRequest == nil)
        clearCache()
    }

    @Test("Initializes once, however many scenes ask")
    func marksInitializedOnce() {
        let service = makeService(initialized: false)
        #expect(service.markInitialized())
        #expect(!service.markInitialized())
    }

    // MARK: Ask to Buy

    /// A parent approves minutes or days later, long after the paywall closed.
    @Test("Keeps the action of a pending purchase past the paywall, and runs it on approval")
    func approvalRunsAction() {
        let service = makeService()
        var received: [PaywallEvent] = []
        service.onEvent = { received.append($0) }
        var ran = false
        service.require(source: "export") { ran = true }
        service.purchaseDidPend(source: "export", productID: "yearly")
        service.dismissPaywall()
        service.paywallDidDismiss()
        #expect(!ran)

        service.handleSuccessfulPurchase(productID: "yearly", subscriptionGroupID: "TEST")
        #expect(ran)
        #expect(received == [
            .purchasePending(source: "export", productID: "yearly"),
            .purchaseApproved(source: "export", productID: "yearly")
        ])
        clearCache()
    }

    /// The usual case: the child asks, quits the app, and the parent approves in the evening.
    @Test("Reports an approval that arrives on a later launch, with the source it was asked from")
    func approvalSurvivesRelaunch() {
        let first = makeService()
        first.purchaseDidPend(source: "export", productID: "yearly")

        let second = PaywallService(configuration: config, texts: .preview)
        var received: [PaywallEvent] = []
        second.onEvent = { received.append($0) }
        second.handleSuccessfulPurchase(productID: "yearly", subscriptionGroupID: "TEST")
        #expect(received == [.purchaseApproved(source: "export", productID: "yearly")])

        // Once, not on every launch after.
        let third = PaywallService(configuration: config, texts: .preview)
        third.onEvent = { received.append($0) }
        third.handleSuccessfulPurchase(productID: "yearly", subscriptionGroupID: "TEST")
        #expect(received.count == 1)
        clearCache()
    }

    /// The paywall reports such a purchase as completed. An approval on top would count it twice.
    @Test("Reports no approval for a purchase that went through at once")
    func directPurchaseIsNoApproval() {
        let service = makeService()
        var received: [PaywallEvent] = []
        service.purchaseDidPend(source: "export", productID: "yearly")
        service.onEvent = { received.append($0) }
        service.handleSuccessfulPurchase(productID: "yearly", subscriptionGroupID: "TEST", isDirectPurchase: true)
        #expect(received.isEmpty)
        #expect(PaywallEntitlementCache().pendingPurchase == nil)
        clearCache()
    }

    /// Apple drops an unanswered request after a day. A purchase weeks later is no approval of it.
    @Test("Forgets a request Apple has dropped by now")
    func pendingPurchaseExpires() {
        clearCache()
        let old = PaywallPendingPurchase(source: "export", productID: "yearly", date: .now.addingTimeInterval(-PaywallPendingPurchase.lifetime - 1))
        PaywallEntitlementCache().write(pendingPurchase: old)
        let service = PaywallService(configuration: config, texts: .preview)
        var received: [PaywallEvent] = []
        service.onEvent = { received.append($0) }
        service.handleSuccessfulPurchase(productID: "yearly", subscriptionGroupID: "TEST")
        #expect(received.isEmpty)
        #expect(PaywallEntitlementCache().pendingPurchase == nil)
        clearCache()
    }

    @Test("Drops the pending action when the user asks for something else")
    func newRequestDropsPendingAction() {
        let service = makeService()
        var ran = false
        service.require(source: "export") { ran = true }
        service.purchaseDidPend(source: "export", productID: "yearly")
        service.dismissPaywall()
        service.paywallDidDismiss()
        service.present(source: "settings")
        service.dismissPaywall()
        service.paywallDidDismiss()
        service.handleSuccessfulPurchase(productID: "yearly", subscriptionGroupID: "TEST")
        #expect(!ran)
        clearCache()
    }

    // MARK: Lifetime next to a subscription

    private let renewingPlan = HeldPlan(state: .subscribed, productID: "yearly", expirationDate: nil, willAutoRenew: true)

    /// An Ask to Buy approval lands through `Transaction.updates` while the launch's first
    /// entitlement read is still running, long before the plan is known. Deciding against a plan
    /// that is still `nil` loses the alert for good, and with it the only route to the cancelling.
    @Test("Points out a renewing subscription when the approval lands before the plan is read")
    func overlapAfterAnApprovalAtLaunch() async {
        let service = makeService()
        service.purchaseDidPend(source: "export", productID: "lifetime")
        service.handleSuccessfulPurchase(productID: "lifetime", subscriptionGroupID: nil)
        #expect(!service.showsSubscriptionOverlap)

        await service.loadSubscriptionDetails { _ in self.renewingPlan }
        #expect(service.showsSubscriptionOverlap)
        clearCache()
    }

    /// The user would keep paying for both, and no app can cancel for them.
    @Test("Points out a renewing subscription once the paywall has closed on a lifetime purchase")
    func overlapAfterLifetimePurchase() {
        let service = makeService()
        service.handleSuccessfulPurchase(productID: "yearly", subscriptionGroupID: "TEST")
        service.heldPlan = renewingPlan
        service.present(source: "settings")
        service.handleSuccessfulPurchase(productID: "lifetime", subscriptionGroupID: nil)
        #expect(!service.showsSubscriptionOverlap)
        service.dismissPaywall()
        service.paywallDidDismiss()
        #expect(service.showsSubscriptionOverlap)
        clearCache()
    }

    /// `Transaction.updates` replays finished purchases at launch.
    @Test("Says nothing when a lifetime purchase is only replayed")
    func noOverlapOnReplay() {
        let service = makeService()
        service.heldPlan = renewingPlan
        service.handleSuccessfulPurchase(productID: "lifetime", subscriptionGroupID: nil)
        service.paywallDidDismiss()
        service.showsSubscriptionOverlap = false
        service.handleSuccessfulPurchase(productID: "lifetime", subscriptionGroupID: nil)
        service.paywallDidDismiss()
        #expect(!service.showsSubscriptionOverlap)
        clearCache()
    }

    /// Bought on another device, it arrives with nothing on screen. Armed, the alert would appear
    /// the next time the user closed the paywall, possibly days later and possibly after they
    /// cancelled the subscription themselves.
    @Test("Says nothing about a lifetime purchase this paywall did not make")
    func noOverlapForAPurchaseMadeElsewhere() {
        let service = makeService()
        service.heldPlan = renewingPlan
        // No paywall on screen, and nothing waiting for a parent.
        service.handleSuccessfulPurchase(productID: "lifetime", subscriptionGroupID: nil)
        #expect(!service.showsSubscriptionOverlap)
        service.present(source: "settings")
        service.dismissPaywall()
        service.paywallDidDismiss()
        #expect(!service.showsSubscriptionOverlap)
        clearCache()
    }

    @Test("Says nothing when the subscription already ends")
    func noOverlapWithoutRenewal() {
        let service = makeService()
        service.heldPlan = HeldPlan(state: .subscribed, productID: "yearly", expirationDate: nil, willAutoRenew: false)
        service.handleSuccessfulPurchase(productID: "lifetime", subscriptionGroupID: nil)
        service.paywallDidDismiss()
        #expect(!service.showsSubscriptionOverlap)
        clearCache()
    }

    // MARK: Presentation

    /// Asked for from inside a sheet without `.paywallSheet()`, the request would otherwise bring
    /// the paywall up once that sheet closes, out of nowhere.
    @Test("Gives up on a request no sheet picked up")
    func dropsUnshownRequest() async throws {
        let service = makeService()
        service.presentationTimeout = .milliseconds(20)
        // The root host is on screen; what covers it is a sheet without `.paywallSheet()`, which
        // is the case this gives up on.
        service.registerSheetHost(UUID())
        var ran = false
        service.require(source: "settings") { ran = true }
        try await Task.sleep(for: .milliseconds(200))
        #expect(service.presentedRequest == nil)
        service.handleSuccessfulPurchase(productID: "yearly", subscriptionGroupID: "TEST")
        service.paywallDidDismiss()
        #expect(!ran)
        clearCache()
    }

    /// A `present(source:)` from an App Intent or a notification can land before the first scene
    /// is on screen. A clock running against an empty app would drop it before anything could
    /// show it, and the user would be left with a button that did nothing.
    @Test("Holds a request made before any sheet host is on screen")
    func holdsARequestUntilAHostAppears() async throws {
        let service = makeService()
        service.presentationTimeout = .milliseconds(20)
        service.present(source: "intent")
        try await Task.sleep(for: .milliseconds(200))
        #expect(service.presentedRequest?.source == "intent")

        let root = UUID()
        service.registerSheetHost(root)
        #expect(service.presents(root))
        // The clock starts with the host: a request nothing picks up is still given up on.
        try await Task.sleep(for: .milliseconds(200))
        #expect(service.presentedRequest == nil)
    }

    @Test("Keeps a request whose sheet came up")
    func keepsShownRequest() async throws {
        let service = makeService()
        service.presentationTimeout = .milliseconds(20)
        service.registerSheetHost(UUID())
        service.present(source: "settings")
        service.paywallDidAppear(try #require(service.presentedRequest))
        try await Task.sleep(for: .milliseconds(200))
        #expect(service.presentedRequest?.source == "settings")
    }

    /// SwiftUI presents one sheet per view, so the paywall has to come from the sheet that is
    /// already up rather than from the root underneath it.
    @Test("Lets the innermost sheet host present")
    func innermostHostPresents() {
        let service = makeService()
        let root = UUID()
        let settingsSheet = UUID()
        service.registerSheetHost(root)
        #expect(service.presents(root))

        service.registerSheetHost(settingsSheet)
        #expect(service.presents(settingsSheet))
        #expect(!service.presents(root))

        service.unregisterSheetHost(settingsSheet)
        #expect(service.presents(root))
    }

    /// SwiftUI repeats an appearance without its disappearance when it rebuilds a view. Counted
    /// rather than named, a host would be registered twice and never fully removed, leaving the
    /// paywall silent for the rest of the session.
    @Test("Registers a sheet host once, however often it appears")
    func hostRegistrationIsIdempotent() {
        let service = makeService()
        let root = UUID()
        let sheet = UUID()
        service.registerSheetHost(root)
        service.registerSheetHost(sheet)
        service.registerSheetHost(sheet)

        service.unregisterSheetHost(sheet)
        #expect(service.presents(root))
    }

    /// An app that owns its service shares it between its windows. The window that opened last
    /// registered last, and without scenes it would take every paywall.
    @Test("Presents in the window that asked")
    func presentsInTheAskingScene() {
        let service = makeService()
        let (mainScene, settingsScene) = (UUID(), UUID())
        let (mainRoot, mainSheet, settingsRoot) = (UUID(), UUID(), UUID())
        service.registerSheetHost(mainRoot, sceneID: mainScene)
        service.registerSheetHost(settingsRoot, sceneID: settingsScene)

        service.sceneDidBecomeActive(mainScene)
        service.present(source: "export")
        #expect(service.presents(mainRoot))
        #expect(!service.presents(settingsRoot))

        // A sheet inside the asking window is its innermost host, wherever it sits in the order.
        service.registerSheetHost(mainSheet, sceneID: mainScene)
        service.registerSheetHost(UUID(), sceneID: settingsScene)
        #expect(service.presents(mainSheet))

        service.sceneDidBecomeActive(settingsScene)
        // The window coming forward moves nothing that is already up.
        #expect(service.presents(mainSheet))
        service.present(source: "settings")
        #expect(!service.presents(mainSheet))
    }

    @Test("Falls back to the innermost host when the asking window is gone")
    func presentsSomewhereWithoutTheScene() {
        let service = makeService()
        let root = UUID()
        service.registerSheetHost(root, sceneID: UUID())
        service.sceneDidBecomeActive(UUID())
        service.present(source: "test")
        #expect(service.presents(root))
    }

    /// The first check after launch may end after the user moved to another window.
    @Test("A held requirement presents in the window that asked")
    func heldRequirementKeepsItsScene() {
        let service = makeService(initialized: false)
        let (first, second) = (UUID(), UUID())
        let (firstRoot, secondRoot) = (UUID(), UUID())
        service.registerSheetHost(firstRoot, sceneID: first)
        service.registerSheetHost(secondRoot, sceneID: second)

        service.sceneDidBecomeActive(first)
        service.require(source: "test") {}
        service.sceneDidBecomeActive(second)
        _ = service.markInitialized()

        #expect(service.presentedRequest != nil)
        #expect(service.presents(firstRoot))
    }

    // MARK: Locked state

    @Test("Draws no lock while nothing is known, and one for a known free user")
    func isLocked() {
        let freshInstall = makeService(initialized: false)
        #expect(!freshInstall.isLocked)
        _ = freshInstall.markInitialized()
        #expect(freshInstall.isLocked)

        // A returning free user: the last launch left its answer behind.
        clearCache()
        PaywallEntitlementCache().write(.none)
        let returning = PaywallService(configuration: config, texts: .preview)
        #expect(returning.isLocked)

        clearCache()
        PaywallEntitlementCache().write(.subscription)
        let subscriber = PaywallService(configuration: config, texts: .preview)
        #expect(!subscriber.isLocked)
        clearCache()
    }

    // MARK: Cache

    // In this suite because it is serialized: these tests and the service share one defaults key.
    private let suiteName = "design.heuser.ButchKit.tests.paywallCache"

    private func clearGroup() {
        UserDefaults.standard.removeObject(forKey: PaywallEntitlementCache.key)
        UserDefaults.standard.removeObject(forKey: PaywallEntitlementCache.legacyKey)
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    /// `nil`, not `.none`: an extension must be able to tell "free" from "never asked".
    @Test("Knows nothing until something was written")
    func emptyIsUnknown() {
        clearGroup()
        #expect(PaywallEntitlementCache(appGroupID: suiteName).entitlement == nil)
        #expect(PaywallEntitlementCache().entitlement == nil)
    }

    @Test("Writes to the group and reads it back")
    func roundTrip() {
        clearGroup()
        let cache = PaywallEntitlementCache(appGroupID: suiteName)
        cache.write(.lifetime)
        #expect(cache.entitlement == .lifetime)
        #expect(UserDefaults.standard.string(forKey: PaywallEntitlementCache.key) == nil)
        clearGroup()
    }

    /// An app that comes from purchase code of its own kept its answer under a key of its own.
    @Test("Reads the app's own earlier key until ButchKit has an answer")
    func legacyCache() {
        clearGroup()
        let legacy = PaywallConfiguration.LegacyCache(key: "isPro", suiteName: suiteName)
        let cache = PaywallEntitlementCache(appGroupID: nil, legacy: legacy)
        #expect(cache.entitlement == nil)
        UserDefaults(suiteName: suiteName)?.set(true, forKey: "isPro")
        #expect(cache.entitlement == .subscription)
        cache.write(.none)
        #expect(cache.entitlement == PaywallEntitlement.none)
        clearGroup()
    }

    /// Seeded from the app's own key, the service would otherwise dedupe its first write away and
    /// never write ButchKit's key at all: the app could never drop `legacyCache`, and an extension
    /// reading the documented key by hand would find nothing forever.
    @Test("Writes its own key even when the answer it started from came from the app's")
    func writesThroughALegacyAnswer() async {
        clearGroup()
        clearCache()
        UserDefaults(suiteName: suiteName)?.set(true, forKey: "isPro")
        let service = PaywallService(
            configuration: PaywallConfiguration(
                subscriptionGroupID: "TEST",
                legacyCache: .init(key: "isPro", suiteName: suiteName)
            ),
            texts: .preview
        )
        #expect(service.entitlement == .subscription)
        #expect(UserDefaults.standard.string(forKey: PaywallEntitlementCache.key) == nil)

        // StoreKit confirms the very same answer.
        await service.refresh(currentEntitlements: entitlements(.subscription))
        #expect(UserDefaults.standard.string(forKey: PaywallEntitlementCache.key) == "subscription")
        clearGroup()
        clearCache()
    }

    /// An app that adopts a group in an update keeps what it cached before, so its subscribers
    /// see no paywall flash on the first launch after it.
    @Test("Falls back to the standard defaults until the group has an answer")
    func adoptsStandardCache() {
        clearGroup()
        PaywallEntitlementCache().write(.subscription)
        let cache = PaywallEntitlementCache(appGroupID: suiteName)
        #expect(cache.entitlement == .subscription)
        cache.write(.none)
        #expect(cache.entitlement == PaywallEntitlement.none)
        clearGroup()
    }

    /// A widget reads the cache only when it draws its timeline, so a flip has to ask for one.
    @Test("Reloads the widgets when the answer in the app group changes, and only then")
    func reloadsWidgets() async {
        clearGroup()
        let grouped = PaywallService(configuration: PaywallConfiguration(subscriptionGroupID: "TEST", appGroupID: suiteName), texts: .preview)
        var reloads = 0
        grouped.reloadWidgets = { reloads += 1 }

        await grouped.refresh { _ in PaywallEntitlementSnapshot(strongest: .subscription) }
        await grouped.refresh { _ in PaywallEntitlementSnapshot(strongest: .subscription) }
        #expect(reloads == 1)

        // Without a group no widget can read the cache.
        let plain = makeService()
        plain.reloadWidgets = { reloads += 1 }
        await plain.refresh { _ in PaywallEntitlementSnapshot(strongest: .subscription) }
        #expect(reloads == 1)
        clearGroup()
        clearCache()
    }

    // MARK: Restore

    /// Stands in for `Transaction.currentEntitlements` after the sync.
    private func entitlements(_ strongest: PaywallEntitlement, unverified: Bool = false) -> (PaywallConfiguration) async -> PaywallEntitlementSnapshot {
        { _ in PaywallEntitlementSnapshot(strongest: strongest, hasUnverified: unverified) }
    }

    @Test("Restores a lifetime purchase and unlocks the app")
    func restoreSucceeds() async {
        let service = makeService()
        let outcome = await service.restorePurchases(sync: {}, currentEntitlements: entitlements(.lifetime))
        #expect(outcome == .restored)
        #expect(service.entitlement == .lifetime)
        clearCache()
    }

    @Test("Finds nothing to restore when the App Store knows no purchase")
    func restoreFindsNothing() async {
        let service = makeService()
        let outcome = await service.restorePurchases(sync: {}, currentEntitlements: entitlements(.none))
        #expect(outcome == .nothingToRestore)
        #expect(service.entitlement == .none)
    }

    @Test("Fails when the sync throws")
    func restoreSyncFails() async {
        let service = makeService()
        let outcome = await service.restorePurchases(sync: { throw SomeError() }, currentEntitlements: entitlements(.none))
        #expect(outcome == .failed)
    }

    @Test("Fails and reports an unverified purchase")
    func restoreFindsUnverified() async {
        let service = makeService()
        var received: [PaywallEvent] = []
        service.onEvent = { received.append($0) }
        let outcome = await service.restorePurchases(sync: {}, currentEntitlements: entitlements(.none, unverified: true))
        #expect(outcome == .failed)
        #expect(service.entitlement == .none)
        #expect(received == [.verificationFailed])
    }

    @Test("Is cancelled when the user backs out of the sign-in")
    func restoreCancelled() async {
        let service = makeService()
        let outcome = await service.restorePurchases(sync: { throw StoreKitError.userCancelled }, currentEntitlements: entitlements(.none))
        #expect(outcome == .cancelled)
    }
}

@Suite("SubscriptionDetail")
struct SubscriptionDetailTests {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Renews when auto-renew is on")
    func renews() {
        #expect(SubscriptionDetail(state: .subscribed, willAutoRenew: true, expirationDate: date) == .renews(date))
    }

    @Test("Ends when auto-renew is off")
    func ends() {
        #expect(SubscriptionDetail(state: .subscribed, willAutoRenew: false, expirationDate: date) == .ends(date))
    }

    /// Grace period and billing retry read the same to the user: the payment needs attention,
    /// whichever date StoreKit reports.
    @Test("Reports a billing issue while the App Store retries", arguments: [
        Product.SubscriptionInfo.RenewalState.inGracePeriod,
        .inBillingRetryPeriod
    ])
    func billingIssue(state: Product.SubscriptionInfo.RenewalState) {
        #expect(SubscriptionDetail(state: state, willAutoRenew: true, expirationDate: date) == .billingIssue)
    }

    /// A renewal line without a date would promise something the row cannot back up.
    @Test("Says nothing for a subscription without a date")
    func noDate() {
        #expect(SubscriptionDetail(state: .subscribed, willAutoRenew: true, expirationDate: nil) == nil)
    }

    @Test("Says nothing once access is gone", arguments: [
        Product.SubscriptionInfo.RenewalState.expired,
        .revoked
    ])
    func noAccess(state: Product.SubscriptionInfo.RenewalState) {
        #expect(SubscriptionDetail(state: state, willAutoRenew: true, expirationDate: date) == nil)
    }
}

@Suite("PaywallStatus")
@MainActor
struct PaywallStatusTests {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)

    private func status(
        _ entitlement: PaywallEntitlement,
        renewing: Bool = true,
        planNames: [String: String] = [:],
        familyShared: Bool = false,
        isEntitlementKnown: Bool = true
    ) -> PaywallStatus {
        PaywallStatus(
            entitlement: entitlement,
            isEntitlementKnown: isEntitlementKnown,
            heldPlan: HeldPlan(state: .subscribed, productID: "yearly", expirationDate: date, willAutoRenew: renewing, isFamilyShared: familyShared),
            lifetimeProductID: "lifetime",
            lifetimeIsFamilyShared: familyShared,
            planNames: planNames,
            showPaywall: {},
            manageSubscription: {}
        )
    }

    @Test("Names the subscription for a subscriber and the lifetime product for an owner")
    func productID() {
        #expect(status(.subscription).productID == "yearly")
        #expect(status(.lifetime).productID == "lifetime")
        #expect(status(.none).productID == nil)
    }

    /// After a plan change the old name would name a plan the user no longer holds.
    @Test("Names only the product held")
    func staleName() {
        #expect(status(.subscription, planNames: ["yearly": "Yearly"]).planName == "Yearly")
        #expect(status(.subscription, planNames: ["monthly": "Monthly"]).planName == nil)
    }

    /// A family member's plan is not this user's to cancel, so neither a subscriber on one nor a
    /// lifetime owner beside one is sent to a management sheet that has nothing for them.
    @Test("Knows a shared plan, and offers no management of one")
    func familySharing() {
        #expect(status(.subscription, familyShared: true).isFamilyShared)
        #expect(!status(.subscription).isFamilyShared)
        #expect(status(.lifetime, familyShared: true).isFamilyShared)
        #expect(!status(.subscription, familyShared: true).canManageSubscription)
        #expect(status(.subscription).canManageSubscription)
        #expect(!status(.lifetime, familyShared: true).canManageSubscription)
    }

    @Test("Tells what happens next only for a subscription")
    func detail() {
        #expect(status(.subscription).detail == .renews(date))
        #expect(status(.lifetime).detail == nil)
        #expect(status(.none).detail == nil)
    }

    /// A subscriber who just reinstalled has nothing cached, and must not be offered a plan. A
    /// returning free user does have a cached answer, and must not be left on a spinner.
    @Test("Is loading only while nothing is cached and StoreKit has not answered")
    func loading() {
        #expect(status(.none, isEntitlementKnown: false).isLoading)
        #expect(!status(.none).isLoading)
        #expect(!status(.subscription, isEntitlementKnown: false).isLoading)
        // What makes it known, StoreKit or the last launch, is decided by
        // ``PaywallService/isEntitlementKnown`` and pinned by the `isLocked` test.
        #expect(!status(.none, isEntitlementKnown: true).isLoading)
    }

    @Test("Offers management to a lifetime owner only while a subscription still renews")
    func management() {
        #expect(status(.subscription, renewing: false).canManageSubscription)
        #expect(status(.lifetime, renewing: true).canManageSubscription)
        #expect(!status(.lifetime, renewing: false).canManageSubscription)
        #expect(!status(.none).canManageSubscription)
    }
}

@Suite("HeldPlan")
struct HeldPlanTests {
    private let earlier = Date(timeIntervalSince1970: 1_800_000_000)
    private let later = Date(timeIntervalSince1970: 1_900_000_000)

    private func plan(_ state: Product.SubscriptionInfo.RenewalState, _ productID: String, expiring date: Date?) -> HeldPlan {
        HeldPlan(state: state, productID: productID, expirationDate: date, willAutoRenew: true)
    }

    /// With Family Sharing, a paid-up plan is the one worth naming, even when a plan with a
    /// payment problem runs longer.
    @Test("Prefers a paid-up plan over one with a payment problem")
    func prefersSubscribed() {
        let paid = plan(.subscribed, "yearly", expiring: earlier)
        let unpaid = plan(.inGracePeriod, "monthly", expiring: later)
        #expect(HeldPlan.current(in: [unpaid, paid]) == paid)
    }

    @Test("Takes the plan that runs longest among equals")
    func prefersLongest() {
        let short = plan(.subscribed, "monthly", expiring: earlier)
        let long = plan(.subscribed, "yearly", expiring: later)
        #expect(HeldPlan.current(in: [long, short]) == long)
    }

    @Test("Ignores statuses that no longer grant access")
    func ignoresLapsed() {
        let plans = [plan(.expired, "monthly", expiring: later), plan(.revoked, "yearly", expiring: later)]
        #expect(HeldPlan.current(in: plans) == nil)
    }
}

@Suite("SubscriptionPhase")
struct SubscriptionPhaseTests {
    /// The four values feed a dashboard chart of active subscribers; renaming one silently splits
    /// its slice into an old and a new label, so the exact strings are pinned here.
    @Test("Maps trial and auto-renew to a stable value", arguments: [
        (isInTrial: true, willAutoRenew: true, expected: "trialRenewing"),
        (isInTrial: true, willAutoRenew: false, expected: "trialCanceled"),
        (isInTrial: false, willAutoRenew: true, expected: "paidRenewing"),
        (isInTrial: false, willAutoRenew: false, expected: "paidCanceled")
    ])
    func stableValues(testCase: (isInTrial: Bool, willAutoRenew: Bool, expected: String)) {
        #expect(SubscriptionPhase(isInTrial: testCase.isInTrial, willAutoRenew: testCase.willAutoRenew).rawValue == testCase.expected)
    }

    @Test("Reports a canceled trial for a subscribed plan with auto-renew off")
    func canceledTrial() {
        let plan = HeldPlan(state: .subscribed, productID: "yearly", expirationDate: nil, willAutoRenew: false, isInTrial: true)
        #expect(plan.phase == .trialCanceled)
    }

    @Test("Reports nothing while a payment problem is open", arguments: [
        Product.SubscriptionInfo.RenewalState.inGracePeriod,
        .inBillingRetryPeriod
    ])
    func paymentProblem(state: Product.SubscriptionInfo.RenewalState) {
        let plan = HeldPlan(state: state, productID: "yearly", expirationDate: nil, willAutoRenew: true)
        #expect(plan.phase == nil)
    }
}

@Suite("PaywallEvent")
struct PaywallEventTests {
    /// Apps forward these to their analytics as they are; a renamed signal or key splits a chart
    /// into an old and a new series, so the exact strings are pinned here.
    @Test("Names every event and its parameters with stable strings")
    func stableNames() {
        let events: [(PaywallEvent, String, [String: String])] = [
            (.presented(source: "s"), "paywall.presented", ["source": "s"]),
            (.purchaseStarted(source: "s", productID: "p"), "paywall.purchaseStarted", ["source": "s", "productID": "p"]),
            (.purchaseCompleted(source: "s", productID: "p", isIntroductoryOffer: true), "paywall.purchaseCompleted", ["source": "s", "productID": "p", "isIntroductoryOffer": "true"]),
            (.purchasePending(source: "s", productID: "p"), "paywall.purchasePending", ["source": "s", "productID": "p"]),
            (.purchaseApproved(source: "s", productID: "p"), "paywall.purchaseApproved", ["source": "s", "productID": "p"]),
            (.purchaseFailed(source: "s", productID: "p", reason: .network), "paywall.purchaseFailed", ["source": "s", "productID": "p", "reason": "network"]),
            (.verificationFailed, "paywall.verificationFailed", [:]),
            (.subscriptionStatus(phase: .trialCanceled, productID: "p"), "paywall.subscriptionStatus", ["phase": "trialCanceled", "productID": "p"])
        ]
        for (event, name, parameters) in events {
            #expect(event.name == name)
            #expect(event.parameters == parameters)
        }
    }

    @Test("Sorts a purchase error into its kind")
    func failureKinds() {
        #expect(PaywallPurchaseFailure(StoreKitError.networkError(URLError(.notConnectedToInternet))) == .network)
        #expect(PaywallPurchaseFailure(Product.PurchaseError.purchaseNotAllowed) == .purchaseNotAllowed)
        #expect(PaywallPurchaseFailure(Product.PurchaseError.invalidOfferIdentifier) == .invalidOffer)
        // Not an offer problem, so it is not charted as one.
        #expect(PaywallPurchaseFailure(Product.PurchaseError.invalidQuantity) == .unknown)
        #expect(PaywallPurchaseFailure(SomeError()) == .unknown)
    }
}
