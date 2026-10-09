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
///         Button(action: status.showPaywall) { status.offerTitle }
///             .accessibilityHint(status.offerHint)
///     case .subscription, .lifetime:
///         LabeledContent {
///             if status.canManageSubscription {
///                 Button(action: status.manageSubscription) { status.manageTitle }
///                     .accessibilityLabel(status.manageLabel)
///                     .accessibilityHint(status.manageHint)
///             }
///         } label: {
///             status.planTitle
///             status.detailText
///         }
///     }
/// }
/// ```
///
/// Belongs below the root's `View.paywallEnvironment(_:features:)`. The words above are
/// ButchKit's own, on ``PaywallStatus``; an app may use words of its own instead. A settings screen presented as a sheet also needs `View.paywallSheet()` on its content, otherwise
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
            isEntitlementKnown: paywall.isEntitlementKnown,
            heldPlan: paywall.heldPlan,
            lifetimeProductID: paywall.lifetimeProductID,
            lifetimeIsFamilyShared: paywall.lifetimeIsFamilyShared,
            planNames: paywall.planNames,
            configuredPlanName: paywall.configuration.planName,
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
