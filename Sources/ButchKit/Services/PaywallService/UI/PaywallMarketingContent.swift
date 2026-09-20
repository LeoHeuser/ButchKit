//
//  PaywallMarketingContent.swift
//  ButchKit
//
//  Created by Leo Heuser on 03.09.26.
//

import SwiftUI

/// The swipeable marketing pages above the subscription buttons. Advances on its own every
/// five seconds and pauses for fifteen after the user swipes.
struct PaywallMarketingContent: View {
    let features: [PaywallFeature]
    /// The pages' fixed height: the app's `featureAreaHeight` share of the paywall, computed by
    /// ``PaywallView``. A paged TabView has no height of its own, and fixed rather than flexible
    /// the pages stay in view while the segmented control under them keeps its place.
    let height: CGFloat

    private let autoAdvanceInterval: TimeInterval = 5
    private let userInteractionCooldown: TimeInterval = 15

    @State private var currentPage = 0
    @State private var isProgrammaticChange = false
    @State private var cooldownEnd: Date = .distantPast

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        pages
        // The paged TabView insets its pages by the top safe area on its own, which bands the
        // photos off under the navigation bar.
        .ignoresSafeArea(edges: .top)
        .frame(height: height)
        // A page about the introductory offer comes and goes with the user's eligibility, which
        // the App Store reports a moment after the paywall opens.
        .onChange(of: features.count) { currentPage = 0 }
        .onChange(of: currentPage) {
            if isProgrammaticChange {
                isProgrammaticChange = false
            } else {
                cooldownEnd = Date().addingTimeInterval(userInteractionCooldown)
            }
        }
        // Reduce Motion means no page moves unless the user moves it, and a single page has
        // nowhere to go: neither keeps a timer running. Keyed on the count as well, so the second
        // page appearing with the introductory offer starts the timer that had nothing to do.
        .task(id: [features.count, reduceMotion ? 1 : 0]) {
            guard features.count > 1, !reduceMotion else { return }
            // Ends with the view; a page change does not restart the interval.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(autoAdvanceInterval))
                guard Date() >= cooldownEnd else { continue }
                withAnimation {
                    isProgrammaticChange = true
                    currentPage = (currentPage + 1) % features.count
                }
            }
        }
    }
}

private extension PaywallMarketingContent {
#if os(iOS)
    var pages: some View {
        TabView(selection: $currentPage) {
            ForEach(features.indices, id: \.self) { index in
                PaywallFeaturePage(feature: features[index])
                    .tag(index)
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
#else
    /// The Mac has no paged `TabView`: without a style it draws a tab bar of empty tabs over the
    /// pages. So one page at a time, cross-faded, with the dots underneath as the way to move,
    /// since there is no swipe either.
    var pages: some View {
        ZStack(alignment: .bottom) {
            if features.indices.contains(currentPage) {
                PaywallFeaturePage(feature: features[currentPage])
                    .id(currentPage)
                    .transition(.opacity)
            }
            if features.count > 1 {
                HStack(spacing: 8) {
                    ForEach(features.indices, id: \.self) { index in
                        Button {
                            withAnimation { currentPage = index }
                        } label: {
                            Circle()
                                .fill(index == currentPage ? .primary : .tertiary)
                                .frame(width: 8, height: 8)
                                // A target a pointer can hit.
                                .padding(4)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        // The page's own title: the dots have no words, and ButchKit ships none.
                        .accessibilityLabel(Text(features[index].title))
                        .accessibilityAddTraits(index == currentPage ? .isSelected : [])
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }
#endif
}

#if DEBUG
// `height` stands in for what PaywallView computes; roughly the default share on a phone.
#Preview("With photos") {
    PaywallMarketingContent(features: .previewFeatures, height: 440)
        .paywallPreviewGround()
}

#Preview("Text only") {
    PaywallMarketingContent(features: .previewFeaturesWithoutPhotos, height: 440)
        .paywallPreviewGround()
}

#Preview("Mixed") {
    PaywallMarketingContent(features: .previewFeaturesMixed, height: 440)
        .paywallPreviewGround()
}
#endif
