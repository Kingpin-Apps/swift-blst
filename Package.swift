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
        // Only safe cSettings here. blst recommends `-fno-builtin`, but SwiftPM accepts
        // it solely via `.unsafeFlags`, which bars this package from being used as a
        // versioned dependency (the whole Cardano stack hit "target 'CBlst' contains
        // unsafe build flags" on Linux). Compile from source like swift-nacl's
        // Clibsodium does — safe cSettings only — so downstream packages can depend on
        // swift-blst by version. blst's constant-time field arithmetic lives in the
        // hand-written assembly (`assembly.S`), not the C glue affected by the flag.
        cSettings: [
            .headerSearchPath("src"),
        ]
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
            path: "Sources/SwiftBLST"
            // No resources: a stray `Resources/cz.json` (the Commitizen config, duplicated from
            // the repo root) was previously `.copy`'d, producing a nested-`Resources/` bundle that
            // iOS codesign rejects as "unsuitable". The library ships no real assets.
        ),
        .testTarget(
            name: "SwiftBLSTTests",
            dependencies: ["SwiftBLST"],
            path: "Tests/SwiftBLSTTests",
            resources: [.copy("Vectors")]
        ),
    ]
)
