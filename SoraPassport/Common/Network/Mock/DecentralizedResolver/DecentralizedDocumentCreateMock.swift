import Foundation
import FireMock

enum DecentralizedDocumentCreateMock: FireMockProtocol {
    case success
    case notFound

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        switch self {
        case .success:
            return 200
        case .notFound:
            return 404
        }
    }

    func mockFile() -> String {
        switch self {
        case .success:
            return R.file.successResultJson.fullName
        case .notFound:
            return R.file.emptyResponseJson.fullName
        }

    }
}

extension DecentralizedDocumentCreateMock {
    @discardableResult
    static func register(mock: DecentralizedDocumentCreateMock) -> Bool {
        guard let serviceUrl = URL(string: ApplicationConfig.shared.didResolverUrl) else {
            return false
        }

        FireMock.register(mock: mock, forURL: serviceUrl, httpMethod: .post)

        return true
    }
}
