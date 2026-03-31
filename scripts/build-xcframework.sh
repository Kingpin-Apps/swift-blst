#!/bin/bash
set -e

# Build CBlst.xcframework for Apple platforms
# Supports: macOS (arm64 + x86_64), iOS device (arm64), iOS Simulator (arm64 + x86_64)

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

# ── Helpers ────────────────────────────────────────────────────────────────────
build_blst() {
    local ARCH="$1"        # e.g. arm64, x86_64
    local SDK="$2"         # e.g. macosx, iphoneos, iphonesimulator
    local EXTRA_FLAGS="$3" # e.g. -D__BLST_PORTABLE__
    local OUT_DIR="$4"     # destination directory for libblst.a

    local SDK_PATH
    SDK_PATH=$(xcrun --sdk "${SDK}" --show-sdk-path)
    local MIN_VERSION_FLAG=""
    case "${SDK}" in
        macosx)           MIN_VERSION_FLAG="-mmacosx-version-min=11.0" ;;
        iphoneos)         MIN_VERSION_FLAG="-miphoneos-version-min=14.0" ;;
        iphonesimulator)  MIN_VERSION_FLAG="-mios-simulator-version-min=14.0" ;;
    esac

    local WORK_DIR="${BUILD_DIR}/${SDK}-${ARCH}"
    mkdir -p "${WORK_DIR}"

    echo "  -> Building blst for ${SDK}/${ARCH} in ${WORK_DIR}"

    # blst's build.sh reads $CC and $CFLAGS.
    # We set CFLAGS to override the default (-O2 -fno-builtin -fPIC are already defaults).
    # Pass -arch and -target as extra positional args so build.sh routes them into CFLAGS.
    (
        cd "${WORK_DIR}"
        CC="$(xcrun --sdk "${SDK}" --find clang)" \
        CFLAGS="-O2 -fno-builtin -fPIC -arch ${ARCH} -isysroot ${SDK_PATH} ${MIN_VERSION_FLAG} ${EXTRA_FLAGS}" \
        bash "${BLST_DIR}/build.sh"
    )

    mkdir -p "${OUT_DIR}"
    cp "${WORK_DIR}/libblst.a" "${OUT_DIR}/libblst.a"
}

make_framework() {
    local LIB="$1"       # path to libblst.a (possibly lipo'd universal)
    local FW_DIR="$2"    # destination .framework directory
    local NAME="CBlst"

    rm -rf "${FW_DIR}"
    mkdir -p "${FW_DIR}/Headers"

    # Copy public headers
    cp "${BLST_DIR}/bindings/blst.h" "${FW_DIR}/Headers/"
    cp "${BLST_DIR}/bindings/blst_aux.h" "${FW_DIR}/Headers/" 2>/dev/null || true

    # Write module map
    cat > "${FW_DIR}/Headers/module.modulemap" <<MODULEMAP
module CBlst {
    header "blst.h"
    export *
}
MODULEMAP

    # Copy the library (as a static framework — just copy the .a directly)
    cp "${LIB}" "${FW_DIR}/${NAME}"

    # Minimal Info.plist
    cat > "${FW_DIR}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleIdentifier</key>
    <string>org.swift-blst.CBlst</string>
    <key>CFBundleName</key>
    <string>CBlst</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>MinimumOSVersion</key>
    <string>11.0</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
</dict>
</plist>
PLIST
}

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# ── macOS arm64 ────────────────────────────────────────────────────────────────
echo "==> macOS arm64"
build_blst "arm64" "macosx" "" "${BUILD_DIR}/macos-arm64"

# ── macOS x86_64 ──────────────────────────────────────────────────────────────
echo "==> macOS x86_64"
build_blst "x86_64" "macosx" "" "${BUILD_DIR}/macos-x86_64"

# ── macOS universal lipo ───────────────────────────────────────────────────────
echo "==> Lipo macOS universal"
mkdir -p "${BUILD_DIR}/macos-universal"
lipo -create \
    "${BUILD_DIR}/macos-arm64/libblst.a" \
    "${BUILD_DIR}/macos-x86_64/libblst.a" \
    -output "${BUILD_DIR}/macos-universal/libblst.a"

# ── iOS device arm64 ──────────────────────────────────────────────────────────
echo "==> iOS device arm64"
build_blst "arm64" "iphoneos" "-D__BLST_PORTABLE__" "${BUILD_DIR}/ios-arm64"

# ── iOS Simulator arm64 ───────────────────────────────────────────────────────
echo "==> iOS Simulator arm64"
build_blst "arm64" "iphonesimulator" "-D__BLST_PORTABLE__" "${BUILD_DIR}/iossim-arm64"

# ── iOS Simulator x86_64 ──────────────────────────────────────────────────────
echo "==> iOS Simulator x86_64"
build_blst "x86_64" "iphonesimulator" "-D__BLST_PORTABLE__" "${BUILD_DIR}/iossim-x86_64"

# ── iOS Simulator universal lipo ──────────────────────────────────────────────
echo "==> Lipo iOS Simulator universal"
mkdir -p "${BUILD_DIR}/iossim-universal"
lipo -create \
    "${BUILD_DIR}/iossim-arm64/libblst.a" \
    "${BUILD_DIR}/iossim-x86_64/libblst.a" \
    -output "${BUILD_DIR}/iossim-universal/libblst.a"

# ── Wrap each into a minimal .framework ───────────────────────────────────────
echo "==> Creating .framework bundles"
make_framework "${BUILD_DIR}/macos-universal/libblst.a"  "${BUILD_DIR}/frameworks/macos/CBlst.framework"
make_framework "${BUILD_DIR}/ios-arm64/libblst.a"         "${BUILD_DIR}/frameworks/ios/CBlst.framework"
make_framework "${BUILD_DIR}/iossim-universal/libblst.a"  "${BUILD_DIR}/frameworks/iossim/CBlst.framework"

# ── Assemble XCFramework ───────────────────────────────────────────────────────
echo "==> Creating XCFramework at ${OUTPUT}"
rm -rf "${OUTPUT}"

xcodebuild -create-xcframework \
    -library "${BUILD_DIR}/macos-universal/libblst.a" \
        -headers "${BUILD_DIR}/frameworks/macos/CBlst.framework/Headers" \
    -library "${BUILD_DIR}/ios-arm64/libblst.a" \
        -headers "${BUILD_DIR}/frameworks/ios/CBlst.framework/Headers" \
    -library "${BUILD_DIR}/iossim-universal/libblst.a" \
        -headers "${BUILD_DIR}/frameworks/iossim/CBlst.framework/Headers" \
    -output "${OUTPUT}"

echo ""
echo "==> Done! XCFramework at: ${OUTPUT}"
echo ""
ls "${OUTPUT}"
