//
//  ButchTextEditor.swift
//  ButchKit
//
//  Created by Leo Heuser on 06.11.25.
//

import SwiftUI

public struct ButchTextEditor: View {
    // MARK: - Parameters
    @Binding private var text: String
    private let placeholder: LocalizedStringKey
    
    // MARK: - Initializer
    public init(text: Binding<String>, placeholder: LocalizedStringKey = "placeholder.text") {
        self._text = text
        self.placeholder = placeholder
    }
    
    // MARK: - View
    public var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 16))
            .foregroundStyle(text.isEmpty ? Color.textSecondary : Color.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 108)
            .padding(.spacingDefault)
            .background(
                RoundedRectangle(cornerRadius: .spacingDefault)
                    .strokeBorder(Color.textFieldBorder, lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.textSecondary)
                        .padding(.spacingDefault)
                        .padding(.top, .spacingS)
                        .allowsHitTesting(false)
                }
            }
    }
}

// MARK: - Preview
#Preview {
    ButchTextEditor(text: .constant(""))
        .padding()
}
