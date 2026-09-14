import Foundation
import StoreKit
import Testing
@testable import ButchKit

@Suite("PaywallConfiguration")
struct PaywallConfigurationTests {
    @Test("Leaves the policy URLs empty by default")
    func defaults() {
        let config = PaywallConfiguration(subscriptionGroupID: "1")
        #expect(config.privacyPolicyURL == nil)
        #expect(config.termsOfServiceURL == nil)
        #expect(!config.hasPolicies)
    }

    /// StoreKit shows the privacy and terms buttons as a pair, so one missing URL must hide both
    /// rather than leave a button that leads nowhere.
    @Test("Shows policies only when both URLs are set")
    func policiesNeedBothURLs() {
        #expect(!PaywallConfiguration(subscriptionGroupID: "1", privacyPolicyURL: "a.com").hasPolicies)
        #expect(!PaywallConfiguration(subscriptionGroupID: "1", termsOfServiceURL: "b.com").hasPolicies)
        #expect(PaywallConfiguration(subscriptionGroupID: "1", privacyPolicyURL: "a.com", termsOfServiceURL: "b.com").hasPolicies)
    }
}

@Suite("PaywallService", .serialized)
@MainActor
struct PaywallServiceTests {
    private let config = PaywallConfiguration(subscriptionGroupID: "TEST")

    /// The cache survives between test runs in the host's defaults; every test starts unsubscribed.
    private func makeService() -> PaywallService {
        UserDefaults.standard.removeObject(forKey: PaywallService.cacheKey)
        return PaywallService(configuration: config, texts: .preview)
    }

    @Test("Starts uninitialized with its configuration")
    func initialState() {
        let service = makeService()
        #expect(!service.isInitialized)
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
        service.handleSuccessfulPurchase()
        service.paywallDidDismiss()
        #expect(!ran)
    }

    @Test("Runs the deferred action once the purchase went through")
    func dismissAfterUnlockRunsAction() {
        let service = makeService()
        var ran = false
        service.require(source: "newScript") { ran = true }
        service.handleSuccessfulPurchase()
        service.paywallDidDismiss()
        #expect(ran)
    }

    @Test("Runs the action immediately when subscribed")
    func requireRunsImmediatelyWhenSubscribed() {
        let service = makeService()
        service.handleSuccessfulPurchase()
        var ran = false
        service.require(source: "newScript") { ran = true }
        #expect(ran)
        #expect(service.presentedRequest == nil)
    }

    @Test("Restores the cached subscription state on launch")
    func restoresCache() {
        let first = makeService()
        first.handleSuccessfulPurchase()
        let second = PaywallService(configuration: config, texts: .preview)
        #expect(second.hasSubscription)
        UserDefaults.standard.removeObject(forKey: PaywallService.cacheKey)
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
