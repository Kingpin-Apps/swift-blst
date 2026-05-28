#!/bin/bash
set -e

# Build CBlst.xcframework for all Apple platforms.
# Supported slices:
#   - macOS      (arm64 + x86_64)
#   - iOS        device (arm64), simulator (arm64 + x86_64)
#   - tvOS       device (arm64), simulator (arm64 + x86_64)
#   - watchOS    device (arm64_32 + arm64), simulator (arm64 + x86_64)
#   - visionOS   device (arm64), simulator (arm64)
#
# All non-macOS/iOS-device slices use blst's portable mode (`-D__BLST_PORTABLE__`)
# so no assembly is required.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BLST_DIR="/tmp/blst"
# Pinned blst commit — update CHECKSUMS.md whenever this changes.
BLST_COMMIT="f262a6e9985f84e1d2842960a158dc768b217884"
BUILD_DIR="${TMPDIR:-/tmp}/cblst-build"
OUTPUT="${REPO_ROOT}/CBlst.xcframework"

echo "==> Build dir: ${BUILD_DIR}"
echo "==> Output:    ${OUTPUT}"

# ── Clone blst if needed ───────────────────────────────────────────────────────
if [ ! -d "${BLST_DIR}" ]; then
    echo "==> Cloning blst..."
    git clone https://github.com/supranational/blst.git "${BLST_DIR}"
    git -C "${BLST_DIR}" checkout "${BLST_COMMIT}"
else
    echo "==> Using existing blst at ${BLST_DIR}"
    ACTUAL=$(git -C "${BLST_DIR}" rev-parse HEAD)
    if [ "${ACTUAL}" != "${BLST_COMMIT}" ]; then
        echo "ERROR: ${BLST_DIR} is at ${ACTUAL}, expected ${BLST_COMMIT}"
        echo "       Delete ${BLST_DIR} and re-run to get the pinned commit."
        exit 1
    fi
fi

# ── Build helper ──────────────────────────────────────────────────────────────
# Compile blst for one (target-triple, sdk) pair and drop libblst.a in OUT_DIR.
build_blst() {
    local TARGET="$1"      # e.g. arm64-apple-tvos14.0, x86_64-apple-watchos9.0-simulator
    local ARCH="$2"        # arm64, x86_64, arm64_32 — used only to name the work dir
    local SDK="$3"         # macosx, iphoneos, iphonesimulator, appletvos, appletvsimulator, watchos, watchsimulator, xros, xrsimulator
    local EXTRA_FLAGS="$4" # e.g. -D__BLST_PORTABLE__
    local OUT_DIR="$5"

    local SDK_PATH
    SDK_PATH=$(xcrun --sdk "${SDK}" --show-sdk-path)

    local WORK_DIR="${BUILD_DIR}/${SDK}-${ARCH}"
    mkdir -p "${WORK_DIR}"

    echo "  -> Building blst for ${TARGET} (sdk ${SDK})"

    (
        cd "${WORK_DIR}"
        CC="$(xcrun --sdk "${SDK}" --find clang)" \
        CFLAGS="-O2 -fno-builtin -fPIC -target ${TARGET} -isysroot ${SDK_PATH} ${EXTRA_FLAGS}" \
        bash "${BLST_DIR}/build.sh"
    )

    mkdir -p "${OUT_DIR}"
    # Skip cp if the build wrote directly to OUT_DIR (paths collide when the
    # SDK name matches our short OUT_DIR name, e.g. watchos-arm64).
    if [ "${WORK_DIR}/libblst.a" != "${OUT_DIR}/libblst.a" ]; then
        cp "${WORK_DIR}/libblst.a" "${OUT_DIR}/libblst.a"
    fi
}

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Portable C only (no assembly) — required for non-x86_64/arm64-device platforms,
# and we use it uniformly on simulators too so a single flag-set covers everything.
PORTABLE="-D__BLST_PORTABLE__"

# ── macOS ──────────────────────────────────────────────────────────────────────
echo "==> macOS"
build_blst "arm64-apple-macos11.0"  "arm64"  "macosx" ""                  "${BUILD_DIR}/macos-arm64"
build_blst "x86_64-apple-macos11.0" "x86_64" "macosx" ""                  "${BUILD_DIR}/macos-x86_64"
mkdir -p "${BUILD_DIR}/macos-universal"
lipo -create \
    "${BUILD_DIR}/macos-arm64/libblst.a" \
    "${BUILD_DIR}/macos-x86_64/libblst.a" \
    -output "${BUILD_DIR}/macos-universal/libblst.a"

