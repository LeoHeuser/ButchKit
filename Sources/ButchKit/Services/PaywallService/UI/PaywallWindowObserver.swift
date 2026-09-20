//
//  PaywallWindowObserver.swift
//  ButchKit
//
//  Created by Leo Heuser on 21.09.26.
//

import SwiftUI

/// Reports when the window it sits in becomes key: the window the user is in. Invisible, placed
/// in the background of every paywall sheet host.
///
/// SwiftUI has nothing for this that works everywhere. `scenePhase` is `.active` for both windows
/// of an iPad in Split View, so it cannot tell them apart; the key window can, on the iPad and the
/// Mac alike. On the Mac a sheet is a window of its own, which is why the hosts inside sheets
/// report too: with a sheet open it is the sheet that becomes key, not the window under it.
struct PaywallWindowObserver {
    let onBecomeKey: () -> Void
}

#if canImport(UIKit)
extension PaywallWindowObserver: UIViewRepresentable {
    func makeUIView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.isUserInteractionEnabled = false
        view.onBecomeKey = onBecomeKey
        return view
    }

    func updateUIView(_ view: ObserverView, context: Context) {
        view.onBecomeKey = onBecomeKey
    }

    final class ObserverView: UIView {
        var onBecomeKey: () -> Void = {}
        private var observation: (any NSObjectProtocol)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            observation.map(NotificationCenter.default.removeObserver)
            observation = nil
            guard let window else { return }
            observation = NotificationCenter.default.addObserver(forName: UIWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onBecomeKey() }
            }
            if window.isKeyWindow { onBecomeKey() }
        }

        isolated deinit {
            observation.map(NotificationCenter.default.removeObserver)
        }
    }
}
#elseif canImport(AppKit)
extension PaywallWindowObserver: NSViewRepresentable {
    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.onBecomeKey = onBecomeKey
        return view
    }

    func updateNSView(_ view: ObserverView, context: Context) {
        view.onBecomeKey = onBecomeKey
    }

    final class ObserverView: NSView {
        var onBecomeKey: () -> Void = {}
        private var observation: (any NSObjectProtocol)?

        /// Invisible to the mouse, as `isUserInteractionEnabled` makes it on UIKit. It fills the
        /// background of the whole host, and a plain `NSView` would answer for every click that
        /// lands on a transparent part of the content above it.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observation.map(NotificationCenter.default.removeObserver)
            observation = nil
            guard let window else { return }
            observation = NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onBecomeKey() }
            }
            if window.isKeyWindow { onBecomeKey() }
        }

        isolated deinit {
            observation.map(NotificationCenter.default.removeObserver)
        }
    }
}
#endif
