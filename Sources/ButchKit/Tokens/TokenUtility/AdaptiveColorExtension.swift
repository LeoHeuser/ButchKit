//
//  AdaptiveColorExtension.swift
//  Butch
//
//  Created by Leo Heuser on 26.09.25.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

extension Color {
    
    /// Creates a color that adapts to the current color scheme.
    /// - Parameters:
    ///   - light: Color for light appearance
    ///   - dark: Color for dark appearance
    /// - Returns: Adaptive color
    public static func adaptiveColor(light: Color, dark: Color) -> Color {
        Color(light: light, dark: dark)
    }
}

private extension Color {
    
    init(light: Color, dark: Color) {
#if canImport(UIKit)
        self.init(light: UIColor(light), dark: UIColor(dark))
#elseif canImport(AppKit)
        self.init(light: NSColor(light), dark: NSColor(dark))
#endif
    }
    
#if canImport(UIKit)
    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor(dynamicProvider: { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        }))
    }
#endif
    
#if canImport(AppKit)
    init(light: NSColor, dark: NSColor) {
        self.init(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            switch appearance.name {
            case .darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua, .accessibilityHighContrastVibrantDark:
                return dark
            default:
                return light
            }
        }))
    }
#endif
}
