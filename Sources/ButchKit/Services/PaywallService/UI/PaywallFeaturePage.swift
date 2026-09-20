//
//  PaywallFeaturePage.swift
//  ButchKit
//
//  Created by Leo Heuser on 03.09.26.
//

import SwiftUI

/// One page: title and description over a full-bleed photo.
///
/// Both the description and the photo are optional. A page with a photo puts its text at the
/// bottom, where the photo has faded out and the text stays legible. Without one there is nothing
/// to sit below, so the text centres rather than leave an empty half above it.
struct PaywallFeaturePage: View {
    let feature: PaywallFeature

    private var hasPhoto: Bool { feature.image != nil }

    var body: some View {
        VStack(spacing: 16) {
            Text(feature.title)
                .font(.title)
                .fontWeight(.bold)

            if let description = feature.description {
                Text(description)
                    .font(.headline)
            }
        }
        .multilineTextAlignment(.center)
        .padding(32)
        .padding(.bottom, hasPhoto ? 32 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: hasPhoto ? .bottom : .center)
        .background {
            if let image = feature.image {
                // Up to the sheet's top edge even where the page is inset for the navigation bar.
                // The text stays inside the safe area, below the close button.
                PaywallBackgroundImage(image: image)
                    .ignoresSafeArea(edges: .top)
            }
        }
    }
}

#if DEBUG
#Preview("Photo and description") {
    PaywallFeaturePage(feature: .previewFull)
        .paywallPreviewGround()
}

#Preview("No description") {
    PaywallFeaturePage(feature: .previewWithoutDescription)
        .paywallPreviewGround()
}

#Preview("No photo") {
    PaywallFeaturePage(feature: .previewWithoutPhoto)
        .paywallPreviewGround()
}

#Preview("Title only") {
    PaywallFeaturePage(feature: .previewTitleOnly)
        .paywallPreviewGround()
}
#endif
