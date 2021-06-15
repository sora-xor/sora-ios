import Foundation
import RobinHood
import FireMock

enum ReferendumDetailsFetchMock: FireMockProtocol {
    case success

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        return R.file.referendumDetailsResponseJson.fullName
    }
}

//extension ReferendumDetailsFetchMock {
//    static func register(mock: ReferendumDetailsFetchMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.referendumDetails.rawValue) else {
//            Logger.shared.warning("Can't find referendum details fetch service endpoint to mock")
//            return
//        }
//
//        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
//            Logger.shared.warning("Can't create referendum details fetch regex")
//            return
//        }
//
//        FireMock.register(mock: mock, regex: regex, httpMethod: .get)
//    }
//}
