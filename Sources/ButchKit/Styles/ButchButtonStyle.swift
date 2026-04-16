//
//  ButchButtonStyle.swift
//  ButchKit
//
//  Created by Leo Heuser on 09.10.25.
//
// TODO: Hier nochmal verbessern, da diese Style in dem einfachen und dem DoubleButton genutzt wird. Das sollten wir dann nochmal hier verbessern und zusammen legen zu zwei Styles die auf zwei Objekte auch zeigen.

import SwiftUI

/// Defines the visual style variant for ButchButtonStyle
public enum ButchButtonKind {
    case primary
    case secondary
}

/// A custom button style matching the Butch design system
public struct ButchButtonStyle: ButtonStyle {
    private let kind: ButchButtonKind
    
    @Environment(\.isEnabled) private var isEnabled
    
    public init(_ kind: ButchButtonKind = .primary) {
        self.kind = kind
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: .spacingXS) {
            configuration.label
        }
        .font(.body)
        .padding(.horizontal, .spacingDefault)
        .padding(.vertical, .spacingS)
        .frame(maxWidth: .infinity, minHeight: 54)
        .foregroundStyle(foregroundColor)
        .background(backgroundColor)
        .overlay {
            if kind == .secondary {
                Capsule()
                    .stroke(Color.buttonForegroundPrimary, lineWidth: 1)
            }
        }
        .clipShape(Capsule())
        .opacity(isEnabled ? 1.0 : 0.4)
        .allowsHitTesting(isEnabled)
    }
    
    private var foregroundColor: Color {
        switch kind {
        case .primary:
            return .buttonForegroundInverted
        case .secondary:
            return .buttonForegroundPrimary
        }
    }
    
    private var backgroundColor: some View {
        Group {
            switch kind {
            case .primary:
                Color.buttonForegroundPrimary
            case .secondary:
                Color.clear.background(.ultraThinMaterial)
            }
        }
    }
}

public extension ButtonStyle where Self == ButchButtonStyle {
    static var butch: ButchButtonStyle { ButchButtonStyle() }
    static func butch(_ kind: ButchButtonKind) -> ButchButtonStyle { ButchButtonStyle(kind) }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        Button("Button Text", systemImage: "square.on.circle") {}
            .buttonStyle(.butch)
        
        Button("Button Text", systemImage: "square.on.circle") {}
            .buttonStyle(.butch(.secondary))
        
        Button("Button Text", systemImage: "square.on.circle") {}
            .buttonStyle(.butch)
            .disabled(true)
        
        Button("Button Text", systemImage: "square.on.circle") {}
            .buttonStyle(.butch(.secondary))
            .disabled(true)
    }
    .padding()
}
