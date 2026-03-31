import CBlst
import BigInt

/// A BLS12-381 scalar (256-bit integer) for key-management operations.
///
/// Note: `blst_p1_mult` / `blst_p2_mult` take raw big-endian bytes, not a `blst_scalar`.
/// Use `BigInt.blstMultiplierBytes()` (in `Internal/WithUnsafeBlstPointer.swift`) for
/// point multiplication. This type is provided for completeness and interop with
/// blst's key-derivation APIs.
public struct BLSTScalar: Sendable {

    internal var inner: blst_scalar

    /// Create from a `BigInt` value via big-endian byte representation.
    public init(_ value: BigInt) {
        var s = blst_scalar()
        let bytes = value.bigEndianBytesPadded(to: 32)
        bytes.withUnsafeBytes { ptr in
            blst_scalar_from_bendian(&s, ptr.baseAddress)
        }
        self.inner = s
    }

    /// Create from exactly 32 big-endian bytes.
    ///
    /// - Throws: `BLSTError.badScalar` if the input is not 32 bytes.
    public init(bytes: [UInt8]) throws {
        guard bytes.count == 32 else { throw BLSTError.badScalar }
        var s = blst_scalar()
        bytes.withUnsafeBytes { ptr in
            blst_scalar_from_bendian(&s, ptr.baseAddress)
        }
        self.inner = s
    }

    /// The scalar value as 32 big-endian bytes.
    public func toBytes() -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 32)
        var s = inner
        blst_bendian_from_scalar(&out, &s)
        return out
    }
}
