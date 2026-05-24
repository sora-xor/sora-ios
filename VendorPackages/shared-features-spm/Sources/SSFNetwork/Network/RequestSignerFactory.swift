import Foundation

enum RequestSignerFactoryError: Error {
    case signingTypeNotSupported
}

public protocol RequestSignerFactory {
    func buildRequestSigner(with type: RequestSigningType) throws -> RequestSigner?
}

public final class BaseRequestSignerFactory: RequestSignerFactory {
    public init() {}

    public func buildRequestSigner(with type: RequestSigningType) throws -> RequestSigner? {
        switch type {
        case .none:
            return nil
        case .bearer:
            throw RequestSignerFactoryError.signingTypeNotSupported
        case let .custom(signer):
            return signer
        }
    }
}
