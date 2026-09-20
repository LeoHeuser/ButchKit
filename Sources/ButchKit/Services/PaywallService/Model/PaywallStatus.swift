//
//  PaywallStatus.swift
//  ButchKit
//
//  Created by Leo Heuser on 17.09.26.
//

import Foundation

/// Everything a settings row needs to say what the user pays for, and the two ways on from there.
/// Handed out by ``PaywallStatusReader``.
public struct PaywallStatus {
    /// Which row to show: the offer, the subscription or the lifetime purchase.
    public let entitlement: PaywallEntitlement
    /// `true` while nothing is known at all: no entitlement cached and StoreKit still to answer,
    /// the first moment after an install. Show a spinner rather than the offer, or a subscriber who
    /// just reinstalled is asked to subscribe. A returning free user has a cached answer, so this
    /// stays `false` and the offer shows at once.
    public let isLoading: Bool
    /// The name of the product held, as App Store Connect spells it and localized per storefront.
    /// `nil` until it has loaded, when it cannot load, and without an entitlement, so the app shows
    /// its own fallback name then.
    public let planName: String?
    /// What happens next with the subscription. Only for ``PaywallEntitlement/subscription``: a
    /// lifetime purchase has no renewal and no end.
    public let detail: SubscriptionDetail?
    /// Whether to offer ``manageSubscription``: for a subscriber on a plan of their own, and for a lifetime owner
    /// only while a subscription still renews next to the purchase, the one thing they could
    /// otherwise keep paying for without finding a way out.
    public let canManageSubscription: Bool
    /// Whether what the user holds is another family member's, shared through Family Sharing.
    /// Such a user cannot manage or cancel it, so word support and settings accordingly: "your
    /// family's plan" rather than "your plan".
    public let isFamilyShared: Bool
    /// Opens the paywall, carrying the reader's source.
    public let showPaywall: @MainActor () -> Void
    /// Opens the system's own subscription management: the sheet on iPhone and iPad, the App
    /// Store on a Mac. Cancelling and changing the plan live there, never in the app.
    public let manageSubscription: @MainActor () -> Void

    /// The product the name is loaded for. Kept apart from the name so the reader loads again only
    /// when the plan itself changes.
    let productID: String?

    /// Decides the status from what StoreKit reported. Pure, so tests feed it without StoreKit.
    ///
    /// `planNames` is looked up by the product held, so a plan change never shows the old plan's
    /// name.
    init(
        entitlement: PaywallEntitlement,
        isInitialized: Bool,
        hasCachedEntitlement: Bool,
        heldPlan: HeldPlan?,
        lifetimeProductID: String?,
        lifetimeIsFamilyShared: Bool,
        planNames: [String: String],
        showPaywall: @escaping @MainActor () -> Void,
        manageSubscription: @escaping @MainActor () -> Void
    ) {
        let productID: String?
        switch entitlement {
        case .none:
            productID = nil
            detail = nil
            canManageSubscription = false
            isFamilyShared = false
        case .subscription:
            productID = heldPlan?.productID
            detail = heldPlan.flatMap {
                SubscriptionDetail(state: $0.state, willAutoRenew: $0.willAutoRenew, expirationDate: $0.expirationDate)
            }
            // A family member's subscription is not this user's to cancel, the same rule the
            // lifetime case applies below.
            canManageSubscription = heldPlan?.isFamilyShared != true
            isFamilyShared = heldPlan?.isFamilyShared == true
        case .lifetime:
            // StoreKit lets no app cancel a subscription, so a lifetime purchase cannot replace one.
            // What it can do is lead there: ``PaywallTexts/SubscriptionOverlap`` right after the
            // purchase, and the Manage button here for as long as the subscription renews.
            productID = lifetimeProductID
            detail = nil
            // A family member's subscription is not this user's to cancel.
            canManageSubscription = heldPlan?.willAutoRenew == true && heldPlan?.isFamilyShared != true
            isFamilyShared = lifetimeIsFamilyShared
        }
        self.productID = productID
        self.entitlement = entitlement
        self.isLoading = entitlement == .none && !isInitialized && !hasCachedEntitlement
        self.planName = productID.flatMap { planNames[$0] }
        self.showPaywall = showPaywall
        self.manageSubscription = manageSubscription
    }

#if DEBUG
    /// A status with fixed answers, for the preview of a row the app draws itself on
    /// ``PaywallStatusReader``. The two actions do nothing.
    public init(
        previewEntitlement: PaywallEntitlement,
        planName: String? = nil,
        detail: SubscriptionDetail? = nil,
        canManageSubscription: Bool = false,
        isFamilyShared: Bool = false,
        isLoading: Bool = false
    ) {
        self.entitlement = previewEntitlement
        self.isLoading = isLoading
        self.planName = planName
        self.detail = detail
        self.canManageSubscription = canManageSubscription
        self.isFamilyShared = isFamilyShared
        self.showPaywall = {}
        self.manageSubscription = {}
        self.productID = nil
    }
#endif
}
