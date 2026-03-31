import CBlst

/// An element of the GT group — the result of a pairing (Miller loop).
///
/// Internally a `blst_fp12` structure (576 bytes).
///
/// > Warning: Do not compare two `Fp12` values with `==` to check pairing equality.
/// > Raw Miller loop outputs are not in final-exponent form, so a naïve field
/// > comparison is not a valid pairing check. Use `Pairing.finalVerify(_:_:)` instead.
public struct Fp12: Sendable {

    internal var inner: blst_fp12

    internal init(inner: blst_fp12) {
        self.inner = inner
    }

    /// Multiply two GT elements (used for combining Miller loop results).
    public static func * (lhs: Fp12, rhs: Fp12) -> Fp12 {
        var out = blst_fp12()
        var l = lhs.inner
        var r = rhs.inner
        blst_fp12_mul(&out, &l, &r)
        return Fp12(inner: out)
    }
}
