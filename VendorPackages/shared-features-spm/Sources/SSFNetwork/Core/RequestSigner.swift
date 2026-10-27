import Foundation

public enum RequestSignerError: Error {
    case badURL
}

public protocol RequestSigner {
    func sign(request: inout URLRequest, config: RequestConfig) throws
}
