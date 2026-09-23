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
/// line of text. With the app's ``ExternalPackagesTexts/Detail`` words it opens the package's own
/// page, which holds the license text and the link to the source. Without them it opens the
/// source directly, marked by an arrow at its trailing end.
struct ExternalPackageRow: View {
    let package: ExternalPackage
    let texts: ExternalPackagesTexts

    var body: some View {
        if let detail = texts.detail {
            NavigationLink {
                ExternalPackageDetail(package: package, texts: texts, detail: detail)
            } label: {
                ExternalPackageRowContent(package: package, purpose: texts.purpose)
            }
            .accessibilityHint(detail.openHint)
        } else if let url = package.url {
            Link(destination: url) {
                // A stack rather than `LabeledContent`: in a list, `LabeledContent` drops its value
                // below a label that wraps, which put the arrow under the description instead of
                // beside the name. On the first line's baseline, the arrow stays beside the name
                // however many lines follow.
                HStack(alignment: .firstTextBaseline) {
                    ExternalPackageRowContent(package: package, purpose: texts.purpose)

                    Spacer()

                    // Sighted readers get nothing else that says this leaves the app; VoiceOver is
                    // already told it is a link, so the arrow would only repeat that.
                    Image(systemName: "arrow.up.right")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityHint(texts.sourceHint)
        } else {
            ExternalPackageRowContent(package: package, purpose: texts.purpose)
        }
    }
}

/// What every kind of row shows: which package, under which license, and what the app uses it for.
private struct ExternalPackageRowContent: View {
    let package: ExternalPackage
    let purpose: Text

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
                purpose

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
#Preview("Opens its page") {
    NavigationStack {
        List {
            ExternalPackageRow(package: .previewRequired, texts: .preview)

            ExternalPackageRow(package: .previewLong, texts: .preview)
        }
    }
}

#Preview("Opens its source") {
    List {
        ExternalPackageRow(package: .previewRequired, texts: .previewWithoutDetail)

        ExternalPackageRow(package: .previewLong, texts: .previewWithoutDetail)
    }
}
#endif
