//
//  PaywallPreviewData.swift
//  ButchKit
//
//  Created by Leo Heuser on 03.09.26.
//

import SwiftUI

extension PaywallConfiguration {
    /// One monthly subscription, the simplest paywall there is.
    ///
    /// Both groups live in the single `ButchKitPreview.storekit` next to this file. Only one
    /// StoreKit configuration is ever active, so two files would mean only half the previews
    /// could load; two groups in one file means every preview works at the same time.
    static let preview = PaywallConfiguration(subscriptionGroupID: "B07C4A12")

    /// Monthly and yearly in one group, the yearly with a free week. Shows how the paywall lays
    /// out more than one tier.
    static let previewTiers = PaywallConfiguration(subscriptionGroupID: "B07C4A21")

    /// The two tiers plus two one-time purchases, so the lifetime segment shows a list rather
    /// than a single product.
    static let previewLifetime = PaywallConfiguration(
        subscriptionGroupID: "B07C4A21",
        lifetimeProductIDs: [
            "design.heuser.butchkit.preview.lifetime",
            "design.heuser.butchkit.preview.lifetimeSupporter"
        ]
    )
}

extension PaywallTexts {
    /// Plain English in place of keys: a package has no catalog, so a preview shows whatever it
    /// is given. Computed for the same reason as the pages below: the closures are not
    /// `Sendable`, which a static constant would require.
    static var preview: PaywallTexts {
        PaywallTexts(
            dismiss: "Close",
            privacyPolicyTitle: "Privacy Policy",
            termsOfServiceTitle: "Terms of Service",
            purchaseFailedTitle: "The purchase didn't go through",
            purchaseFailedMessage: "Nothing was charged. Try again in a moment.",
            subscriptionTab: "Subscription",
            oneTimeTab: "One-Time Purchase",
            restorePurchases: "Restore Purchases",
            restoreSucceededTitle: "Purchase Restored",
            nothingToRestoreTitle: "No Purchase to Restore",
            restoreFailedTitle: "Restore Failed",
            restoreFailedMessage: "Your purchase could not be restored. Check your internet connection and try again.",
            offer: "See subscription plans",
            offerHint: "Opens the subscription offer.",
            fallbackPlanName: "Plus",
            manage: "Manage",
            manageHint: "Opens Apple's subscription management.",
            renews: { Text("Renews on \($0, format: .dateTime.day().month().year())") },
            ends: { Text("Ends on \($0, format: .dateTime.day().month().year())") },
            billingIssue: "Payment didn't go through."
        )
    }
}

extension ImageResource {
    /// The placeholders in `PaywallPreviewAssets.xcassets`, standing in for an app's own photos.
    /// Only Xcode compiles the catalog, so these resolve in previews and nowhere else.
    static func previewPhoto(_ index: Int) -> ImageResource {
        ImageResource(name: "PaywallPreview\(index)", bundle: .module)
    }
}

extension PayWallFeature {
    /// The four shapes a page can take. Every preview in the module draws from these, so the
    /// sample copy lives in one place. Computed rather than stored: `PayWallFeature` is not
    /// `Sendable`, which a static constant would require.
    static var previewFull: PayWallFeature {
        PayWallFeature(
            title: "Write without limits",
            description: "Unlimited scripts, scenes and characters.",
            image: .previewPhoto(1)
        )
    }

    static var previewWithoutDescription: PayWallFeature {
        PayWallFeature(title: "Everywhere you are", image: .previewPhoto(2))
    }

    static var previewWithoutPhoto: PayWallFeature {
        PayWallFeature(
            title: "Export like a pro",
            description: "Industry-standard PDF and Final Draft files in one tap."
        )
    }

    static var previewTitleOnly: PayWallFeature {
        PayWallFeature(title: "One subscription, every device")
    }
}

extension [PayWallFeature] {
    /// Three pages with photos, the case an app ships.
    static var previewFeatures: [PayWallFeature] {
        [
            .previewFull,
            PayWallFeature(
                title: "Everywhere you are",
                description: "Your work stays in sync across iPhone, iPad and Mac.",
                image: .previewPhoto(2)
            ),
            PayWallFeature(
                title: "Export like a pro",
                description: "Industry-standard PDF and Final Draft files in one tap.",
                image: .previewPhoto(3)
            )
        ]
    }

    /// The same three pages without photos, for the text-only layout.
    static var previewFeaturesWithoutPhotos: [PayWallFeature] {
        previewFeatures.map { PayWallFeature(title: $0.title, description: $0.description) }
    }

    /// All four page shapes in one swipeable set. Swipe through it to see how the two layouts
    /// sit next to each other.
    static var previewFeaturesMixed: [PayWallFeature] {
        [.previewFull, .previewWithoutDescription, .previewWithoutPhoto, .previewTitleOnly]
    }
}

extension View {
    /// The dark ground the paywall forces on itself, so a preview shows a page as the paywall does.
    func paywallPreviewGround() -> some View {
        background(.black).preferredColorScheme(.dark)
    }
}
