//
//  PaywallConfiguration.swift
//  ButchKit
//
//  Created by Leo Heuser on 03.09.26.
//

import Foundation

/// Everything the paywall needs to know about one app's subscription.
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
/// There is no list of product identifiers. Entitlement is decided per subscription group, so
/// every tier in the group (monthly, yearly, …) unlocks the app without being named here. The
/// group identifier usually differs between the local `.storekit` file and App Store Connect;
/// resolve that with `#if DEBUG` where the configuration is declared.
public struct PaywallConfiguration: Sendable, Equatable {
    /// The App Store Connect subscription group whose members unlock the app.
    public let subscriptionGroupID: String
    /// Shown behind the paywall's privacy policy button. `nil` hides the policy buttons.
    public let privacyPolicyURL: String?
    /// Shown behind the paywall's terms of service button. `nil` hides the policy buttons.
    public let termsOfServiceURL: String?

    public init(
        subscriptionGroupID: String,
        privacyPolicyURL: String? = nil,
        termsOfServiceURL: String? = nil
    ) {
        self.subscriptionGroupID = subscriptionGroupID
        self.privacyPolicyURL = privacyPolicyURL
        self.termsOfServiceURL = termsOfServiceURL
    }

    /// Whether the paywall shows the privacy policy and terms buttons. StoreKit shows both or
    /// neither, so one missing URL hides the pair.
    var hasPolicies: Bool {
        privacyPolicyURL != nil && termsOfServiceURL != nil
    }
}
