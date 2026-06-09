// swift-tools-version: 6.0
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
#else
    // Linux / Android / WebAssembly / etc. — consume a pre-built static blst library
    // as a binaryTarget. blst requires `-fno-builtin` (see scripts/build-linux.sh),
    // which SwiftPM only accepts via `.unsafeFlags`; a versioned package exposing
    // unsafe flags cannot be used as a dependency, so we keep that flag inside the
    // offline artifact build and ship the result as a flag-free binary instead.
    // Build/refresh the bundle with `scripts/build-linux.sh` (CI: build-linux.yml).
    cblstBinaryTarget = .binaryTarget(
        name: "CBlst",
        path: "CBlst.artifactbundle"
    )
    cblstTargets = [cblstBinaryTarget]
#endif

let package = Package(
    name: "SwiftBLST",
    platforms: [
        .macOS(.v14),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "CBlst", targets: ["CBlst"]),
        .library(name: "SwiftBLST", targets: ["SwiftBLST"]),
    ],
    dependencies: [
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.7.0"),
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
