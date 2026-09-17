//
//  PaywallBackgroundImage.swift
//  ButchKit
//
//  Created by Leo Heuser on 03.09.26.
//

import SwiftUI

/// A full-bleed photo masked by a gradient over its lower part, so text stays legible on it.
struct PaywallBackgroundImage: View {
    var image: ImageResource
    var gradientHeight: CGFloat = 0.62

    var body: some View {
        GeometryReader { proxy in
            Image(image)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 1 - gradientHeight),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
    }
}

#if DEBUG
#Preview {
    PaywallBackgroundImage(image: .previewPhoto(1))
        .paywallPreviewGround()
}
#endif
