//
//  ExternalPackageRow.swift
//  ButchKit
//
//  Created by Leo Heuser on 02.09.26.
//

import SwiftUI

/// One package's row in ``ExternalPackagesView``: the package, its license, and what the app uses
/// it for.
///
/// The whole row is the way in rather than a word underneath it: a row is a larger target than a
/// line of text. It opens the package's own page, which holds the license text and the link to the
/// source.
struct ExternalPackageRow: View {
    let package: ExternalPackage

    var body: some View {
        NavigationLink {
            ExternalPackageDetail(package: package)
        } label: {
            ExternalPackageRowContent(package: package)
        }
        .accessibilityHint(Text("accessibility.hint.externalPackages.open", tableName: "ExternalPackages", bundle: .module))
    }
}

/// What every kind of row shows: which package, under which license, and what the app uses it for.
private struct ExternalPackageRowContent: View {
    let package: ExternalPackage

    /// Between the name and the purpose. Wider than the gap inside the purpose, so the row reads
    /// as two blocks: which package, and why it is here. Scaled, so the gaps grow with the text.
    @ScaledMetric private var groupSpacing: CGFloat = 8

    /// Between the purpose label and its text. Tight, so the label reads as the caption of that
    /// text rather than as a line of its own.
    @ScaledMetric private var purposeSpacing: CGFloat = 4

    /// Above and below the row, so neighboring packages do not run into each other.
    @ScaledMetric private var rowPadding: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: groupSpacing) {
            // A package's name and its license identifier are what they are, not language. The
            // description is already resolved by `ExternalPackage`.
            //
            // The license shares the name's line rather than taking one of its own: a short
            // identifier does not earn a line, and at the name's size in regular weight it still
            // reads as secondary.
            Text("\(Text(verbatim: package.name))\(Text(verbatim: " · \(package.license)").fontWeight(.regular))")
                .font(.headline)
                // Only this line in the tint: it names what the row opens, so it is the part that
                // has to look pressable.
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: purposeSpacing) {
                Text("label.externalPackages.purpose \(ExternalPackagesView.appName)", tableName: "ExternalPackages", bundle: .module)

                Text(verbatim: package.description)
            }
            .font(.subheadline)
            // `Color.secondary` rather than `.secondary`: inside a link the hierarchical style
            // resolves against the tint, which turns this text a faded blue that reads worse than
            // plain gray.
            .foregroundStyle(Color.secondary)
        }
        .padding(.vertical, rowPadding)
        // One item for VoiceOver, so each package is one swipe, not two.
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        List {
            ExternalPackageRow(package: .previewRequired)

            ExternalPackageRow(package: .previewLong)
        }
    }
}
#endif
