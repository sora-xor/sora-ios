import Foundation
import FireMock

enum DecentralizedDocumentFetchMock: FireMockProtocol {
    case success
    case notFound

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        switch self {
        case .success:
            return R.file.decentralizedDocumentResponseJson.fullName
        case .notFound:
            return R.file.decentralizedDocumentNotFoundJson.fullName
        }
    }
}

extension DecentralizedDocumentFetchMock {
    @discardableResult
    static func register(mock: DecentralizedDocumentFetchMock) -> Bool {
        let regex = ApplicationConfig.shared.didResolverUrl.appendingPathCompletionRegex()

        FireMock.register(mock: mock, regex: regex, httpMethod: .get)

        return true
    }
}
