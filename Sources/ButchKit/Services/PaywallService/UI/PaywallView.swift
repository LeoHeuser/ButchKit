//
//  PaywallView.swift
//  ButchKit
//
//  Created by Leo Heuser on 03.09.26.
//

import StoreKit
import SwiftUI

/// The paywall sheet: marketing pages over Apple's `SubscriptionStoreView`. Presented only by the
/// root modifier, never by app code; see ``PaywallService/present(source:)``.
struct PaywallView: View {
    let request: PaywallRequest
    
    @Environment(PaywallService.self) private var paywall
    @State private var showsPurchaseFailedAlert = false
    /// The paywall's own height, measured on the sheet. The marketing pages take a share of it as
    /// their minimum height; see ``PaywallMarketingContent``.
    @State private var paywallHeight: CGFloat = 0
    
    /// Whether the app supplied marketing pages. Without them the paywall hands the whole sheet
    /// to StoreKit, see ``storeView``.
    private var hasFeatures: Bool { !paywall.features.isEmpty }
    
    var body: some View {
        NavigationStack {
            storeView
            // Apple's cancellation button shrinks the content container, banding the full-bleed
            // photos off at the top. The toolbar button below does the same job without the inset.
                .storeButton(.hidden, for: .cancellation)
                .storeButton(.visible, for: .restorePurchases)
                .storeButton(paywall.configuration.hasPolicies ? .visible : .hidden, for: .policies)
                .subscriptionStoreButtonLabel(.action)
            // StoreKit is the only thing that knows the group, so it counts the tiers itself:
            // one plan gets a single action button, several get a picker over one Subscribe
            // button. `.buttons` was fixed here and forced a full-width button per tier,
            // which crushed the marketing pages above it.
                .subscriptionStoreControlStyle(.automatic)
                .policyDestination(for: .privacyPolicy, url: paywall.configuration.privacyPolicyURL, title: paywall.texts.privacyPolicyTitle)
                .policyDestination(for: .termsOfService, url: paywall.configuration.termsOfServiceURL, title: paywall.texts.termsOfServiceTitle)
                .onInAppPurchaseStart { _ in
                    paywall.report(.purchaseStarted(source: request.source))
                }
                .onInAppPurchaseCompletion { _, result in
                    handlePurchaseCompletion(result)
                }
                .alert(Text(paywall.texts.purchaseFailedTitle), isPresented: $showsPurchaseFailedAlert) {
                } message: {
                    Text(paywall.texts.purchaseFailedMessage)
                }
                .onChange(of: paywall.hasSubscription) { _, isActive in
                    // Covers purchase, restore and renewal alike: a restore never reaches
                    // onInAppPurchaseCompletion, it arrives through Transaction.updates.
                    if isActive {
                        paywall.dismissPaywall()
                    }
                }
            // Both only serve the photos: they run the pages up under the status bar. Apple's
            // own header belongs inside the safe area, and it scrolls, so it needs the bar's
            // material behind it or it slides under the close button.
                .ignoresSafeArea(edges: hasFeatures ? .top : [])
#if os(iOS)
                .toolbarBackground(hasFeatures ? .hidden : .automatic, for: .navigationBar)
#endif
                .sheetDismissButton(paywall.texts.dismiss)
        }
        // Measured out here rather than inside: the sheet's height is the same whatever
        // SubscriptionStoreView does with its own layout, and it does not shift when the
        // modifiers above are reordered.
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: geometry.size.height, initial: true) { _, newHeight in
                        paywallHeight = newHeight
                    }
            }
        }
        // The marketing pages put uncolored text on full-bleed photos shot for a dark ground,
        // so the paywall stays dark regardless of the device appearance. Without pages there is
        // no photo to protect and Apple's storefront follows the device like any other sheet.
        .preferredColorScheme(hasFeatures ? .dark : nil)
        // Outside the NavigationStack, so pushing a policy destination cannot fire this twice.
        // This is the funnel's denominator: without it the purchase count has no reference.
        .onAppear {
            paywall.report(.presented(source: request.source))
        }
    }
    
    /// Apple's `SubscriptionStoreView` in one of its two shapes. With pages it takes ours as its
    /// marketing content; without, the init that has no content closure leaves StoreKit its own
    /// header, which carries the app icon, the app name and the group's App Store Connect
    /// description. An empty content closure would give neither, just a blank header.
    @ViewBuilder
    private var storeView: some View {
        if hasFeatures {
            SubscriptionStoreView(groupID: paywall.configuration.subscriptionGroupID, visibleRelationships: .all) {
                PaywallMarketingContent(features: paywall.features, availableHeight: paywallHeight)
            }
        } else {
            SubscriptionStoreView(groupID: paywall.configuration.subscriptionGroupID, visibleRelationships: .all)
        }
    }
    
    private func handlePurchaseCompletion(_ result: Result<Product.PurchaseResult, any Error>) {
        switch result {
        case .success(let purchaseResult):
            switch purchaseResult {
            case .success:
                // Only this path is a fresh purchase from the paywall, and only here is the
                // source known. A free trial start runs through here too.
                paywall.report(.purchaseCompleted(source: request.source))
                paywall.handleSuccessfulPurchase()
            case .pending:
                // Ask to Buy: Apple's UI informs the user, so no app-side alert. The later
                // approval arrives through Transaction.updates.
                paywall.report(.purchasePending(source: request.source))
            case .userCancelled:
                break
            @unknown default:
                break
            }
        case .failure(let error):
            // Backing out of the Apple ID or confirmation sheet is thrown, not returned as
            // `.userCancelled`. Not a failure, so neither the alert nor the funnel sees it.
            if case StoreKitError.userCancelled = error { return }
            paywall.report(.purchaseFailed(source: request.source, reason: error.localizedDescription))
            showsPurchaseFailedAlert = true
        }
    }
}

