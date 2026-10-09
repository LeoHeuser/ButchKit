// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// ButchKit deliberately targets the current Swift toolchain rather than the widest one. The
// concrete cost today is the `@concurrent` attribute (SE-0461) in LogExport: it changes nothing
// under 6.2's defaults, but it keeps the "never runs on the caller's actor" guarantee true once
// the language adopts caller-inherited isolation for `nonisolated async` in Swift 7.

import PackageDescription

let package = Package(
    name: "ButchKit",
    // ButchKit words its own components, see "Localization" in `Documentation/ButchKit.md`.
    // English is the source; every other language comes from the catalogs below.
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ButchKit",
            targets: ["ButchKit"]
        )
    ],
    targets: [
        .target(
            name: "ButchKit",
            // Belongs to the paywall previews, but is a scheme file rather than a bundle resource.
            exclude: ["Services/PaywallService/Preview/ButchKitPreview.storekit"],
            resources: [
                // Placeholder photos for the paywall previews, see PaywallPreviewData.swift.
                .process("Services/PaywallService/Preview/PaywallPreviewAssets.xcassets"),
                // Each component's own words, one catalog per component.
                .process("Services/PaywallService/Paywall.xcstrings"),
                .process("General Utility/ExternalPackagesView/ExternalPackages.xcstrings")
            ]
        ),
        .testTarget(
            name: "ButchKitTests",
            dependencies: ["ButchKit"]
        )
    ]
)
