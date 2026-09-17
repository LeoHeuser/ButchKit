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
        #expect(PaywallRestoreOutcome.decide(syncError: offline, snapshot: nothing) == .failed)
        #expect(PaywallRestoreOutcome.decide(syncError: SomeError(), snapshot: nothing) == .failed)
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
    private func makeService() -> PaywallService {
        clearCache()
        return PaywallService(configuration: config, texts: .preview)
    }

    private func clearCache() {
        UserDefaults.standard.removeObject(forKey: PaywallService.cacheKey)
        UserDefaults.standard.removeObject(forKey: PaywallService.legacyCacheKey)
    }

    @Test("Starts uninitialized with its configuration")
    func initialState() {
        let service = makeService()
        #expect(!service.isInitialized)
        #expect(service.entitlement == .none)
        #expect(!service.hasAccess)
        #expect(service.configuration == config)
        #expect(service.features.isEmpty)
        #expect(service.presentedRequest == nil)
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
        service.require(source: "newScript") { ran = true }
        #expect(!ran)
        #expect(service.presentedRequest?.source == "newScript")
    }

    /// Closing the paywall without buying must not run the gated action later by accident.
    @Test("Drops the deferred action when dismissed without a subscription")
    func dismissWithoutUnlockDropsAction() {
        let service = makeService()
        var ran = false
        service.require(source: "newScript") { ran = true }
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
        service.require(source: "newScript") { ran = true }
        service.present(source: "settings")
        service.handleSuccessfulPurchase(productID: "yearly", subscriptionGroupID: "TEST")
        service.paywallDidDismiss()
        #expect(!ran)
    }

    @Test("Runs the deferred action once the purchase went through")
    func dismissAfterUnlockRunsAction() {
        let service = makeService()
        var ran = false
        service.require(source: "newScript") { ran = true }
        service.handleSuccessfulPurchase(productID: "yearly", subscriptionGroupID: "TEST")
        service.paywallDidDismiss()
        #expect(ran)
    }

    @Test("Runs the action immediately when subscribed")
    func requireRunsImmediatelyWhenSubscribed() {
        let service = makeService()
        service.handleSuccessfulPurchase(productID: "yearly", subscriptionGroupID: "TEST")
        var ran = false
        service.require(source: "newScript") { ran = true }
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
        UserDefaults.standard.set(true, forKey: PaywallService.legacyCacheKey)
        let service = PaywallService(configuration: config, texts: .preview)
        #expect(service.entitlement == .subscription)
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
