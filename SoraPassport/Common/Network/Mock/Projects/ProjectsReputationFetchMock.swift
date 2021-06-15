import Foundation
import FireMock

enum ProjectsReputationFetchMock: FireMockProtocol {
    case success
    case nullSuccess

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        switch self {
        case .success:
            return R.file.reputationResponseJson.fullName
        case .nullSuccess:
            return R.file.reputationNullResponseJson.fullName
        }
    }
}

//extension ProjectsReputationFetchMock {
//    static func register(mock: ProjectsReputationFetchMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.reputation.rawValue) else {
//            Logger.shared.warning("Can't find reputation fetch endpoint to mock")
//            return
//        }
//
//        guard let url = URL(string: service.serviceEndpoint) else {
//            Logger.shared.warning("Can't create reputation fetch regex")
//            return
//        }
//
//        FireMock.register(mock: mock, forURL: url, httpMethod: .get)
//    }
//}
