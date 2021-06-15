import Foundation
import FireMock
import SoraFoundation

enum EthConfigMock: FireMockProtocol {
    case available
    case notFound

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        switch self {
        case .available:
            return 200
        case .notFound:
            return 404
        }

    }

    func mockFile() -> String {
        switch self {
        case .available:
            return R.file.ethConfigResponseJson.fullName
        case .notFound:
            return R.file.emptyResponseJson.fullName
        }
    }
}

//extension EthConfigMock {
//    static func register(mock: EthConfigMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.ethConfig.rawValue) else {
//            Logger.shared.warning("Can't find eth config service endpoint to mock")
//            return
//        }
//
//        guard let url = URL(string: service.serviceEndpoint) else {
//            Logger.shared.warning("Can't create eth config fetch url")
//            return
//        }
//
//        FireMock.register(mock: mock, forURL: url, httpMethod: .get)
//    }
//}
