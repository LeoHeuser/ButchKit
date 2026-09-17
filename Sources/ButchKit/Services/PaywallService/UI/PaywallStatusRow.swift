//
//  PaywallStatusRow.swift
//  ButchKit
//
//  Created by Leo Heuser on 03.09.26.
//

import StoreKit
import SwiftUI

/// One settings row that says whether the user pays, and leads somewhere either way.
///
/// A subscriber sees the plan's name, what happens next with it, and the way to the system's
/// own subscription management; a lifetime owner sees what they bought, plus that management
/// while a subscription still renews next to it; everybody else gets the offer. Both of the first
/// are things an app has to have: Apple expects a management path, and a subscriber who cannot
/// find out what they are paying for writes to support instead.
///
/// ```swift
/// Form {
///     Section {
///         PaywallStatusRow(source: "settings")
///     }
/// }
/// ```
///
/// Belongs in a `Form` or a `List`, below the root's `View.paywallEnvironment(_:texts:features:)`.
/// A settings screen presented as a sheet also needs `View.paywallSheet()` on its content,
/// otherwise the paywall has nowhere to appear from. Every word it shows comes from the app's
/// ``PaywallTexts``.
public struct PaywallStatusRow: View {
    private let source: String

    @Environment(PaywallService.self) private var paywall

    /// Creates the row.
    ///
    /// - Parameter source: The app's name for this entry point, carried on every
    ///   ``PaywallEvent`` the row produces. Conventionally `"settings"`.
    public init(source: String) {
        self.source = source
    }

    public var body: some View {
        // Three rows rather than one row that changes its mind: the states share a place in the
        // form, not a shape. What they have in common is only that they sit here.
        //
        // `entitlement` rather than the loaded status, so the row matches what the app unlocks.
        switch paywall.entitlement {
        case .lifetime:
            LifetimeRow()
        case .subscription:
            SubscribedRow()
        case .none:
            UnsubscribedRow(source: source)
        }
    }
}

/// The subscriber's row: the plan they hold, what happens next with it, and the way to the
/// system's management for it.
private struct SubscribedRow: View {
    @Environment(PaywallService.self) private var paywall

    /// The product held, which the name is loaded for. Kept apart from the status so a renewal
    /// of the same plan does not fetch the name again.
    @State private var productID: String?

    @State private var detail: SubscriptionDetail?

    var body: some View {
        LabeledContent {
            ManageSubscriptionButton()
        } label: {
            PlanName(productID: productID)

            if let detail {
                DetailLine(detail: detail, texts: paywall.texts)
            }
        }
        // Runs again on every change StoreKit reports, so a renewal, a cancellation or a plan
        // change shows here without the settings having to be reopened.
        .subscriptionStatus(for: paywall.configuration.subscriptionGroupID) { state in
            // Loading and failure keep what the row already shows: the detail is decoration,
            // and a line that blinks away on a network hiccup would read as a lapsed plan.
            guard case .success(let statuses) = state else { return }
            let plan = HeldPlan.current(in: statuses.compactMap(HeldPlan.init))
            productID = plan?.productID
            detail = plan.flatMap {
                SubscriptionDetail(state: $0.state, willAutoRenew: $0.willAutoRenew, expirationDate: $0.expirationDate)
            }
        }
    }
}

// TODO: Revisit with purchase groups. The configuration should say which App Store Connect
// subscriptions and one-time purchases belong together, so the paywall can resolve the overlap on
// its own: the one-time purchase replaces the subscription, which then does not keep running.
// StoreKit lets no app cancel a subscription itself, so "replaces" means leading the user to the
// cancellation, for example right after the one-time purchase.

/// The lifetime owner's row: what they bought. A one-time purchase has no renewal, no end and no
/// plan to change, so the row offers management only while a subscription next to it still renews,
/// the one thing the user could otherwise keep paying for without finding a way out.
private struct LifetimeRow: View {
    @Environment(PaywallService.self) private var paywall

    /// The lifetime product held, which the name is loaded for.
    @State private var productID: String?

    /// Whether a subscription in the group still renews next to the lifetime purchase.
    @State private var subscriptionRenews = false

    var body: some View {
        LabeledContent {
            if subscriptionRenews {
                ManageSubscriptionButton()
            }
        } label: {
            PlanName(productID: productID)
        }
        .task(findHeldProduct)
        // Follows the subscription live, so the button goes away once the user has cancelled.
        .subscriptionStatus(for: paywall.configuration.subscriptionGroupID) { state in
            guard case .success(let statuses) = state else { return }
            subscriptionRenews = HeldPlan.current(in: statuses.compactMap(HeldPlan.init))?.willAutoRenew == true
        }
    }

