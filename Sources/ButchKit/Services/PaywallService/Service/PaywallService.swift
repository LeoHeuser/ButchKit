//
//  PaywallService.swift
//  ButchKit
//
//  Created by Leo Heuser on 03.09.26.
//

/**

 # PaywallService
 The `PaywallService` owns one answer: does this user have an active subscription. It is an
 `@Observable` service fed by StoreKit 2, plus the state of the paywall sheet, so any view can gate
 a feature or show the paywall without owning a line of StoreKit.

 Integrate it once on the root view, with the app's configuration and marketing pages:
 ```swift
 RootView()
     .paywallEnvironment(paywallConfig, texts: paywallTexts, features: paywallFeatures)
 ```

 Then read it anywhere below like a native environment value:
 ```swift
 @Environment(PaywallService.self) private var paywall

 if paywall.hasSubscription { … }                        // gate a feature
 paywall.present(source: "settings")                      // show the paywall
 paywall.require(source: "newScript") { addScript() }     // run now, or right after the unlock
 ```

 ## What it does behind the scenes
 - `Transaction.currentEntitlements` decides `hasSubscription` at launch and on every `refresh()`.
 - `Transaction.updates` keeps it current for renewals, restores, Ask to Buy approvals and refunds.
 - The last answer is cached in `UserDefaults`, so a subscriber never sees the paywall flash while
   StoreKit is still answering after launch.
 - Verified transactions are finished; unverified ones are left alone, logged, and reported as
   ``PaywallEvent/verificationFailed``.

 With a network connection StoreKit's answer is definitive: no entitlement means no access.
 Offline, StoreKit 2 answers from its own local cache, so a genuine subscriber keeps access.

 ## Direct construction
 The root modifier creates the service for you. Tests, previews and code outside a view hierarchy
 construct one directly: `PaywallService(configuration: config, texts: texts)`, then call `initialize()` once to
 start following StoreKit.

 */

import Foundation
import OSLog
import StoreKit

@MainActor
@Observable
public final class PaywallService {

    // MARK: - Configuration

    public let configuration: PaywallConfiguration
    /// The marketing pages the paywall shows, in order.
    public let features: [PayWallFeature]
    /// Every word the paywall and the settings row show, supplied by the app.
    public let texts: PaywallTexts

    // MARK: - State

    /// Whether the user currently holds a subscription in the configured group.
    ///
    /// Starts from the cached value of the last launch, then follows StoreKit.
    public private(set) var hasSubscription: Bool

    /// `true` once the first `Transaction.currentEntitlements` check has completed after launch.
    /// Hold a launch gate on this if the first screen depends on the subscription.
    public private(set) var isInitialized = false

    /// The paywall presentation in flight, if any. The root sheet is bound to it.
    public private(set) var presentedRequest: PaywallRequest?

    /// Receives every ``PaywallEvent``. Assign once, typically in the root view, to forward the
    /// funnel to the app's analytics.
    public var onEvent: ((PaywallEvent) -> Void)?

    // MARK: - Private State

    private var actionAfterUnlock: (() -> Void)?
    private var updatesTask: Task<Void, Never>?
    /// Sheets below the root that carry their own paywall sheet, see `View.paywallSheet()`. While
    /// one is on screen it presents the paywall and the root sheet stays out of the way.
    var nestedSheetHosts = 0
    private let logger: Logger

    static let cacheKey = "design.heuser.ButchKit.paywall.hasSubscription"

    // MARK: - Initialization

    /// Creates a service. Cheap: nothing talks to StoreKit until ``initialize()``.
    ///
    /// - Parameters:
    ///   - configuration: The subscription group and policy URLs.
    ///   - texts: Every word the paywall and the settings row show.
    ///   - features: The marketing pages the paywall shows.
    ///   - subsystem: Where to log. Defaults to the app's own subsystem, see ``LoggerService``.
    public init(
        configuration: PaywallConfiguration,
        texts: PaywallTexts,
        features: [PayWallFeature] = [],
        subsystem: String? = nil
    ) {
        self.configuration = configuration
        self.texts = texts
        self.features = features
        self.logger = LoggerService(subsystem: subsystem)["Purchase"]
        // Restore the last known state so a subscriber sees no paywall flash while StoreKit
        // answers asynchronously after launch.
        self.hasSubscription = UserDefaults.standard.bool(forKey: Self.cacheKey)
    }

#if DEBUG
    /// A service with a fixed answer, for previews: StoreKit has nothing to say in a preview, so
    /// without this every preview shows a user who does not pay. It never talks to StoreKit and
    /// never writes the cache, so a preview of a subscriber leaves the next launch untouched.
    ///
    /// - Parameters:
    ///   - configuration: The subscription group, which the settings row still reads.
    ///   - texts: The app's own words, so the preview reads like the app.
    ///   - previewSubscribed: What ``hasSubscription`` answers.
    public convenience init(configuration: PaywallConfiguration, texts: PaywallTexts, previewSubscribed: Bool) {
        self.init(configuration: configuration, texts: texts)
        hasSubscription = previewSubscribed
        isInitialized = true
    }
#endif

