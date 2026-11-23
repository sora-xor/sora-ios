import Foundation

public enum CloudStorageServiceError: Error {
    case notFound
    case incorectPassword
    case incorectJson
    case notAuthorized
    /// The Google account that would serve the request is not the one the
    /// caller named. Nothing was read from it.
    case accountChanged
}

extension CloudStorageServiceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "Not Found"
        case .incorectPassword:
            return "Incorect password"
        case .incorectJson:
            return "Incorect json"
        case .notAuthorized:
            return "Not authorized"
        case .accountChanged:
            return "Google account changed"
        }
    }
}
