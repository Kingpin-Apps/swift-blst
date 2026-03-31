# ``SwiftBLST``

BLS12-381 elliptic curve cryptography for Swift — a wrapper around the audited `blst` C library.

## Overview

SwiftBLST provides group arithmetic, point serialization, hash-to-curve, and pairing operations for the BLS12-381 curve. It covers all 17 BLS12-381 built-in functions required by Cardano's PlutusV3 UPLC evaluator, and is suitable for general-purpose BLS cryptography on Apple platforms and Linux.

The library wraps [`blst`](https://github.com/supranational/blst) (Supranational, Apache 2.0) — the same C library used by Ethereum's consensus layer, Filecoin, Chia, and Aiken's Rust `uplc` crate.

### Working with G1 and G2 Points

The two curve groups, ``G1Point`` and ``G2Point``, have identical APIs. Points can be created from the standard generator, by deserializing compressed bytes, or by hashing arbitrary data.

```swift
import SwiftBLST
import BigInt

// Arithmetic
let g = G1Point.generator
let p = g.multiplied(by: 42)
let q = g.multiplied(by: 58)
let sum = p + q
let neg = p.negated()
assert(p + neg == G1Point.infinity)

// Serialization
let bytes = p.compress()                        // 48 bytes
let recovered = try G1Point(compressed: bytes)

// Hash to curve
let dst = Data("BLS12381G1_XMD:SHA-256_SSWU_RO_NUL_".utf8)
let point = G1Point.hash(to: Data("hello".utf8), dst: dst)
```

### Pairings

``Pairing`` computes the Miller loop and final-exponentiation verification over G1 × G2 → GT.

```swift
// Compute e(a·G1, b·G2) and verify it equals e(G1, (a·b)·G2)
let a: BigInt = 42
let b: BigInt = 137

let lhs = Pairing.millerLoop(
    g1: G1Point.generator.multiplied(by: a),
    g2: G2Point.generator.multiplied(by: b)
)
let rhs = Pairing.millerLoop(
    g1: G1Point.generator,
    g2: G2Point.generator.multiplied(by: a * b)
)
assert(Pairing.finalVerify(lhs, rhs))
```

### Error Handling

Operations that may fail — deserialization and group-membership checks — throw ``BLSTError``:

```swift
do {
    let point = try G1Point(compressed: someBytes)
} catch BLSTError.badEncoding {
    // bytes were not a valid compressed G1 point
} catch BLSTError.pointNotInGroup {
    // point is on the curve but not in the prime-order subgroup
}
```

## Topics

### G1 Curve

- ``G1Point``

### G2 Curve

- ``G2Point``

### Pairing

- ``Pairing``
- ``Fp12``

### Errors

- ``BLSTError``

### Key Management

- ``BLSTScalar``
