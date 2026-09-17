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
    /// The name of the product held, as App Store Connect spells it and localized per storefront.
    /// `nil` until it has loaded, when it cannot load, and without an entitlement, so the app shows
    /// its own fallback name then.
    public let planName: String?
    /// What happens next with the subscription. Only for ``PaywallEntitlement/subscription``: a
    /// lifetime purchase has no renewal and no end.
    public let detail: SubscriptionDetail?
    /// Whether to offer ``manageSubscription``: always for a subscriber, and for a lifetime owner
    /// only while a subscription still renews next to the purchase, the one thing they could
    /// otherwise keep paying for without finding a way out.
    public let canManageSubscription: Bool
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
    /// `loadedName` carries the product it was loaded for and is dropped for any other, so a plan
    /// change never shows the old plan's name.
    init(
        entitlement: PaywallEntitlement,
        heldPlan: HeldPlan?,
        lifetimeProductID: String?,
        loadedName: (productID: String, name: String)?,
        showPaywall: @escaping @MainActor () -> Void,
        manageSubscription: @escaping @MainActor () -> Void
    ) {
        let productID: String?
        switch entitlement {
        case .none:
            productID = nil
            detail = nil
            canManageSubscription = false
        case .subscription:
            productID = heldPlan?.productID
            detail = heldPlan.flatMap {
                SubscriptionDetail(state: $0.state, willAutoRenew: $0.willAutoRenew, expirationDate: $0.expirationDate)
            }
            canManageSubscription = true
        case .lifetime:
            // TODO: Revisit with purchase groups. The configuration should say which App Store Connect
            // subscriptions and one-time purchases belong together, so the paywall can resolve the overlap on
            // its own: the one-time purchase replaces the subscription, which then does not keep running.
            // StoreKit lets no app cancel a subscription itself, so "replaces" means leading the user to the
            // cancellation, for example right after the one-time purchase.
            productID = lifetimeProductID
            detail = nil
            canManageSubscription = heldPlan?.willAutoRenew == true
        }
        self.productID = productID
        self.entitlement = entitlement
        self.planName = loadedName.flatMap { $0.productID == productID ? $0.name : nil }
        self.showPaywall = showPaywall
        self.manageSubscription = manageSubscription
    }
}
