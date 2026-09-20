//
//  ManageSubscriptionModifier.swift
//  ButchKit
//
//  Created by Leo Heuser on 20.09.26.
//

import StoreKit
import SwiftUI

/// Where the App Store keeps subscriptions on the Mac, which has no in-app sheet for them.
private let macSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")

/// Opens the system's own subscription management when asked to: the sheet on iPhone and iPad,
/// the App Store on a Mac. One place for it, so the settings row and the alert after a lifetime
/// purchase lead to the same thing.
struct ManageSubscriptionModifier: ViewModifier {
    /// Set to `true` to open the management. Taken back at once: it is a request, not a state.
    @Binding var isRequested: Bool
    let subscriptionGroupID: String?

    @Environment(\.openURL) private var openURL
    @Environment(\.device) private var device
    /// Only ever set where the sheet exists. On a Mac management opens the App Store instead and
    /// this stays `false`.
    @State private var showsManageSheet = false

    func body(content: Content) -> some View {
        content
            .manageSubscriptionsSheet(isPresented: $showsManageSheet, in: subscriptionGroupID)
            .onChange(of: isRequested) { _, requested in
                guard requested else { return }
                isRequested = false
                open()
            }
    }

    private func open() {
        // The sheet does not exist on a Mac, and an iPhone or iPad app running there is still
        // compiled for iOS, so the platform alone does not answer this. ``Device`` is the SDK's
        // one answer to it, and a preview can flip the branch without switching simulators.
        guard device.isMac else {
            showsManageSheet = true
            return
        }
        if let url = macSubscriptionsURL { openURL(url) }
    }
}

private extension View {
    /// `manageSubscriptionsSheet` is iOS only. Isolated into a `@ViewBuilder` because a `#if`
    /// around the modifier at the call site would fork the caller's type between the platforms.
    /// Without a group the app sells no subscription, so there is nothing to manage.
    @ViewBuilder
    func manageSubscriptionsSheet(isPresented: Binding<Bool>, in subscriptionGroupID: String?) -> some View {
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
}
