import Testing
import Foundation
@testable import SwiftBLST

// MARK: - JSON model

private struct VectorFile: Decodable {
    let dst: String
    let vectors: [Vector]
}

private struct Vector: Decodable {
    let msg: String
    struct Point: Decodable { let x, y: String }
    let P: Point
}

// MARK: - BLS12-381 field helpers

/// (p − 1) / 2 for BLS12-381, big-endian.
/// p = 0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab
private let bls12381HalfPrime: [UInt8] = [
    0x0d, 0x00, 0x88, 0xf5, 0x1c, 0xbf, 0xf3, 0x4d,
    0x25, 0x8d, 0xd3, 0xdb, 0x21, 0xa5, 0xd6, 0x6b,
    0xb2, 0x3b, 0xa5, 0xc2, 0x79, 0xc2, 0x89, 0x5f,
    0xb3, 0x98, 0x69, 0x50, 0x7b, 0x58, 0x7b, 0x12,
    0x0f, 0x55, 0xff, 0xff, 0x58, 0xa9, 0xff, 0xff,
    0xdc, 0xff, 0x7f, 0xff, 0xff, 0xff, 0xd5, 0x55,
]

/// Parse a hex string (with optional "0x" prefix) into exactly 48 big-endian bytes.
private func fpBytes(hex: String) -> [UInt8] {
    let h = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
    let padded = String(repeating: "0", count: Swift.max(0, 96 - h.count)) + h
    return (0..<48).map { i in
        let lo = padded.index(padded.startIndex, offsetBy: i * 2)
        let hi = padded.index(lo, offsetBy: 2)
        return UInt8(padded[lo..<hi], radix: 16)!
    }
}

/// Returns true if the 48-byte big-endian value `a` is strictly greater than `b`.
private func fpGreaterThan(_ a: [UInt8], _ b: [UInt8]) -> Bool {
    for i in 0..<48 {
        if a[i] > b[i] { return true }
        if a[i] < b[i] { return false }
    }
    return false
}

/// True if a 48-byte field element is all zeros.
private func fpIsZero(_ a: [UInt8]) -> Bool { a.allSatisfy { $0 == 0 } }

// MARK: - Compressed-form constructors from affine coordinates

/// Build the expected 48-byte G1 compressed point from affine (x, y) hex strings.
///
/// BLS12-381 compression flags (top 3 bits of byte 0):
///   bit 7 = 1  (compressed)
///   bit 6 = 0  (not infinity)
///   bit 5 = 1  iff  y > (p−1)/2  (sign of y)
private func g1Compressed(x xHex: String, y yHex: String) -> Data {
    var xb = fpBytes(hex: xHex)
    let yb = fpBytes(hex: yHex)
    xb[0] |= 0x80
    if fpGreaterThan(yb, bls12381HalfPrime) { xb[0] |= 0x20 }
    return Data(xb)
}

/// Build the expected 96-byte G2 compressed point from affine Fp2 (x, y) fields.
///
/// Each field string in the blst test vectors is "0x<c1_hex>,0x<c0_hex>" where
/// c1 is the imaginary component and c0 is the real/constant component.
///
/// blst's G2 serialization puts **c0 first** (bytes 0–47), then c1 (bytes 48–95),
/// matching blst's internal blst_fp2 layout (fp[0] = c0, fp[1] = c1).
///
/// Sign rule (blst convention): bit 5 of byte 0 is set iff y_c0 > (p−1)/2.
private func g2Compressed(x xHex: String, y yHex: String) -> Data {
    func parseFp2(_ s: String) -> ([UInt8], [UInt8]) {
        // Vector format: "0x<c1>,0x<c0>" — first value is c1, second is c0.
        let parts = s.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return (fpBytes(hex: parts[0]), fpBytes(hex: parts[1]))  // (c1, c0)
    }
    let (xc1, xc0) = parseFp2(xHex)
    let (_,   yc0) = parseFp2(yHex)
    // blst serialises c0 first and uses c0 to determine the sign bit.
    var out = xc0
    out[0] |= 0x80
    if fpGreaterThan(yc0, bls12381HalfPrime) { out[0] |= 0x20 }
    return Data(out + xc1)
}

// MARK: - Tests

@Suite("Hash-to-curve vectors (BLS12381 XMD:SHA-256 SSWU RO)")
struct HashToCurveVectorTests {

    // MARK: - G1

    @Test func g1HashToCurveVectors() throws {
        let url = try #require(Bundle.module.url(
            forResource: "BLS12381G1_XMD_SHA-256_SSWU_RO_",
            withExtension: "json",
            subdirectory: "Vectors"
        ))
        let file = try JSONDecoder().decode(VectorFile.self, from: Data(contentsOf: url))
        let dst = Data(file.dst.utf8)

        for (i, vec) in file.vectors.enumerated() {
            let msg = Data(vec.msg.utf8)
            let actual = G1Point.hash(to: msg, dst: dst).compress()
            let expected = g1Compressed(x: vec.P.x, y: vec.P.y)
            #expect(actual == expected, "G1 vector \(i) failed (msg: \"\(vec.msg)\")")
        }
    }

    // MARK: - G2 RO

    @Test func g2HashToCurveVectors() throws {
        let url = try #require(Bundle.module.url(
            forResource: "BLS12381G2_XMD_SHA-256_SSWU_RO_",
            withExtension: "json",
            subdirectory: "Vectors"
        ))
        let file = try JSONDecoder().decode(VectorFile.self, from: Data(contentsOf: url))
        let dst = Data(file.dst.utf8)

        for (i, vec) in file.vectors.enumerated() {
            let msg = Data(vec.msg.utf8)
            let actual = G2Point.hash(to: msg, dst: dst).compress()
            let expected = g2Compressed(x: vec.P.x, y: vec.P.y)
            #expect(actual == expected, "G2 RO vector \(i) failed (msg: \"\(vec.msg)\")")
        }
    }

    // MARK: - G1 NU (encode_to_curve)

    @Test func g1EncodeToCurveVectors() throws {
        let url = try #require(Bundle.module.url(
            forResource: "BLS12381G1_XMD_SHA-256_SSWU_NU_",
            withExtension: "json",
            subdirectory: "Vectors"
        ))
        let file = try JSONDecoder().decode(VectorFile.self, from: Data(contentsOf: url))
        let dst = Data(file.dst.utf8)

        for (i, vec) in file.vectors.enumerated() {
            let msg = Data(vec.msg.utf8)
            let actual = G1Point.encode(to: msg, dst: dst).compress()
            let expected = g1Compressed(x: vec.P.x, y: vec.P.y)
            #expect(actual == expected, "G1 NU vector \(i) failed (msg: \"\(vec.msg)\")")
        }
    }

    // MARK: - G2 NU (encode_to_curve)

    @Test func g2EncodeToCurveVectors() throws {
        let url = try #require(Bundle.module.url(
            forResource: "BLS12381G2_XMD_SHA-256_SSWU_NU_",
            withExtension: "json",
            subdirectory: "Vectors"
        ))
        let file = try JSONDecoder().decode(VectorFile.self, from: Data(contentsOf: url))
        let dst = Data(file.dst.utf8)

        for (i, vec) in file.vectors.enumerated() {
            let msg = Data(vec.msg.utf8)
            let actual = G2Point.encode(to: msg, dst: dst).compress()
            let expected = g2Compressed(x: vec.P.x, y: vec.P.y)
            #expect(actual == expected, "G2 NU vector \(i) failed (msg: \"\(vec.msg)\")")
        }
    }
}
