//
//  PaywallFeature.swift
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
/// let paywallFeatures: [PaywallFeature] = [
///     PaywallFeature(title: "paywall.feature.1.title",
///                    description: "paywall.feature.1.description",
///                    image: .payWallFeature1),
///     // A page with no photo, on the paywall's dark ground:
///     PaywallFeature(title: "paywall.feature.2.title",
///                    description: "paywall.feature.2.description"),
///     // A headline on its own:
///     PaywallFeature(title: "paywall.feature.3.title"),
/// ]
/// ```
///
/// Title and description are keys in the app's own string catalog; the image is an asset from the
/// app's catalog. The photos are shown on a dark ground, so shoot or grade them for that.
public struct PaywallFeature: Identifiable, Sendable {
    public let title: LocalizedStringResource
    /// The line below the title. `nil` shows the title on its own.
    public let description: LocalizedStringResource?
    /// The photo behind the text. `nil` leaves the paywall's dark ground bare.
    public let image: ImageResource?
    /// Whether the page speaks of the introductory offer, "One month free" and the like. Such a
    /// page shows only to a user who can still get that offer, see
    /// ``PaywallService/isEligibleForIntroOffer``: to anyone else it would promise something the
    /// App Store will not give them.
    public let introOfferOnly: Bool

    /// The title's key: the same for the same page however often the value is built, where a
    /// `UUID()` would be new on every render. Give two pages the same title key and they share an
    /// identity, so keep the keys distinct.
    public var id: String { title.key }

    public init(
        title: LocalizedStringResource,
        description: LocalizedStringResource? = nil,
        image: ImageResource? = nil,
        introOfferOnly: Bool = false
    ) {
        self.title = title
        self.description = description
        self.image = image
        self.introOfferOnly = introOfferOnly
    }
}

/// The spelling before 2.0.
@available(*, deprecated, renamed: "PaywallFeature")
public typealias PayWallFeature = PaywallFeature
