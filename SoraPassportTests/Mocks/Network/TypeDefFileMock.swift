import Foundation
import FireMock

enum TypeDefFileMock: FireMockProtocol {
    case westendDefault
    case kusamaDefault
    case polkadotDefault
    case soraDefault
//    case westendNetwork
//    case kusamaNetwork
    case polkadotNetwork
    case soraNetwork

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        switch self {
        case .westendDefault, .kusamaDefault, .polkadotDefault, .soraDefault:
            return R.file.runtimeDefaultJson.fullName
        case .polkadotNetwork:
            return R.file.runtimePolkadotJson.fullName
        case .soraNetwork:
            return R.file.runtimeSoraJson.fullName
        }
    }
}

extension TypeDefFileMock {
    static func register(mock: TypeDefFileMock, url: URL) {
        FireMock.register(mock: mock, forURL: url, httpMethod: .get)
    }
}
