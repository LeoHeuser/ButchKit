//
//  ExternalPackageRow.swift
//  ButchKit
//
//  Created by Leo Heuser on 02.09.26.
//

import SwiftUI

/// One package's row in ``ExternalPackagesView``: the package, its license, what the app uses it
/// for, and the way to its source.
///
/// The whole row is the link rather than a word underneath it. There is one thing to do with an
/// entry in this list -- go and read the package -- and a row that does it is a larger target
/// than a line of text, marked by an arrow at its trailing end.
struct ExternalPackageRow: View {
    let package: ExternalPackage
    let texts: ExternalPackagesTexts

    /// Between the name and the purpose. Wider than the gap inside the purpose, so the row reads
    /// as two blocks: which package, and why it is here.
    private static let groupSpacing: CGFloat = 8

    /// Between the purpose label and its text. Tight, so the label reads as the caption of that
    /// text rather than as a line of its own.
    private static let purposeSpacing: CGFloat = 4

    /// Above and below the row, so neighboring packages do not run into each other.
    private static let rowPadding: CGFloat = 4

    var body: some View {
        Link(destination: package.url) {
            // A stack rather than `LabeledContent`: in a list, `LabeledContent` drops its value
            // below a label that wraps, which put the arrow under the description instead of
            // beside the name. On the first line's baseline, the arrow stays beside the name
            // however many lines follow.
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Self.groupSpacing) {
                    // A package's name and its license identifier are what they are, not
                    // language. The description is already resolved by `ExternalPackage`.
                    //
                    // The license shares the name's line rather than taking one of its own: a
                    // short identifier does not earn a line, and at the name's size in regular
                    // weight it still reads as secondary.
                    (Text(verbatim: package.name)
                     + Text(verbatim: " · \(package.license)").fontWeight(.regular))
                        .font(.headline)
                        // Only this line in the tint: it names what the link opens, so it is the
                        // part that has to look pressable.
                        .foregroundStyle(.tint)

                    VStack(alignment: .leading, spacing: Self.purposeSpacing) {
                        texts.purpose

                        Text(verbatim: package.description)
                    }
                    .font(.subheadline)
                    // `Color.secondary` rather than `.secondary`: inside a link the hierarchical
                    // style resolves against the tint, which turns this text a faded blue that
                    // reads worse than plain gray.
                    .foregroundStyle(Color.secondary)
                }
                .padding(.vertical, Self.rowPadding)
                // One item for VoiceOver, so each package is one swipe, not two.
                .accessibilityElement(children: .combine)

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
    }
}

#if DEBUG
#Preview {
    List {
        ExternalPackageRow(package: .previewRequired, texts: .preview)

        ExternalPackageRow(package: .previewLong, texts: .preview)
    }
}
#endif