# ── iOS ────────────────────────────────────────────────────────────────────────
echo "==> iOS"
build_blst "arm64-apple-ios14.0"            "arm64"  "iphoneos"        "${PORTABLE}" "${BUILD_DIR}/ios-arm64"
build_blst "arm64-apple-ios14.0-simulator"  "arm64"  "iphonesimulator" "${PORTABLE}" "${BUILD_DIR}/iossim-arm64"
build_blst "x86_64-apple-ios14.0-simulator" "x86_64" "iphonesimulator" "${PORTABLE}" "${BUILD_DIR}/iossim-x86_64"
mkdir -p "${BUILD_DIR}/iossim-universal"
lipo -create \
    "${BUILD_DIR}/iossim-arm64/libblst.a" \
    "${BUILD_DIR}/iossim-x86_64/libblst.a" \
    -output "${BUILD_DIR}/iossim-universal/libblst.a"

# ── tvOS ───────────────────────────────────────────────────────────────────────
echo "==> tvOS"
build_blst "arm64-apple-tvos14.0"            "arm64"  "appletvos"        "${PORTABLE}" "${BUILD_DIR}/tvos-arm64"
build_blst "arm64-apple-tvos14.0-simulator"  "arm64"  "appletvsimulator" "${PORTABLE}" "${BUILD_DIR}/tvossim-arm64"
build_blst "x86_64-apple-tvos14.0-simulator" "x86_64" "appletvsimulator" "${PORTABLE}" "${BUILD_DIR}/tvossim-x86_64"
mkdir -p "${BUILD_DIR}/tvossim-universal"
lipo -create \
    "${BUILD_DIR}/tvossim-arm64/libblst.a" \
    "${BUILD_DIR}/tvossim-x86_64/libblst.a" \
    -output "${BUILD_DIR}/tvossim-universal/libblst.a"

# ── watchOS ────────────────────────────────────────────────────────────────────
# Device slice covers both arm64_32 (Series 4–9) and arm64 (Series 10+, Ultra).
echo "==> watchOS"
build_blst "arm64_32-apple-watchos7.0"        "arm64_32" "watchos"        "${PORTABLE}" "${BUILD_DIR}/watchos-arm64_32"
build_blst "arm64-apple-watchos9.0"           "arm64"    "watchos"        "${PORTABLE}" "${BUILD_DIR}/watchos-arm64"
build_blst "arm64-apple-watchos9.0-simulator" "arm64"    "watchsimulator" "${PORTABLE}" "${BUILD_DIR}/watchossim-arm64"
build_blst "x86_64-apple-watchos9.0-simulator" "x86_64"  "watchsimulator" "${PORTABLE}" "${BUILD_DIR}/watchossim-x86_64"
mkdir -p "${BUILD_DIR}/watchos-universal"
lipo -create \
    "${BUILD_DIR}/watchos-arm64_32/libblst.a" \
    "${BUILD_DIR}/watchos-arm64/libblst.a" \
    -output "${BUILD_DIR}/watchos-universal/libblst.a"
mkdir -p "${BUILD_DIR}/watchossim-universal"
lipo -create \
    "${BUILD_DIR}/watchossim-arm64/libblst.a" \
    "${BUILD_DIR}/watchossim-x86_64/libblst.a" \
    -output "${BUILD_DIR}/watchossim-universal/libblst.a"

# ── visionOS ───────────────────────────────────────────────────────────────────
# Simulator is arm64-only (visionOS Simulator runs only on Apple silicon).
echo "==> visionOS"
build_blst "arm64-apple-xros1.0"           "arm64" "xros"        "${PORTABLE}" "${BUILD_DIR}/xros-arm64"
build_blst "arm64-apple-xros1.0-simulator" "arm64" "xrsimulator" "${PORTABLE}" "${BUILD_DIR}/xrossim-arm64"

# ── Assemble XCFramework ───────────────────────────────────────────────────────
# Headerless on purpose: blst.h lives in CBlstModule/include and is exposed via
# the CBlst wrapper target in Package.swift. Keeping the xcframework headerless
# prevents modulemap collisions when this package is combined with others.
echo "==> Creating XCFramework at ${OUTPUT}"
rm -rf "${OUTPUT}"

xcodebuild -create-xcframework \
    -library "${BUILD_DIR}/macos-universal/libblst.a" \
    -library "${BUILD_DIR}/ios-arm64/libblst.a" \
    -library "${BUILD_DIR}/iossim-universal/libblst.a" \
    -library "${BUILD_DIR}/tvos-arm64/libblst.a" \
    -library "${BUILD_DIR}/tvossim-universal/libblst.a" \
    -library "${BUILD_DIR}/watchos-universal/libblst.a" \
    -library "${BUILD_DIR}/watchossim-universal/libblst.a" \
    -library "${BUILD_DIR}/xros-arm64/libblst.a" \
    -library "${BUILD_DIR}/xrossim-arm64/libblst.a" \
    -output "${OUTPUT}"

echo ""
echo "==> Done! XCFramework at: ${OUTPUT}"
echo ""
ls "${OUTPUT}"
