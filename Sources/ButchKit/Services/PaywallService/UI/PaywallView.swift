//
//  PaywallView.swift
//  ButchKit
//
//  Created by Leo Heuser on 03.09.26.
//

import StoreKit
import SwiftUI

/// The paywall sheet: marketing pages over Apple's `SubscriptionStoreView`. Presented only by the
/// root modifier, never by app code; see ``PaywallService/present(source:)``.
struct PaywallView: View {
    let request: PaywallRequest
    
    @Environment(PaywallService.self) private var paywall
    @State private var showsPurchaseFailedAlert = false
    /// `true` from the tap on the restore button until its outcome is known. The button is
    /// disabled meanwhile, so a second tap cannot start a second sync.
    @State private var isRestoring = false
    /// The last restore's outcome. Kept after its alert closes, so the alert keeps its words while
    /// it fades out; the next restore overwrites it, and it goes with the sheet.
    @State private var restoreOutcome: PaywallRestoreOutcome?
    @State private var showsRestoreAlert = false
    /// The paywall's own height, measured on the sheet. The marketing pages take the app's
    /// ``PaywallConfiguration/featureAreaHeight`` share of it.
    @State private var paywallHeight: CGFloat = 0
    /// Which offer is on screen when the app sells lifetime products next to its plans. The
    /// subscription is always first and the default.
    @State private var offer: Offer = .subscription

    private enum Offer: Hashable {
        case subscription
        case oneTime
    }

    /// Whether the app supplied marketing pages. They decide the paywall's look: full-bleed pages
    /// under the status bar on a dark ground. A `featureAreaHeight` of 0 counts as no pages.
    private var hasFeatures: Bool { !paywall.features.isEmpty && paywall.configuration.featureAreaHeight > 0 }

    /// Whether the app sells lifetime products.
    private var offersOneTime: Bool { !paywall.configuration.lifetimeProductIDs.isEmpty }

    /// Whether the app sells lifetime products next to its plans, which puts the segmented control
    /// under the pages. Without a group it sells lifetime products alone.
    private var offersBoth: Bool { paywall.configuration.subscriptionGroupID != nil && offersOneTime }

    /// Whether the paywall draws its own header: pages, the segmented control, or both. Without
    /// either it hands the whole sheet to StoreKit, see ``storeView``. An app without a group
    /// always sells lifetime products, so it never ends up there.
    private var usesMarketingContent: Bool { hasFeatures || offersOneTime }
    
