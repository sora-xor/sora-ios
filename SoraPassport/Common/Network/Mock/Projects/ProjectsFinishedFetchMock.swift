import Foundation
import FireMock
import SoraFoundation

enum ProjectsFinishedFetchMock: FireMockProtocol {
    case success

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        return R.file.finishedProjectsResponseJson.fullName
    }
}

//extension ProjectsFinishedFetchMock {
//    static func register(mock: ProjectsFinishedFetchMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.finished.rawValue) else {
//            Logger.shared.warning("Can't find finished projects fetch service endpoint to mock")
//            return
//        }
//
//        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
//            Logger.shared.warning("Can't create finished projects fetch regex")
//            return
//        }
//
//        FireMock.register(mock: mock, regex: regex, httpMethod: .get)
//    }
//}
