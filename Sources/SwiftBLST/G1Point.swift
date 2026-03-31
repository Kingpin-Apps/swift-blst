import CBlst
import BigInt
import Foundation

/// A point on the BLS12-381 G1 curve.
///
/// Internally stored in projective (Jacobian) coordinates (`blst_p1`).
/// Serialization uses the 48-byte SEC1 compressed format.
public struct G1Point: Sendable, Equatable {

    internal var inner: blst_p1

    internal init(inner: blst_p1) {
        self.inner = inner
    }

    // MARK: - Constants

    /// The standard generator point for G1.
    public static let generator: G1Point = {
        var p = blst_p1()
        blst_p1_from_affine(&p, blst_p1_affine_generator())
        return G1Point(inner: p)
    }()

    /// The point at infinity (identity element).
    public static let infinity: G1Point = {
        return G1Point(inner: blst_p1())
    }()

    // MARK: - Arithmetic

    /// Point addition: `lhs + rhs`.
    public static func + (lhs: G1Point, rhs: G1Point) -> G1Point {
        var out = blst_p1()
        var l = lhs.inner
        var r = rhs.inner
        blst_p1_add_or_double(&out, &l, &r)
        return G1Point(inner: out)
    }

    /// Point negation: `-self`.
    public func negated() -> G1Point {
        var p = inner
        blst_p1_cneg(&p, true)
        return G1Point(inner: p)
    }

    /// Scalar multiplication: `scalar × self`.
    ///
    /// - Parameter scalar: An arbitrary-precision integer. Negative values are reduced mod the group order.
    public func multiplied(by scalar: BigInt) -> G1Point {
        var out = blst_p1()
        var base = inner
        let (bytes, nbits) = scalar.blstMultiplierBytes()
        bytes.withUnsafeBytes { ptr in
            blst_p1_mult(&out, &base, ptr.baseAddress, nbits)
        }
        return G1Point(inner: out)
    }

    // MARK: - Equality

    /// Constant-time equality via blst.
    public static func == (lhs: G1Point, rhs: G1Point) -> Bool {
        var l = lhs.inner
        var r = rhs.inner
        return blst_p1_is_equal(&l, &r)
    }

    // MARK: - Serialization

    /// Compress to 48 bytes (SEC1 compressed point format).
    public func compress() -> Data {
        var out = [UInt8](repeating: 0, count: 48)
        var p = inner
        // blst_p1_compress takes a projective point directly.
        blst_p1_compress(&out, &p)
        return Data(out)
    }

    /// Deserialize from 48 compressed bytes.
    ///
    /// - Throws: `BLSTError` if the bytes are not a valid compressed G1 point.
    public init(compressed: Data) throws {
        guard compressed.count == 48 else {
            throw BLSTError.badEncoding
        }
        var affine = blst_p1_affine()
        let err = compressed.withUnsafeBytes { ptr -> BLST_ERROR in
            blst_p1_uncompress(&affine, ptr.baseAddress)
        }
        try checkBLST(err)
        guard blst_p1_affine_in_g1(&affine) else {
            throw BLSTError.pointNotInGroup
        }
        var p = blst_p1()
        blst_p1_from_affine(&p, &affine)
        self.inner = p
    }

    // MARK: - Hash / Encode to Group

    /// Hash arbitrary bytes to a G1 point (random-oracle variant, `hash_to_curve`).
    ///
    /// Uses `blst_hash_to_g1` — the full random-oracle map with two field elements.
    /// This is the variant required by Cardano UPLC `bls12_381_G1_hashToGroup`.
    ///
    /// - Parameters:
    ///   - message: The message to hash.
    ///   - dst: Domain Separation Tag (e.g. `"BLS12381G1_XMD:SHA-256_SSWU_RO_"`).
    public static func hash(to message: Data, dst: Data) -> G1Point {
        var out = blst_p1()
        message.withUnsafeBytes { msgPtr in
            dst.withUnsafeBytes { dstPtr in
                blst_hash_to_g1(
                    &out,
                    msgPtr.baseAddress, message.count,
                    dstPtr.baseAddress, dst.count,
                    nil, 0
                )
            }
        }
        return G1Point(inner: out)
    }

    /// Encode arbitrary bytes to a G1 point (non-uniform / injective variant, `encode_to_curve`).
    ///
    /// Uses `blst_encode_to_g1` — a deterministic injective encoding with one field element.
    /// This is faster than `hash(to:dst:)` but does **not** produce pseudorandom output.
    /// Use `hash(to:dst:)` unless you specifically need the NU variant.
    ///
    /// - Parameters:
    ///   - message: The message to encode.
    ///   - dst: Domain Separation Tag (e.g. `"BLS12381G1_XMD:SHA-256_SSWU_NU_"`).
    public static func encode(to message: Data, dst: Data) -> G1Point {
        var out = blst_p1()
        message.withUnsafeBytes { msgPtr in
            dst.withUnsafeBytes { dstPtr in
                blst_encode_to_g1(
                    &out,
                    msgPtr.baseAddress, message.count,
                    dstPtr.baseAddress, dst.count,
                    nil, 0
                )
            }
        }
        return G1Point(inner: out)
    }

    // MARK: - Validation

    /// `true` if this is the point at infinity.
    public var isInfinity: Bool {
        var p = inner
        return blst_p1_is_inf(&p)
    }

    /// `true` if the point lies on the BLS12-381 G1 curve.
    public var isOnCurve: Bool {
        var p = inner
        return blst_p1_on_curve(&p)
    }

    /// `true` if the point is in the G1 prime-order subgroup.
    public var isInGroup: Bool {
        var p = inner
        return blst_p1_in_g1(&p)
    }
}