private extension View {
    /// Attaches a policy destination only when the app configured a URL for it.
    @ViewBuilder
    func policyDestination(for policy: SubscriptionStorePolicyKind, url: String?, title: LocalizedStringKey) -> some View {
        if let url {
            subscriptionStorePolicyDestination(for: policy) {
                NavigationStack {
                    StaticWebView(url, navigationTitle: title)
                }
            }
        } else {
            self
        }
    }
}

// The subscription buttons load from `ButchKitPreview.storekit`, which has to be selected under
// Product > Scheme > Edit Scheme > Run > Options. Xcode drops that reference when it rewrites the
// scheme; re-add it there if a preview shows "Subscription Unavailable" instead of the buttons.
#Preview("Photos (1)") {
    PaywallView(request: PaywallRequest(source: "preview"))
        .environment(PaywallService(configuration: .preview, texts: .preview, features: .previewFeatures))
}

#Preview("Text (1)") {
    PaywallView(request: PaywallRequest(source: "preview"))
        .environment(PaywallService(configuration: .preview, texts: .preview, features: .previewFeaturesWithoutPhotos))
}

// All four page shapes in one set, so the jump between the two layouts is visible while swiping.
#Preview("Mixed (1)") {
    PaywallView(request: PaywallRequest(source: "preview"))
        .environment(PaywallService(configuration: .preview, texts: .preview, features: .previewFeaturesMixed))
}

// The same paywall against a group with two tiers. Both groups are in `ButchKitPreview.storekit`,
// so these load alongside the three above with nothing to switch.
#Preview("Photos (2)") {
    PaywallView(request: PaywallRequest(source: "preview"))
        .environment(PaywallService(configuration: .previewTiers, texts: .preview, features: .previewFeatures))
}

#Preview("Text (2)") {
    PaywallView(request: PaywallRequest(source: "preview"))
        .environment(PaywallService(configuration: .previewTiers, texts: .preview, features: .previewFeaturesWithoutPhotos))
}

#Preview("Mixed (2)") {
    PaywallView(request: PaywallRequest(source: "preview"))
        .environment(PaywallService(configuration: .previewTiers, texts: .preview, features: .previewFeaturesMixed))
}

// No pages at all: the app never passed any, or passed an empty array. StoreKit takes the whole
// sheet, and the paywall follows the device appearance rather than forcing its dark ground.
#Preview("Empty (1)") {
    PaywallView(request: PaywallRequest(source: "preview"))
        .environment(PaywallService(configuration: .preview, texts: .preview))
}

#Preview("Empty (2)") {
    PaywallView(request: PaywallRequest(source: "preview"))
        .environment(PaywallService(configuration: .previewTiers, texts: .preview))
}
