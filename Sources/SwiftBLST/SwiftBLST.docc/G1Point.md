# ``SwiftBLST/G1Point``

A point on the BLS12-381 G1 curve, with 48-byte compressed serialization.

## Overview

`G1Point` is the primary type for G1 group operations. Points are stored internally in projective (Jacobian) coordinates and converted to affine form only for serialization — this avoids field inversions during arithmetic.

All `G1Point` values are value types (`struct`) and are safe to use across concurrent contexts (`Sendable`).

### Arithmetic

Point addition and scalar multiplication are the fundamental operations. The scalar accepts an arbitrary-precision `BigInt`, matching the Cardano UPLC integer type directly.

```swift
let g = G1Point.generator

// Addition
let twoG = g + g

// Negation
let negG = g.negated()
assert(g + negG == G1Point.infinity)

// Scalar multiplication
let p = g.multiplied(by: 12345)

// Associativity: (a·b)·G == a·(b·G)
let a: BigInt = 7
let b: BigInt = 11
assert(g.multiplied(by: a * b) == g.multiplied(by: b).multiplied(by: a))
```

### Serialization

The compressed format is 48 bytes per the SEC1 standard and the BLS12-381 specification. The most-significant bit signals compression; the second bit signals the sign of the y coordinate.

```swift
// Compress
let bytes: Data = G1Point.generator.compress()  // 48 bytes

// Decompress — validates curve membership and subgroup membership
let point = try G1Point(compressed: bytes)
```

Throws ``BLSTError/badEncoding`` if the input is not 48 bytes or is not a valid point encoding. Throws ``BLSTError/pointNotInGroup`` if the point is on the curve but outside the prime-order subgroup (cofactor check).

### Hash to Curve

Two variants are provided, following the IETF hash-to-curve specification (RFC 9380):

```swift
let msg = Data("my message".utf8)

// Random-oracle variant (RO) — use for BLS signatures and Cardano UPLC
let dst = Data("BLS12381G1_XMD:SHA-256_SSWU_RO_NUL_".utf8)
let p1 = G1Point.hash(to: msg, dst: dst)

// Non-uniform variant (NU) — deterministic injective encoding, faster
let dst2 = Data("BLS12381G1_XMD:SHA-256_SSWU_NU_NUL_".utf8)
let p2 = G1Point.encode(to: msg, dst: dst2)
```

The `dst` (Domain Separation Tag) must be unique to your application and protocol. Never reuse the same DST for different purposes.

## Topics

### Constants

- ``generator``
- ``infinity``

### Arithmetic

- ``+(_:_:)``
- ``negated()``
- ``multiplied(by:)``

### Serialization

- ``compress()``
- ``init(compressed:)``

### Hash to Curve

- ``hash(to:dst:)``
- ``encode(to:dst:)``

### Validation

- ``isInfinity``
- ``isOnCurve``
- ``isInGroup``
