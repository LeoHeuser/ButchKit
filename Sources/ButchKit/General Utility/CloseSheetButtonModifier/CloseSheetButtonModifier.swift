//
//  closeSheetButtonModifier.swift
//  ButchKit
//
//  Created by Leo Heuser on 25.01.26.
//

/**

 # CloseSheetButtonModifier
 Quite often a sheet itselfs need a close button to make it easily acessiboel for everyone to navigate within the views. Here the close CloseSheetButtonModifier helpts so that you do not need to redefine toolbars and dismiss buttons all the time.

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