    var body: some View {
        NavigationStack {
            storeView
            // Apple's cancellation button shrinks the content container, banding the full-bleed
            // photos off at the top. The toolbar button below does the same job without the inset.
                .storeButton(.hidden, for: .cancellation)
            // One restore button for subscriptions and lifetime products, see ``restoreButton``.
            // Apple's would only sync, without reading the entitlements again or saying how it went.
                .storeButton(.hidden, for: .restorePurchases)
                .storeButton(paywall.configuration.hasPolicies ? .visible : .hidden, for: .policies)
                .subscriptionStoreButtonLabel(.action)
            // StoreKit is the only thing that knows the group, so it counts the tiers itself:
            // one plan gets a single action button, several get a picker over one Subscribe
            // button. Under the paywall's own header, `controlsUnderHeader()` replaces this with
            // the picker placed in the scroll view.
                .subscriptionStoreControlStyle(.automatic)
                .policyDestination(for: .privacyPolicy, url: paywall.configuration.privacyPolicyURL, title: paywall.texts.privacyPolicyTitle)
                .policyDestination(for: .termsOfService, url: paywall.configuration.termsOfServiceURL, title: paywall.texts.termsOfServiceTitle)
            // Both handlers cover every StoreKit view inside, the lifetime products included.
                .onInAppPurchaseStart { product in
                    paywall.report(.purchaseStarted(source: request.source, productID: product.id))
                }
                .onInAppPurchaseCompletion { product, result in
                    await handlePurchaseCompletion(of: product, result)
                }
                .alert(Text(paywall.texts.purchaseFailedTitle), isPresented: $showsPurchaseFailedAlert) {
                } message: {
                    Text(paywall.texts.purchaseFailedMessage)
                }
                .alert(Text(restoreAlertTitle), isPresented: $showsRestoreAlert) {
                } message: {
                    if restoreOutcome == .failed {
                        Text(paywall.texts.restoreFailedMessage)
                    }
                }
                .onChange(of: showsRestoreAlert) { _, isPresented in
                    // Closing the alert is the step a restore held back: the sheet closes now if
                    // the app is unlocked.
                    if !isPresented, paywall.hasAccess {
                        paywall.dismissPaywall()
                    }
                }
                .onChange(of: paywall.entitlement) { previous, current in
                    // Covers purchase, renewal and Ask to Buy approvals, which never reach
                    // onInAppPurchaseCompletion. The entitlement rather than `hasAccess`, so a
                    // subscriber buying lifetime closes the sheet too. A restore holds the sheet
                    // until its alert is read.
                    if current > previous, !isRestoring, !showsRestoreAlert {
                        paywall.dismissPaywall()
                    }
                }
            // Only the photos run up to the sheet's edge. Apple's own header, without pages,
            // belongs inside the safe area under the navigation bar.
                .ignoresSafeArea(edges: hasFeatures ? .top : [])
#if os(iOS)
            // With pages there is no navigation bar at all: it counts towards the top safe area,
            // and the paged pages inset themselves by it, banding the photos off under the bar.
            // The close and restore buttons float over the photo instead.
                .toolbar(hasFeatures ? .hidden : .automatic, for: .navigationBar)
                .overlay(alignment: .topLeading) {
                    if hasFeatures {
                        closeButton
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if hasFeatures {
                        restoreButton
                            .closeButtonStyle()
                            .buttonBorderShape(.capsule)
                            .controlSize(.large)
                            .padding()
                    }
                }
#endif
            // Without pages, and on the Mac, both buttons stay in the toolbar, opposite each other.
                .sheetDismissButton(paywall.texts.dismiss)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        restoreButton
                    }
                }
        }
        // Measured out here rather than inside: the sheet's height is the same whatever
        // SubscriptionStoreView does with its own layout, and it does not shift when the
        // modifiers above are reordered.
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: geometry.size.height, initial: true) { _, newHeight in
                        paywallHeight = newHeight
                    }
            }
        }
        // The marketing pages put uncolored text on full-bleed photos shot for a dark ground,
        // so the paywall stays dark regardless of the device appearance. Without pages there is
        // no photo to protect and Apple's storefront follows the device like any other sheet.
        .preferredColorScheme(hasFeatures ? .dark : nil)
        // Outside the NavigationStack, so pushing a policy destination cannot fire this twice.
        // This is the funnel's denominator: without it the purchase count has no reference.
        .onAppear {
            paywall.report(.presented(source: request.source))
        }
    }
    
    /// The whole sheet under the toolbar. With pages or lifetime products, our ``header`` sits
    /// fixed above the ``purchaseArea``, outside StoreKit, so the pages stay in view whatever the
    /// purchases below them do. Without either, the init of `SubscriptionStoreView` that has no
    /// content closure leaves StoreKit its own header, which carries the app icon, the app name
    /// and the group's App Store Connect description. The segmented control alone takes that
    /// header away: with lifetime products next to plans, supply at least one page.
    @ViewBuilder
    private var storeView: some View {
        if usesMarketingContent {
            VStack(spacing: 0) {
                header
                purchaseArea
                    .frame(maxHeight: .infinity)
                    // A cross-fade between the two offers rather than a hard swap.
                    .animation(.smooth, value: offer)
            }
        } else if let groupID = paywall.configuration.subscriptionGroupID {
            SubscriptionStoreView(groupID: groupID, visibleRelationships: .all)
        }
    }

    /// The pages and, with lifetime products next to plans, the segmented control under them. Never scrolls, so
    /// both keep their place whichever offer is selected.
    private var header: some View {
        VStack(spacing: 0) {
            if hasFeatures {
                PaywallMarketingContent(features: paywall.features, height: paywallHeight * paywall.configuration.featureAreaHeight)
            }
            if offersBoth {
                // Each segment reads its own title to VoiceOver, so the picker needs no label.
                Picker(selection: $offer) {
                    Text(paywall.texts.subscriptionTab).tag(Offer.subscription)
                    Text(paywall.texts.oneTimeTab).tag(Offer.oneTime)
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .controlSize(.large)
                .sensoryFeedback(.selection, trigger: offer)
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
    }

    /// What the selected offer sells, under the fixed header. Scrolls on its own when it does not
    /// fit the rest of the sheet. Without a group there is nothing to select: the lifetime products.
    @ViewBuilder
    private var purchaseArea: some View {
        if let groupID = paywall.configuration.subscriptionGroupID, offer == .subscription {
            // An empty marketing slot: the header above already does that job, outside StoreKit.
            SubscriptionStoreView(groupID: groupID, visibleRelationships: .all) {
                EmptyView()
            }
            .controlsUnderHeader()
        } else {
            PaywallOneTimeStore()
        }
    }
    
    private var restoreAlertTitle: String {
        switch restoreOutcome {
        case .restored: paywall.texts.restoreSucceededTitle
        case .nothingToRestore: paywall.texts.nothingToRestoreTitle
        case .failed: paywall.texts.restoreFailedTitle
        case .cancelled, nil: ""
        }
    }

    /// Brings back subscriptions and lifetime products alike, top right opposite the close button.
    /// Styled by where it sits: floating over the photos, or in the toolbar.
    private var restoreButton: some View {
        Button(action: restore) {
            Text(paywall.texts.restorePurchases)
                // Kept in place under the spinner, so the button keeps its size.
                .opacity(isRestoring ? 0 : 1)
                .overlay {
                    if isRestoring {
                        ProgressView()
                    }
                }
        }
        .disabled(isRestoring)
        .accessibilityLabel(paywall.texts.restorePurchases)
    }

    private func restore() {
        isRestoring = true
        Task {
            let outcome = await paywall.restorePurchases()
            // One synchronous step, so no render sees the sheet released between the two.
            restoreOutcome = outcome
            showsRestoreAlert = outcome != .cancelled
            isRestoring = false
        }
    }

    /// The close button over the photos, where the toolbar's would need a navigation bar. VoiceOver
    /// reads the app's word for it; the button shows only the symbol.
    private var closeButton: some View {
        Button(paywall.texts.dismiss, systemImage: "xmark") {
            paywall.dismissPaywall()
        }
        .labelStyle(.iconOnly)
        .closeButtonStyle()
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .padding()
    }

    private func handlePurchaseCompletion(of product: Product, _ result: Result<Product.PurchaseResult, any Error>) async {
        switch result {
        case .success(let purchaseResult):
            switch purchaseResult {
            case .success(let verification):
                // Unverified purchases are left unfinished, as in the updates listener; nothing
                // is granted on a receipt that did not check out. The alert still tells the user,
                // who may have been charged, that the purchase did not unlock anything.
                guard case .verified(let transaction) = verification else {
                    paywall.report(.verificationFailed)
                    showsPurchaseFailedAlert = true
                    return
                }
                // Finished here, where the purchase happened. Left open, it would only be
                // finished by the updates listener on a later launch.
                await transaction.finish()
                // Only this path is a fresh purchase from the paywall, and only here is the
                // source known. A free trial start runs through here too.
                paywall.report(.purchaseCompleted(source: request.source, productID: product.id))
                paywall.handleSuccessfulPurchase(productID: transaction.productID, subscriptionGroupID: transaction.subscriptionGroupID)
            case .pending:
                // Ask to Buy: Apple's UI informs the user, so no app-side alert. The later
                // approval arrives through Transaction.updates.
                paywall.report(.purchasePending(source: request.source))
            case .userCancelled:
                break
            @unknown default:
                break
            }
        case .failure(let error):
            // Backing out of the Apple ID or confirmation sheet is thrown, not returned as
            // `.userCancelled`. Not a failure, so neither the alert nor the funnel sees it.
            if case StoreKitError.userCancelled = error { return }
            paywall.report(.purchaseFailed(source: request.source, reason: error.localizedDescription))
            showsPurchaseFailedAlert = true
        }
    }
}

private extension View {
    /// A round close button in the look of the system's own: Liquid Glass where the system has it,
    /// a bordered circle before.
    @ViewBuilder
    func closeButtonStyle() -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }

    /// Puts the plans right under the header and lets them scroll together with the Subscribe
    /// button, rather than wherever StoreKit's automatic placement would put them below an empty
    /// marketing slot. Only the picker style offers that placement, so a group with one plan shows
    /// it as a single card over the Subscribe button. The placement is iOS 18 and macOS 15;
    /// earlier systems keep the automatic style.
    @ViewBuilder
    func controlsUnderHeader() -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            subscriptionStoreControlStyle(.picker, placement: .scrollView)
        } else {
            self
        }
    }

    /// Attaches a policy destination only when the app configured a URL for it.
    @ViewBuilder
    func policyDestination(for policy: SubscriptionStorePolicyKind, url: String?, title: LocalizedStringKey) -> some View {
        if let url {
            subscriptionStorePolicyDestination(for: policy) {
                NavigationStack {
                    GatedWebView(url, navigationTitle: title)
                }
            }
        } else {
            self
        }
    }
}

