//
//  PaywallStatusReader.swift
//  ButchKit
//
//  Created by Leo Heuser on 17.09.26.
//

import StoreKit
import SwiftUI

/// Where the App Store keeps subscriptions on the Mac, which has no in-app sheet for them.
private let macSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")

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
    @Environment(\.openURL) private var openURL

    @State private var heldPlan: HeldPlan?
    @State private var lifetimeProductID: String?
    @State private var loadedName: (productID: String, name: String)?
    /// Only ever set where the sheet exists. On a Mac management opens the App Store instead and
    /// this stays `false`.
    @State private var showsManageSheet = false

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
        // `entitlement` rather than the loaded status, so the row matches what the app unlocks.
        let status = PaywallStatus(
            entitlement: paywall.entitlement,
            isInitialized: paywall.isInitialized,
            hasCachedEntitlement: paywall.hasCachedEntitlement,
            heldPlan: heldPlan,
            lifetimeProductID: lifetimeProductID,
            loadedName: loadedName,
            showPaywall: showPaywall,
            manageSubscription: manageSubscription
        )

        content(status)
            .task(id: paywall.entitlement) { await findLifetimeProduct() }
            .task(id: status.productID) { await loadName(of: status.productID) }
            // Runs again on every change StoreKit reports, so a renewal, a cancellation or a plan
            // change shows without the settings having to be reopened.
            .subscriptionStatus(for: paywall.configuration.subscriptionGroupID) { state in
                // Loading and failure keep what is already known: the detail is decoration, and a
                // line that blinks away on a network hiccup would read as a lapsed plan.
                guard case .success(let statuses) = state else { return }
                heldPlan = HeldPlan.current(in: statuses)
            }
            .manageSubscription(isPresented: $showsManageSheet, subscriptionGroupID: paywall.configuration.subscriptionGroupID)
    }

    private func showPaywall() {
        // `present`, not `require`: a settings row sells nothing on its own, so there is no
        // action waiting on the other side of a purchase.
        paywall.present(source: source)
    }

    private func manageSubscription() {
#if os(iOS)
        // The sheet does not exist on a Mac, and an iPhone or iPad app running there is still
        // compiled for iOS. `isMacCatalystApp` is true for both kinds of app on a Mac.
        if !ProcessInfo.processInfo.isMacCatalystApp {
            showsManageSheet = true
            return
        }
#endif
        if let url = macSubscriptionsURL { openURL(url) }
    }

    private func findLifetimeProduct() async {
        guard paywall.entitlement == .lifetime else { return }
        // The same pass the service decides the entitlement from, so the row never names a
        // product the service did not count.
        lifetimeProductID = await PaywallEntitlementSnapshot.current(under: paywall.configuration).lifetimeProductID
    }

    /// The name is decoration: when it cannot load, the app's fallback stands in, and the next
    /// visit to the settings tries again.
    private func loadName(of productID: String?) async {
        guard let productID, loadedName?.productID != productID else { return }
        if let product = try? await Product.products(for: [productID]).first {
            loadedName = (productID, product.displayName)
        }
    }
}

private extension View {
    /// `manageSubscriptionsSheet` is iOS only. Isolated into a `@ViewBuilder` because a `#if`
    /// around the modifier at the call site would fork the reader's type between the platforms.
    /// Without a group the app sells no subscription, so there is nothing to manage.
    @ViewBuilder
    func manageSubscription(isPresented: Binding<Bool>, subscriptionGroupID: String?) -> some View {
#if os(iOS)
        if let subscriptionGroupID {
            // With the group, the sheet opens on this app's plan rather than on a list the user
            // has to find it in.
            manageSubscriptionsSheet(isPresented: isPresented, subscriptionGroupID: subscriptionGroupID)
        } else {
            self
        }
#else
        self
#endif
    }

    /// `subscriptionStatusTask` for the configured group, and nothing without one: an app that
    /// sells only lifetime products has no status to follow.
    @ViewBuilder
    func subscriptionStatus(
        for subscriptionGroupID: String?,
        action: @escaping @MainActor @Sendable (EntitlementTaskState<[Product.SubscriptionInfo.Status]>) async -> Void
    ) -> some View {
        if let subscriptionGroupID {
            subscriptionStatusTask(for: subscriptionGroupID, action: action)
        } else {
            self
        }
    }
}