    // SE-0371 isolated deinit: runs on the MainActor so it can reach the isolated task.
    isolated deinit {
        updatesTask?.cancel()
    }

    // MARK: - Entitlement

    /// Starts listening for transactions, runs the first entitlement check and marks the service
    /// initialized. Called once by the root modifier; call it yourself only when constructing the
    /// service directly. Further calls only refresh.
    public func initialize() async {
        listenForUpdates()
        await refresh()
        isInitialized = true
    }

    /// Re-reads the current entitlements. Call on foreground if a lapsed subscription should
    /// lock the app without waiting for `Transaction.updates`.
    public func refresh() async {
        var hasActive = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.subscriptionGroupID == configuration.subscriptionGroupID {
                hasActive = true
                break
            }
        }

        // Only a real active->inactive transition is worth a notice. A user who never
        // subscribed would otherwise log this on every launch.
        if !hasActive, hasSubscription {
            logger.notice("Subscription cleared: no active entitlement")
        }
        setSubscriptionActive(hasActive)
        logger.debug("Subscription status resolved: active=\(hasActive, privacy: .public)")
    }

    /// Marks the subscription active right after a verified purchase, ahead of
    /// `Transaction.currentEntitlements` catching up. The paywall calls this.
    public func handleSuccessfulPurchase() {
        setSubscriptionActive(true)
    }

    // MARK: - Presentation

    /// Shows the paywall.
    ///
    /// - Parameter source: The app's name for where the user hit the lock, carried on every
    ///   ``PaywallEvent`` for this presentation.
    public func present(source: String) {
        // A new request never inherits an action from an earlier one that was never shown.
        actionAfterUnlock = nil
        presentedRequest = PaywallRequest(source: source)
    }

    /// Runs `action` now if the user is subscribed. Otherwise shows the paywall and runs `action`
    /// once the purchase went through, so the user lands where they were going. Closing the
    /// paywall without subscribing drops the action.
    public func require(source: String, _ action: @escaping () -> Void) {
        guard !hasSubscription else {
            action()
            return
        }
        present(source: source)
        actionAfterUnlock = action
    }

    /// Closes the paywall.
    public func dismissPaywall() {
        presentedRequest = nil
    }

    /// Forwards an event to ``onEvent`` and logs the ones that are diagnostics.
    public func report(_ event: PaywallEvent) {
        switch event {
        case .purchasePending:
            logger.notice("Purchase pending: waiting for approval")
        case .purchaseFailed(_, let reason):
            logger.error("Purchase failed: reason=\(reason, privacy: .public)")
        case .verificationFailed:
            logger.error("Transaction verification failed")
        case .presented, .purchaseStarted, .purchaseCompleted:
            break
        }
        onEvent?(event)
    }

    /// Called by the sheet's `onDismiss`, whichever way the sheet went away. The request itself
    /// is already cleared by then, through `dismissPaywall()` or the sheet binding.
    func paywallDidDismiss() {
        let action = actionAfterUnlock
        actionAfterUnlock = nil
        guard hasSubscription else { return }
        action?()
    }

    // MARK: - Private

    /// Single write point for the subscription state: updates `hasSubscription` and the cache.
    private func setSubscriptionActive(_ active: Bool) {
        hasSubscription = active
        UserDefaults.standard.set(active, forKey: Self.cacheKey)
    }

    private func listenForUpdates() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard case .verified(let transaction) = result else {
                    // Unverified transactions are intentionally not finished (Apple's
                    // recommendation). Surfaced for diagnostics on verification issues.
                    report(.verificationFailed)
                    continue
                }
                await transaction.finish()
                processVerifiedTransaction(transaction)
            }
        }
    }

    private func processVerifiedTransaction(_ transaction: StoreKit.Transaction) {
        guard transaction.subscriptionGroupID == configuration.subscriptionGroupID else { return }
        if transaction.revocationDate != nil {
            logger.notice("Subscription revoked by App Store")
            setSubscriptionActive(false)
        } else {
            setSubscriptionActive(true)
        }
    }
}
