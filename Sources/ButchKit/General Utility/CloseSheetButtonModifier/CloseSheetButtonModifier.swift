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
    let title: LocalizedStringKey

    @Environment(\.dismiss) var dismiss

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(title, systemImage: "xmark") {
                        dismiss()
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
        modifier(DismissSheetButton(title: title))
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
