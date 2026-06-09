# swift-blst

A Swift Package wrapping the [`blst`](https://github.com/supranational/blst) C library (Supranational, Apache 2.0) to provide **BLS12-381 elliptic curve cryptography** for Swift on macOS, iOS, and Linux.

[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20Linux-lightgrey.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

---

## Why swift-blst?

BLS12-381 is the elliptic curve used by Ethereum's consensus layer, Filecoin, Chia, and **Cardano's PlutusV3** (Chang hardfork). Cardano's UPLC evaluator requires 17 BLS12-381 built-in functions — this library provides all of them.

`swift-blst` wraps the same `blst` C library. `blst` is formally audited and assembly-optimised for ARM64 and x86_64.

---

## Platform Support

| Platform | Architecture | Notes |
|---|---|---|
| macOS 14+ | ARM64, x86_64 | Native assembly |
| iOS 16+ | ARM64 | `__BLST_PORTABLE__` used |
| iOS Simulator | ARM64, x86_64 | `__BLST_PORTABLE__` used |
| Linux | x86_64, aarch64 | Artifact bundle |

---

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Kingpin-Apps/swift-blst.git", from: "0.1.0"),
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "SwiftBLST", package: "swift-blst"),
        ]
    )
]
```

Or in Xcode: **File → Add Package Dependencies** and enter the repository URL.

---

## Quick Start

```swift
import SwiftBLST
import BigInt

// G1 point arithmetic
let g1 = G1Point.generator
let p = g1.multiplied(by: 42)
let q = g1.multiplied(by: 58)
let sum = p + q                         // point addition
let neg = p.negated()                   // point negation
print(p + neg == G1Point.infinity)      // true

// Serialization (48 bytes, SEC1 compressed)
let bytes: Data = p.compress()
let recovered = try G1Point(compressed: bytes)

// Hash to G1
let dst = Data("BLS12381G1_XMD:SHA-256_SSWU_RO_NUL_".utf8)
let hashed = G1Point.hash(to: Data("hello".utf8), dst: dst)

// G2 (96-byte compressed points — same API)
let g2 = G2Point.generator
let r = g2.multiplied(by: 42)

// Pairing: e(G1, G2) → GT
let gt = Pairing.millerLoop(g1: g1, g2: G2Point.generator)