// The products load from `ButchKitPreview.storekit`, which has to be selected under
// Product > Scheme > Edit Scheme > Run > Options. Xcode drops that reference when it rewrites the
// scheme; re-add it there if a preview shows "Subscription Unavailable" instead of the buttons.
// Every setup is a case of `PaywallPreviewStore`; switch a preview by changing its case.
#Preview("1 Subscription") {
    PaywallView.preview(.oneSubscription)
}

#Preview("3 Subscriptions") {
    PaywallView.preview(.threeSubscriptions)
}

// Without a group there is no segmented control: the lifetime products are the whole offer.
#Preview("1 One-Time") {
    PaywallView.preview(.oneOneTimePurchase)
}

#Preview("3 One-Time") {
    PaywallView.preview(.threeOneTimePurchases)
}

#Preview("Subscriptions + One-Time") {
    PaywallView.preview(.subscriptionsAndOneTimePurchases)
}

#Preview("Text") {
    PaywallView.preview(.subscriptionsAndOneTimePurchases, features: .previewFeaturesWithoutPhotos)
}

// All four page shapes in one set, so the jump between the two layouts is visible while swiping.
#Preview("Mixed") {
    PaywallView.preview(.subscriptionsAndOneTimePurchases, features: .previewFeaturesMixed)
}

// No pages at all: the app never passed any, or passed an empty array. StoreKit takes the whole
// sheet, and the paywall follows the device appearance rather than forcing its dark ground.
#Preview("Empty") {
    PaywallView.preview(.oneSubscription, features: [])
}

// No pages and no group: the lifetime products under the toolbar, with no StoreKit header above.
#Preview("Empty + One-Time") {
    PaywallView.preview(.threeOneTimePurchases, features: [])
}
