//
//  PaywallStrings.swift
//  ButchKit
//
//  Created by Leo Heuser on 09.10.26.
//

import Foundation

/// Every word the paywall and its settings row show, from `Paywall.xcstrings` in this module.
///
/// ButchKit words these itself, so an app hands in nothing. Each string follows the language the
/// app runs in: a package's catalog only offers what the app's own bundle also offers, so the
/// paywall never speaks a language the rest of the app does not. A language the app supports and
/// this catalog lacks falls back to English, so the catalog carries every language a consuming
/// app ships.
///
/// Resources rather than strings, so SwiftUI resolves each one when it draws, in the language of
/// the view's environment. The English stands here as the default value, which Xcode extracts into
/// the catalog as its source.
enum PaywallStrings {

    // MARK: - Paywall sheet

    static var dismiss: LocalizedStringResource {
        LocalizedStringResource("button.paywall.dismiss", defaultValue: "Close", table: "Paywall", bundle: .module,
               comment: "Button that closes the paywall. Shown as an X, read aloud by VoiceOver.")
    }

    static var privacyPolicy: LocalizedStringResource {
        LocalizedStringResource("label.paywall.privacyPolicy", defaultValue: "Privacy Policy", table: "Paywall", bundle: .module,
               comment: "Link to the privacy policy under the purchase options, and the title of the page it opens.")
    }

    static var termsOfService: LocalizedStringResource {
        LocalizedStringResource("label.paywall.termsOfService", defaultValue: "Terms of Service", table: "Paywall", bundle: .module,
               comment: "Link to the terms under the purchase options, and the title of the page it opens. Matches the App Store's own wording next to subscriptions.")
    }

    static var policyConnector: LocalizedStringResource {
        LocalizedStringResource("label.paywall.policyConnector", defaultValue: " and ", table: "Paywall", bundle: .module,
               comment: "The word between the two policy links: 'Terms of Service and Privacy Policy'. Includes the spaces around it, so a language that writes none, such as Chinese, leaves them out.")
    }

    static var restorePurchases: LocalizedStringResource {
        LocalizedStringResource("button.paywall.restorePurchases", defaultValue: "Restore", table: "Paywall", bundle: .module,
               comment: "Paywall button that brings back earlier purchases, for example on a new device. Shown as text in a small button, so keep it short.")
    }

    static var purchaseFailedTitle: LocalizedStringResource {
        LocalizedStringResource("error.paywall.purchaseFailed.title", defaultValue: "Purchase Failed", table: "Paywall", bundle: .module,
               comment: "Title of the alert after a purchase failed.")
    }

    static var purchaseFailedMessage: LocalizedStringResource {
        LocalizedStringResource("error.paywall.purchaseFailed.message", defaultValue: "Nothing was unlocked. Try again. If you were already charged, use Restore.", table: "Paywall", bundle: .module,
               comment: "Message of the alert after a purchase failed. 'Restore' is the paywall's restore button and must match its translation.")
    }

    static var restoreSucceededTitle: LocalizedStringResource {
        LocalizedStringResource("alert.paywall.restore.succeeded.title", defaultValue: "Purchases Restored", table: "Paywall", bundle: .module,
               comment: "Title of the alert after restoring brought a purchase back. One sentence, the alert has no message.")
    }

    static var nothingToRestoreTitle: LocalizedStringResource {
        LocalizedStringResource("alert.paywall.restore.nothingFound.title", defaultValue: "Nothing to Restore", table: "Paywall", bundle: .module,
               comment: "Title of the alert after restoring found no earlier purchase. One sentence, the alert has no message.")
    }

    static var restoreFailedTitle: LocalizedStringResource {
        LocalizedStringResource("error.paywall.restoreFailed.title", defaultValue: "Restore Failed", table: "Paywall", bundle: .module,
               comment: "Title of the alert after restoring failed, for example because a purchase did not pass verification.")
    }

    static var restoreFailedMessage: LocalizedStringResource {
        LocalizedStringResource("error.paywall.restoreFailed.message", defaultValue: "Your purchases could not be restored. Try again later.", table: "Paywall", bundle: .module,
               comment: "Message of the alert after restoring failed for a reason other than a missing connection.")
    }

    static var restoreOfflineTitle: LocalizedStringResource {
        LocalizedStringResource("error.paywall.restoreOffline.title", defaultValue: "No Connection", table: "Paywall", bundle: .module,
               comment: "Title of the alert after restoring failed because the App Store could not be reached.")
    }

    static var restoreOfflineMessage: LocalizedStringResource {
        LocalizedStringResource("error.paywall.restoreOffline.message", defaultValue: "The App Store could not be reached. Check your internet connection and try again.", table: "Paywall", bundle: .module,
               comment: "Message of the alert after restoring failed because the App Store could not be reached.")
    }

    static var purchased: LocalizedStringResource {
        LocalizedStringResource("accessibility.label.paywall.purchased", defaultValue: "Purchased", table: "Paywall", bundle: .module,
               comment: "VoiceOver label of the checkmark that replaces the Buy button of a one-time purchase the user already owns.")
    }

    static var productsUnavailableTitle: LocalizedStringResource {
        LocalizedStringResource("error.paywall.productsUnavailable.title", defaultValue: "Purchases Unavailable", table: "Paywall", bundle: .module,
               comment: "Title shown in place of the one-time purchases when none of them could be loaded.")
    }

    static var productsUnavailableMessage: LocalizedStringResource {
        LocalizedStringResource("error.paywall.productsUnavailable.message", defaultValue: "Check your connection and try again.", table: "Paywall", bundle: .module,
               comment: "Message under that title. The usual cause is a missing connection.")
    }

