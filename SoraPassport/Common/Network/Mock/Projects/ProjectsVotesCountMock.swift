import Foundation
import FireMock

enum ProjectsVotesCountMock: FireMockProtocol {
    case success

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        return R.file.votesCountResponseJson.fullName
    }
}

//extension ProjectsVotesCountMock {
//    static func register(mock: ProjectsVotesCountMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.votesCount.rawValue) else {
//            Logger.shared.warning("Can't find votes fetch service endpoint to mock")
//            return
//        }
//
//        guard let url = URL(string: service.serviceEndpoint) else {
//            Logger.shared.warning("Can't create votes count url")
//            return
//        }
//
//        FireMock.register(mock: mock, forURL: url, httpMethod: .get)
//    }
//}
