import Foundation
import FireMock
import SoraFoundation

enum ProjectDetailsFetchMock: FireMockProtocol {
    case success

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        return R.file.projectDetailsResponseJson.fullName
    }
}

//extension ProjectDetailsFetchMock {
//    static func register(mock: ProjectDetailsFetchMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.projectDetails.rawValue) else {
//            Logger.shared.warning("Can't find project details fetch service endpoint to mock")
//            return
//        }
//
//        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
//            Logger.shared.warning("Can't create project details fetch regex")
//            return
//        }
//
//        FireMock.register(mock: mock, regex: regex, httpMethod: .get)
//    }
//}
