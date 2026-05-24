import Foundation

public protocol NetworkClient {
    func perform(request: URLRequest) async throws -> Data
}
