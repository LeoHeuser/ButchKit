//
//  PaywallOneTimeStore.swift
//  ButchKit
//
//  Created by Leo Heuser on 15.09.26.
//

import OSLog
import StoreKit
import SwiftUI

/// The lifetime products, the paywall's second offer next to the subscription plans.
///
/// `SubscriptionStoreView` shows nothing but auto-renewable subscriptions, so the lifetime products
/// get Apple's `ProductView`, one card per product across the full width. Name, description and
/// price come from App Store Connect, localized per storefront, so there is nothing for the app to
/// word. The restore button at the top of the paywall brings these back along with the plans.
struct PaywallOneTimeStore: View {
    @Environment(PaywallService.self) private var paywall

    @State private var policy: Policy?
    /// The products that did not load. Once that is all of them the side has nothing to sell, see
    /// ``unavailable(_:)``. One of several missing is a wrong identifier, which only the log shows.
    @State private var missingProductIDs: Set<String> = []
    /// Changed by the retry button: a `ProductView` loads once, so a new identity loads again.
    @State private var reloadToken = 0

    private var nothingLoaded: Bool {
        missingProductIDs.isSuperset(of: paywall.configuration.lifetimeProductIDs)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if nothingLoaded, let texts = paywall.texts.sheet.productsUnavailable {
                    unavailable(texts)
                }
                ForEach(paywall.configuration.lifetimeProductIDs, id: \.self) { productID in
                    ProductView(id: productID)
                        .productViewStyle(PaywallProductStyle(
                            productID: productID,
                            // The products the user already owns. Their Buy button would sell the
                            // user what is already theirs. Every one of them, not only the one the
                            // entitlement is named after: an app may sell several.
                            isOwned: paywall.ownedLifetimeProductIDs.contains(productID),
                            purchasedLabel: paywall.texts.sheet.purchasedLabel,
                            logger: paywall.logger,
                            onLoad: { loaded in
                                if loaded {
                                    missingProductIDs.remove(productID)
                                } else {
                                    missingProductIDs.insert(productID)
                                }
                            }
                        ))
                        .id(reloadToken)
                }
                policyLinks
            }
            .padding()
        }
        .sheet(item: $policy) { policy in
            NavigationStack {
                GatedWebView(policy.url, title: policy.title)
                    .modifier(DismissSheetButton(title: Text(paywall.texts.sheet.dismiss)))
            }
        }
    }

    /// Said once for the whole side rather than per card, with the way to try again.
    private func unavailable(_ texts: PaywallTexts.Sheet.ProductsUnavailable) -> some View {
        ContentUnavailableView {
            Text(texts.title)
        } description: {
            Text(texts.message)
        } actions: {
            Button(texts.retry) {
                missingProductIDs = []
                reloadToken += 1
            }
        }
    }

    /// One of the two policy pages, open in a sheet.
    private struct Policy: Identifiable {
        let url: String
        let title: LocalizedStringResource
        var id: String { url }
    }

    /// StoreKit draws the policy buttons with its subscription controls and nowhere else, so under
    /// the lifetime products they are ours: the same two pages, by the same rule of both or neither.
    @ViewBuilder
    private var policyLinks: some View {
        if let policies = paywall.configuration.policies {
            HStack(spacing: 24) {
                Button(paywall.texts.sheet.privacyPolicyTitle) {
                    policy = Policy(url: policies.privacy, title: paywall.texts.sheet.privacyPolicyTitle)
                }
                Button(paywall.texts.sheet.termsOfServiceTitle) {
                    policy = Policy(url: policies.terms, title: paywall.texts.sheet.termsOfServiceTitle)
                }
            }
            .font(.footnote)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        }
    }
}

/// One lifetime product as a card across the full width, in the look of Apple's plan cards on the
/// subscription side: name and description, then a Buy button that carries the price, shaped like
/// Apple's Subscribe button. Apple's own styles size the view to its content and centre it.
private struct PaywallProductStyle: ProductViewStyle {
    let productID: String
    let isOwned: Bool
    let purchasedLabel: String?
    let logger: Logger
    /// Tells the store whether the product loaded, see ``PaywallOneTimeStore/missingProductIDs``.
    let onLoad: (Bool) -> Void

    func makeBody(configuration: Configuration) -> some View {
        switch configuration.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding()
        case .success(let product):
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    // App Store Connect's words, already localized per storefront.
                    Text(verbatim: product.displayName)
                        .font(.headline)
                    Text(verbatim: product.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                // Through the configuration rather than `product.purchase()`, so the paywall's
                // purchase handlers see it like any other StoreKit purchase.
                Button {
                    configuration.purchase()
                } label: {
                    Group {
                        if isOwned {
                            Image(systemName: "checkmark")
                                .accessibilityLabel(purchasedLabel ?? product.displayPrice)
                        } else {
                            Text(verbatim: product.displayPrice)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .buttonBorderShape(.capsule)
                .disabled(isOwned)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.tertiary, in: .rect(cornerRadius: 24, style: .continuous))
            .onAppear { onLoad(true) }
        case .failure(let error):
            missingProduct
                .onAppear {
                    logger.error("Lifetime product failed to load: id=\(productID, privacy: .public) \(error.logCode, privacy: .public)")
                    onLoad(false)
                }
        default:
            // A wrong identifier, or a product not yet cleared for sale. Invisible on screen, so
            // the log is the only place it shows before App Review finds it.
            missingProduct
                .onAppear {
                    logger.error("Lifetime product unavailable: id=\(productID, privacy: .public)")
                    onLoad(false)
                }
        }
    }

    /// No card: one without a product would be a dead button. `EmptyView` never appears, so it
    /// could not carry the log line.
    private var missingProduct: some View {
        Color.clear.frame(height: 0)
    }
}

#if DEBUG
// Loads from `ButchKitPreview.storekit`; see the note in `PaywallView.swift` if the cards show
// nothing but a spinner.
#Preview {
    PaywallOneTimeStore()
        .environment(PaywallService.preview(.threeOneTimePurchases))
        .paywallPreviewGround()
}

// Nothing loads: the message and the retry button instead of an empty side.
#Preview("Unavailable") {
    PaywallOneTimeStore()
        .environment(PaywallService.preview(.unavailableOneTimePurchases))
        .paywallPreviewGround()
}
#endif