// Verify e(a·G1, b·G2) == e(G1, (a·b)·G2)
let a: BigInt = 42
let b: BigInt = 137
let lhs = Pairing.millerLoop(g1: g1.multiplied(by: a), g2: G2Point.generator.multiplied(by: b))
let rhs = Pairing.millerLoop(g1: g1, g2: G2Point.generator.multiplied(by: a * b))
print(Pairing.finalVerify(lhs, rhs))    // true
```

---

## API Reference

### G1Point

A point on the BLS12-381 G1 curve. 48-byte compressed serialization.

| Member | Description |
|---|---|
| `.generator` | Standard generator point |
| `.infinity` | Point at infinity (identity) |
| `+` | Point addition |
| `.negated()` | Point negation |
| `.multiplied(by:)` | Scalar multiplication (accepts `BigInt`) |
| `.compress()` | Serialize to 48 bytes (SEC1 compressed) |
| `init(compressed:)` | Deserialize from 48 bytes; throws `BLSTError` |
| `.hash(to:dst:)` | Hash-to-curve, random-oracle variant (RO) |
| `.encode(to:dst:)` | Encode-to-curve, non-uniform variant (NU) |
| `.isInfinity` | True if the point at infinity |
| `.isOnCurve` | True if the point lies on the curve |
| `.isInGroup` | True if the point is in the prime-order subgroup |

### G2Point

A point on the BLS12-381 G2 curve. 96-byte compressed serialization. Identical API to `G1Point`.

### Pairing

| Member | Description |
|---|---|
| `Pairing.millerLoop(g1:g2:)` | Compute Miller loop e(G1, G2) → `Fp12` |
| `Pairing.finalVerify(_:_:)` | Check e(a) == e(b) after final exponentiation |

### Fp12

An element of the GT group (576 bytes). Result of `Pairing.millerLoop`.

| Member | Description |
|---|---|
| `*` | Multiply two GT elements |
| `==` | Equality (constant-time) |

> **Important:** Use `Pairing.finalVerify` to compare pairings in production — raw Miller loop outputs are not in final-exponentiation form, so `Fp12 ==` alone is not a correct equality check.

### BLSTError

`BLSTError` is a Swift `Error` enum that wraps all error codes from the blst C library:

| Case | Meaning |
|---|---|
| `.badEncoding` | Bytes are not a valid point encoding |
| `.pointNotOnCurve` | Point is not on the curve |
| `.pointNotInGroup` | Point is not in the prime-order subgroup |
| `.aggregationTypeMismatch` | Mixing aggregation types |
| `.verifyFail` | Signature verification failed |
| `.publicKeyIsInfinity` | Public key is the infinity point |
| `.badScalar` | Scalar is out of range |

---

## hash_to_curve vs encode_to_curve

Both `hash(to:dst:)` and `encode(to:dst:)` map arbitrary bytes to a curve point, but differ in their security properties:

| | `hash(to:dst:)` (RO) | `encode(to:dst:)` (NU) |
|---|---|---|
| blst function | `blst_hash_to_g1/g2` | `blst_encode_to_g1/g2` |
| Field elements | 2 | 1 |
| Output | Pseudorandom (indistinguishable from random) | Deterministic injective |
| Speed | ~2× slower | Faster |
| Use for | BLS signatures, UPLC builtins | Verifiable random functions, some ZKP protocols |

The Cardano UPLC `bls12_381_G1_hashToGroup` / `bls12_381_G2_hashToGroup` builtins use the **RO** variant (`hash`).

---

## Cardano UPLC BLS12-381 Builtins

This library covers all 17 BLS12-381 built-in functions required by PlutusV3:

**G1 (7):** `add`, `neg`, `scalarMul`, `equal`, `compress`, `uncompress`, `hashToGroup`

**G2 (7):** same set for G2

**Pairing (3):** `millerLoop`, `mulMlResult` (`Fp12.*`), `finalVerify`

---

## Updating blst

The pre-built binaries in `CBlst.xcframework/` and `CBlst.artifactbundle/` are built from blst at a pinned revision. To update:

```bash
# Re-clone blst at the desired tag
git clone --depth 1 --branch v0.3.13 https://github.com/supranational/blst.git /tmp/blst

# Rebuild Apple platforms (run on macOS)
bash scripts/build-xcframework.sh

# Rebuild Linux (run in a Linux environment or Docker)
bash scripts/build-linux.sh
```

Then commit the updated `CBlst.xcframework/` and `CBlst.artifactbundle/` directories.

### iOS and `__BLST_PORTABLE__`

The iOS and iOS Simulator slices are built with `-D__BLST_PORTABLE__`, which disables hand-written ARMv8 assembly in favour of portable C fallbacks. This is ~2–3× slower but required by the iOS SDK. macOS ARM64 uses native assembly without this flag.

---

## Development

### Running Tests

```bash
swift test
```

The test suite includes:
- Compress/decompress round-trips
- Arithmetic identities (associativity, P + (−P) = ∞, etc.)
- Pairing bilinearity
- Official `blst` hash-to-curve test vectors (all 4 suites: G1/G2 × RO/NU)

### Project Structure

```
swift-blst/
├── Package.swift
├── scripts/
│   ├── build-xcframework.sh    # Build CBlst.xcframework (run on macOS)
│   └── build-linux.sh          # Build CBlst.artifactbundle (run on Linux)
├── CBlst.xcframework/          # Pre-built: macOS + iOS + iOS Simulator
├── CBlst.artifactbundle/       # Pre-built: Linux x86_64 + aarch64
└── Sources/
    └── SwiftBLST/
        ├── G1Point.swift
        ├── G2Point.swift
        ├── Fp12.swift
        ├── Pairing.swift
        ├── BLSTError.swift
        ├── Scalar.swift
        └── Internal/
            └── WithUnsafeBlstPointer.swift
```

## License

`swift-blst` is released under the **Apache 2.0 License**.

The bundled `blst` library is also Apache 2.0. See [blst/LICENSE](https://github.com/supranational/blst/blob/master/LICENSE).
