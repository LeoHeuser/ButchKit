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

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(paywall.configuration.lifetimeProductIDs, id: \.self) { productID in
                    ProductView(id: productID)
                        .productViewStyle(PaywallProductStyle(productID: productID, logger: paywall.logger))
                }
            }
            .padding()
        }
    }
}

/// One lifetime product as a card across the full width, in the look of Apple's plan cards on the
/// subscription side: name and description, then a Buy button that carries the price, shaped like
/// Apple's Subscribe button. Apple's own styles size the view to its content and centre it.
private struct PaywallProductStyle: ProductViewStyle {
    let productID: String
    let logger: Logger

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
                    Text(verbatim: product.displayPrice)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .buttonBorderShape(.capsule)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.tertiary, in: .rect(cornerRadius: 24, style: .continuous))
        case .failure(let error):
            missingProduct
                .onAppear { logger.error("Lifetime product failed to load: id=\(productID, privacy: .public) \(error.logCode, privacy: .public)") }
        default:
            // A wrong identifier, or a product not yet cleared for sale. Invisible on screen, so
            // the log is the only place it shows before App Review finds it.
            missingProduct
                .onAppear { logger.error("Lifetime product unavailable: id=\(productID, privacy: .public)") }
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
#endif
