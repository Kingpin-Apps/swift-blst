# ``SwiftBLST/Pairing``

BLS12-381 pairing operations: Miller loop and final exponentiation.

## Overview

A pairing is a bilinear map e: G1 × G2 → GT, where GT is the multiplicative subgroup of Fp12. SwiftBLST exposes two operations:

- **``millerLoop(g1:g2:)``** — the computationally heavy part that produces a raw Fp12 value
- **``finalVerify(_:_:)``** — applies the final exponentiation and checks equality of two pairings

The typical pattern for verifying a BLS signature or a SNARK proof is:

```swift
// Check e(a·G1, b·G2) == e(G1, (a·b)·G2)
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

### Argument Order

`blst_miller_loop` takes G2 first, then G1 (the opposite of mathematical convention). `millerLoop(g1:g2:)` uses labelled parameters to avoid confusion — always pass the G1 point to `g1:` and the G2 point to `g2:`.

### Multiplying Miller Loop Results

When combining multiple pairings (e.g., for batch verification), multiply the raw ``Fp12`` values before calling `finalVerify`:

```swift
let e1 = Pairing.millerLoop(g1: p1, g2: q1)
let e2 = Pairing.millerLoop(g1: p2, g2: q2)
// Check e(p1,q1) · e(p2,q2) == 1
let product = e1 * e2
```

### Why Not Use Fp12 == Directly?

Raw Miller loop outputs are *not* in final-exponentiation form. Two mathematically equal pairings may produce different `Fp12` values from the Miller loop. Always use ``finalVerify(_:_:)`` for pairing equality checks.

## Topics

### Operations

- ``millerLoop(g1:g2:)``
- ``finalVerify(_:_:)``
