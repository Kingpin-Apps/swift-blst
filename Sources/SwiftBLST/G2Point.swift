import CBlst
import BigInt
import Foundation

/// A point on the BLS12-381 G2 curve.
///
/// Internally stored in projective (Jacobian) coordinates (`blst_p2`).
/// Serialization uses the 96-byte SEC1 compressed format.
public struct G2Point: Sendable, Equatable {

    internal var inner: blst_p2

    internal init(inner: blst_p2) {
        self.inner = inner
    }

    // MARK: - Constants

    /// The standard generator point for G2.
    public static let generator: G2Point = {
        var p = blst_p2()
        blst_p2_from_affine(&p, blst_p2_affine_generator())
        return G2Point(inner: p)
    }()

    /// The point at infinity (identity element).
    public static let infinity: G2Point = {
        return G2Point(inner: blst_p2())
    }()

    // MARK: - Arithmetic

    /// Point addition: `lhs + rhs`.
    public static func + (lhs: G2Point, rhs: G2Point) -> G2Point {
        var out = blst_p2()
        var l = lhs.inner
        var r = rhs.inner
        blst_p2_add_or_double(&out, &l, &r)
        return G2Point(inner: out)
    }

    /// Point negation: `-self`.
    public func negated() -> G2Point {
        var p = inner
        blst_p2_cneg(&p, true)
        return G2Point(inner: p)
    }

    /// Scalar multiplication: `scalar × self`.
    ///
    /// - Parameter scalar: An arbitrary-precision integer. Negative values are reduced mod the group order.
    public func multiplied(by scalar: BigInt) -> G2Point {
        var out = blst_p2()
        var base = inner
        let (bytes, nbits) = scalar.blstMultiplierBytes()
        bytes.withUnsafeBytes { ptr in
            blst_p2_mult(&out, &base, ptr.baseAddress, nbits)
        }
        return G2Point(inner: out)
    }

    // MARK: - Equality

    /// Constant-time equality via blst.
    public static func == (lhs: G2Point, rhs: G2Point) -> Bool {
        var l = lhs.inner
        var r = rhs.inner
        return blst_p2_is_equal(&l, &r)
    }

    // MARK: - Serialization

    /// Compress to 96 bytes (SEC1 compressed point format).
    public func compress() -> Data {
        var out = [UInt8](repeating: 0, count: 96)
        var p = inner
        blst_p2_compress(&out, &p)
        return Data(out)
    }

    /// Deserialize from 96 compressed bytes.
    ///
    /// - Throws: `BLSTError` if the bytes are not a valid compressed G2 point.
    public init(compressed: Data) throws {
        guard compressed.count == 96 else {
            throw BLSTError.badEncoding
        }
        var affine = blst_p2_affine()
        let err = compressed.withUnsafeBytes { ptr -> BLST_ERROR in
            blst_p2_uncompress(&affine, ptr.baseAddress)
        }
        try checkBLST(err)
        guard blst_p2_affine_in_g2(&affine) else {
            throw BLSTError.pointNotInGroup
        }
        var p = blst_p2()
        blst_p2_from_affine(&p, &affine)
        self.inner = p
    }

    // MARK: - Hash / Encode to Group

    /// Hash arbitrary bytes to a G2 point (random-oracle variant, `hash_to_curve`).
    ///
    /// Uses `blst_hash_to_g2` — the full random-oracle map with two field elements.
    /// This is the variant required by Cardano UPLC `bls12_381_G2_hashToGroup`.
    ///
    /// - Parameters:
    ///   - message: The message to hash.
    ///   - dst: Domain Separation Tag (e.g. `"BLS12381G2_XMD:SHA-256_SSWU_RO_"`).
    public static func hash(to message: Data, dst: Data) -> G2Point {
        var out = blst_p2()
        message.withUnsafeBytes { msgPtr in
            dst.withUnsafeBytes { dstPtr in
                blst_hash_to_g2(
                    &out,
                    msgPtr.baseAddress, message.count,
                    dstPtr.baseAddress, dst.count,
                    nil, 0
                )
            }
        }
        return G2Point(inner: out)
    }

    /// Encode arbitrary bytes to a G2 point (non-uniform / injective variant, `encode_to_curve`).
    ///
    /// Uses `blst_encode_to_g2` — a deterministic injective encoding with one field element.
    /// This is faster than `hash(to:dst:)` but does **not** produce pseudorandom output.
    /// Use `hash(to:dst:)` unless you specifically need the NU variant.
    ///
    /// - Parameters:
    ///   - message: The message to encode.
    ///   - dst: Domain Separation Tag (e.g. `"BLS12381G2_XMD:SHA-256_SSWU_NU_"`).
    public static func encode(to message: Data, dst: Data) -> G2Point {
        var out = blst_p2()
        message.withUnsafeBytes { msgPtr in
            dst.withUnsafeBytes { dstPtr in
                blst_encode_to_g2(
                    &out,
                    msgPtr.baseAddress, message.count,
                    dstPtr.baseAddress, dst.count,
                    nil, 0
                )
            }
        }
        return G2Point(inner: out)
    }

    // MARK: - Validation

    /// `true` if this is the point at infinity.
    public var isInfinity: Bool {
        var p = inner
        return blst_p2_is_inf(&p)
    }

    /// `true` if the point lies on the BLS12-381 G2 curve.
    public var isOnCurve: Bool {
        var p = inner
        return blst_p2_on_curve(&p)
    }

    /// `true` if the point is in the G2 prime-order subgroup.
    public var isInGroup: Bool {
        var p = inner
        return blst_p2_in_g2(&p)
    }
}
