//
//  PaywallEvent.swift
//  ButchKit
//
//  Created by Leo Heuser on 03.09.26.
//

/// The paywall funnel, as it happens.
///
/// ButchKit has no analytics dependency. Hand `onEvent` to the root modifier and forward each
/// event to whatever the app uses. Every event says what it is called and what it carries, so
/// the bridge is one line and an event added by a later ButchKit flows through it untouched:
///
/// ```swift
/// .paywallEnvironment(paywallConfig, texts: paywallTexts) { event in
///     TelemetryDeck.signal(event.name, parameters: event.parameters)
/// }
/// ```
///
/// An app that wants its own names switches over the cases instead, with a `default` that falls
/// back to ``name``: without one, every new case stops the app from compiling.
///
/// `source` is the app's own name for where the user hit the lock ("newItem", "settings"), the
/// value passed to `PaywallService.present(source:)` or `require(source:_:)`. `productID` is the
/// App Store product the user chose, so a paywall with several plans, or a lifetime purchase next
/// to them, can tell which one sells.
public enum PaywallEvent: Sendable, Equatable {
    /// The paywall appeared. The funnel's denominator.
    case presented(source: String)
    /// The user tapped a purchase button and the App Store sheet is about to show.
    case purchaseStarted(source: String, productID: String)
    /// A fresh purchase from the paywall went through. A free trial start counts too. Restores
    /// and renewals arrive through `Transaction.updates` and are deliberately not reported here.
    /// `isIntroductoryOffer` tells a trial start from a paid purchase, so a funnel does not count
    /// every free week as revenue.
    case purchaseCompleted(source: String, productID: String, isIntroductoryOffer: Bool)
    /// Ask to Buy: the purchase waits for a parent's approval.
    case purchasePending(source: String, productID: String)
    /// A pending purchase was approved, minutes or days after ``purchasePending(source:productID:)``
    /// and with the same source, so the funnel closes where it opened, also when the app was quit
    /// in between. Never reported for a purchase that went through at once, and not for a request
    /// older than two days, which Apple has dropped by then.
    case purchaseApproved(source: String, productID: String)
    /// The purchase failed, and of what kind. A user backing out of the App Store sheet is not a
    /// failure and is not reported.
    case purchaseFailed(source: String, productID: String, reason: PaywallPurchaseFailure)
    /// A transaction from the App Store failed verification and was not finished.
    case verificationFailed
    /// Where an active subscriber stands, reported once per service after the first entitlement
    /// check. A snapshot of a state rather than a step in the funnel: it answers how many
    /// subscribers have already canceled their trial or their paid period, and never counts as a
    /// conversion. Users without a running subscription, lifetime owners included, report nothing,
    /// so a chart of it compares active subscribers only.
    case subscriptionStatus(phase: SubscriptionPhase, productID: String)

    /// What the event is called, for an analytics signal. Stable across releases.
    public var name: String {
        switch self {
        case .presented: "paywall.presented"
        case .purchaseStarted: "paywall.purchaseStarted"
        case .purchaseCompleted: "paywall.purchaseCompleted"
        case .purchasePending: "paywall.purchasePending"
        case .purchaseApproved: "paywall.purchaseApproved"
        case .purchaseFailed: "paywall.purchaseFailed"
        case .verificationFailed: "paywall.verificationFailed"
        case .subscriptionStatus: "paywall.subscriptionStatus"
        }
    }

    /// What the event carries, under stable keys: `source`, `productID`, `isIntroductoryOffer`,
    /// `reason` and `phase`, each only on the events that have it.
    public var parameters: [String: String] {
        switch self {
        case .presented(let source):
            ["source": source]
        case .purchaseStarted(let source, let productID), .purchasePending(let source, let productID), .purchaseApproved(let source, let productID):
            ["source": source, "productID": productID]
        case .purchaseCompleted(let source, let productID, let isIntroductoryOffer):
            ["source": source, "productID": productID, "isIntroductoryOffer": String(isIntroductoryOffer)]
        case .purchaseFailed(let source, let productID, let reason):
            ["source": source, "productID": productID, "reason": reason.rawValue]
        case .verificationFailed:
            [:]
        case .subscriptionStatus(let phase, let productID):
            ["phase": phase.rawValue, "productID": productID]
        }
    }
}
