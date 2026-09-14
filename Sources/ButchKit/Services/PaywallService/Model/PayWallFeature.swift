//
//  PayWallFeature.swift
//  ButchKit
//
//  Created by Leo Heuser on 03.09.26.
//

import SwiftUI

/// One marketing page on the paywall: a title, optionally a line of text, optionally a full-bleed
/// photo behind both.
///
/// Declare the pages once, next to the configuration, and pass them to
/// `View.paywallEnvironment(_:texts:features:)`. The paywall shows them as swipeable pages that
/// advance on their own.
///
/// ```swift
/// let paywallFeatures: [PayWallFeature] = [
///     PayWallFeature(title: "paywall.feature.1.title",
///                    description: "paywall.feature.1.description",
///                    image: .payWallFeature1),
///     // A page with no photo, on the paywall's dark ground:
///     PayWallFeature(title: "paywall.feature.2.title",
///                    description: "paywall.feature.2.description"),
///     // A headline on its own:
///     PayWallFeature(title: "paywall.feature.3.title"),
/// ]
/// ```
///
/// Title and description are keys in the app's own string catalog; the image is an asset from the
/// app's catalog. The photos are shown on a dark ground, so shoot or grade them for that.
public struct PayWallFeature: Identifiable {
    public let id = UUID()
    public let title: LocalizedStringKey
    /// The line below the title. `nil` shows the title on its own.
    public let description: LocalizedStringKey?
    /// The photo behind the text. `nil` leaves the paywall's dark ground bare.
    public let image: ImageResource?

    public init(
        title: LocalizedStringKey,
        description: LocalizedStringKey? = nil,
        image: ImageResource? = nil
    ) {
        self.title = title
        self.description = description
        self.image = image
    }
}
