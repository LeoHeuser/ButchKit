//
//  PaywallStatusReader.swift
//  ButchKit
//
//  Created by Leo Heuser on 17.09.26.
//

import SwiftUI

/// Hands a settings row everything it needs to say what the user pays for, and leaves the look to
/// the app. ButchKit keeps StoreKit, the paywall and the subscription management; the app only
/// draws.
///
/// ```swift
/// PaywallStatusReader(source: "settings") { status in
///     switch status.entitlement {
///     case .none where status.isLoading:
///         ProgressView()
///     case .none:
///         Button(rowTexts.offer, action: status.showPaywall)
///     case .subscription, .lifetime:
///         LabeledContent {
///             if status.canManageSubscription {
///                 Button(rowTexts.manage, action: status.manageSubscription)
///             }
///         } label: {
///             rowTexts.planName(status.planName)
///             if let detail = status.detail {
///                 rowTexts.detail(detail)
///             }
///         }
///     }
/// }
/// ```
///
/// Belongs below the root's `View.paywallEnvironment(_:texts:features:)`. The `rowTexts` above are
/// a ``PaywallTexts/StatusRow`` the app declares for itself, or words of its own altogether. A
/// settings screen presented as a sheet also needs `View.paywallSheet()` on its content, otherwise
/// the paywall has nowhere to appear from. ``PaywallStatusRow`` is the plain row built on this.
public struct PaywallStatusReader<Content: View>: View {
    private let source: String
    private let content: (PaywallStatus) -> Content

    @Environment(PaywallService.self) private var paywall

    @State private var managesSubscription = false

    /// Creates the reader.
    ///
    /// - Parameters:
    ///   - source: The app's name for this entry point, carried on every ``PaywallEvent`` the
    ///     paywall produces from here. Conventionally `"settings"`.
    ///   - content: The row, drawn from the current status.
    public init(source: String, @ViewBuilder content: @escaping (PaywallStatus) -> Content) {
        self.source = source
        self.content = content
    }

    public var body: some View {
        // Everything from the service, which follows StoreKit for the life of the app: a settings
        // screen opened for the tenth time shows the plan at once, with nothing loading in.
        // `entitlement` rather than the plan decides the row, so it matches what the app unlocks.
        let status = PaywallStatus(
            entitlement: paywall.entitlement,
            isInitialized: paywall.isInitialized,
            hasCachedEntitlement: paywall.hasCachedEntitlement,
            heldPlan: paywall.heldPlan,
            lifetimeProductID: paywall.lifetimeProductID,
            lifetimeIsFamilyShared: paywall.lifetimeIsFamilyShared,
            planNames: paywall.planNames,
            showPaywall: showPaywall,
            manageSubscription: { managesSubscription = true }
        )

        content(status)
            .task(id: status.productID) {
                if let productID = status.productID { await paywall.loadPlanName(for: productID) }
            }
            .modifier(ManageSubscriptionModifier(isRequested: $managesSubscription, subscriptionGroupID: paywall.configuration.subscriptionGroupID))
    }

    private func showPaywall() {
        // `present`, not `require`: a settings row sells nothing on its own, so there is no
        // action waiting on the other side of a purchase.
        paywall.present(source: source)
    }
}
