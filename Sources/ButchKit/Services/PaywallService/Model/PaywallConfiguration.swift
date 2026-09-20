//
//  PaywallConfiguration.swift
//  ButchKit
//
//  Created by Leo Heuser on 03.09.26.
//

import Foundation

/// Everything the paywall needs to know about one app's products, plus the one layout choice an
/// app makes: how much of the paywall its marketing pages take.
///
/// A value, declared once in the app and handed to `View.paywallEnvironment(_:texts:features:)`:
///
/// ```swift
/// let paywallConfig = PaywallConfiguration(
///     subscriptionGroupID: "21900977",
///     privacyPolicyURL: "https://heuser.design/app/privacy",
///     termsOfServiceURL: "https://heuser.design/app/terms"
/// )
/// ```
///
/// There is no list of subscription identifiers. Entitlement is decided per subscription group,
/// so every tier in the group (monthly, yearly, …) unlocks the app without being named here. The
/// group identifier usually differs between the local `.storekit` file and App Store Connect;
/// resolve that with `#if DEBUG` where the configuration is declared.
///
/// The only products that are named are the optional lifetime purchases, non-consumables that
/// each unlock the app for good. An app that sells any passes their identifiers; every other app
/// leaves them out. An app that sells nothing but those leaves out the group instead:
///
/// ```swift
/// let paywallConfig = PaywallConfiguration(lifetimeProductIDs: ["design.heuser.App.full_version"])
/// ```
public struct PaywallConfiguration: Sendable, Equatable {
    /// The App Store Connect subscription group whose members unlock the app. `nil` for an app
    /// that sells only lifetime products; the paywall then shows those alone.
    public let subscriptionGroupID: String?
    /// The non-consumables that each unlock the app once and for all, in the order the paywall
    /// lists them. Empty for an app that sells none; with any, the paywall offers them on a
    /// segment of their own next to the subscription plans.
    public let lifetimeProductIDs: [String]
    /// Shown behind the paywall's privacy policy button. `nil` hides the policy buttons.
    public let privacyPolicyURL: String?
    /// Shown behind the paywall's terms of service button. `nil` hides the policy buttons.
    public let termsOfServiceURL: String?
    /// The share of the paywall's height the marketing pages take, fixed, from 0 (no pages) to 1
    /// (the whole sheet). Values outside are clamped. An upper bound rather than a promise: on a
    /// short screen or at a large text size the pages take less, so the Subscribe button stays
    /// in view, see ``featureHeight(in:reserving:)``.
    public let featureAreaHeight: Double
    /// The app group the last confirmed entitlement is cached in, for an app with a widget, an
    /// extension or an App Intent that needs the answer in another process; they read it through
    /// ``PaywallEntitlementCache``. `nil` keeps it in the app's own defaults.
    public let appGroupID: String?
    /// Whether the root modifier reads the entitlements again each time the app comes to the
    /// foreground, so a subscription that ran out in the background locks the app at once. Costs
    /// one local StoreKit read; turn it off only for an app that refreshes on a rhythm of its own.
    public let refreshesOnForeground: Bool
    /// Whether the subscription side carries Apple's "Redeem Code" button, for offer codes handed
    /// out in a campaign, a press kit or a support case. StoreKit shows on its own only the offers
    /// the App Store already knows the user is eligible for; a code someone was given has no other
    /// way in. Off unless the app hands out codes.
    public let showsRedeemCode: Bool
    /// Where the app kept its own answer before it adopted ButchKit, see ``LegacyCache``.
    public let legacyCache: LegacyCache?

    /// A `Bool` in `UserDefaults` under which an app's own purchase code kept "this user pays",
    /// before the app adopted ButchKit. Read at launch until ButchKit has an answer of its own, so
    /// the first launch after that update shows a paying user no paywall flash. It only ever draws
    /// the interface for a moment: StoreKit's answer replaces it, and nothing is unlocked on it
    /// for good, see ``PaywallService/verifiedEntitlement``.
    public struct LegacyCache: Sendable, Equatable {
        public let key: String
        /// The suite the key lives in, `nil` for the standard defaults.
        public let suiteName: String?

        public init(key: String, suiteName: String? = nil) {
            self.key = key
            self.suiteName = suiteName
        }
    }

    public init(
        subscriptionGroupID: String? = nil,
        lifetimeProductIDs: [String] = [],
        privacyPolicyURL: String? = nil,
        termsOfServiceURL: String? = nil,
        featureAreaHeight: Double = 0.62,
        appGroupID: String? = nil,
        refreshesOnForeground: Bool = true,
        showsRedeemCode: Bool = false,
        legacyCache: LegacyCache? = nil
    ) {
        assert(subscriptionGroupID != nil || !lifetimeProductIDs.isEmpty, "A paywall needs a subscription group, lifetime products, or both")
        self.featureAreaHeight = min(max(featureAreaHeight, 0), 1)
        self.subscriptionGroupID = subscriptionGroupID
        self.lifetimeProductIDs = lifetimeProductIDs
        self.privacyPolicyURL = privacyPolicyURL
        self.termsOfServiceURL = termsOfServiceURL
        self.appGroupID = appGroupID
        self.refreshesOnForeground = refreshesOnForeground
        self.showsRedeemCode = showsRedeemCode
        self.legacyCache = legacyCache
    }

    /// How tall the marketing pages are on a sheet of the given height: their share of it, less
    /// whatever the purchases below need to keep the Subscribe button in view. On a tall sheet
    /// the share stands; on a short one, or at a large text size, the pages give way. Pure, so
    /// the rule is testable without a view.
    func featureHeight(in sheetHeight: CGFloat, reserving purchaseHeight: CGFloat) -> CGFloat {
        min(sheetHeight * featureAreaHeight, max(sheetHeight - purchaseHeight, 0))
    }

    /// The two policy pages, or `nil` unless both are set. StoreKit shows both or neither, so one
    /// missing URL hides the pair; the lifetime side draws its own links by the same rule.
    var policies: (privacy: String, terms: String)? {
        guard let privacyPolicyURL, let termsOfServiceURL else { return nil }
        return (privacyPolicyURL, termsOfServiceURL)
    }

    /// Whether the paywall shows the privacy policy and terms buttons.
    var hasPolicies: Bool { policies != nil }

    /// What one verified transaction grants under this configuration. Pure, so the decision is
    /// testable without StoreKit.
    func entitlement(productID: String, subscriptionGroupID: String?) -> PaywallEntitlement {
        if lifetimeProductIDs.contains(productID) {
            return .lifetime
        }
        // Checked for `nil` first: without a group of its own, a product without one is no member.
        if let ownGroupID = self.subscriptionGroupID, subscriptionGroupID == ownGroupID {
            return .subscription
        }
        return .none
    }
}
