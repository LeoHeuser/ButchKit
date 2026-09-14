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
/// own subscription management; everybody else gets the offer. Both are things an app has to
/// have: Apple expects a management path, and a subscriber who cannot find out what they are
/// paying for writes to support instead.
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
        // Two rows rather than one row that changes its mind: the states share a place in the
        // form, not a shape. What they have in common is only that they sit here.
        //
        // `hasSubscription` rather than the loaded status, so the row matches what the app unlocks.
        if paywall.hasSubscription {
            SubscribedRow()
        } else {
            UnsubscribedRow(source: source)
        }
    }
}

/// The subscriber's row: the plan they hold, what happens next with it, and the way to the
/// system's management for it.
private struct SubscribedRow: View {
    /// Where the App Store keeps subscriptions on the Mac, which has no in-app sheet for them.
    private static let macSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")

    @Environment(PaywallService.self) private var paywall
    @Environment(\.openURL) private var openURL

    /// Only ever set where the sheet exists. On a Mac the button opens the App Store instead and
    /// this stays `false`.
    @State private var managesSubscription = false

    /// The product held, which the name below is loaded for. Kept apart from the status so a
    /// renewal of the same plan does not fetch the name again.
    @State private var productID: String?

    /// The App Store's name for the plan held, localized per storefront. It follows the plan
    /// through an upgrade or a downgrade, which a name in the app's catalog could not. `nil`
    /// until it has loaded; the app's fallback name stands in until then.
    @State private var planName: String?

    @State private var detail: SubscriptionDetail?

    var body: some View {
        LabeledContent {
            // Apple's own screen, not one of ours: cancelling, changing the plan and the renewal
            // date all live there, and none of them is something an app may do on the user's
            // behalf.
            Button(paywall.texts.manage, action: manage)
                .accessibilityHint(paywall.texts.manageHint)
        } label: {
            if let planName {
                // A product name from App Store Connect, already localized there.
                Text(verbatim: planName)
            } else {
                Text(paywall.texts.fallbackPlanName)
            }

            if let detail {
                DetailLine(detail: detail, texts: paywall.texts)
            }
        }
        .manageSubscription(isPresented: $managesSubscription, subscriptionGroupID: paywall.configuration.subscriptionGroupID)
        // Runs again on every change StoreKit reports, so a renewal, a cancellation or a plan
        // change shows here without the settings having to be reopened.
        .subscriptionStatusTask(for: paywall.configuration.subscriptionGroupID) { state in
            // Loading and failure keep what the row already shows: the detail is decoration,
            // and a line that blinks away on a network hiccup would read as a lapsed plan.
            guard case .success(let statuses) = state else { return }
            update(from: statuses)
        }
        .task(id: productID, loadPlanName)
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

    private func update(from statuses: [Product.SubscriptionInfo.Status]) {
        let plans = statuses.compactMap { status -> HeldPlan? in
            guard case .verified(let transaction) = status.transaction,
                  case .verified(let renewal) = status.renewalInfo
            else { return nil }
            return HeldPlan(
                state: status.state,
                productID: transaction.productID,
                expirationDate: transaction.expirationDate,
                willAutoRenew: renewal.willAutoRenew
            )
        }
        let plan = HeldPlan.current(in: plans)

        productID = plan?.productID
        detail = plan.flatMap {
            SubscriptionDetail(state: $0.state, willAutoRenew: $0.willAutoRenew, expirationDate: $0.expirationDate)
        }
    }

    @Sendable private func loadPlanName() async {
        guard let productID else { return }

        // A failed fetch leaves the app's fallback name in place. The name is decoration here,
        // and the next visit to the settings tries again.
        if let product = try? await Product.products(for: [productID]).first {
            planName = product.displayName
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
    @ViewBuilder
    func manageSubscription(isPresented: Binding<Bool>, subscriptionGroupID: String) -> some View {
#if os(iOS)
        // With the group, the sheet opens on this app's plan rather than on a list the user
        // has to find it in.
        manageSubscriptionsSheet(isPresented: isPresented, subscriptionGroupID: subscriptionGroupID)
#else
        self
#endif
    }
}

// Guarded because the subscribed preview reads a DEBUG-only initializer.
#if DEBUG
#Preview("Unsubscribed") {
    Form {
        PaywallStatusRow(source: "preview")
    }
    .environment(PaywallService(configuration: .preview, texts: .preview))
}

// Without a purchase in the preview's StoreKit file, the row shows the fallback name and no
// second line.
#Preview("Subscribed") {
    Form {
        PaywallStatusRow(source: "preview")
    }
    .environment(PaywallService(configuration: .preview, texts: .preview, previewSubscribed: true))
}
#endif
