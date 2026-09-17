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
    let features: [PayWallFeature]
    /// The pages' fixed height: the app's `featureAreaHeight` share of the paywall, computed by
    /// ``PaywallView``. A paged TabView has no height of its own, and fixed rather than flexible
    /// the pages stay in view while the segmented control under them keeps its place.
    let height: CGFloat

    private let autoAdvanceInterval: TimeInterval = 5
    private let userInteractionCooldown: TimeInterval = 15

    @State private var currentPage = 0
    @State private var isProgrammaticChange = false
    @State private var cooldownEnd: Date = .distantPast

    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(features.indices, id: \.self) { index in
                PaywallFeaturePage(feature: features[index])
                    .tag(index)
            }
        }
        #if os(iOS)
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        #endif
        // The paged TabView insets its pages by the top safe area on its own, which bands the
        // photos off under the navigation bar.
        .ignoresSafeArea(edges: .top)
        .frame(height: height)
        .onChange(of: currentPage) {
            if isProgrammaticChange {
                isProgrammaticChange = false
            } else {
                cooldownEnd = Date().addingTimeInterval(userInteractionCooldown)
            }
        }
        .task {
            // Ends with the view; a page change does not restart the interval.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(autoAdvanceInterval))
                guard features.count > 1, Date() >= cooldownEnd else { continue }
                withAnimation {
                    isProgrammaticChange = true
                    currentPage = (currentPage + 1) % features.count
                }
            }
        }
    }
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
