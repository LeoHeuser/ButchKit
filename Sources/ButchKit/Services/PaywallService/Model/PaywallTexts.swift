//
//  PaywallTexts.swift
//  ButchKit
//
//  Created by Leo Heuser on 13.09.26.
//

import SwiftUI

/// Every word the paywall and its settings row show, handed in by the app.
///
/// ButchKit ships no strings. Each key is written in the app's own code, where Xcode finds it and
/// extracts it into the app's catalog like any other string, so the app owns the wording, the keys
/// and the table each one lives in. Declared once, next to the app's ``PaywallConfiguration``,
/// and handed to `View.paywallEnvironment(_:texts:features:)`:
///
/// ```swift
/// let paywallTexts = PaywallTexts(
///     dismiss: "button.dismissSheet",
///     privacyPolicyTitle: "webView.privacyPolicy.title",
///     termsOfServiceTitle: "webView.termsOfUse.title",
///     purchaseFailedTitle: String(localized: "error.paywall.purchaseFailed.title", table: "Errors"),
///     purchaseFailedMessage: String(localized: "error.paywall.purchaseFailed.message", table: "Errors"),
///     subscriptionTab: "paywall.segment.subscription",
///     oneTimeTab: "paywall.segment.oneTime",
///     restorePurchases: "button.paywall.restorePurchases",
///     restoreSucceededTitle: String(localized: "alert.paywall.restore.succeeded.title"),
///     nothingToRestoreTitle: String(localized: "alert.paywall.restore.nothingFound.title"),
///     restoreFailedTitle: String(localized: "error.paywall.restoreFailed.title", table: "Errors"),
///     restoreFailedMessage: String(localized: "error.paywall.restoreFailed.message", table: "Errors"),
///     offer: "button.settings.subscribe",
///     offerHint: String(localized: "accessibility.button.settings.subscribe", table: "Accessibility"),
///     fallbackPlanName: "label.settings.subscription.plan",
///     manage: "button.settings.manageSubscription",
///     manageHint: String(localized: "accessibility.button.settings.manageSubscription", table: "Accessibility"),
///     renews: { Text("label.settings.subscription.renews \($0, format: .dateTime.day().month().year())") },
///     ends: { Text("label.settings.subscription.ends \($0, format: .dateTime.day().month().year())") },
///     billingIssue: String(localized: "error.settings.subscription.billingIssue", table: "Errors")
/// )
/// ```
///
/// Three shapes, by what the string is. A plain label is a `LocalizedStringKey`, looked up in the
/// app's default table. A hint or an error is a `String` the app has already resolved, so the app
/// names its table itself. The two dated lines are closures, so the key, its placeholder and the
/// date's format all stand in the app's code together.
public struct PaywallTexts {

    // MARK: - Paywall sheet

    /// The close button in the paywall's toolbar.
    public let dismiss: LocalizedStringKey
    /// Navigation title of the privacy policy page.
    public let privacyPolicyTitle: LocalizedStringKey
    /// Navigation title of the terms page.
    public let termsOfServiceTitle: LocalizedStringKey
    /// Title of the alert after a failed purchase.
    public let purchaseFailedTitle: String
    /// Message of the alert after a failed purchase.
    public let purchaseFailedMessage: String
    /// The segment for the subscription plans, shown when the app also sells lifetime products.
    public let subscriptionTab: LocalizedStringKey
    /// The segment for the lifetime products.
    public let oneTimeTab: LocalizedStringKey
    /// The restore button at the top right of the paywall, for subscriptions and lifetime products
    /// alike. Shown as text, so keep it short.
    public let restorePurchases: LocalizedStringKey
    /// Title of the alert after a restore brought a purchase back. One
    /// sentence, so it has no message. Its OK closes the paywall.
    public let restoreSucceededTitle: String
    /// Title of the alert after a restore that found no purchase to bring back. One sentence, so
    /// it has no message.
    public let nothingToRestoreTitle: String
    /// Title of the alert after a restore that failed: the App Store could not be reached, or the
    /// purchase it found did not pass verification.
    public let restoreFailedTitle: String
    /// Message of that alert. One text for both causes, so it asks to check the connection and try
    /// again rather than naming either.
    public let restoreFailedMessage: String

    // MARK: - Settings row

    /// The ``PaywallStatusRow`` button that opens the paywall while there is no subscription.
    public let offer: LocalizedStringKey
    /// The VoiceOver hint of ``offer``.
    public let offerHint: String
    /// The plan's name until the App Store's own name has loaded.
    public let fallbackPlanName: LocalizedStringKey
    /// The button into the system's subscription management.
    public let manage: LocalizedStringKey
    /// The VoiceOver hint of ``manage``.
    public let manageHint: String
    /// The line under the plan name while it renews, built from the renewal date.
    public let renews: (Date) -> Text
    /// The line under the plan name once auto-renew is off, built from the last day of access.
    public let ends: (Date) -> Text
    /// The line under the plan name during the grace period after a failed renewal.
    public let billingIssue: String

    public init(
        dismiss: LocalizedStringKey,
        privacyPolicyTitle: LocalizedStringKey,
        termsOfServiceTitle: LocalizedStringKey,
        purchaseFailedTitle: String,
        purchaseFailedMessage: String,
        subscriptionTab: LocalizedStringKey,
        oneTimeTab: LocalizedStringKey,
        restorePurchases: LocalizedStringKey,
        restoreSucceededTitle: String,
        nothingToRestoreTitle: String,
        restoreFailedTitle: String,
        restoreFailedMessage: String,
        offer: LocalizedStringKey,
        offerHint: String,
        fallbackPlanName: LocalizedStringKey,
        manage: LocalizedStringKey,
        manageHint: String,
        renews: @escaping (Date) -> Text,
        ends: @escaping (Date) -> Text,
        billingIssue: String
    ) {
        self.dismiss = dismiss
        self.privacyPolicyTitle = privacyPolicyTitle
        self.termsOfServiceTitle = termsOfServiceTitle
        self.purchaseFailedTitle = purchaseFailedTitle
        self.purchaseFailedMessage = purchaseFailedMessage
        self.subscriptionTab = subscriptionTab
        self.oneTimeTab = oneTimeTab
        self.restorePurchases = restorePurchases
        self.restoreSucceededTitle = restoreSucceededTitle
        self.nothingToRestoreTitle = nothingToRestoreTitle
        self.restoreFailedTitle = restoreFailedTitle
        self.restoreFailedMessage = restoreFailedMessage
        self.offer = offer
        self.offerHint = offerHint
        self.fallbackPlanName = fallbackPlanName
        self.manage = manage
        self.manageHint = manageHint
        self.renews = renews
        self.ends = ends
        self.billingIssue = billingIssue
    }

    // MARK: - Settings row words

    // Words, not views: a row of the app's own on `PaywallStatusReader` gets the same wording and
    // the same rules as `PaywallStatusRow`, and still decides every font, color and icon itself.

    /// The plan's name: the App Store's own once loaded, ``fallbackPlanName`` until then.
    public func planName(_ name: String?) -> Text {
        // A product name from App Store Connect is already localized there.
        name.map { Text(verbatim: $0) } ?? Text(fallbackPlanName)
    }

    /// The line under the plan's name.
    public func detail(_ detail: SubscriptionDetail) -> Text {
        switch detail {
        case .renews(let date): renews(date)
        case .ends(let date): ends(date)
        case .billingIssue: Text(billingIssue)
        }
    }
}
