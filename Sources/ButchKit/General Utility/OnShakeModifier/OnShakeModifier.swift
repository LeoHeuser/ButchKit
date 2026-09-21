//
//  OnShakeModifier.swift
//  ButchKit
//
//  Created by Leo Heuser on 05.08.26.
//

/**

 # OnShakeModifier
 SwiftUI has no shake gesture. UIKit does, but it only ever delivers one through the responder chain, which a SwiftUI view never sees. `onShake` closes that gap: it catches the gesture where every responder chain ends — at the window — and hands it to any view that asks for it.

 Useful for the things that should not take up screen space: a hidden debug menu, a feedback sheet, a "start over" shortcut.

 ## Usage

 ```swift
 struct ContentView: View {
     @State private var showDebugMenu = false

     var body: some View {
         MyView()
             .onShake { showDebugMenu = true }
     }
 }
 ```

 `isEnabled` turns a listener off without removing it, for cases the view itself cannot see:

 ```swift
 .onShake(isEnabled: hasFinishedOnboarding) { showDebugMenu = true }
 ```

 Anything outside a view body — a service, a view controller — observes `Notification.Name.deviceDidShake` directly.

 ## Shake to Undo

 People whose hands set the gesture off by accident switch Shake to Undo off in Accessibility › Touch. That setting governs UIKit's own undo interface, nothing else, so `onShake` ignores it by default: most shakes are not an undo, and binding a debug menu to an undo setting would surprise everyone.

 An action the user cannot take back is the exception. Pass `respectsShakeToUndoSetting: true` and the listener goes quiet for exactly the people most likely to trigger it unintentionally:

 ```swift
 .onShake(respectsShakeToUndoSetting: true) { deleteLastRecording() }
 ```

 ## Only while the view is on screen

 A shake reaches a view only while that view is actually on screen. Being alive in the hierarchy is not enough: SwiftUI keeps the views of inactive tabs and of screens you navigated away from in memory, and they would otherwise all react to the same shake.

 There is no SwiftUI signal for this. `onAppear` and `onDisappear` cover tabs and navigation but not presentation — a view behind a sheet never disappears. UIKit knows both, so `ShakeVisibility` asks it at the moment of the shake.

 What this means in practice:

 - Visible: reacts.
 - Inactive tab, or a screen you navigated away from: does not react.
 - Behind a sheet or a full screen cover: does not react. A view inside the sheet does.
 - Removed by a condition: gone entirely, nothing listens.
 - Hidden with `opacity(0)` or `hidden()`: still reacts. It is on screen, only not drawn.

 ## Notes

 - iOS only. There is no shake on macOS, so the modifier does not exist there rather than pretending to work. Shared code needs its own `#if os(iOS)`.
 - The `UIWindow` override applies to the whole app. If a second SDK overrides `motionEnded` in an extension as well, one of the two silently wins. An app's own `UIWindow` subclass is fine: its `super` call reaches this one.
 - With several windows open, every listening view that is on screen reacts, not only the one in the shaken window. That is what `isEnabled` is for.
 - Shake still triggers the system undo interface, because the override calls `super`. An app that does not want it sets `UIApplication.shared.applicationSupportsShakeToEdit = false` itself. That switch is the app's side of the story; `respectsShakeToUndoSetting` is the user's.
 - In the Simulator, `Ctrl+Cmd+Z` performs a shake.

 ## Credit

 The window level technique is Paul Hudson's, from Hacking with Swift, "How to detect shake gestures":
 https://www.hackingwithswift.com/quick-start/swiftui/how-to-detect-shake-gestures

 Three things here go beyond it: `super.motionEnded` is called, so the app keeps shake to undo; `motionEnded` replaces
 `motionBegan`, so a cancelled gesture does not count; and a listener only fires while its view is on screen.

 */

#if os(iOS)

import SwiftUI
import UIKit

public extension Notification.Name {
    /// Posted on the main actor after a completed shake gesture. The object is the `UIWindow` that received it.
    ///
    /// The way in for anything that has no view body: a service, an actor, a view controller. Views use
    /// `View.onShake(isEnabled:respectsShakeToUndoSetting:perform:)`, which additionally checks that the view is on screen — an observer
    /// registered here does not, and hears every shake in the app.
    static let deviceDidShake = Notification.Name("design.heuser.ButchKit.deviceDidShake")
}

