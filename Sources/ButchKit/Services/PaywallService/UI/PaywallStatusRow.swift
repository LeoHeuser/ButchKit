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
    private let systemImage: String?

    @Environment(PaywallService.self) private var paywall

    /// Creates the row.
    ///
    /// - Parameters:
    ///   - source: The app's name for this entry point, carried on every ``PaywallEvent`` the
    ///     row produces. Conventionally `"settings"`.
    ///   - systemImage: An SF Symbol in front of the row, for a settings screen whose rows all
    ///     carry one. The same symbol in every state. Anything beyond an icon is a row of the
    ///     app's own on ``PaywallStatusReader``.
    public init(source: String, systemImage: String? = nil) {
        self.source = source
        self.systemImage = systemImage
    }

    public var body: some View {
        if let texts = paywall.texts.statusRow {
            PaywallStatusReader(source: source) { status in
                switch status.entitlement {
                case .none where status.isLoading:
                    // Nothing cached and StoreKit still to answer: a subscriber who just
                    // reinstalled must not be offered a subscription.
                    ProgressView()
                        .frame(maxWidth: .infinity)
                case .none:
                    Button(action: status.showPaywall) {
                        withIcon { Text(texts.offer) }
                    }
                        .accessibilityLabel(texts.offerLabel)
                        .accessibilityHint(texts.offerHint)
                case .subscription, .lifetime:
                    LabeledContent {
                        if status.canManageSubscription {
                            Button(texts.manage, action: status.manageSubscription)
                                .accessibilityLabel(texts.manageLabel)
                                .accessibilityHint(texts.manageHint)
                        }
                    } label: {
                        withIcon {
                            texts.planName(status.planName)

                            if let detail = status.detail {
                                texts.detail(detail)
                            }
                        }
                    }
                }
            }
        } else {
            Color.clear.frame(height: 0)
                .onAppear { paywall.logger.fault("PaywallStatusRow has no words: PaywallTexts.statusRow is missing") }
        }
    }

    /// The row's words behind its symbol, or on their own without one. The symbol is decoration:
    /// the words already say everything VoiceOver needs.
    @ViewBuilder
    private func withIcon(@ViewBuilder _ title: () -> some View) -> some View {
        if let systemImage {
            Label {
                VStack(alignment: .leading) { title() }
            } icon: {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
            }
        } else {
            title()
        }
    }
}

// Guarded because the subscribed previews read a DEBUG-only helper.
#if DEBUG
#Preview("Unsubscribed") {
    Form {
        PaywallStatusRow(source: "preview")
    }
    .paywallEnvironment(.preview(.oneSubscription, entitlement: .none))
}

// Nothing cached and no answer yet, as on the first launch after an install.
#Preview("Loading") {
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
    .paywallEnvironment(.preview(.oneSubscription, entitlement: .subscription))
}

// The product's name loads from `ButchKitPreview.storekit`; until then, the fallback name.
#Preview("Lifetime") {
    Form {
        PaywallStatusRow(source: "preview")
    }
    .paywallEnvironment(.preview(.subscriptionsAndOneTimePurchases, entitlement: .lifetime))
}
#endif
