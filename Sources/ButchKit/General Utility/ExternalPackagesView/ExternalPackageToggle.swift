//
//  ExternalPackageToggle.swift
//  ButchKit
//
//  Created by Leo Heuser on 23.09.26.
//

import SwiftUI

/// The switch of one optional package, the same one ``ExternalPackagesView`` shows under it.
///
/// For a second place the user looks for it, such as a privacy screen or an onboarding page:
/// people who want to turn analytics off look under privacy, not under licenses.
///
/// ```swift
/// Section {
///     ExternalPackageToggle(package: .analytics, texts: externalPackagesTexts)
/// }
/// ```
///
/// It stores under the package's ``ExternalPackage/ID`` and runs its
/// ``ExternalPackage/onEnabledChange``, so every copy of the switch, here or in the list, shows
/// the same decision and reacts the same way. There is no second place the decision lives.
///
/// Draws nothing for a required package, which has no switch.
public struct ExternalPackageToggle: View {
    private let package: ExternalPackage
    private let texts: ExternalPackagesTexts

    /// Stored under the package's id, which is what ``ExternalPackage/ID/isEnabled`` reads.
    @AppStorage private var isEnabled: Bool

    public init(package: ExternalPackage, texts: ExternalPackagesTexts) {
        assert(package.isOptional, "\(package.name) is required, so it has no switch.")
        self.package = package
        self.texts = texts
        // Asking the gate first moves a decision into the app group, if the id names one and it
        // is not there yet, so the switch cannot show the default over a stored decision.
        _ = package.id.isEnabled
        // The key, default and store the gate reads, so the switch always shows what it answers.
        _isEnabled = AppStorage(
            wrappedValue: package.id.enabledByDefault,
            package.id.defaultsKey,
            store: package.id.store
        )
    }

    public var body: some View {
        if package.isOptional {
            // The reaction runs in the setter rather than in `onChange`. `onChange` would also
            // fire in every other open copy of this switch, since they all watch the same stored
            // value, and run the app's reaction once per copy instead of once per flip.
            Toggle(isOn: Binding(
                get: { isEnabled },
                set: { enabled in
                    // `onEnabledChange` promises a real change, and the id stores only one.
                    guard package.id.setEnabled(enabled) else { return }
                    package.onEnabledChange?(enabled)
                }
            )) {
                texts.toggle(package.name)
            }
            .accessibilityHint(texts.toggleHint)
        }
    }
}

#if DEBUG
#Preview {
    Form {
        ExternalPackageToggle(package: .previewOptional, texts: .preview)
    }
}
#endif
