//
//  PaywallEnvironment.swift
//  ButchKit
//
//  Created by Leo Heuser on 03.09.26.
//

import SwiftUI

/// Creates the service, injects it and attaches the paywall sheet at the root.
struct PaywallEnvironmentModifier: ViewModifier {
    @State private var service: PaywallService

    init(configuration: PaywallConfiguration, texts: PaywallTexts, features: [PayWallFeature]) {
        _service = State(initialValue: PaywallService(configuration: configuration, texts: texts, features: features))
    }

    func body(content: Content) -> some View {
        content
            .modifier(PaywallSheetModifier(isRoot: true))
            .environment(service)
            .task { await service.initialize() }
    }
}

/// The paywall sheet, bound to `PaywallService.presentedRequest`.
///
/// Only one instance may present at a time, or SwiftUI queues the second presentation behind the
/// first and shows it later. A nested instance announces itself while on screen, and the root
/// instance sees no request for as long as one is.
struct PaywallSheetModifier: ViewModifier {
    let isRoot: Bool

    @Environment(PaywallService.self) private var paywall

    func body(content: Content) -> some View {
        content
            .sheet(
                item: Binding(
                    get: { isRoot && paywall.nestedSheetHosts > 0 ? nil : paywall.presentedRequest },
                    set: { request in
                        if request == nil { paywall.dismissPaywall() }
                    }
                ),
                onDismiss: paywall.paywallDidDismiss
            ) { request in
                PaywallView(request: request)
            }
            .onAppear { if !isRoot { paywall.nestedSheetHosts += 1 } }
            .onDisappear { if !isRoot { paywall.nestedSheetHosts -= 1 } }
    }
}

public extension View {
    /// Root-level entry point. Creates the ``PaywallService``, injects it into the environment,
    /// runs the first entitlement check and attaches the paywall sheet. Apply once at the highest
    /// point of your app.
    ///
    /// ```swift
    /// RootView()
    ///     .paywallEnvironment(paywallConfig, texts: paywallTexts, features: paywallFeatures)
    /// ```
    ///
    /// The pages are optional. Without them the paywall drops its own marketing content and shows
    /// Apple's plain storefront, which brings the app icon, name and the group's App Store Connect
    /// description with it:
    ///
    /// ```swift
    /// RootView()
    ///     .paywallEnvironment(paywallConfig, texts: paywallTexts)
    /// ```
    ///
    /// - Parameters:
    ///   - configuration: The subscription group and policy URLs.
    ///   - texts: Every word the paywall and the settings row show, from the app's own catalogs.
    ///   - features: The marketing pages the paywall shows, in order. Leave them out and the
    ///     paywall shows Apple's own storefront instead.
    func paywallEnvironment(
        _ configuration: PaywallConfiguration,
        texts: PaywallTexts,
        features: [PayWallFeature] = []
    ) -> some View {
        modifier(PaywallEnvironmentModifier(configuration: configuration, texts: texts, features: features))
    }

    /// Reinforcement for views that are themselves presented as a sheet.
    ///
    /// SwiftUI presents one sheet per view. While a Settings sheet is open, the root sheet cannot
    /// appear on top of it, so a `present(source:)` from inside Settings would go nowhere. Apply
    /// this once to the content of such a sheet and the paywall presents from there instead.
    /// Views pushed onto a `NavigationStack` need nothing. Requires that a parent already
    /// applied `.paywallEnvironment(_:texts:features:)`.
    func paywallSheet() -> some View {
        modifier(PaywallSheetModifier(isRoot: false))
    }
}
