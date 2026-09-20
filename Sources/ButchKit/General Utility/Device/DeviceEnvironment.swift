//
//  DeviceEnvironment.swift
//  ButchKit
//
//  Created by Leo Heuser on 18.09.26.
//

import SwiftUI

private struct DeviceKey: EnvironmentKey {
    static let defaultValue = Device.current
}

public extension EnvironmentValues {
    /// The ``Device`` for this view hierarchy.
    ///
    /// Works without any setup, it defaults to ``Device/current``:
    ///
    /// ```swift
    /// @Environment(\.device) private var device
    /// ```
    ///
    /// A preview can take the other branch without switching simulators:
    /// `.environment(\.device, .iPad)`. That only changes what the view reads here. The system
    /// still lays out sheets and bars for the real device.
    var device: Device {
        get { self[DeviceKey.self] }
        set { self[DeviceKey.self] = newValue }
    }
}
