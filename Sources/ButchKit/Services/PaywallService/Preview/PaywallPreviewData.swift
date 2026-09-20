//
//  PaywallPreviewData.swift
//  ButchKit
//
//  Created by Leo Heuser on 03.09.26.
//

import SwiftUI

#if DEBUG
extension PaywallTexts {
    /// Plain English in place of keys: a package has no catalog, so a preview shows whatever it
    /// is given.
    static let preview = PaywallTexts(
        sheet: Sheet(
            dismiss: "Close",
            privacyPolicyTitle: "Privacy Policy",
            termsOfServiceTitle: "Terms of Service",
            purchaseFailedTitle: "The purchase didn't go through",
            purchaseFailedMessage: "Nothing was charged. Try again in a moment.",
            restorePurchases: "Restore Purchases",
            restoreSucceededTitle: "Purchase Restored",
            nothingToRestoreTitle: "No Purchase to Restore",
            restoreFailedTitle: "Restore Failed",
            restoreFailedMessage: "Your purchase could not be restored. Try again in a moment.",
            restoreOffline: .init(
                title: "No Connection",
                message: "The App Store could not be reached. Check your internet connection and try again."
            ),
            purchasedLabel: "Purchased",
            productsUnavailable: .init(
                title: "Purchases Unavailable",
                message: "Check your connection and try again.",
                retry: "Try Again"
            )
        ),
        offerTabs: OfferTabs(subscription: "Subscription", oneTime: "One-Time Purchase"),
        statusRow: StatusRow(
            offer: "See subscription plans",
            offerLabel: "See subscription plans",
            offerHint: "Opens the subscription offer.",
            fallbackPlanName: "Plus",
            manage: "Manage",
            manageLabel: "Manage subscription",
            manageHint: "Opens Apple's subscription management.",
            renews: { Text("Renews on \($0, format: .dateTime.day().month().year())") },
            ends: { Text("Ends on \($0, format: .dateTime.day().month().year())") },
            billingIssue: "Payment didn't go through."
        ),
        subscriptionOverlap: SubscriptionOverlap(
            title: "Your subscription is still running",
            message: "Your purchase unlocks everything for good. The subscription renews until you cancel it.",
            manage: "Manage Subscription",
            later: "Later"
        )
    )
}

extension ImageResource {
    /// The placeholders in `PaywallPreviewAssets.xcassets`, standing in for an app's own photos.
    /// Only Xcode compiles the catalog, so these resolve in previews and nowhere else.
    static func previewPhoto(_ index: Int) -> ImageResource {
        ImageResource(name: "PaywallPreview\(index)", bundle: .module)
    }
}

extension PaywallFeature {
    /// The four shapes a page can take. Every preview in the module draws from these, so the
    /// sample copy lives in one place.
    static let previewFull = PaywallFeature(
        title: "Write without limits",
        description: "Unlimited scripts, scenes and characters.",
        image: .previewPhoto(1)
    )

    static let previewWithoutDescription = PaywallFeature(title: "Everywhere you are", image: .previewPhoto(2))

    static let previewWithoutPhoto = PaywallFeature(
        title: "Export like a pro",
        description: "Industry-standard PDF and Final Draft files in one tap."
    )

    static let previewTitleOnly = PaywallFeature(title: "One subscription, every device")
}

extension [PaywallFeature] {
    /// Three pages with photos, the case an app ships.
    static let previewFeatures: [PaywallFeature] = [
        .previewFull,
        PaywallFeature(
            title: "Everywhere you are",
            description: "Your work stays in sync across iPhone, iPad and Mac.",
            image: .previewPhoto(2)
        ),
        PaywallFeature(
            title: "Export like a pro",
            description: "Industry-standard PDF and Final Draft files in one tap.",
            image: .previewPhoto(3)
        )
    ]

    /// The same three pages without photos, for the text-only layout.
    static let previewFeaturesWithoutPhotos: [PaywallFeature] = Self.previewFeatures
        .map { PaywallFeature(title: $0.title, description: $0.description) }

    /// All four page shapes in one swipeable set. Swipe through it to see how the two layouts
    /// sit next to each other.
    static let previewFeaturesMixed: [PaywallFeature] = [
        .previewFull, .previewWithoutDescription, .previewWithoutPhoto, .previewTitleOnly
    ]
}

extension View {
    /// The dark ground the paywall forces on itself, so a preview shows a page as the paywall does.
    func paywallPreviewGround() -> some View {
        background(.black).preferredColorScheme(.dark)
    }
}
#endif
