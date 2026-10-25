import Foundation

final class RESTNetworkClient: NetworkClient {
    private let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    // MARK: - NetworkClient

    func perform(request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        return try processDataResponse(data: data, response: response)
    }

    // MARK: - Private methods

    private func processDataResponse(
        data: Data,
        response: URLResponse
    ) throws -> Data {
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
            throw NetworkingError(status: .unknown)
        }
        guard 200 ..< 299 ~= statusCode else {
            throw NetworkingError(errorCode: statusCode)
        }

        return data
    }
}
