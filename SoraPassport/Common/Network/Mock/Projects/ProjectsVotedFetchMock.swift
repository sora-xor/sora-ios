import Foundation
import FireMock
import SoraFoundation

enum ProjectsVotedFetchMock: FireMockProtocol {
    case success

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        return R.file.votedProjectsResponseJson.fullName
    }
}

//extension ProjectsVotedFetchMock {
//    static func register(mock: ProjectsVotedFetchMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.voted.rawValue) else {
//            Logger.shared.warning("Can't find voted projects fetch service endpoint to mock")
//            return
//        }
//
//        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
//            Logger.shared.warning("Can't create voted projects fetch regex")
//            return
//        }
//
//        FireMock.register(mock: mock, regex: regex, httpMethod: .get)
//    }
//}
