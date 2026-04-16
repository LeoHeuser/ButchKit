//
//  ButchDoubleActionButton.swift
//  ButchKit
//
//  Created by Leo Heuser on 06.11.25.
//

import SwiftUI

/// A double-action button combining primary and secondary actions.
public struct ButchDoubleActionButton: View {
    // MARK: - Properties
    private let primaryIcon: String
    private let primaryText: LocalizedStringKey
    private let secondaryIcon: String
    private let primaryAction: () -> Void
    private let secondaryAction: () -> Void
    private let secondaryWidth: CGFloat
    
    // MARK: - Initializer
    
    /// Creates a double-action button.
    /// - Parameters:
    ///   - primaryIcon: SF Symbol for primary button
    ///   - primaryText: Localized text for primary button
    ///   - secondaryIcon: SF Symbol for secondary button
    ///   - secondaryWidth: Width of secondary button in points (default: 81)
    ///   - primaryAction: Primary button action
    ///   - secondaryAction: Secondary button action
    public init(
        primaryIcon: String,
        primaryText: LocalizedStringKey,
        secondaryIcon: String,
        secondaryWidth: CGFloat = 81,
        primaryAction: @escaping () -> Void,
        secondaryAction: @escaping () -> Void
    ) {
        self.primaryIcon = primaryIcon
        self.primaryText = primaryText
        self.secondaryIcon = secondaryIcon
        self.secondaryWidth = secondaryWidth
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }
    
    // MARK: - View
    public var body: some View {
        HStack(spacing: 0) {
            PrimaryButton(
                icon: primaryIcon,
                text: primaryText,
                width: secondaryWidth * 2.5,
                action: primaryAction
            )
            
            SecondaryButton(
                icon: secondaryIcon,
                width: secondaryWidth,
                action: secondaryAction
            )
        }
    }
}

// MARK: - Subviews

private struct PrimaryButton: View {
    let icon: String
    let text: LocalizedStringKey
    let width: CGFloat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(text)
                    .lineLimit(1)
            }
            .font(.body)
            .frame(width: width, height: 60)
        }
        .foregroundStyle(Color.buttonForegroundInverted)
        .background(Color.buttonForegroundPrimary)
        .background(.ultraThinMaterial)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 30,
                bottomLeadingRadius: 30,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0,
                style: .continuous
            )
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 30,
                bottomLeadingRadius: 30,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0,
                style: .continuous
            )
            .strokeBorder(Color.buttonForegroundPrimary, lineWidth: 1)
        )
    }
}

private struct SecondaryButton: View {
    let icon: String
    let width: CGFloat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body)
                .frame(width: width, height: 60)
        }
        .foregroundStyle(Color.buttonForegroundPrimary)
        .background(.ultraThinMaterial)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 30,
                topTrailingRadius: 30,
                style: .continuous
            )
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 30,
                topTrailingRadius: 30,
                style: .continuous
            )
            .strokeBorder(Color.buttonForegroundPrimary, lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        ButchDoubleActionButton(
            primaryIcon: "doc.viewfinder",
            primaryText: "button.scanDocument",
            secondaryIcon: "plus",
            primaryAction: { print("Primary action") },
            secondaryAction: { print("Secondary action") }
        )
    }
    .padding()
}
