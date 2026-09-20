//
//  PaywallPreviewStore.swift
//  ButchKit
//
//  Created by Leo Heuser on 17.09.26.
//

import SwiftUI

#if DEBUG
/// The product setups the paywall previews cover, from the smallest paywall to the fullest.
///
/// Every setup lives in the single `ButchKitPreview.storekit` next to this file, which the ButchKit
/// Previews scheme in `Development/ButchKit.xcworkspace` selects. A scheme holds one StoreKit
/// configuration, and the previews read that one: separate files would mean only one setup could
/// load at a time, while one file lets every preview work at once. Debug only, like the preview data
/// next to it, so no preview code reaches an app's release build.
enum PaywallPreviewStore {
    /// One monthly plan, the simplest paywall there is.
    case oneSubscription
    /// Weekly, monthly and yearly in one group, the yearly with a free week.
    case threeSubscriptions
    /// A single lifetime product and no subscription.
    case oneOneTimePurchase
    /// Three lifetime products and no subscription.
    case threeOneTimePurchases
    /// The three plans next to the three lifetime products, which brings in the segmented control.
    case subscriptionsAndOneTimePurchases
    /// Lifetime products the store does not know, as when none of them load.
    case unavailableOneTimePurchases

    private static let lifetimeProductIDs = [
        "design.heuser.butchkit.preview.lifetime",
        "design.heuser.butchkit.preview.lifetimeSupporter",
        "design.heuser.butchkit.preview.lifetimePatron"
    ]

    var configuration: PaywallConfiguration {
        switch self {
        case .oneSubscription:
            PaywallConfiguration(subscriptionGroupID: "B07C4A12")
        case .threeSubscriptions:
            PaywallConfiguration(subscriptionGroupID: "B07C4A21")
        case .oneOneTimePurchase:
            PaywallConfiguration(lifetimeProductIDs: [Self.lifetimeProductIDs[0]])
        case .threeOneTimePurchases:
            PaywallConfiguration(lifetimeProductIDs: Self.lifetimeProductIDs)
        case .unavailableOneTimePurchases:
            PaywallConfiguration(lifetimeProductIDs: ["design.heuser.butchkit.preview.unknown"])
        case .subscriptionsAndOneTimePurchases:
            PaywallConfiguration(subscriptionGroupID: "B07C4A21", lifetimeProductIDs: Self.lifetimeProductIDs)
        }
    }
}

extension PaywallService {
    /// A service over one preview store, for previews that need the products and nothing else.
    static func preview(_ store: PaywallPreviewStore) -> PaywallService {
        PaywallService(configuration: store.configuration, texts: .preview)
    }

    /// The same with a fixed answer for ``entitlement``, for previews of what a paying user sees.
    static func preview(_ store: PaywallPreviewStore, entitlement: PaywallEntitlement) -> PaywallService {
        PaywallService(configuration: store.configuration, texts: .preview, previewEntitlement: entitlement)
    }
}

extension PaywallView {
    /// The whole paywall over one preview store, with the photo pages unless told otherwise. Pass
    /// `[]` for a paywall without pages.
    static func preview(_ store: PaywallPreviewStore, features: [PaywallFeature] = .previewFeatures) -> some View {
        PaywallView(request: PaywallRequest(source: "preview"))
            .environment(PaywallService(configuration: store.configuration, texts: .preview, features: features))
    }
}
#endif
