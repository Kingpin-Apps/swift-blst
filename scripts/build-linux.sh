#!/bin/bash
set -e

# Build libblst.a for Linux (x86_64 and/or arm64) and wrap it in an artifact bundle
# suitable for use as a Swift Package Manager binaryTarget.
#
# Usage:
#   bash build-linux.sh [--arch x86_64|aarch64] [--output <dir>]
#
# Output: CBlst.artifactbundle/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BLST_DIR="/tmp/blst"
# Pinned blst commit — update CHECKSUMS.md whenever this changes.
BLST_COMMIT="f262a6e9985f84e1d2842960a158dc768b217884"
BUILD_DIR="${TMPDIR:-/tmp}/cblst-linux-build"
OUTPUT="${REPO_ROOT}/CBlst.artifactbundle"
TARGET_ARCH="${TARGET_ARCH:-$(uname -m)}"  # default to host arch

while [[ $# -gt 0 ]]; do
    case "$1" in
        --arch)    TARGET_ARCH="$2"; shift 2 ;;
        --output)  OUTPUT="$2";      shift 2 ;;
        *)         echo "Unknown arg: $1"; exit 1 ;;
    esac
done

echo "==> Target arch: ${TARGET_ARCH}"
echo "==> Build dir:   ${BUILD_DIR}"
echo "==> Output:      ${OUTPUT}"

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

# ── Build blst ────────────────────────────────────────────────────────────────
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

echo "==> Building blst for Linux/${TARGET_ARCH}"
(
    cd "${BUILD_DIR}"
    CC="clang" \
    CFLAGS="-O2 -fno-builtin -fPIC -D__BLST_PORTABLE__" \
    bash "${BLST_DIR}/build.sh"
)

# ── Assemble artifact bundle ───────────────────────────────────────────────────
# SPM artifact bundle layout:
#   CBlst.artifactbundle/
#     info.json
#     CBlst/
#       <triple>/
#         lib/
#           libblst.a
#         include/
#           blst.h
#           blst_aux.h (if present)
#           module.modulemap

# Map uname arch to Swift triple
case "${TARGET_ARCH}" in
    x86_64)  TRIPLE="x86_64-unknown-linux-gnu" ;;
    aarch64|arm64) TRIPLE="aarch64-unknown-linux-gnu" ;;
    *)       TRIPLE="${TARGET_ARCH}-unknown-linux-gnu" ;;
esac

BUNDLE_LIB="${OUTPUT}/CBlst/${TRIPLE}/lib"
BUNDLE_INC="${OUTPUT}/CBlst/${TRIPLE}/include"

rm -rf "${OUTPUT}"
mkdir -p "${BUNDLE_LIB}"
mkdir -p "${BUNDLE_INC}"

cp "${BUILD_DIR}/libblst.a" "${BUNDLE_LIB}/libblst.a"
cp "${BLST_DIR}/bindings/blst.h" "${BUNDLE_INC}/"
cp "${BLST_DIR}/bindings/blst_aux.h" "${BUNDLE_INC}/" 2>/dev/null || true

cat > "${BUNDLE_INC}/module.modulemap" <<MODULEMAP
module CBlst {
    header "blst.h"
    export *
}
MODULEMAP

# Write the SPM artifact bundle info.json
cat > "${OUTPUT}/info.json" <<INFO
{
  "schemaVersion": "1.0",
  "artifacts": {
    "CBlst": {
      "type": "staticLibrary",
      "version": "1.0.0",
      "variants": [
        {
          "path": "CBlst/${TRIPLE}",
          "supportedTriples": ["${TRIPLE}"]
        }
      ]
    }
  }
}
INFO

echo ""
echo "==> Done! Artifact bundle at: ${OUTPUT}"
echo ""
ls -R "${OUTPUT}"