extension UIWindow {
    /// Every responder chain ends at the window, so this sees a shake no matter which view holds first responder.
    ///
    /// The technique is Paul Hudson's, from Hacking with Swift:
    /// https://www.hackingwithswift.com/quick-start/swiftui/how-to-detect-shake-gestures
    ///
    /// `super` runs first and on purpose: it keeps UIKit's own motion handling, shake to undo included, intact.
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)

        guard motion == .motionShake else { return }

        NotificationCenter.default.post(name: .deviceDidShake, object: self)
    }
}

/// Whether the view is on screen at this moment: inside a window, and not covered by a sheet, a cover or a popover.
///
/// SwiftUI has no such signal. `onAppear` and `onDisappear` cover tabs and navigation but not presentation — a view
/// behind a sheet never disappears. UIKit does know, so this asks it at the moment of the shake rather than tracking
/// state over time.
@MainActor
final class ShakeVisibility {
    fileprivate weak var view: UIView?

    var isOnScreen: Bool {
        guard let view, view.window != nil else { return false }

        var responder: UIResponder? = view
        var owner: UIViewController?

        while let current = responder {
            if let controller = current as? UIViewController {
                owner = controller
                break
            }

            responder = current.next
        }

        // Only the containment chain, never `presentingViewController`: a view inside a sheet would otherwise
        // find the controller that presented that very sheet and mistake it for something covering itself.
        while let controller = owner {
            if controller.presentedViewController != nil { return false }

            owner = controller.parent
        }

        return true
    }
}

/// A zero-cost UIKit anchor. It draws nothing and takes no touches; it exists so `ShakeVisibility` has a view to ask about.
private struct ShakeVisibilityProbe: UIViewRepresentable {
    let visibility: ShakeVisibility

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        visibility.view = view

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        visibility.view = uiView
    }
}

struct OnShakeModifier: ViewModifier {
    let isEnabled: Bool
    let respectsShakeToUndoSetting: Bool
    let action: () -> Void

    @State private var visibility = ShakeVisibility()

    func body(content: Content) -> some View {
        content
            .background(ShakeVisibilityProbe(visibility: visibility))
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
                guard isEnabled, visibility.isOnScreen else { return }

                // Read at the moment of the shake, never cached: the setting can change while the app runs.
                guard !respectsShakeToUndoSetting || UIAccessibility.isShakeToUndoEnabled else { return }

                action()
            }
    }
}

public extension View {
    /// Runs an action when the device is shaken, for as long as this view is on screen.
    ///
    /// ```swift
    /// MyView()
    ///     .onShake { showDebugMenu = true }
    /// ```
    ///
    /// Several views may listen at once. Each one reacts only while it is on screen, so a shake goes to whatever the
    /// person is actually looking at:
    ///
    /// - Visible: reacts.
    /// - Inactive tab, or a screen navigated away from: does not react.
    /// - Behind a sheet or a full screen cover: does not react. A view inside the sheet does.
    /// - Hidden with `opacity(0)` or `hidden()`: still reacts. It is on screen, only not drawn.
    ///
    /// Use `isEnabled` for a condition the view cannot see itself, such as two visible views where only one should
    /// answer. Outside a view body, observe `Notification.Name.deviceDidShake` instead.
    ///
    /// In the Simulator, `Ctrl+Cmd+Z` performs a shake.
    ///
    /// - Parameters:
    ///   - isEnabled: Whether this view reacts to a shake. Defaults to `true`.
    ///   - respectsShakeToUndoSetting: Whether Accessibility › Touch › Shake to Undo switches this
    ///     listener off along with the system undo interface. Defaults to `false`, because that
    ///     setting is about undo and most shakes are not. Pass `true` for an action the user cannot
    ///     take back: it goes quiet for the people whose hands set the gesture off by accident.
    ///   - action: What to run once the gesture completes. Called on the main actor.
    func onShake(isEnabled: Bool = true,
                 respectsShakeToUndoSetting: Bool = false,
                 perform action: @escaping () -> Void) -> some View {
        modifier(OnShakeModifier(isEnabled: isEnabled,
                                 respectsShakeToUndoSetting: respectsShakeToUndoSetting,
                                 action: action))
    }
}

#Preview {
    @Previewable @State var shakeCount: Int = 0

    VStack(spacing: 8) {
        Text("\(shakeCount)")
            .font(.system(size: 64, weight: .semibold, design: .rounded))
            .contentTransition(.numericText())

        Text("Shake the device, or press Ctrl+Cmd+Z in the Simulator.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
    .padding()
    .onShake {
        withAnimation {
            shakeCount += 1
        }
    }
}

#endif
