# ``SwiftBLST/G2Point``

A point on the BLS12-381 G2 curve, with 96-byte compressed serialization.

## Overview

`G2Point` is the G2 counterpart to ``G1Point``. The API is identical — only the compressed size (96 bytes vs 48) and the underlying curve differ. G2 is defined over an extension field Fp2, making operations roughly 3× slower than G1.

In BLS signature schemes, public keys typically live in G1 and signatures in G2 (or vice versa). In Cardano's UPLC, both groups are used for the 17 BLS12-381 built-in functions.

```swift
let g = G2Point.generator

// Arithmetic
let p = g.multiplied(by: 42)
let q = g.multiplied(by: 58)
let sum = p + q
assert(g + g.negated() == G2Point.infinity)

// Serialization (96 bytes)
let bytes = p.compress()
let recovered = try G2Point(compressed: bytes)

// Hash to G2
let dst = Data("BLS12381G2_XMD:SHA-256_SSWU_RO_NUL_".utf8)
let hashed = G2Point.hash(to: Data("hello".utf8), dst: dst)
```

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
