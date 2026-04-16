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
    @Environment(\.dismiss) var dismiss
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.dismissSheet", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
    }
}

public extension View {
    func sheetDismissButton() -> some View {
        modifier(DismissSheetButton())
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
                .sheetDismissButton()
        }
    }
}
