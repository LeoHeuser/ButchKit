//
//  CloseSheetButtonModifier.swift
//  ButchKit
//
//  Created by Leo Heuser on 25.01.26.
//

/**

 # CloseSheetButtonModifier
 A sheet often needs its own close button so that everyone can leave it easily. `View.sheetDismissButton(_:)` adds one, so the toolbar and dismiss action are not redefined in every sheet.

 */

import SwiftUI

struct DismissSheetButton: ViewModifier {
    /// Held as `Text` so a caller inside the SDK can apply the modifier directly with a
    /// `LocalizedStringResource`. A public overload for one cannot be added: a string literal
    /// would then be ambiguous at every existing call site.
    let title: Text

    @Environment(\.dismiss) var dismiss

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label { title } icon: { Image(systemName: "xmark") }
                    }
                }
            }
    }
}

public extension View {
    /// A close button in the sheet's toolbar.
    ///
    /// - Parameter title: The button's name, from the app's catalog. The toolbar shows only the
    ///   symbol; VoiceOver reads the name.
    func sheetDismissButton(_ title: LocalizedStringKey) -> some View {
        modifier(DismissSheetButton(title: Text(title)))
    }
}

#Preview {
    @Previewable @State var isPresented: Bool = true

    VStack {
        Button("Show Sheet") {
            isPresented.toggle()
        }
    }
    .sheet(isPresented: $isPresented) {
        NavigationStack {
            Text("Foreground")
                .sheetDismissButton("Close")
        }
    }
}
