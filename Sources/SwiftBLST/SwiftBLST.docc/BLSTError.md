# ``SwiftBLST/BLSTError``

Errors returned by the blst C library, bridged to Swift.

## Overview

`BLSTError` is thrown by any operation that validates input from an untrusted source — primarily ``G1Point/init(compressed:)`` and ``G2Point/init(compressed:)``. All other operations (arithmetic, hashing) are total functions that always succeed.

```swift
do {
    let point = try G1Point(compressed: untrustedBytes)
    // point is guaranteed to be on the curve and in the prime-order subgroup
} catch BLSTError.badEncoding {
    // not 48 bytes, or the encoding bits are invalid
} catch BLSTError.pointNotInGroup {
    // valid point encoding, but not in the G1 prime-order subgroup
} catch {
    // other blst errors (aggregation, scalar, etc.)
}
```

### Subgroup Checks

`init(compressed:)` always performs both a curve check *and* a subgroup (cofactor) check. A point that passes the curve check but fails the subgroup check throws ``pointNotInGroup``. Skipping the subgroup check is a known attack vector in BLS12-381 — SwiftBLST does not allow it.

## Topics

### Error Cases

- ``badEncoding``
- ``pointNotOnCurve``
- ``pointNotInGroup``
- ``aggregationTypeMismatch``
- ``verifyFail``
- ``publicKeyIsInfinity``
- ``badScalar``
