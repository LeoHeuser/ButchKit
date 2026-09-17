//
//  PaywallStatusRow.swift
//  ButchKit
//
//  Created by Leo Heuser on 03.09.26.
//

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
/// Belongs in a `Form` or a `List`, placed like ``PaywallStatusReader``, which it is built on. Every
/// word it shows comes from the app's ``PaywallTexts``. An app that wants its own look builds the
/// row on the reader instead.
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
        PaywallStatusReader(source: source) { status in
            switch status.entitlement {
            case .none:
                Button(paywall.texts.offer, action: status.showPaywall)
                    .accessibilityHint(paywall.texts.offerHint)
            case .subscription, .lifetime:
                LabeledContent {
                    if status.canManageSubscription {
                        Button(paywall.texts.manage, action: status.manageSubscription)
                            .accessibilityHint(paywall.texts.manageHint)
                    }
                } label: {
                    paywall.texts.planName(status.planName)

                    if let detail = status.detail {
                        paywall.texts.detail(detail)
                    }
                }
            }
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
