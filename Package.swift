// swift-tools-version: 6.2
import PackageDescription
import Foundation

// On Apple platforms, the CBlst binary (xcframework) is headerless to avoid
// modulemap collisions when combined with other xcframework packages.
// Headers are provided separately via the CBlst wrapper target.
let cblstBinaryTarget: Target
let cblstTargets: [Target]
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    cblstBinaryTarget = .binaryTarget(
        name: "_CBlstBinary",
        path: "CBlst.xcframework"
    )
    cblstTargets = [
        cblstBinaryTarget,
        .target(
            name: "CBlst",
            dependencies: ["_CBlstBinary"],
            path: "CBlstModule",
            publicHeadersPath: "include"
        ),
    ]
#elseif os(Linux)
    cblstBinaryTarget = .binaryTarget(
        name: "CBlst",
        path: "CBlst.artifactbundle"
    )
    cblstTargets = [cblstBinaryTarget]
#else
    cblstBinaryTarget = .systemLibrary(
        name: "CBlst",
        path: "CBlst",
        pkgConfig: "blst",
        providers: [
            .apt(["libblst-dev"]),
            .brew(["blst"]),
        ]
    )
    cblstTargets = [cblstBinaryTarget]
#endif

let package = Package(
    name: "swift-blst",
    platforms: [
        .macOS(.v14),
        .iOS(.v16),
    ],
    products: [
        .library(name: "CBlst", targets: ["CBlst"]),
        .library(name: "SwiftBLST", targets: ["SwiftBLST"]),
    ],
    dependencies: [
        .package(url: "https://github.com/attaswift/BigInt.git", .upToNextMinor(from: "5.3.0")),
    ],
    targets: cblstTargets + [
        .target(
            name: "SwiftBLST",
            dependencies: [
                "CBlst",
                .product(name: "BigInt", package: "BigInt"),
            ],
            path: "Sources/SwiftBLST",
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "SwiftBLSTTests",
            dependencies: ["SwiftBLST"],
            path: "Tests/SwiftBLSTTests",
            resources: [.copy("Vectors")]
        ),
    ]
)
