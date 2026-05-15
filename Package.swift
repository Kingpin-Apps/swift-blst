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
    // Linux / Android / WebAssembly / etc. — compile blst from vendored portable C
    // source (no assembly; pinned commit per scripts/build-linux.sh).
    cblstBinaryTarget = .target(
        name: "CBlst",
        path: "BlstLinuxSource",
        exclude: [],
        // Two translation units, matching blst's official `build.sh`:
        //   - `src/server.c`         — the C library (single TU, includes every other .c)
        //   - `assembly.S`           — top-level dispatcher; includes per-arch .S files
        //                              from `elf/` (x86_64 / aarch64) and defines all
        //                              the modular-arithmetic + SHA-256 symbols that
        //                              `server.c` references but doesn't define.
        sources: ["src/server.c", "assembly.S"],
        publicHeadersPath: "include",
        cSettings: [
            .headerSearchPath("src"),
            .unsafeFlags(["-fno-builtin"]),
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
