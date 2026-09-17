//
//  PaywallService.swift
//  ButchKit
//
//  Created by Leo Heuser on 03.09.26.
//

/**

 # PaywallService
 The `PaywallService` owns one answer: does this user pay for the app. It is an `@Observable`
 service fed by StoreKit 2, plus the state of the paywall sheet, so any view can gate a feature or
 show the paywall without owning a line of StoreKit.

 Integrate it once on the root view, with the app's configuration and marketing pages:
 ```swift
 RootView()
     .paywallEnvironment(paywallConfig, texts: paywallTexts, features: paywallFeatures)
 ```

 Then read it anywhere below like a native environment value:
 ```swift
 @Environment(PaywallService.self) private var paywall

 if paywall.hasAccess { … }                              // gate a feature
 paywall.present(source: "settings")                      // show the paywall
 paywall.require(source: "newScript") { addScript() }     // run now, or right after the unlock
 ```

 ## What it does behind the scenes
 - `Transaction.currentEntitlements` decides ``entitlement`` at launch and on every `refresh()`:
   a subscription in the configured group, or one of the app's lifetime products if it sells any.
 - `Transaction.updates` keeps it current for renewals, restores, Ask to Buy approvals and refunds.
 - The last answer is cached in `UserDefaults`, so a paying user never sees the paywall flash while
   StoreKit is still answering after launch.
 - Verified transactions are finished; unverified ones are left alone, logged, and reported as
   ``PaywallEvent/verificationFailed``.
 - The restore button at the top of the paywall runs `AppStore.sync()`, reads the entitlements
   afresh for subscriptions and lifetime products alike, and the paywall shows one of three
   alerts; the sheet stays open until it is read.

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

    /// What the user holds: a subscription in the configured group, the lifetime product, or
    /// nothing. Starts from the cached value of the last launch, then follows StoreKit.
    public private(set) var entitlement: PaywallEntitlement

    /// Whether the user pays for the app, by subscription or by the lifetime product. The one
    /// answer every gate reads; ``entitlement`` says which of the two it is.
    public var hasAccess: Bool { entitlement != .none }

    /// The name ``hasAccess`` had before lifetime products, when paying meant subscribing.
    @available(*, deprecated, renamed: "hasAccess")
    public var hasSubscription: Bool { hasAccess }

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

    static let cacheKey = "design.heuser.ButchKit.paywall.entitlement"
    /// The cache before the lifetime product, one Bool. Read once so a subscriber updating the
    /// app sees no paywall flash; the first write goes to ``cacheKey`` and this key is left behind.
    static let legacyCacheKey = "design.heuser.ButchKit.paywall.hasSubscription"

    // MARK: - Initialization

    /// Creates a service. Cheap: nothing talks to StoreKit until ``initialize()``.
    ///
    /// - Parameters:
    ///   - configuration: The subscription group, the optional lifetime products and the policy URLs.
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
        // Restore the last known state so a paying user sees no paywall flash while StoreKit
        // answers asynchronously after launch.
        let defaults = UserDefaults.standard
        if let cached = defaults.string(forKey: Self.cacheKey).flatMap(PaywallEntitlement.init(rawValue:)) {
            self.entitlement = cached
        } else {
            self.entitlement = defaults.bool(forKey: Self.legacyCacheKey) ? .subscription : .none
        }
    }

#if DEBUG
    /// A service with a fixed answer, for previews: StoreKit has nothing to say in a preview, so
    /// without this every preview shows a user who does not pay. It never talks to StoreKit and
    /// never writes the cache, so a preview of a subscriber leaves the next launch untouched.
    ///
    /// - Parameters:
    ///   - configuration: The subscription group, which the settings row still reads.
    ///   - texts: The app's own words, so the preview reads like the app.
    ///   - previewEntitlement: What ``entitlement`` answers.
    public convenience init(configuration: PaywallConfiguration, texts: PaywallTexts, previewEntitlement: PaywallEntitlement) {
        self.init(configuration: configuration, texts: texts)
        entitlement = previewEntitlement
        isInitialized = true
    }

    /// The same, for previews that only care whether the user pays.
    public convenience init(configuration: PaywallConfiguration, texts: PaywallTexts, previewSubscribed: Bool) {
        self.init(configuration: configuration, texts: texts, previewEntitlement: previewSubscribed ? .subscription : .none)
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
        applyEntitlement(await PaywallEntitlementSnapshot.current(under: configuration).strongest)
    }

    /// Marks the purchase active right after it was verified, ahead of
    /// `Transaction.currentEntitlements` catching up. The paywall calls this.
    ///
    /// Decided by the same rule as ``refresh()`` and the updates listener, so a purchase can
    /// never unlock differently from the transaction StoreKit lists for it later.
    ///
    /// - Parameters:
    ///   - productID: The product bought.
    ///   - subscriptionGroupID: The product's subscription group, `nil` for a lifetime product.
    public func handleSuccessfulPurchase(productID: String, subscriptionGroupID: String?) {
        let granted = configuration.entitlement(productID: productID, subscriptionGroupID: subscriptionGroupID)
        setEntitlement(max(entitlement, granted))
    }

    // MARK: - Restore

    /// Brings back earlier purchases from the App Store, subscriptions and lifetime products alike,
    /// for the restore button at the top of the paywall. The paywall shows the outcome.
    ///
    /// `AppStore.sync()` returns nothing, and a purchase that was already finished does not come
    /// back through `Transaction.updates`, so the entitlements are read afresh afterwards.
    ///
    /// - Parameters:
    ///   - sync: Asks the App Store for the account's transactions. Replaced in tests.
    ///   - currentEntitlements: Reads the entitlements after the sync. Replaced in tests.
    /// - Returns: How the restore ended.
    func restorePurchases(
        sync: () async throws -> Void = { try await AppStore.sync() },
        currentEntitlements: (PaywallConfiguration) async -> PaywallEntitlementSnapshot = PaywallEntitlementSnapshot.current(under:)
    ) async -> PaywallRestoreOutcome {
        var syncError: (any Error)?
        do {
            try await sync()
        } catch {
            syncError = error
        }
        let snapshot = await currentEntitlements(configuration)
        applyEntitlement(snapshot.strongest)

        let outcome = PaywallRestoreOutcome.decide(syncError: syncError, snapshot: snapshot)
        logRestore(outcome, syncError: syncError, entitlement: snapshot.strongest)
        return outcome
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

    /// Runs `action` now if the user pays. Otherwise shows the paywall and runs `action`
    /// once the purchase went through, so the user lands where they were going. Closing the
    /// paywall without buying drops the action.
    public func require(source: String, _ action: @escaping () -> Void) {
        guard !hasAccess else {
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
        guard hasAccess else { return }
        action?()
    }

    // MARK: - Private

    /// Takes an entitlement freshly read from StoreKit: notes a real loss of access and stores it.
    private func applyEntitlement(_ resolved: PaywallEntitlement) {
        // Only a real active->inactive transition is worth a notice. A user who never
        // paid would otherwise log this on every launch.
        if resolved == .none, hasAccess {
            logger.notice("Entitlement cleared: no active entitlement")
        }
        setEntitlement(resolved)
        logger.debug("Entitlement resolved: \(resolved.rawValue, privacy: .public)")
    }

    /// One line per restore, so a report of "I tapped restore and nothing happened" can be read
    /// from the log.
    private func logRestore(_ outcome: PaywallRestoreOutcome, syncError: (any Error)?, entitlement: PaywallEntitlement) {
        switch outcome {
        case .restored:
            logger.notice("Restore finished: outcome=restored entitlement=\(entitlement.rawValue, privacy: .public)")
        case .nothingToRestore:
            logger.notice("Restore finished: outcome=nothingToRestore")
        case .cancelled:
            logger.notice("Restore finished: outcome=cancelled")
        case .failed:
            if let syncError {
                logger.error("Restore failed: reason=sync \(syncError.logCode, privacy: .public)")
            } else {
                logger.error("Restore failed: reason=unverified")
                report(.verificationFailed)
            }
        }
    }

    /// Single write point for the entitlement: updates the state and the cache.
    private func setEntitlement(_ entitlement: PaywallEntitlement) {
        self.entitlement = entitlement
        UserDefaults.standard.set(entitlement.rawValue, forKey: Self.cacheKey)
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
                await processVerifiedTransaction(transaction)
            }
        }
    }

    private func processVerifiedTransaction(_ transaction: StoreKit.Transaction) async {
        let granted = configuration.entitlement(
            productID: transaction.productID,
            subscriptionGroupID: transaction.subscriptionGroupID
        )
        guard granted != .none else { return }
        if transaction.revocationDate != nil {
            // A refund of one product says nothing about the other: a revoked lifetime purchase
            // leaves a running subscription in place. So the truth is re-read, not cleared.
            logger.notice("Entitlement revoked by App Store: \(granted.rawValue, privacy: .public)")
            await refresh()
        } else {
            handleSuccessfulPurchase(productID: transaction.productID, subscriptionGroupID: transaction.subscriptionGroupID)
        }
    }
}
