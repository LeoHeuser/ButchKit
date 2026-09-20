//
//  PaywallEnvironment.swift
//  ButchKit
//
//  Created by Leo Heuser on 03.09.26.
//

import SwiftUI

/// Creates the service and keeps it for the life of the view, for an app that does not own one.
struct PaywallEnvironmentModifier: ViewModifier {
    @State private var service: PaywallService

    init(configuration: PaywallConfiguration, texts: PaywallTexts, features: [PaywallFeature], onEvent: ((PaywallEvent) -> Void)?) {
        let service = PaywallService(configuration: configuration, texts: texts, features: features)
        // Set before the first `initialize()`, so the launch's subscription status never goes
        // out to a listener that has not arrived yet.
        service.onEvent = onEvent
        _service = State(initialValue: service)
    }

    func body(content: Content) -> some View {
        content.modifier(PaywallRootModifier(service: service))
    }
}

/// Injects the service, starts it and attaches the paywall sheet at the root.
struct PaywallRootModifier: ViewModifier {
    let service: PaywallService

    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .modifier(PaywallSheetModifier())
            .environment(service)
            .task { await service.initialize() }
            .onChange(of: scenePhase) { _, phase in
                // A subscription that ran out in the background produced no transaction to hear
                // of. Not before the first check: the launch reads on its own.
                guard phase == .active, service.isInitialized, service.configuration.refreshesOnForeground else { return }
                Task { await service.refresh() }
            }
    }
}

/// The paywall sheet, bound to `PaywallService.presentedRequest`.
///
/// Only one instance may present at a time, or SwiftUI queues the second presentation behind the
/// first and shows it later. Each instance registers itself with the service while on screen, and
/// the innermost one presents; see ``PaywallService/presents(_:)``.
struct PaywallSheetModifier: ViewModifier {
    @Environment(PaywallService.self) private var paywall

    /// This host's identity, fixed for the life of the view.
    @State private var hostID = UUID()

    func body(content: Content) -> some View {
        content
            .sheet(
                item: Binding(
                    get: { paywall.presents(hostID) ? paywall.presentedRequest : nil },
                    set: { request in
                        if request == nil { paywall.dismissPaywall() }
                    }
                ),
                onDismiss: paywall.paywallDidDismiss
            ) { request in
                PaywallView(request: request)
            }
            .onAppear { paywall.registerSheetHost(hostID) }
            .onDisappear { paywall.unregisterSheetHost(hostID) }
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
    ///   - onEvent: Where every ``PaywallEvent`` goes, usually the app's analytics.
    func paywallEnvironment(
        _ configuration: PaywallConfiguration,
        texts: PaywallTexts,
        features: [PaywallFeature] = [],
        onEvent: ((PaywallEvent) -> Void)? = nil
    ) -> some View {
        modifier(PaywallEnvironmentModifier(configuration: configuration, texts: texts, features: features, onEvent: onEvent))
    }

    /// The same for an app that owns its ``PaywallService``: one with several windows, which
    /// would otherwise run one service per window, or one whose code outside the view hierarchy
    /// needs the answer too. The app builds the service once, keeps it, and hands it to every
    /// scene's root:
    ///
    /// ```swift
    /// @main
    /// struct MyApp: App {
    ///     @State private var paywall = PaywallService(configuration: paywallConfig, texts: paywallTexts)
    ///
    ///     var body: some Scene {
    ///         WindowGroup {
    ///             RootView()
    ///                 .paywallEnvironment(paywall)
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// Set ``PaywallService/onEvent`` before the first scene appears, in the app's `init`, or the
    /// launch's subscription status goes out to nobody. In a preview, pass a service made with
    /// `previewEntitlement:` to see what a paying user sees.
    func paywallEnvironment(_ service: PaywallService) -> some View {
        modifier(PaywallRootModifier(service: service))
    }

    /// Reinforcement for views that are themselves presented as a sheet.
    ///
    /// SwiftUI presents one sheet per view. While a Settings sheet is open, the root sheet cannot
    /// appear on top of it, so a `present(source:)` from inside Settings would go nowhere. Apply
    /// this once to the content of such a sheet and the paywall presents from there instead.
    /// Views pushed onto a `NavigationStack` need nothing. Requires that a parent already
    /// applied `.paywallEnvironment(_:texts:features:)`.
    func paywallSheet() -> some View {
        modifier(PaywallSheetModifier())
    }
}
