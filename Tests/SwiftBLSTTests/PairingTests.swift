import Testing
@testable import SwiftBLST
import BigInt

@Suite("Pairing")
struct PairingTests {

    // MARK: - Bilinearity: e(a·G1, b·G2) == e(G1, (a·b)·G2)

    @Test func bilinearity() {
        let a: BigInt = 42
        let b: BigInt = 137

        let aG1  = G1Point.generator.multiplied(by: a)
        let bG2  = G2Point.generator.multiplied(by: b)
        let abG2 = G2Point.generator.multiplied(by: a * b)

        let lhs = Pairing.millerLoop(g1: aG1, g2: bG2)
        let rhs = Pairing.millerLoop(g1: G1Point.generator, g2: abG2)
        #expect(Pairing.finalVerify(lhs, rhs))
    }

    // e(a·G1, G2) == e(G1, a·G2) — bilinearity in first argument
    @Test func bilinearityFirstArgument() {
        let a: BigInt = 13

        let aG1 = G1Point.generator.multiplied(by: a)
        let aG2 = G2Point.generator.multiplied(by: a)

        let lhs = Pairing.millerLoop(g1: aG1, g2: G2Point.generator)
        let rhs = Pairing.millerLoop(g1: G1Point.generator, g2: aG2)
        #expect(Pairing.finalVerify(lhs, rhs))
    }

    // MARK: - finalVerify rejects distinct points

    @Test func finalVerifyDistinctPointsFails() {
        let lhs = Pairing.millerLoop(g1: G1Point.generator, g2: G2Point.generator)
        let rhs = Pairing.millerLoop(g1: G1Point.generator, g2: G2Point.generator.multiplied(by: 2))
        #expect(!Pairing.finalVerify(lhs, rhs))
    }

    // MARK: - Fp12 multiplication: millerLoop(2G1, G2) == millerLoop(G1,G2) * millerLoop(G1,G2)

    @Test func fp12Multiplication() {
        let g1 = G1Point.generator
        let g2 = G2Point.generator
        let single = Pairing.millerLoop(g1: g1, g2: g2)
        let doubled = Pairing.millerLoop(g1: g1.multiplied(by: 2), g2: g2)
        #expect(Pairing.finalVerify(doubled, single * single))
    }

    // MARK: - Self-consistency: finalVerify(x, x) is true

    @Test func finalVerifySelfIsTrue() {
        let gt = Pairing.millerLoop(g1: G1Point.generator, g2: G2Point.generator)
        #expect(Pairing.finalVerify(gt, gt))
    }

    // MARK: - Infinity pairing

    @Test func pairingWithInfinityIsNeutral() {
        // e(O, Q) == e(P, O) == 1 (neutral element in GT)
        let inf1 = Pairing.millerLoop(g1: G1Point.infinity, g2: G2Point.generator)
        let inf2 = Pairing.millerLoop(g1: G1Point.generator, g2: G2Point.infinity)
        #expect(Pairing.finalVerify(inf1, inf2))
    }
}
