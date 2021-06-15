import Foundation
import FireMock

enum ReputationDetailsFetchMock: FireMockProtocol {
    case success

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        return R.file.reputationDetailsResponseJson.fullName
    }
}

//extension ReputationDetailsFetchMock {
//    static func register(mock: ReputationDetailsFetchMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.reputationDetails.rawValue) else {
//            Logger.shared.warning("Can't find reputation details fetch service endpoint to mock")
//            return
//        }
//
//        guard let url = URL(string: service.serviceEndpoint) else {
//            Logger.shared.warning("Can't create reputation details fetch url")
//            return
//        }
//
//        FireMock.register(mock: mock, forURL: url, httpMethod: .get)
//    }
//}
