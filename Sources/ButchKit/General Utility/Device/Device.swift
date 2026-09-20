//
//  Device.swift
//  ButchKit
//
//  Created by Leo Heuser on 18.09.26.
//

import Foundation

/// The product class the app is running on.
///
/// Inside a view, read it from the environment, where a preview can override it:
///
/// ```swift
/// struct CameraView: View {
///     @Environment(\.device) private var device
///
///     var body: some View {
///         Content()
///             .presentationDetents(device.isiPad ? [.large] : [.medium, .large])
///     }
/// }
/// ```
///
/// Services, actors and background work cannot reach the environment and use ``current`` instead.
///
/// This answers a hardware question, not a layout question. An iPad in Split View or Slide Over
/// is as narrow as an iPhone and still reports ``iPad``. Decide layout with
/// `horizontalSizeClass`, which follows the window.
public enum Device: Sendable, Equatable, CaseIterable {
    case iPhone
    case iPad
    case mac
    
    /// The device this process runs on. Resolved once, because it cannot change while the
    /// process lives.
    ///
    /// Read from the hardware model identifier ("iPad14,1") rather than UIKit: `UIDevice` is bound
    /// to the main actor, which would lock out the very callers this property exists for, and
    /// `UITraitCollection.current` does not report the idiom reliably off the main thread. A wrong
    /// first read would stick for the life of the process.
    public static let current: Device = {
#if os(macOS)
        .mac
#else
        // Covers Mac Catalyst and iPad apps running on Apple silicon Macs.
        if ProcessInfo.processInfo.isMacCatalystApp || ProcessInfo.processInfo.isiOSAppOnMac {
            return .mac
        }
        return modelIdentifier.hasPrefix("iPad") ? .iPad : .iPhone
#endif
    }()
    
    // Spelled like Apple's own `isiOSAppOnMac`: the brand's lowercase prefix stays lowercase.
    
    /// Whether this is an iPhone.
    public var isiPhone: Bool { self == .iPhone }
    
    /// Whether this is an iPad, whatever the size of the app's window.
    public var isiPad: Bool { self == .iPad }
    
    /// Whether this is a Mac.
    public var isMac: Bool { self == .mac }
    
#if !os(macOS)
    /// The simulator runs on the Mac's kernel, so `uname` names the Mac there. The simulator
    /// publishes the model it stands in for through its environment instead.
    private static var modelIdentifier: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var system = utsname()
        uname(&system)
        return withUnsafeBytes(of: &system.machine) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
#endif
}
