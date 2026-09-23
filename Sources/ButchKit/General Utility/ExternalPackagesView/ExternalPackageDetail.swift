//
//  ExternalPackageDetail.swift
//  ButchKit
//
//  Created by Leo Heuser on 23.09.26.
//

import SwiftUI

/// One package's own page: its copyright notice and license text, and the way to its source.
///
/// This is what the license asks the app to include, so it is in the app itself, readable offline
/// and fixed to the text the app shipped with, rather than behind a link to a repository that can
/// move.
struct ExternalPackageDetail: View {
    let package: ExternalPackage
    let texts: ExternalPackagesTexts
    let detail: ExternalPackagesTexts.Detail

    var body: some View {
        List {
            // A license handed in by name alone has nothing to show here; its name is in the row.
            if package.copyright != nil || package.licenseText != nil {
                ExternalPackageLicenseSection(package: package)
            }

            if let url = package.url {
                Section {
                    Link(destination: url) {
                        HStack {
                            Text(detail.source)

                            Spacer()

                            // Sighted readers get nothing else that says this leaves the app;
                            // VoiceOver is already told it is a link.
                            Image(systemName: "arrow.up.right")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityHint(texts.sourceHint)
                }
            }
        }
        // The package's name is what it is, not language.
        .navigationTitle(Text(verbatim: package.name))
    }
}

/// The license as the package states it: the notice, then the full text, under the license's name.
private struct ExternalPackageLicenseSection: View {
    let package: ExternalPackage

    /// Between the notice and the text, so the notice reads as the text's heading.
    @ScaledMetric private var noticeSpacing: CGFloat = 12

    /// Above and below the text, so it does not touch the section's edges.
    @ScaledMetric private var textPadding: CGFloat = 4

    var body: some View {
        Section {
            // The notice stands directly above the text, which is where the text's "above
            // copyright notice" expects it.
            VStack(alignment: .leading, spacing: noticeSpacing) {
                if let copyright = package.copyright {
                    Text(verbatim: copyright)
                        .font(.subheadline.weight(.semibold))
                }

                if let licenseText = package.licenseText {
                    Text(verbatim: licenseText)
                        .font(.footnote)
                }
            }
            .padding(.vertical, textPadding)
            // Legal text is something people quote and paste into a request.
            .textSelection(.enabled)
        } header: {
            Text(verbatim: package.license)
        }
    }
}

#if DEBUG
#Preview("MIT") {
    NavigationStack {
        ExternalPackageDetail(package: .previewOptional, texts: .preview, detail: .preview)
    }
}

#Preview("Apache 2.0") {
    NavigationStack {
        ExternalPackageDetail(package: .previewRequired, texts: .preview, detail: .preview)
    }
}

#Preview("No text") {
    NavigationStack {
        ExternalPackageDetail(package: .previewLong, texts: .preview, detail: .preview)
    }
}
#endif
