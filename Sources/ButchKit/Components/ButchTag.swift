//
//  ButchTag.swift
//  Butch
//
//  Created by Leo Heuser on 26.09.25.
//

import SwiftUI

public struct ButchTag: View {
    // MARK: - Parameters
    private let title: LocalizedStringKey
    
    // MARK: - Initializer
    public init(_ title: LocalizedStringKey) {
        self.title = title
    }
    
    // MARK: - View
    public var body: some View {
        TagContent(title: title)
            .padding(.horizontal, .spacingDefault)
            .padding(.vertical, .spacingS)
            .background(.clear)
            .overlay(
                RoundedRectangle(cornerRadius: .infinity)
                    .strokeBorder(Color.borderLight, lineWidth: 1)
            )
    }
}

// MARK: - View Parts
extension ButchTag {
    
    /// Tag Content
    private struct TagContent: View {
        let title: LocalizedStringKey
        
        var body: some View {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Preview
#Preview("ButchTag") {
    VStack(spacing: .spacingDefault) {
        ButchTag("tag.category")
        ButchTag("tag.featured")
        ButchTag("tag.new")
        ButchTag("tag.premium")
    }
    .padding()
}