    static var retry: LocalizedStringResource {
        LocalizedStringResource("button.paywall.retry", defaultValue: "Try Again", table: "Paywall", bundle: .module,
               comment: "Button that loads the one-time purchases again after they could not be loaded.")
    }

    // MARK: - Segmented control

    static var subscriptionTab: LocalizedStringResource {
        LocalizedStringResource("label.paywall.tab.subscription", defaultValue: "Subscription", table: "Paywall", bundle: .module,
               comment: "Segment of the paywall that shows the subscription plans, next to the one-time purchases.")
    }

    static var oneTimeTab: LocalizedStringResource {
        LocalizedStringResource("label.paywall.tab.oneTime", defaultValue: "One-Time Purchase", table: "Paywall", bundle: .module,
               comment: "Segment of the paywall that shows the one-time purchases, next to the subscription plans.")
    }

    // MARK: - Lifetime next to a subscription

    static var overlapTitle: LocalizedStringResource {
        LocalizedStringResource("alert.paywall.subscriptionOverlap.title", defaultValue: "Your Subscription Is Still Active", table: "Paywall", bundle: .module,
               comment: "Title of the alert after a one-time purchase that unlocks everything, while the user's subscription still renews.")
    }

    static var overlapMessage: LocalizedStringResource {
        LocalizedStringResource("alert.paywall.subscriptionOverlap.message", defaultValue: "Your purchase unlocks everything for good. The subscription renews until you cancel it.", table: "Paywall", bundle: .module,
               comment: "Message of that alert. The app cannot cancel the subscription itself, so it explains why the user should.")
    }

    static var manageSubscription: LocalizedStringResource {
        LocalizedStringResource("button.paywall.manageSubscription", defaultValue: "Manage Subscription", table: "Paywall", bundle: .module,
               comment: "Button in that alert which opens the system's subscription management.")
    }

    static var later: LocalizedStringResource {
        LocalizedStringResource("button.paywall.later", defaultValue: "Later", table: "Paywall", bundle: .module,
               comment: "Button in that alert which closes it and leaves the subscription alone.")
    }

    // MARK: - Settings row

    static var offer: LocalizedStringResource {
        LocalizedStringResource("button.paywallStatus.offer", defaultValue: "Upgrade", table: "Paywall", bundle: .module,
               comment: "Settings button that opens the paywall, while the user pays for nothing.")
    }

    /// The same with the app's name for what it sells, see ``PaywallConfiguration/planName``.
    static func offer(planName: String) -> LocalizedStringResource {
        LocalizedStringResource("button.paywallStatus.offer.named", defaultValue: "Upgrade to \(planName)", table: "Paywall", bundle: .module,
               comment: "Settings button that opens the paywall, while the user pays for nothing. The placeholder is the name of what the app sells, for example 'Pro'.")
    }

    static var offerHint: LocalizedStringResource {
        LocalizedStringResource("accessibility.hint.paywallStatus.offer", defaultValue: "Opens the purchase options.", table: "Paywall", bundle: .module,
               comment: "VoiceOver hint of the settings button that opens the paywall.")
    }

    static var subscriptionPlan: LocalizedStringResource {
        LocalizedStringResource("label.paywallStatus.subscription", defaultValue: "Subscription", table: "Paywall", bundle: .module,
               comment: "Settings row for a subscriber, in place of the plan's name until the App Store has provided it.")
    }

    static var lifetimePlan: LocalizedStringResource {
        LocalizedStringResource("label.paywallStatus.lifetime", defaultValue: "Lifetime Purchase", table: "Paywall", bundle: .module,
               comment: "Settings row for a user who bought the app once, in place of the product's name until the App Store has provided it.")
    }

    static var manage: LocalizedStringResource {
        LocalizedStringResource("button.paywallStatus.manage", defaultValue: "Manage", table: "Paywall", bundle: .module,
               comment: "Settings button that opens the system's subscription management. Next to the plan's name, so the verb alone.")
    }

    static var manageLabel: LocalizedStringResource {
        LocalizedStringResource("accessibility.label.paywallStatus.manage", defaultValue: "Manage Subscription", table: "Paywall", bundle: .module,
               comment: "VoiceOver label of that button. Keeps the visible word, so Voice Control still finds it.")
    }

    static var manageHint: LocalizedStringResource {
        LocalizedStringResource("accessibility.hint.paywallStatus.manage", defaultValue: "Opens subscription management.", table: "Paywall", bundle: .module,
               comment: "VoiceOver hint of that button.")
    }

    static func renews(on date: String) -> LocalizedStringResource {
        LocalizedStringResource("label.paywallStatus.renews", defaultValue: "Renews \(date)", table: "Paywall", bundle: .module,
               comment: "Line under the plan's name in the settings while the subscription renews. The placeholder is the renewal date.")
    }

    static func ends(on date: String) -> LocalizedStringResource {
        LocalizedStringResource("label.paywallStatus.ends", defaultValue: "Ends \(date)", table: "Paywall", bundle: .module,
               comment: "Line under the plan's name in the settings once auto-renew is off. The placeholder is the last day of access.")
    }

    static var billingIssue: LocalizedStringResource {
        LocalizedStringResource("error.paywallStatus.billingIssue", defaultValue: "Payment issue. Check your payment method.", table: "Paywall", bundle: .module,
               comment: "Line under the plan's name in the settings while the App Store cannot charge a renewal.")
    }
}

private extension LocalizedStringResource.BundleDescription {
    /// This module's resource bundle, where `Paywall.xcstrings` is compiled to.
    static var module: Self { .atURL(Bundle.module.bundleURL) }
}
