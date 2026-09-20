//
//  PaywallPurchaseFailure.swift
//  ButchKit
//
//  Created by Leo Heuser on 20.09.26.
//

import StoreKit

/// Why a purchase failed, by kind. What ``PaywallEvent/purchaseFailed(source:productID:reason:)``
/// carries in place of the error's own text, so an app can chart failures without sending a
/// system string to its analytics. The raw values are stable.
public enum PaywallPurchaseFailure: String, Sendable {
    /// The App Store could not be reached.
    case network
    /// The product is not sold in the user's storefront.
    case notAvailableInStorefront
    /// The App Store does not offer the product right now.
    case productUnavailable
    /// This device or account may not make purchases, for example under Screen Time.
    case purchaseNotAllowed
    /// The user is not eligible for the offer on the product.
    case ineligibleForOffer
    /// The offer on the product was set up wrongly.
    case invalidOffer
    /// StoreKit or the system failed.
    case system
    /// Anything else.
    case unknown

    init(_ error: any Error) {
        switch error {
        case StoreKitError.networkError: self = .network
        case StoreKitError.notAvailableInStorefront: self = .notAvailableInStorefront
        case StoreKitError.systemError: self = .system
        case Product.PurchaseError.productUnavailable: self = .productUnavailable
        case Product.PurchaseError.purchaseNotAllowed: self = .purchaseNotAllowed
        case Product.PurchaseError.ineligibleForOffer: self = .ineligibleForOffer
        // Named one by one rather than as "any other purchase error", so a case that is not about
        // the offer, `invalidQuantity` today, is not charted as one.
        case Product.PurchaseError.invalidOfferIdentifier,
             Product.PurchaseError.invalidOfferPrice,
             Product.PurchaseError.invalidOfferSignature,
             Product.PurchaseError.missingOfferParameters: self = .invalidOffer
        default: self = .unknown
        }
    }
}
