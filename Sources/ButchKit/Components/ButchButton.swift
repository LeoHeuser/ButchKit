//
//  ButchButton.swift
//  ButchKit
//
//  Created by Leo Heuser on 14.10.25.
//

import SwiftUI

public struct ButchButton: View {
    // MARK: - Properties
    private let titleKey: LocalizedStringKey
    private let systemImage: String
    private let kind: ButchButtonKind
    private let action: () -> Void
    
    // MARK: - Init
    public init(
        _ titleKey: LocalizedStringKey,
        systemImage: String,
        kind: ButchButtonKind = .primary,
        action: @escaping () -> Void
    ) {
        self.titleKey = titleKey
        self.systemImage = systemImage
        self.kind = kind
        self.action = action
    }
    
    // MARK: - View
    public var body: some View {
        Button(titleKey, systemImage: systemImage, action: action)
            .buttonStyle(.butch(kind))
    }
}

// MARK: - Preview
#Preview {
    ButchButton("button.placeholder", systemImage: "circle.square") {
        // Action that will be triggered by pressing this button.
    }
}
