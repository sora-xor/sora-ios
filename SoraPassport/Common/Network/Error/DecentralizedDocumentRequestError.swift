import Foundation

enum DecentralizedDocumentQueryDataError: Error {
    case decentralizedIdNotFound

    static func error(from status: StatusData) -> DecentralizedDocumentQueryDataError? {
        switch status.code {
        case "DID_NOT_FOUND":
            return .decentralizedIdNotFound
        default:
            return nil
        }
    }
}

enum DecentralizedDocumentCreationDataError: Error {
    case decentralizedIdTooLong
    case decentralizedIdDuplicated
    case invalidProof
    case proofVerificationFailed
    case publicKeyNotFound

    static func error(from status: StatusData) -> DecentralizedDocumentCreationDataError? {
        switch status.code {
        case "DID_IS_TOO_LONG":
            return .decentralizedIdTooLong
        case "DID_DUPLICATE":
            return .decentralizedIdDuplicated
        case "INVALID_PROOF_SIGNATURE":
            return .proofVerificationFailed
        case "INVALID_PROOF":
            return .invalidProof
        case "PUBLIC_KEY_VALUE_NOT_PRESENTED":
            return .publicKeyNotFound
        default:
            return nil
        }
    }
}
