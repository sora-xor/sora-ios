import Foundation

enum NetworkUnitError: Error {
    case serviceUnavailable
    case brokenServiceEndpoint
    case typeMappingMissing
}
