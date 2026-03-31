import CBlst

/// Errors surfaced by the blst C library.
public enum BLSTError: Error, Sendable, CustomStringConvertible {
    case badEncoding
    case pointNotOnCurve
    case pointNotInGroup
    case aggregationTypeMismatch
    case verifyFail
    case publicKeyIsInfinity
    case badScalar

    init(_ code: BLST_ERROR) {
        switch code {
        case BLST_BAD_ENCODING:
            self = .badEncoding
        case BLST_POINT_NOT_ON_CURVE:
            self = .pointNotOnCurve
        case BLST_POINT_NOT_IN_GROUP:
            self = .pointNotInGroup
        case BLST_AGGR_TYPE_MISMATCH:
            self = .aggregationTypeMismatch
        case BLST_VERIFY_FAIL:
            self = .verifyFail
        case BLST_PK_IS_INFINITY:
            self = .publicKeyIsInfinity
        case BLST_BAD_SCALAR:
            self = .badScalar
        default:
            self = .badEncoding
        }
    }

    public var description: String {
        switch self {
        case .badEncoding:              return "BLST: bad encoding"
        case .pointNotOnCurve:         return "BLST: point not on curve"
        case .pointNotInGroup:         return "BLST: point not in group"
        case .aggregationTypeMismatch: return "BLST: aggregation type mismatch"
        case .verifyFail:              return "BLST: verification failed"
        case .publicKeyIsInfinity:     return "BLST: public key is infinity"
        case .badScalar:               return "BLST: bad scalar"
        }
    }
}

/// Throws `BLSTError` if `code` is not `BLST_SUCCESS`.
internal func checkBLST(_ code: BLST_ERROR) throws {
    guard code == BLST_SUCCESS else {
        throw BLSTError(code)
    }
}
