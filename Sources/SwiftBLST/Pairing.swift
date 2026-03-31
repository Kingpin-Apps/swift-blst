import CBlst

/// BLS12-381 pairing operations.
public enum Pairing {

    /// Compute the Miller loop pairing: e(g1, g2) → GT.
    ///
    /// The blst C signature is `blst_miller_loop(ret, Q_g2_affine, P_g1_affine)` —
    /// G2 is the first point argument, G1 is second.
    ///
    /// - Parameters:
    ///   - g1: A point on G1.
    ///   - g2: A point on G2.
    /// - Returns: The GT element (an `Fp12` value).
    public static func millerLoop(g1: G1Point, g2: G2Point) -> Fp12 {
        var result = blst_fp12()
        var p1affine = blst_p1_affine()
        var p2affine = blst_p2_affine()
        var g1p = g1.inner
        var g2p = g2.inner
        blst_p1_to_affine(&p1affine, &g1p)
        blst_p2_to_affine(&p2affine, &g2p)
        // Note: G2 (Q) is the first point argument per the blst C API.
        blst_miller_loop(&result, &p2affine, &p1affine)
        return Fp12(inner: result)
    }

    /// Final pairing verification.
    ///
    /// Checks whether `finalexp(a) * conj(finalexp(b)) == 1` in GT, which is
    /// equivalent to checking `e(a_g1, a_g2) == e(b_g1, b_g2)` when `a` and `b`
    /// are raw Miller loop outputs.
    ///
    /// This is the correct way to compare two pairings — do not use `Fp12 ==` directly
    /// in production verification, as raw Miller loop outputs are not in the final-exp form.
    ///
    /// - Returns: `true` if the two pairings are equal.
    public static func finalVerify(_ a: Fp12, _ b: Fp12) -> Bool {
        var left = a.inner
        var right = b.inner
        return blst_fp12_finalverify(&left, &right)
    }
}
