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
/// leaves them out.
public struct PaywallConfiguration: Sendable, Equatable {
    /// The App Store Connect subscription group whose members unlock the app.
    public let subscriptionGroupID: String
    /// The non-consumables that each unlock the app once and for all, in the order the paywall
    /// lists them. Empty for an app that sells none; with any, the paywall offers them on a
    /// segment of their own next to the subscription plans.
    public let lifetimeProductIDs: [String]
    /// Shown behind the paywall's privacy policy button. `nil` hides the policy buttons.
    public let privacyPolicyURL: String?
    /// Shown behind the paywall's terms of service button. `nil` hides the policy buttons.
    public let termsOfServiceURL: String?
    /// The share of the paywall's height the marketing pages take, fixed, from 0 (no pages) to 1
    /// (the whole sheet, which pushes the purchases out of view). Values outside are clamped.
    /// The larger it is, the sooner a short screen needs a scroll to reach the Subscribe button.
    public let featureAreaHeight: Double

    public init(
        subscriptionGroupID: String,
        lifetimeProductIDs: [String] = [],
        privacyPolicyURL: String? = nil,
        termsOfServiceURL: String? = nil,
        featureAreaHeight: Double = 0.62
    ) {
        self.featureAreaHeight = min(max(featureAreaHeight, 0), 1)
        self.subscriptionGroupID = subscriptionGroupID
        self.lifetimeProductIDs = lifetimeProductIDs
        self.privacyPolicyURL = privacyPolicyURL
        self.termsOfServiceURL = termsOfServiceURL
    }

    /// Whether the paywall shows the privacy policy and terms buttons. StoreKit shows both or
    /// neither, so one missing URL hides the pair.
    var hasPolicies: Bool {
        privacyPolicyURL != nil && termsOfServiceURL != nil
    }

    /// What one verified transaction grants under this configuration. Pure, so the decision is
    /// testable without StoreKit.
    func entitlement(productID: String, subscriptionGroupID: String?) -> PaywallEntitlement {
        if lifetimeProductIDs.contains(productID) {
            return .lifetime
        }
        if subscriptionGroupID == self.subscriptionGroupID {
            return .subscription
        }
        return .none
    }
}
