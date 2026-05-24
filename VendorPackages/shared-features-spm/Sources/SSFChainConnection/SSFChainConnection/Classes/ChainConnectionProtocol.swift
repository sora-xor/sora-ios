import Foundation

public protocol ChainConnectionProtocol {
    associatedtype T
    func getActiveStatus() async -> Bool
    func connection() async throws -> T
}
