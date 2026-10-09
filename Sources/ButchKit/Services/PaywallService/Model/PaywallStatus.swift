//
//  PaywallStatus.swift
//  ButchKit
//
//  Created by Leo Heuser on 17.09.26.
//

import SwiftUI

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
    /// `nil` until it has loaded, when it cannot load, and without an entitlement. ``planTitle``
    /// falls back on its own.
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
    /// The app's name for what it sells, see ``PaywallConfiguration/planName``.
    let configuredPlanName: LocalizedStringResource?

    /// Decides the status from what StoreKit reported. Pure, so tests feed it without StoreKit.
    ///
    /// `planNames` is looked up by the product held, so a plan change never shows the old plan's
    /// name.
    init(
        entitlement: PaywallEntitlement,
        isEntitlementKnown: Bool,
        heldPlan: HeldPlan?,
        lifetimeProductID: String?,
        lifetimeIsFamilyShared: Bool,
        planNames: [String: String],
        configuredPlanName: LocalizedStringResource? = nil,
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
            // What it can do is lead there: an alert right after the
            // purchase, and the Manage button here for as long as the subscription renews.
            productID = lifetimeProductID
            detail = nil
            // A family member's subscription is not this user's to cancel.
            canManageSubscription = heldPlan?.willAutoRenew == true && heldPlan?.isFamilyShared != true
            isFamilyShared = lifetimeIsFamilyShared
        }
        self.productID = productID
        self.entitlement = entitlement
        self.isLoading = entitlement == .none && !isEntitlementKnown
        self.planName = productID.flatMap { planNames[$0] }
        self.configuredPlanName = configuredPlanName
        self.showPaywall = showPaywall
        self.manageSubscription = manageSubscription
    }

    /// A status with fixed answers, for the preview of a row the app draws itself on
    /// ``PaywallStatusReader``. The two actions do nothing. Available in every build, because an
    /// app's `#Preview` compiles in release too; use it in previews only.
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
        self.configuredPlanName = nil
    }
}

// MARK: - Words

/// ButchKit's words for the row, in the language the app runs in. ``PaywallStatusRow`` shows
/// them; a row of the app's own on ``PaywallStatusReader`` takes the same ones and still decides
/// every font, color and icon itself.
public extension PaywallStatus {
    /// The button that opens the paywall: "Upgrade to Pro" with a
    /// ``PaywallConfiguration/planName``, "Upgrade" without. Also its accessibility label, so
    /// Voice Control finds it by what it shows.
    var offerTitle: Text {
        if let configuredPlanName {
            Text(PaywallStrings.offer(planName: String(localized: configuredPlanName)))
        } else {
            Text(PaywallStrings.offer)
        }
    }

    /// The VoiceOver hint of ``offerTitle``.
    var offerHint: Text { Text(PaywallStrings.offerHint) }

    /// The plan's name: the App Store's own once loaded, until then the app's
    /// ``PaywallConfiguration/planName`` or ButchKit's "Subscription" or "Lifetime Purchase".
    var planTitle: Text {
        // A product name from App Store Connect is already localized there.
        if let planName { return Text(verbatim: planName) }
        if let configuredPlanName { return Text(configuredPlanName) }
        return Text(entitlement == .lifetime ? PaywallStrings.lifetimePlan : PaywallStrings.subscriptionPlan)
    }

    /// The line under the plan's name, `nil` when there is nothing to say.
    var detailText: Text? {
        detail.map { detail in
            switch detail {
            case .renews(let date): Text(PaywallStrings.renews(on: date.formatted(Self.dateFormat)))
            case .ends(let date): Text(PaywallStrings.ends(on: date.formatted(Self.dateFormat)))
            case .billingIssue: Text(PaywallStrings.billingIssue)
            }
        }
    }

    /// The button into the system's subscription management. The verb alone, next to the plan.
    var manageTitle: Text { Text(PaywallStrings.manage) }

    /// The accessibility label of ``manageTitle``, which says what is managed and keeps the
    /// visible word for Voice Control.
    var manageLabel: Text { Text(PaywallStrings.manageLabel) }

    /// The VoiceOver hint of ``manageTitle``.
    var manageHint: Text { Text(PaywallStrings.manageHint) }

    /// One format for both dated lines, so they cannot drift apart.
    private static var dateFormat: Date.FormatStyle { .dateTime.day().month().year() }
}