    @Sendable private func findHeldProduct() async {
        // The same pass the service decides the entitlement from, so the row never names a
        // product the service did not count.
        productID = await PaywallEntitlementSnapshot.current(under: paywall.configuration).lifetimeProductID
    }
}

/// The way to the system's own subscription management. Apple's screen, not one of ours:
/// cancelling, changing the plan and the renewal date all live there, and none of them is
/// something an app may do on the user's behalf.
private struct ManageSubscriptionButton: View {
    /// Where the App Store keeps subscriptions on the Mac, which has no in-app sheet for them.
    private static let macSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")

    @Environment(PaywallService.self) private var paywall
    @Environment(\.openURL) private var openURL

    /// Only ever set where the sheet exists. On a Mac the button opens the App Store instead and
    /// this stays `false`.
    @State private var managesSubscription = false

    var body: some View {
        Button(paywall.texts.manage, action: manage)
            .accessibilityHint(paywall.texts.manageHint)
            .manageSubscription(isPresented: $managesSubscription, subscriptionGroupID: paywall.configuration.subscriptionGroupID)
    }

    private func manage() {
#if os(iOS)
        // The sheet does not exist on a Mac, and an iPhone or iPad app running there is still
        // compiled for iOS. `isMacCatalystApp` is true for both kinds of app on a Mac.
        if !ProcessInfo.processInfo.isMacCatalystApp {
            managesSubscription = true
            return
        }
#endif
        if let url = Self.macSubscriptionsURL { openURL(url) }
    }
}

/// The name of the product held, as App Store Connect spells it and localized per storefront, so
/// it follows an upgrade or a downgrade, which a name in the app's catalog could not. The app's
/// fallback name stands in until it has loaded, and when it cannot load: the name is decoration
/// here, and the next visit to the settings tries again.
private struct PlanName: View {
    let productID: String?

    @Environment(PaywallService.self) private var paywall
    @State private var name: String?

    var body: some View {
        Group {
            if let name {
                // A product name from App Store Connect, already localized there.
                Text(verbatim: name)
            } else {
                Text(paywall.texts.fallbackPlanName)
            }
        }
        .task(id: productID, loadName)
    }

    @Sendable private func loadName() async {
        guard let productID else { return }
        if let product = try? await Product.products(for: [productID]).first {
            name = product.displayName
        }
    }
}

/// What happens next with the plan, in the line under its name.
private struct DetailLine: View {
    let detail: SubscriptionDetail
    let texts: PaywallTexts

    var body: some View {
        switch detail {
        case .renews(let date):
            texts.renews(date)
        case .ends(let date):
            texts.ends(date)
        case .billingIssue:
            Text(texts.billingIssue)
        }
    }
}

/// Everybody else's row: the offer, shown rather than demanded.
private struct UnsubscribedRow: View {
    let source: String

    @Environment(PaywallService.self) private var paywall

    var body: some View {
        // `present`, not `require`: the settings sell nothing on their own, so there is no
        // action waiting on the other side of a purchase.
        Button(paywall.texts.offer) {
            paywall.present(source: source)
        }
        .accessibilityHint(paywall.texts.offerHint)
    }
}

private extension View {
    /// `manageSubscriptionsSheet` is iOS only. Isolated into a `@ViewBuilder` because a `#if`
    /// around the modifier at the call site would fork the row's type between the platforms.
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

// Guarded because the subscribed previews read a DEBUG-only helper.
#if DEBUG
#Preview("Unsubscribed") {
    Form {
        PaywallStatusRow(source: "preview")
    }
    .environment(PaywallService.preview(.oneSubscription))
}

// Without a purchase in the preview's StoreKit file, the row shows the fallback name and no
// second line.
#Preview("Subscribed") {
    Form {
        PaywallStatusRow(source: "preview")
    }
    .environment(PaywallService.preview(.oneSubscription, entitlement: .subscription))
}

// The product's name loads from `ButchKitPreview.storekit`; until then, the fallback name.
#Preview("Lifetime") {
    Form {
        PaywallStatusRow(source: "preview")
    }
    .environment(PaywallService.preview(.subscriptionsAndOneTimePurchases, entitlement: .lifetime))
}
#endif
