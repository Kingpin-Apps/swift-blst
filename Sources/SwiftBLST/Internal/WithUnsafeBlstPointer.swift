import BigInt
import Foundation

extension BigInt {
    /// Serialize to a big-endian byte array padded to `byteCount` bytes.
    internal func bigEndianBytesPadded(to byteCount: Int) -> [UInt8] {
        let bytes = Array(self.serialize())  // BigInt.serialize() → big-endian Data
        precondition(
            bytes.count <= byteCount,
            "Scalar requires \(bytes.count) bytes but target is only \(byteCount) bytes — value exceeds \(byteCount * 8) bits"
        )
        if bytes.count < byteCount {
            return [UInt8](repeating: 0, count: byteCount - bytes.count) + bytes
        }
        return bytes
    }

    /// Returns (little-endian bytes padded to 32 bytes, number of significant bits)
    /// for use with `blst_p1_mult` / `blst_p2_mult`.
    ///
    /// Despite what some documentation says, `blst_p*_mult` uses LITTLE-ENDIAN byte
    /// ordering for the scalar (confirmed in blst src/e1.c via `limbs_from_le_bytes`).
    /// Passing the exact bit count is required by the blst API.
    internal func blstMultiplierBytes() -> ([UInt8], Int) {
        let beBytes = bigEndianBytesPadded(to: 32)
        // Reverse big-endian → little-endian for blst.
        let leBytes = Array(beBytes.reversed())
        // Find the position of the most significant set bit.
        var nbits = 0
        for i in stride(from: leBytes.count - 1, through: 0, by: -1) {
            if leBytes[i] != 0 {
                nbits = i * 8 + (8 - leBytes[i].leadingZeroBitCount)
                break
            }
        }
        // blst requires nbits >= 1 even for scalar = 0.
        return (leBytes, Swift.max(nbits, 1))
    }
}
