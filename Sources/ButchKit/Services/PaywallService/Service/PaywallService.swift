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

 Or own it: an app with several windows, or with code outside a view that needs the answer, builds
 the service itself, keeps it in its `App` and hands it to the same modifier:
 ```swift
 @State private var paywall = PaywallService(configuration: paywallConfig, texts: paywallTexts)

 RootView()
     .paywallEnvironment(paywall)
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
   `Product.SubscriptionInfo.Status.updates` covers what produces no transaction, a subscription
   running out while the app is open, and the root modifier reads again on every foreground.
 - The last verified answer is cached in `UserDefaults`, in the app group if the configuration
   names one, so a paying user never sees the paywall flash while StoreKit is still answering
   after launch. Until it has answered, ``entitlement`` is that cached answer and
   ``verifiedEntitlement`` is `nil`: draw from the first, decide anything lasting on the second.
 - Verified transactions are finished; unverified ones are left alone, logged, and reported as
   ``PaywallEvent/verificationFailed``.
 - The restore button at the top of the paywall runs `AppStore.sync()`, reads the entitlements
   afresh for subscriptions and lifetime products alike, and the paywall shows one of three
   alerts; the sheet stays open until it is read. ``restorePurchases()`` does the same for a
   row in the app's settings, which words the outcome itself.

 With a network connection StoreKit's answer is definitive: no entitlement means no access.
 Offline, StoreKit 2 answers from its own local cache, so a genuine subscriber keeps access.

 ## Direct construction
 `PaywallService(configuration: config, texts: texts)`. Handed to
 `View.paywallEnvironment(_:)`, the modifier starts it. Without a view, call `initialize()` once
 to start following StoreKit.

 */

import Foundation
import OSLog
import StoreKit
import WidgetKit

@MainActor
@Observable
public final class PaywallService {

    // MARK: - Configuration

    public let configuration: PaywallConfiguration
    /// The marketing pages the paywall shows, in order.
    public let features: [PaywallFeature]
    /// Every word the paywall and the settings row show, supplied by the app.
    public let texts: PaywallTexts

    // MARK: - State

    /// What the user holds: a subscription in the configured group, the lifetime product, or
    /// nothing. Starts from the cached value of the last launch, then follows StoreKit. Until
    /// ``isInitialized`` it is that cached value, which is what the interface should draw from
    /// and nothing else should rely on; see ``verifiedEntitlement``.
    public private(set) var entitlement: PaywallEntitlement

    /// Whether the user pays for the app, by subscription or by the lifetime product. The one
    /// answer every view reads; ``entitlement`` says which of the two it is.
    public var hasAccess: Bool { entitlement != .none }

    /// ``entitlement`` once StoreKit has answered, `nil` until then. `nil` means not known yet,
    /// never "does not pay". Read this rather than ``entitlement`` for anything that outlasts the
    /// screen: a value written for an extension, sent to a server or reported to analytics, and
    /// any unlock that cannot be taken back. The cache behind ``entitlement`` is a plain
    /// `UserDefaults` value the user can edit, there to stop a flash and not to be trusted.
    public var verifiedEntitlement: PaywallEntitlement? { isInitialized ? entitlement : nil }

    /// ``hasAccess`` once StoreKit has answered, `false` until then.
    public var hasVerifiedAccess: Bool { isInitialized && hasAccess }

    /// Whether to draw the locked state: lock badges, banners, read-only content. `true` once it is
    /// known that the user does not pay, from StoreKit or from the answer the last launch left
    /// behind. `false` for a paying user, and while nothing is known at all, the first moment after
    /// an install, so a subscriber who just reinstalled never sees a lock flash by. For looks only:
    /// gate actions on ``hasAccess`` or ``require(source:_:)``.
    ///
    /// The other side of ``PaywallStatus/isLoading``, which draws the spinner for that same first
    /// moment. Both rest on `isInitialized || hasCachedEntitlement`: change what counts as known
    /// and they have to move together.
    public var isLocked: Bool { !hasAccess && (isInitialized || hasCachedEntitlement) }

    /// `true` once the first `Transaction.currentEntitlements` check has completed after launch.
    /// Hold a launch gate on this if the first screen depends on the subscription.
    public private(set) var isInitialized = false

    /// The paywall presentation in flight, if any. The root sheet is bound to it.
    public private(set) var presentedRequest: PaywallRequest?

    /// Whether the user can still get the group's introductory offer, the free trial usually.
    /// `nil` until the App Store has said, for an app without a group, and for a user who already
    /// pays. A page marked ``PaywallFeature/introOfferOnly`` shows only while this is `true`, so
    /// the paywall never promises a free month to someone who has had it. Read it for the same
    /// reason wherever the app words the offer itself.
    public private(set) var isEligibleForIntroOffer: Bool?

    /// Receives every ``PaywallEvent``. Assign once, typically in the root view, to forward the
    /// funnel to the app's analytics.
    public var onEvent: ((PaywallEvent) -> Void)?

    // MARK: - Internal State

    /// The plan the user holds in the group, `nil` without one. Kept here rather than in the
    /// settings row, so the row has it the moment it appears instead of loading it on every visit,
    /// and the launch report needs no query of its own.
    var heldPlan: HeldPlan?
    /// The lifetime product the entitlement rests on, and whether it is a family member's.
    private(set) var lifetimeProductID: String?
    private(set) var lifetimeIsFamilyShared = false
    /// Product names as App Store Connect spells them, by product, see ``loadPlanName(for:)``.
    private(set) var planNames: [String: String] = [:]
    /// Set once a lifetime purchase left a subscription renewing next to it and the paywall has
    /// closed. The sheet host shows ``PaywallTexts/SubscriptionOverlap`` on it.
    var showsSubscriptionOverlap = false

    // MARK: - Private State

    private var actionAfterUnlock: (() -> Void)?
    /// An Ask to Buy purchase waiting for a parent, and what the user was on the way to when they
    /// asked. The paywall is long closed when the approval comes, see ``handleSuccessfulPurchase(productID:subscriptionGroupID:)``.
    @ObservationIgnored private var pendingPurchase: PaywallPendingPurchase? {
        didSet { cache.write(pendingPurchase: pendingPurchase) }
    }
    /// A lifetime purchase went through next to a renewing subscription, see ``showsSubscriptionOverlap``.
    private var subscriptionOverlapIsDue = false
    /// A `require` that arrived before StoreKit had answered, decided by ``markInitialized()``.
    private var heldRequirement: (source: String, sceneID: UUID?, action: () -> Void)?
    private var updatesTask: Task<Void, Never>?
    private var statusUpdatesTask: Task<Void, Never>?
    /// The last refresh started. Each one runs behind the one before, see ``refresh()``.
    private var refreshTask: Task<Void, Never>?
    /// When the last purchase was granted, see ``purchaseGracePeriod``.
    private var lastPurchase: ContinuousClock.Instant?
    /// How long after a purchase a refresh may not take the access away again. StoreKit lists a
    /// fresh transaction a moment late, right when the app returns from the payment sheet and
    /// reads on foreground. Changed in tests.
    var purchaseGracePeriod: Duration = .seconds(10)
    /// The request whose sheet came up, see ``present(source:)``.
    private var shownRequestID: PaywallRequest.ID?
    /// How long a request may wait for its sheet. Generous: giving up on a sheet that is only
    /// slow would close a paywall the user was about to see, and a `present(source:)` from an App
    /// Intent or a notification can land before the scene is on screen. Changed in tests.
    var presentationTimeout: Duration = .seconds(5)
    /// The sheet hosts on screen, the innermost last, each with the scene it belongs to. The root
    /// modifier registers one and every `View.paywallSheet()` another, see ``presents(_:)``.
    private var sheetHosts: [(id: UUID, sceneID: UUID?)] = []
    /// The scene whose window the user is in, see ``sceneDidBecomeActive(_:)``. Not observed: it
    /// only stamps the next request, and a window coming forward must not re-render every host.
    @ObservationIgnored private var activeSceneID: UUID?
    /// The scene of the last request. Outlives the request, so the alert after the paywall comes
    /// up in the same window.
    private var presentationSceneID: UUID?
    /// Tells the widgets to read the cache again. Replaced in tests.
    @ObservationIgnored var reloadWidgets: () -> Void = { WidgetCenter.shared.reloadAllTimelines() }
    /// The last value handed to the cache, so an unchanged answer is not written again, see
    /// ``setEntitlement(_:)``. Starts as what the launch found, `nil` when it found nothing.
    private var lastWrittenEntitlement: PaywallEntitlement?
    /// Whether a previous launch left an answer behind. Apart from ``isInitialized`` because a
    /// returning free user has an answer, and must be offered the subscription rather than a
    /// spinner, see ``PaywallStatus/isLoading``.
    let hasCachedEntitlement: Bool
    let logger: Logger
    private let cache: PaywallEntitlementCache

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
        features: [PaywallFeature] = [],
        subsystem: String? = nil
    ) {
        self.configuration = configuration
        self.texts = texts
        self.features = features
        let logger = LoggerService(subsystem: subsystem)["Purchase"]
        self.logger = logger
        let cache = PaywallEntitlementCache(appGroupID: configuration.appGroupID, legacy: configuration.legacyCache)
        self.cache = cache
        let cached = cache.entitlement
        self.hasCachedEntitlement = cached != nil
        // Only what ButchKit itself wrote, never a fallback: an answer read from the standard
        // defaults or from the app's own key must still reach this store once StoreKit confirms
        // it, or the migration never finishes and an extension keeps finding nothing.
        self.lastWrittenEntitlement = cache.ownEntitlement
        // Restore the last known state so a paying user sees no paywall flash while StoreKit
        // answers asynchronously after launch.
        self.entitlement = cached ?? .none
        // Whoever asked a parent on an earlier launch is still waiting. A request Apple has
        // dropped by now is not kept: see ``PaywallPendingPurchase/lifetime``.
        if let pending = cache.pendingPurchase {
            if pending.isCurrent(at: .now) {
                self.pendingPurchase = pending
            } else {
                cache.write(pendingPurchase: nil)
            }
        }
        // The configuration's own assert is gone in a release build, where this would otherwise
        // be an empty sheet and nothing else.
        if configuration.subscriptionGroupID == nil, configuration.lifetimeProductIDs.isEmpty {
            logger.fault("Paywall configuration sells nothing: no subscription group and no lifetime products")
        }
        if configuration.subscriptionGroupID != nil, !configuration.lifetimeProductIDs.isEmpty, texts.offerTabs == nil {
            logger.fault("Paywall segments have no titles: PaywallTexts.offerTabs is missing")
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
        // What a refresh would have found, so the settings row names a product.
        lifetimeProductID = previewEntitlement == .lifetime ? configuration.lifetimeProductIDs.first : nil
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
        statusUpdatesTask?.cancel()
    }

    // MARK: - Entitlement

    /// Starts listening to StoreKit, runs the first entitlement check and marks the service
    /// initialized. Called by the root modifier; call it yourself only without one. Further calls
    /// do nothing, so every scene of an app that owns its service may run it.
    public func initialize() async {
        guard !isInitialized else { return }
        listenForUpdates()
        listenForStatusUpdates()
        // The entitlement read alone, which is local. The public `refresh()` would ask the App
        // Store as well, and the gate below must not wait on a network answer.
        await refresh(currentEntitlements: PaywallEntitlementSnapshot.current(under:))
        guard markInitialized() else { return }
        // After isInitialized, so a slow App Store answer never holds up a launch gate.
        await loadSubscriptionDetails()
        await reportSubscriptionPhase()
    }

    /// Re-reads the current entitlements. The root modifier does this on every foreground, see
    /// ``PaywallConfiguration/refreshesOnForeground``.
    ///
    /// Safe to call from a task that may be cancelled, and from several places at once: each read
    /// runs to its end, one behind the other.
    public func refresh() async {
        await refresh(currentEntitlements: PaywallEntitlementSnapshot.current(under:))
        await loadSubscriptionDetails()
    }

    /// - Parameter currentEntitlements: Reads the entitlements. Replaced in tests.
    func refresh(currentEntitlements: @escaping (PaywallConfiguration) async -> PaywallEntitlementSnapshot) async {
        let previous = refreshTask
        // A task of its own, because a cancelled read ends early and would report a paying user as
        // holding nothing. Behind the one before rather than alongside, so the answer read last
        // is the one that stands, and never joined to it, so a refresh after a refund reads again.
        let task = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            applyEntitlement(await currentEntitlements(configuration))
        }
        refreshTask = task
        await task.value
        // Nothing queued behind it, so the chain starts empty again rather than holding the last
        // task, and through it every task that waited on one, for the life of the service.
        if refreshTask == task { refreshTask = nil }
    }

    /// Closes the first entitlement check. `false` when another scene's call got there first.
    func markInitialized() -> Bool {
        guard !isInitialized else { return false }
        isInitialized = true
        if let held = heldRequirement {
            heldRequirement = nil
            // In the window that asked, not whichever is in front by now: the first check can end
            // after the user has moved on.
            require(source: held.source, sceneID: held.sceneID, held.action)
        }
        return true
    }

    /// Marks the purchase active right after it was verified, ahead of
    /// `Transaction.currentEntitlements` catching up. The paywall and the updates listener call
    /// this, both with a verified transaction in hand.
    ///
    /// Decided by the same rule as ``refresh()`` and the updates listener, so a purchase can
    /// never unlock differently from the transaction StoreKit lists for it later.
    ///
    /// - Parameters:
    ///   - productID: The product bought.
    ///   - subscriptionGroupID: The product's subscription group, `nil` for a lifetime product.
    ///   - isDirectPurchase: `true` from the paywall's own completion handler: the purchase went
    ///     through at once, so whatever was pending for the product was not what unlocked it.
    func handleSuccessfulPurchase(productID: String, subscriptionGroupID: String?, isDirectPurchase: Bool = false) {
        let granted = configuration.entitlement(productID: productID, subscriptionGroupID: subscriptionGroupID)
        guard granted != .none else { return }
        lastPurchase = .now
        // Only a purchase that lifts the user to lifetime: `Transaction.updates` replays finished
        // purchases at launch, and an owner must not be asked about their subscription every time.
        if granted == .lifetime, entitlement < .lifetime {
            lifetimeProductID = productID
            // Only a purchase this paywall made: from the sheet on screen, or the approval of what
            // it asked for. One bought on another device arrives through `Transaction.updates` with
            // nothing on screen, and would otherwise leave the alert armed to appear out of nowhere.
            let isOurs = presentedRequest != nil || pendingPurchase?.productID == productID
            subscriptionOverlapIsDue = isOurs && heldPlan?.willAutoRenew == true && texts.subscriptionOverlap != nil
        }
        setEntitlement(max(entitlement, granted))
        if isDirectPurchase {
            // Reported as completed by the paywall. Reporting an approval too would count it twice.
            if pendingPurchase?.productID == productID { pendingPurchase = nil }
        } else {
            resolvePendingPurchase(productID: productID)
        }
    }

    /// Ask to Buy: the purchase waits for a parent. Apple's own sheet tells the user; the paywall
    /// stays as it is. What the user was on the way to is kept past the paywall's closing.
    func purchaseDidPend(source: String, productID: String) {
        pendingPurchase = PaywallPendingPurchase(source: source, productID: productID, date: .now)
        report(.purchasePending(source: source, productID: productID))
    }

    /// The approval of an Ask to Buy purchase, which arrives through `Transaction.updates`, often
    /// long after the paywall closed and usually after the app was quit. Reported so the funnel
    /// can close, on whichever launch it arrives. The user is taken where they were going when
    /// they asked only if the app is still running: an action does not survive a launch.
    private func resolvePendingPurchase(productID: String) {
        guard let pending = pendingPurchase, pending.productID == productID else { return }
        pendingPurchase = nil
        guard pending.isCurrent(at: .now) else { return }
        report(.purchaseApproved(source: pending.source, productID: productID))
        // With the paywall still open, closing it runs the action, see ``paywallDidDismiss()``.
        guard presentedRequest == nil else { return }
        runActionAfterUnlock()
    }

    // MARK: - Restore

    /// Brings back earlier purchases from the App Store, subscriptions and lifetime products alike.
    /// The paywall's own restore button runs this and shows the outcome. A "Restore Purchases" row
    /// in the app's settings runs it too, and words the outcome itself: nothing for
    /// ``PaywallRestoreOutcome/cancelled``, an alert for the rest. It asks for the App Store
    /// sign-in, so only ever call it from a button.
    ///
    /// - Returns: How the restore ended.
    public func restorePurchases() async -> PaywallRestoreOutcome {
        await restorePurchases(sync: { try await AppStore.sync() }, currentEntitlements: PaywallEntitlementSnapshot.current(under:))
    }

    /// `AppStore.sync()` returns nothing, and a purchase that was already finished does not come
    /// back through `Transaction.updates`, so the entitlements are read afresh afterwards.
    ///
    /// - Parameters:
    ///   - sync: Asks the App Store for the account's transactions. Replaced in tests.
    ///   - currentEntitlements: Reads the entitlements after the sync. Replaced in tests.
    func restorePurchases(
        sync: () async throws -> Void,
        currentEntitlements: (PaywallConfiguration) async -> PaywallEntitlementSnapshot
    ) async -> PaywallRestoreOutcome {
        var syncError: (any Error)?
        do {
            try await sync()
        } catch {
            syncError = error
        }
        let snapshot = await currentEntitlements(configuration)
        applyEntitlement(snapshot)

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
        present(source: source, sceneID: activeSceneID)
    }

    /// - Parameter sceneID: The scene that asked, the window the paywall comes up in.
    private func present(source: String, sceneID: UUID?) {
        // A new request never inherits an action from an earlier one that was never shown.
        actionAfterUnlock = nil
        heldRequirement = nil
        let request = PaywallRequest(source: source)
        presentationSceneID = sceneID
        presentedRequest = request
        watchPresentation(of: request)
    }

    /// Runs `action` now if the user pays. Otherwise shows the paywall and runs `action`
    /// once the purchase went through, so the user lands where they were going. Closing the
    /// paywall without buying drops the action.
    ///
    /// Before StoreKit has answered for the first time, the decision waits for that answer: a
    /// cached value someone edited opens nothing, and a subscriber on a fresh install is not shown
    /// a paywall. That wait is the first moment after launch and ends with ``isInitialized``.
    public func require(source: String, _ action: @escaping () -> Void) {
        require(source: source, sceneID: activeSceneID, action)
    }

    private func require(source: String, sceneID: UUID?, _ action: @escaping () -> Void) {
        guard isInitialized else {
            heldRequirement = (source, sceneID, action)
            return
        }
        guard !hasAccess else {
            action()
            return
        }
        present(source: source, sceneID: sceneID)
        actionAfterUnlock = action
    }

    /// Closes the paywall.
    public func dismissPaywall() {
        presentedRequest = nil
    }

    /// Notes a sheet host that came on screen, see `View.paywallSheet()`. By identity rather than
    /// by a count: SwiftUI repeats an appearance without its disappearance when it rebuilds a view,
    /// and a host counted twice would leave the paywall silent for the rest of the session.
    func registerSheetHost(_ hostID: UUID, sceneID: UUID? = nil) {
        guard !sheetHosts.contains(where: { $0.id == hostID }) else { return }
        sheetHosts.append((hostID, sceneID))
    }

    func unregisterSheetHost(_ hostID: UUID) {
        sheetHosts.removeAll { $0.id == hostID }
    }

    /// Notes the scene whose window became key: the one the user is in, and so the one the next
    /// `present` comes from. An app that owns its service shares it between its windows, and
    /// without this the paywall would come up in whichever window opened last.
    func sceneDidBecomeActive(_ sceneID: UUID?) {
        activeSceneID = sceneID
    }

    /// Whether this host is the one to present: the innermost on screen. SwiftUI presents one
    /// sheet per view, so a paywall asked for from inside a sheet has to come from that sheet, or
    /// it queues behind it and appears on the way out.
    ///
    /// The innermost of the scene that asked. Should that scene have no host, its window closed
    /// or never reported itself, the innermost of all: a paywall in another window is better than
    /// none.
    func presents(_ hostID: UUID) -> Bool {
        let host = sheetHosts.last { $0.sceneID == presentationSceneID } ?? sheetHosts.last
        return host?.id == hostID
    }

    /// Forwards an event to ``onEvent`` and logs the ones that are diagnostics.
    public func report(_ event: PaywallEvent) {
        switch event {
        case .purchasePending:
            logger.notice("Purchase pending: waiting for approval")
        case .purchaseApproved:
            logger.notice("Purchase approved: pending purchase went through")
        case .verificationFailed:
            logger.error("Transaction verification failed")
        // A failed purchase is logged with its error, see ``reportPurchaseFailure(_:source:productID:)``.
        case .presented, .purchaseStarted, .purchaseCompleted, .purchaseFailed, .subscriptionStatus:
            break
        }
        onEvent?(event)
    }

    /// Logs the error by its code and reports its kind. The event carries no text of the error's:
    /// an app forwards events as they are, and a description is whatever the system put in it.
    func reportPurchaseFailure(_ error: any Error, source: String, productID: String) {
        logger.error("Purchase failed: \(error.logCode, privacy: .public)")
        report(.purchaseFailed(source: source, productID: productID, reason: PaywallPurchaseFailure(error)))
    }

    /// Called by the paywall once it is on screen. This is the funnel's denominator: without it
    /// the purchase count has no reference.
    func paywallDidAppear(_ request: PaywallRequest) {
        shownRequestID = request.id
        report(.presented(source: request.source))
    }

    /// Called by the sheet's `onDismiss`, whichever way the sheet went away. The request itself
    /// is already cleared by then, through `dismissPaywall()` or the sheet binding.
    func paywallDidDismiss() {
        guard hasAccess else {
            // Closed without access. With a purchase waiting for a parent the action waits with it,
            // see ``resolvePendingPurchase(productID:)``; otherwise it is dropped here.
            if pendingPurchase == nil { actionAfterUnlock = nil }
            return
        }
        runActionAfterUnlock()
    }

    /// Loads a product's name for the settings row, once per product for the life of the service.
    /// The name is decoration: when it cannot load, the app's fallback stands in, and the next
    /// visit to the settings tries again.
    func loadPlanName(for productID: String) async {
        guard planNames[productID] == nil else { return }
        if let product = try? await Product.products(for: [productID]).first {
            planNames[productID] = product.displayName
        }
    }

    // MARK: - Private

    /// Gives up on a request no sheet picked up: the paywall was asked for from inside a sheet
    /// that lacks `.paywallSheet()`. Left standing, the request would bring the paywall up out of
    /// nowhere once that sheet closes.
    private func watchPresentation(of request: PaywallRequest) {
        let timeout = presentationTimeout
        Task { [weak self] in
            try? await Task.sleep(for: timeout)
            guard let self, presentedRequest?.id == request.id, shownRequestID != request.id else { return }
            logger.error("Paywall not shown: no sheet could present it, apply .paywallSheet() inside the presenting sheet. source=\(request.source, privacy: .public)")
            presentedRequest = nil
            actionAfterUnlock = nil
        }
    }

    /// Takes the user where they were going when they hit the lock, then points out a
    /// subscription left running next to a lifetime purchase. Both ends of an unlock, the paywall
    /// closing and an Ask to Buy approval arriving after it, finish here.
    private func runActionAfterUnlock() {
        let action = actionAfterUnlock
        actionAfterUnlock = nil
        action?()
        showSubscriptionOverlapIfDue()
    }

    /// After the paywall has closed, never over it: the alert leads out of the app's purchase and
    /// into the system's subscription management.
    private func showSubscriptionOverlapIfDue() {
        guard subscriptionOverlapIsDue else { return }
        subscriptionOverlapIsDue = false
        showsSubscriptionOverlap = true
    }

    /// See ``PaywallEvent/subscriptionStatus(phase:productID:)``. From the plan the first refresh
    /// loaded, so the report costs no query of its own.
    private func reportSubscriptionPhase() async {
        guard entitlement == .subscription, let plan = heldPlan, let phase = plan.phase else { return }
        report(.subscriptionStatus(phase: phase, productID: plan.productID))
    }

    /// What the group says beyond the entitlement: the plan a paying user holds, and whether a
    /// user who does not pay can still get the introductory offer. Each asked only of the user it
    /// concerns, so nobody's launch carries a query whose answer goes nowhere.
    private func loadSubscriptionDetails() async {
        guard let groupID = configuration.subscriptionGroupID else { return }
        guard hasAccess else {
            if heldPlan != nil { heldPlan = nil }
            // Asked once. Only a purchase changes the answer, and that sets it back to `nil`
            // below; without this every foreground of every free user costs a round trip.
            guard isEligibleForIntroOffer == nil else { return }
            let isEligible = await Product.SubscriptionInfo.isEligibleForIntroOffer(for: groupID)
            // A cancelled read comes back `false` rather than throwing, and would quietly take
            // every introductory offer page off the paywall of a user who is eligible.
            guard !Task.isCancelled else { return }
            if isEligibleForIntroOffer != isEligible { isEligibleForIntroOffer = isEligible }
            return
        }
        if isEligibleForIntroOffer != nil { isEligibleForIntroOffer = nil }
        do {
            let plan = HeldPlan.current(in: try await Product.SubscriptionInfo.status(for: groupID))
            if heldPlan != plan { heldPlan = plan }
        } catch {
            // Decoration for the settings row and analytics. What is known stays, and the next
            // refresh tries again.
            logger.error("Loading the subscription status failed: \(error.logCode, privacy: .public)")
        }
    }

    /// Takes the entitlements freshly read from StoreKit: notes a real loss of access and stores them.
    private func applyEntitlement(_ snapshot: PaywallEntitlementSnapshot) {
        let resolved = snapshot.strongest
        if resolved < entitlement, let lastPurchase, .now - lastPurchase < purchaseGracePeriod {
            logger.notice("Entitlement kept: StoreKit does not list the purchase yet")
            return
        }
        // Only a real active->inactive transition is worth a notice. A user who never
        // paid would otherwise log this on every launch.
        if resolved == .none, hasAccess {
            logger.notice("Entitlement cleared: no active entitlement")
        }
        // Guarded for the same reason as ``setEntitlement(_:)``: this runs on every foreground, and
        // an unguarded write would re-render the settings row and the paywall for an answer that
        // did not move.
        if lifetimeProductID != snapshot.lifetimeProductID { lifetimeProductID = snapshot.lifetimeProductID }
        if lifetimeIsFamilyShared != snapshot.lifetimeIsFamilyShared { lifetimeIsFamilyShared = snapshot.lifetimeIsFamilyShared }
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
        case .offline:
            logger.notice("Restore finished: outcome=offline")
        case .failed:
            if let syncError {
                logger.error("Restore failed: reason=sync \(syncError.logCode, privacy: .public)")
            } else {
                logger.error("Restore failed: reason=unverified")
                report(.verificationFailed)
            }
        }
    }

    /// Single write point for the entitlement: updates the state and the cache. Only ever reached
    /// with an answer from StoreKit, never with the cached one, so whatever reads the cache from
    /// outside, an extension or a widget, never finds a guess in it.
    private func setEntitlement(_ entitlement: PaywallEntitlement) {
        // `@Observable` does not compare before it notifies. Without this every foreground refresh
        // would re-render every gated screen in the app and rewrite the defaults key, for an
        // answer that did not move. Compared against what was written, not against ``entitlement``,
        // so the first `.none` of a fresh install still reaches the cache.
        guard entitlement != lastWrittenEntitlement else { return }
        lastWrittenEntitlement = entitlement
        self.entitlement = entitlement
        cache.write(entitlement)
        // A widget reads the cache from the app group, and only when it draws its timeline. Without
        // this a user who just paid keeps a locked widget until the next one.
        if configuration.appGroupID != nil { reloadWidgets() }
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

    /// A subscription that runs out produces no transaction, so `Transaction.updates` stays
    /// silent and an app left open would stay unlocked. The status does change, and the
    /// entitlements are read again on it.
    private func listenForStatusUpdates() {
        guard statusUpdatesTask == nil, configuration.subscriptionGroupID != nil else { return }
        statusUpdatesTask = Task { [weak self] in
            for await _ in Product.SubscriptionInfo.Status.updates {
                guard let self else { return }
                await refresh()
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
            // The grace period holds a purchase StoreKit has not listed yet, not one it has taken
            // back. `Transaction.updates` replays finished purchases at launch, so without this a
            // refund arriving in the same batch would be waved through.
            lastPurchase = nil
            await refresh()
        } else if let expirationDate = transaction.expirationDate, expirationDate <= .now {
            // `Transaction.updates` replays finished purchases at launch, a subscription that ran
            // out since among them. Granting on it would arm ``purchaseGracePeriod``, and the
            // launch's own read, which correctly finds nothing, would then be refused as too
            // early: the user would be shown as paying until the next foreground. A subscription
            // running out while the app is open produces no transaction at all, see
            // ``listenForStatusUpdates()``, so there is nothing else this can be.
            logger.debug("Expired transaction ignored: \(transaction.productID, privacy: .public)")
        } else {
            handleSuccessfulPurchase(productID: transaction.productID, subscriptionGroupID: transaction.subscriptionGroupID)
            // A renewal or a plan change moves the settings row's second line. Only a
            // subscription has one: a lifetime product would cost a query that answers nothing.
            if granted == .subscription { await loadSubscriptionDetails() }
        }
    }
}
