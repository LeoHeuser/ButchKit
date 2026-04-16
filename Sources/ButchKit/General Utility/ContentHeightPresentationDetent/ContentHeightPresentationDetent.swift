//
//  DynamicSheetHeightModifier.swift
//  Butch
//
//  Created by Leo Heuser on 27.09.25.
//

import SwiftUI

/// A ViewModifier that automatically adjusts sheet height to match content size with safe area padding.
/// Uses GeometryReader to measure content height and applies standard padding top and bottom for visual spacing.
///
/// Usage:
/// ```swift
/// .sheet(isPresented: $showSheet) {
///     FolderCreationView()
///         .useContentHeightPresentationDetent
/// }
/// ```
///
/// Features:
/// - Automatic top and bottom padding for safe area
/// - Minimum height to ensure sheet visibility
/// - Content height measurement with padding calculation
///
/// Requirements:
/// - iOS 17.0+, macOS 14.0+
/// - Apply directly to sheet content
/// - Do not combine with other presentationDetents
public extension View {
    /// Automatically adjusts sheet height to content size with safe area padding.
    var useContentHeightPresentationDetent: some View {
        modifier(ContentHeightPresentationDetentModifier())
    }
}

/// Internal modifier that measures content height, adds padding, and updates presentation detents.
/// Ensures minimum height and proper visual spacing with standard padding.
public struct ContentHeightPresentationDetentModifier: ViewModifier {
    @State private var contentHeight: CGFloat = 100
    
    private let standardPadding: CGFloat = 32
    private let minimumHeight: CGFloat = 100
    
    public init() {}
    
    public func body(content: Content) -> some View {
        content
            .padding(.vertical, standardPadding)
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onChange(of: geometry.size.height, initial: true) { _, newHeight in
                            contentHeight = max(newHeight, minimumHeight)
                        }
                }
            }
            .presentationDetents([.height(contentHeight)])
    }
}

#Preview("Short Content") {
    @Previewable @State var isPresented = true
    
    Button("Show Sheet") { isPresented = true }
        .sheet(isPresented: $isPresented) {
            VStack(spacing: 12) {
                Text("Sheet Title")
                    .font(.headline)
                Text("This sheet adjusts its height to fit the content.")
            }
            .useContentHeightPresentationDetent
        }
}

#Preview("Long Content") {
    @Previewable @State var isPresented = true
    
    Button("Show Sheet") { isPresented = true }
        .sheet(isPresented: $isPresented) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sheet Title")
                    .font(.headline)
                ForEach(1..<8) { index in
                    Text("Item \(index)")
                }
            }
            .useContentHeightPresentationDetent
        }
}
