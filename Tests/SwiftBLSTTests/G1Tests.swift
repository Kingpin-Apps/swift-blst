import Testing
import Foundation
@testable import SwiftBLST
import BigInt

@Suite("G1Point")
struct G1Tests {

    // MARK: - Compress / Decompress round-trip

    @Test func generatorCompressDecompress() throws {
        let gen = G1Point.generator
        let compressed = gen.compress()
        #expect(compressed.count == 48)
        let recovered = try G1Point(compressed: compressed)
        #expect(gen == recovered)
    }

    // G1 generator compressed: 0x97f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb
    @Test func knownGeneratorHex() throws {
        let knownHex = "97f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb"
        let data = try #require(Data(hexString: knownHex))
        let point = try G1Point(compressed: data)
        #expect(!point.isInfinity)
        #expect(point.isOnCurve)
        #expect(point.isInGroup)
        #expect(point == G1Point.generator)
    }

    // MARK: - Infinity

    @Test func infinityIsInfinity() {
        #expect(G1Point.infinity.isInfinity)
    }

    @Test func generatorIsNotInfinity() {
        #expect(!G1Point.generator.isInfinity)
    }

    // MARK: - Arithmetic

    @Test func additionWithNegationIsInfinity() {
        let p = G1Point.generator
        #expect((p + p.negated()).isInfinity)
    }

    @Test func additionIsCommutative() {
        let g = G1Point.generator
        #expect((g + g) == (g + g))
    }

    @Test func scalarMultiplicationByZeroIsInfinity() {
        #expect(G1Point.generator.multiplied(by: 0).isInfinity)
    }

    @Test func scalarMultiplicationByOneIsGenerator() {
        let g = G1Point.generator
        #expect(g.multiplied(by: 1) == g)
    }

    @Test func scalarMultiplicationVsDoubling() {
        let g = G1Point.generator
        #expect(g.multiplied(by: 2) == g + g)
    }

    @Test func scalarMultiplicationAssociativity() {
        let g = G1Point.generator
        let a: BigInt = 5
        let b: BigInt = 7
        // (a*b)*G == a*(b*G)
        #expect(g.multiplied(by: a * b) == g.multiplied(by: b).multiplied(by: a))
    }

    // MARK: - Hash to Group

    @Test func hashToGroupIsOnCurve() {
        let point = G1Point.hash(
            to: Data("test message".utf8),
            dst: Data("BLS12381G1_XMD:SHA-256_SSWU_RO_".utf8)
        )
        #expect(!point.isInfinity)
        #expect(point.isOnCurve)
        #expect(point.isInGroup)
    }

    @Test func hashToGroupDifferentMessagesAreDifferent() {
        let dst = Data("BLS12381G1_XMD:SHA-256_SSWU_RO_".utf8)
        let p1 = G1Point.hash(to: Data("msg1".utf8), dst: dst)
        let p2 = G1Point.hash(to: Data("msg2".utf8), dst: dst)
        #expect(p1 != p2)
    }

    // MARK: - Error handling

    @Test func invalidLengthThrows() {
        #expect(throws: (any Error).self) { try G1Point(compressed: Data(repeating: 0, count: 47)) }
        #expect(throws: (any Error).self) { try G1Point(compressed: Data(repeating: 0, count: 49)) }
    }

    @Test func invalidBytesThrows() {
        #expect(throws: (any Error).self) { try G1Point(compressed: Data(repeating: 0xFF, count: 48)) }
    }
}
