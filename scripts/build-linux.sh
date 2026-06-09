#!/bin/bash
set -e

# Build libblst.a for Linux (x86_64 and/or aarch64) and wrap it in a Swift Package
# Manager artifact bundle, consumed as a `binaryTarget`. Compiling blst as a binary
# (rather than a source target) keeps blst's required `-fno-builtin` flag — which can
# only be passed to SwiftPM via `.unsafeFlags` — out of the package graph, so the
# package can be depended on by version without tripping the "unsafe build flags" check.
#
# Usage:
#   bash build-linux.sh [--arch x86_64|aarch64] [--output <dir>]
#       Build the given arch (default: host) and (re)write info.json for every arch
#       currently present under <output>/CBlst/. Run once per arch to accumulate a
#       multi-arch bundle.
#
#   bash build-linux.sh --assemble-only [--output <dir>]
#       Skip building; just (re)write info.json from the arch directories already
#       present. Used by CI to combine per-arch outputs built on separate runners.
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
ASSEMBLE_ONLY=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --arch)          TARGET_ARCH="$2"; shift 2 ;;
        --output)        OUTPUT="$2";      shift 2 ;;
        --assemble-only) ASSEMBLE_ONLY=1;  shift ;;
        *)               echo "Unknown arg: $1"; exit 1 ;;
    esac
done

# ── (Re)write info.json listing every arch present under ${OUTPUT}/CBlst/ ───────
# Scans the per-triple directories already on disk and emits one variant each, so the
# bundle stays valid whether it holds one arch or several.
write_info_json() {
    local variants="" first=1
    for dir in "${OUTPUT}"/CBlst/*/; do
        [ -d "${dir}" ] || continue
        local triple
        triple="$(basename "${dir}")"
        [ "${first}" -eq 1 ] || variants="${variants},"
        first=0
        variants="${variants}
        {
          \"path\": \"CBlst/${triple}\",
          \"supportedTriples\": [\"${triple}\"]
        }"
    done

    if [ "${first}" -eq 1 ]; then
        echo "ERROR: no arch directories found under ${OUTPUT}/CBlst/ — nothing to assemble."
        exit 1
    fi

    cat > "${OUTPUT}/info.json" <<INFO
{
  "schemaVersion": "1.0",
  "artifacts": {
    "CBlst": {
      "type": "staticLibrary",
      "version": "1.0.0",
      "variants": [${variants}
      ]
    }
  }
}
INFO
}

if [ "${ASSEMBLE_ONLY}" -eq 1 ]; then
    echo "==> Assemble-only: regenerating info.json from existing arch dirs in ${OUTPUT}"
    write_info_json
    echo ""
    echo "==> Done! Artifact bundle at: ${OUTPUT}"
    ls -R "${OUTPUT}"
    exit 0
fi

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

# ── Place this arch into the bundle ────────────────────────────────────────────
# SPM artifact bundle layout:
#   CBlst.artifactbundle/
#     info.json
#     CBlst/
#       <triple>/
#         lib/libblst.a
#         include/{blst.h, blst_aux.h?, module.modulemap}

# Map uname arch to Swift triple
case "${TARGET_ARCH}" in
    x86_64)        TRIPLE="x86_64-unknown-linux-gnu" ;;
    aarch64|arm64) TRIPLE="aarch64-unknown-linux-gnu" ;;
    *)             TRIPLE="${TARGET_ARCH}-unknown-linux-gnu" ;;
esac

BUNDLE_LIB="${OUTPUT}/CBlst/${TRIPLE}/lib"
BUNDLE_INC="${OUTPUT}/CBlst/${TRIPLE}/include"

# Only clear this arch's directory — other arches already in the bundle are preserved.
rm -rf "${OUTPUT}/CBlst/${TRIPLE}"
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

write_info_json

echo ""
echo "==> Done! Artifact bundle at: ${OUTPUT}"
echo ""
ls -R "${OUTPUT}"
