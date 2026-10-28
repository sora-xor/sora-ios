import Foundation

public enum RequestSigningType {
    case none
    case bearer
    case custom(signer: RequestSigner)
}
