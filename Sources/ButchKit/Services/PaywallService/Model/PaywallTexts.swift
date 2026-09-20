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
///     sheet: .init(
///         dismiss: "button.dismissSheet",
///         privacyPolicyTitle: "webView.privacyPolicy.title",
///         termsOfServiceTitle: "webView.termsOfUse.title",
///         purchaseFailedTitle: String(localized: "error.paywall.purchaseFailed.title", table: "Errors"),
///         purchaseFailedMessage: String(localized: "error.paywall.purchaseFailed.message", table: "Errors"),
///         restorePurchases: "button.paywall.restorePurchases",
///         restoreSucceededTitle: String(localized: "alert.paywall.restore.succeeded.title"),
///         nothingToRestoreTitle: String(localized: "alert.paywall.restore.nothingFound.title"),
///         restoreFailedTitle: String(localized: "error.paywall.restoreFailed.title", table: "Errors"),
///         restoreFailedMessage: String(localized: "error.paywall.restoreFailed.message", table: "Errors")
///     ),
///     statusRow: .init(
///         offer: "button.settings.subscribe",
///         offerLabel: String(localized: "accessibility.button.settings.subscribe.label", table: "Accessibility"),
///         offerHint: String(localized: "accessibility.button.settings.subscribe", table: "Accessibility"),
///         fallbackPlanName: "label.settings.subscription.plan",
///         manage: "button.settings.manageSubscription",
///         manageLabel: String(localized: "accessibility.button.settings.manageSubscription.label", table: "Accessibility"),
///         manageHint: String(localized: "accessibility.button.settings.manageSubscription", table: "Accessibility"),
///         renews: { Text("label.settings.subscription.renews \($0, format: .dateTime.day().month().year())") },
///         ends: { Text("label.settings.subscription.ends \($0, format: .dateTime.day().month().year())") },
///         billingIssue: String(localized: "error.settings.subscription.billingIssue", table: "Errors")
///     )
/// )
/// ```
///
/// Three groups, by where the words appear, and an app words only what it shows. ``Sheet`` is the
/// paywall itself and always needed. ``OfferTabs`` is the segmented control, which exists only
/// when lifetime products are sold next to a subscription. ``StatusRow`` is the settings row,
/// for an app that uses ``PaywallStatusRow`` or wants the same words in a row of its own.
///
/// Three shapes, by what the string is. A plain label is a `LocalizedStringResource`, written as
/// a string literal and looked up in the app's default table. An accessibility label, a hint or
/// an error is a `String` the app has already resolved, so the app names its table itself. The
/// two dated lines are closures, so the key, its placeholder and the date's format all stand in
/// the app's code together.
///
/// There are no default words, on purpose: a default would be a string in no catalog of the app's,
/// shown in English in every language without anyone noticing. A later ButchKit that needs a new
/// word adds it as a new optional group, or falls back to a word that is already here. It never
/// adds a required parameter to a group that exists.
public struct PaywallTexts: Sendable {
    /// The paywall sheet.
    public let sheet: Sheet
    /// The segmented control between plans and lifetime products. Needed only by an app that
    /// sells both; without it there the segments show no titles, and the log says so.
    public let offerTabs: OfferTabs?
    /// The settings row. Needed by ``PaywallStatusRow``; without it the row stays empty, and the
    /// log says so.
    public let statusRow: StatusRow?

    public init(sheet: Sheet, offerTabs: OfferTabs? = nil, statusRow: StatusRow? = nil) {
        self.sheet = sheet
        self.offerTabs = offerTabs
        self.statusRow = statusRow
    }

    // MARK: - Paywall sheet

    public struct Sheet: Sendable {
        /// The close button in the paywall's toolbar.
        public let dismiss: LocalizedStringResource
        /// Navigation title of the privacy policy page.
        public let privacyPolicyTitle: LocalizedStringResource
        /// Navigation title of the terms page.
        public let termsOfServiceTitle: LocalizedStringResource
        /// Title of the alert after a failed purchase.
        public let purchaseFailedTitle: String
        /// Message of the alert after a failed purchase.
        public let purchaseFailedMessage: String
        /// The restore button at the top right of the paywall, for subscriptions and lifetime products
        /// alike. Shown as text, so keep it short.
        public let restorePurchases: LocalizedStringResource
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

        public init(
            dismiss: LocalizedStringResource,
            privacyPolicyTitle: LocalizedStringResource,
            termsOfServiceTitle: LocalizedStringResource,
            purchaseFailedTitle: String,
            purchaseFailedMessage: String,
            restorePurchases: LocalizedStringResource,
            restoreSucceededTitle: String,
            nothingToRestoreTitle: String,
            restoreFailedTitle: String,
            restoreFailedMessage: String
        ) {
            self.dismiss = dismiss
            self.privacyPolicyTitle = privacyPolicyTitle
            self.termsOfServiceTitle = termsOfServiceTitle
            self.purchaseFailedTitle = purchaseFailedTitle
            self.purchaseFailedMessage = purchaseFailedMessage
            self.restorePurchases = restorePurchases
            self.restoreSucceededTitle = restoreSucceededTitle
            self.nothingToRestoreTitle = nothingToRestoreTitle
            self.restoreFailedTitle = restoreFailedTitle
            self.restoreFailedMessage = restoreFailedMessage
        }
    }

    // MARK: - Segmented control

    public struct OfferTabs: Sendable {
        /// The segment for the subscription plans.
        public let subscription: LocalizedStringResource
        /// The segment for the lifetime products.
        public let oneTime: LocalizedStringResource

        public init(subscription: LocalizedStringResource, oneTime: LocalizedStringResource) {
            self.subscription = subscription
            self.oneTime = oneTime
        }
    }

    // MARK: - Settings row

    public struct StatusRow: Sendable {
        /// The ``PaywallStatusRow`` button that opens the paywall while there is no subscription.
        public let offer: LocalizedStringResource
        /// The accessibility label of ``offer``. Keep the visible words in it, so Voice Control still
        /// finds the button by what it shows.
        public let offerLabel: String
        /// The VoiceOver hint of ``offer``.
        public let offerHint: String
        /// The plan's name until the App Store's own name has loaded.
        public let fallbackPlanName: LocalizedStringResource
        /// The button into the system's subscription management.
        public let manage: LocalizedStringResource
        /// The accessibility label of ``manage``. The visible word is only the verb, so the label says
        /// what is managed and keeps that word for Voice Control.
        public let manageLabel: String
        /// The VoiceOver hint of ``manage``.
        public let manageHint: String
        /// The line under the plan name while it renews, built from the renewal date.
        public let renews: @Sendable (Date) -> Text
        /// The line under the plan name once auto-renew is off, built from the last day of access.
        public let ends: @Sendable (Date) -> Text
        /// The line under the plan name during the grace period after a failed renewal.
        public let billingIssue: String

        public init(
            offer: LocalizedStringResource,
            offerLabel: String,
            offerHint: String,
            fallbackPlanName: LocalizedStringResource,
            manage: LocalizedStringResource,
            manageLabel: String,
            manageHint: String,
            renews: @escaping @Sendable (Date) -> Text,
            ends: @escaping @Sendable (Date) -> Text,
            billingIssue: String
        ) {
            self.offer = offer
            self.offerLabel = offerLabel
            self.offerHint = offerHint
            self.fallbackPlanName = fallbackPlanName
            self.manage = manage
            self.manageLabel = manageLabel
            self.manageHint = manageHint
            self.renews = renews
            self.ends = ends
            self.billingIssue = billingIssue
        }

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
}
