//
//  ErrorSystem.swift
//  ButchKit
//
//  Created by Leo Heuser on 07.02.26.
//

/**
 A lightweight error presentation system for SwiftUI apps.
 
 ## Overview
 The ErrorSystem provides a standardized way to display user-facing errors as alerts.
 It consists of three parts:
 - ``UserFacingError`` protocol to define error types with title and message
 - ``ErrorSystemService`` observable service to trigger error alerts
 - `.errorSystem()` view modifier to enable error presentation
 
 ## Usage
 1. Define your errors:
 ```swift
 enum PdfErrors: UserFacingError {
 case generic
 case noFile
 case fileTooLarge
 
 var title: LocalizedStringKey {
 switch self {
 case .generic: "error.generic.title"
 case .noFile: "error.pdf.noFile.title"
 case .fileTooLarge: "error.pdf.fileTooLarge.title"
 }
 }
 
 var message: LocalizedStringKey {
 switch self {
 case .generic: "error.generic.message"
 case .noFile: "error.pdf.noFile.message"
 case .fileTooLarge: "error.pdf.fileTooLarge.message"
 }
 }
 }
 ```
 
 2. Attach the modifier at the app root:
 ```swift
 ContentView()
 .errorSystem()
 ```
 
 3. Show errors from any child view:
 ```swift
 @Environment(\.errorService) private var errorService
 
 errorService.show(PdfErrors.noFile)
 ```
 
 4. Optionally provide a recovery action:
 ```swift
 errorService.show(PdfErrors.fileTooLarge, recoverAction: "button.retry") {
 // Recovery logic here
 }
 ```
 */

import SwiftUI

// MARK: - Protocol

public protocol UserFacingError: Sendable {
    static var generic: Self { get }
    var title: LocalizedStringKey { get }
    var message: LocalizedStringKey { get }
}

// MARK: - Service

@MainActor
@Observable
public final class ErrorSystemService {
    
    // MARK: - Properties
    
    var currentError: (any UserFacingError)?
    var recoverActionLabel: LocalizedStringKey?
    var recoverHandler: (@MainActor @Sendable () -> Void)?
    
    // MARK: - Init
    
    nonisolated public init() {}
    
    // MARK: - Methods
    
    nonisolated public func show(
        _ error: sending any UserFacingError,
        recoverAction: sending LocalizedStringKey? = nil,
        recover: sending (@MainActor @Sendable () -> Void)? = nil
    ) {
        Task { @MainActor in
            currentError = error
            recoverActionLabel = recoverAction
            recoverHandler = recover
        }
    }
    
    func dismiss() {
        currentError = nil
        recoverActionLabel = nil
        recoverHandler = nil
    }
}

// MARK: - Environment

private struct ErrorSystemServiceKey: EnvironmentKey {
    static let defaultValue = ErrorSystemService()
}

public extension EnvironmentValues {
    var errorService: ErrorSystemService {
        get { self[ErrorSystemServiceKey.self] }
        set { self[ErrorSystemServiceKey.self] = newValue }
    }
}

// MARK: - Modifier

private struct ErrorSystemModifier: ViewModifier {
    @State private var service = ErrorSystemService()
    let table: String?

    private var isPresented: Binding<Bool> {
        Binding(
            get: { service.currentError != nil },
            set: { if !$0 { service.dismiss() } }
        )
    }

    private var titleText: Text {
        let key = service.currentError?.title ?? "error.generic.title"
        if let table {
            return Text(key, tableName: table)
        }
        return Text(key)
    }

    private var messageText: Text {
        let key = service.currentError?.message ?? "error.generic.message"
        if let table {
            return Text(key, tableName: table)
        }
        return Text(key)
    }

    func body(content: Content) -> some View {
        content
            .environment(\.errorService, service)
            .alert(
                titleText,
                isPresented: isPresented
            ) {
                if let recoverLabel = service.recoverActionLabel,
                   let recoverHandler = service.recoverHandler {
                    Button(recoverLabel) {
                        recoverHandler()
                        service.dismiss()
                    }
                }
                Button("alertSystem.button.dismiss", role: .cancel) {
                    service.dismiss()
                }
            } message: {
                messageText
            }
    }
}

// MARK: - View Extension

public extension View {
    func errorSystem(table: String? = nil) -> some View {
        modifier(ErrorSystemModifier(table: table))
    }
}

// MARK: - Preview

private enum PreviewError: UserFacingError {
    case generic
    case noFile
    case fileTooLarge
    
    var title: LocalizedStringKey {
        switch self {
        case .generic: "Error"
        case .noFile: "No File Found"
        case .fileTooLarge: "File Too Large"
        }
    }
    
    var message: LocalizedStringKey {
        switch self {
        case .generic: "An error occurred."
        case .noFile: "The requested file could not be found."
        case .fileTooLarge: "The file exceeds the maximum allowed size."
        }
    }
}

#Preview("Error System") {
    ErrorSystemPreview()
        .errorSystem()
}

private struct ErrorSystemPreview: View {
    @Environment(\.errorService) private var errorService
    
    var body: some View {
        VStack(spacing: .spacingL) {
            Button("Show No File Error") {
                errorService.show(PreviewError.noFile)
            }
            Button("Show File Too Large Error") {
                errorService.show(PreviewError.fileTooLarge)
            }
            Button("Show Error with Recovery") {
                errorService.show(
                    PreviewError.fileTooLarge,
                    recoverAction: "Retry"
                ) {
                    print("Recovery action triggered")
                }
            }
        }
        .padding()
    }
}
