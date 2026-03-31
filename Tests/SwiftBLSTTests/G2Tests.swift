import Testing
import Foundation
@testable import SwiftBLST
import BigInt

@Suite("G2Point")
struct G2Tests {

    // MARK: - Compress / Decompress round-trip

    @Test func generatorCompressDecompress() throws {
        let gen = G2Point.generator
        let compressed = gen.compress()
        #expect(compressed.count == 96)
        let recovered = try G2Point(compressed: compressed)
        #expect(gen == recovered)
    }

    // MARK: - Infinity

    @Test func infinityIsInfinity() {
        #expect(G2Point.infinity.isInfinity)
    }

    @Test func generatorIsNotInfinity() {
        #expect(!G2Point.generator.isInfinity)
    }

    // MARK: - Arithmetic

    @Test func additionWithNegationIsInfinity() {
        let p = G2Point.generator
        #expect((p + p.negated()).isInfinity)
    }

    @Test func scalarMultiplicationByZeroIsInfinity() {
        #expect(G2Point.generator.multiplied(by: 0).isInfinity)
    }

    @Test func scalarMultiplicationByOneIsGenerator() {
        let g = G2Point.generator
        #expect(g.multiplied(by: 1) == g)
    }

    @Test func scalarMultiplicationVsDoubling() {
        let g = G2Point.generator
        #expect(g.multiplied(by: 2) == g + g)
    }

    @Test func scalarMultiplicationAssociativity() {
        let g = G2Point.generator
        let a: BigInt = 5
        let b: BigInt = 7
        #expect(g.multiplied(by: a * b) == g.multiplied(by: b).multiplied(by: a))
    }

    // MARK: - Hash to Group

    @Test func hashToGroupIsOnCurve() {
        let point = G2Point.hash(
            to: Data("test message".utf8),
            dst: Data("BLS12381G2_XMD:SHA-256_SSWU_RO_".utf8)
        )
        #expect(!point.isInfinity)
        #expect(point.isOnCurve)
        #expect(point.isInGroup)
    }

    @Test func hashToGroupDifferentMessagesAreDifferent() {
        let dst = Data("BLS12381G2_XMD:SHA-256_SSWU_RO_".utf8)
        let p1 = G2Point.hash(to: Data("msg1".utf8), dst: dst)
        let p2 = G2Point.hash(to: Data("msg2".utf8), dst: dst)
        #expect(p1 != p2)
    }

    // MARK: - Error handling

    @Test func invalidLengthThrows() {
        #expect(throws: (any Error).self) { try G2Point(compressed: Data(repeating: 0, count: 95)) }
        #expect(throws: (any Error).self) { try G2Point(compressed: Data(repeating: 0, count: 97)) }
    }

    @Test func invalidBytesThrows() {
        #expect(throws: (any Error).self) { try G2Point(compressed: Data(repeating: 0xFF, count: 96)) }
    }
}
