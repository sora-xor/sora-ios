import Foundation
import FireMock

enum ProjectsInvitedMock: FireMockProtocol {
    case successWithoutParent
    case successWithParent

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        switch self {
        case .successWithoutParent:
            return R.file.invitedFetchWithoutParentJson.fullName
        case .successWithParent:
            return R.file.invitedFetchWithParentJson.fullName
        }
    }
}
//
//extension ProjectsInvitedMock {
//    static func register(mock: ProjectsInvitedMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.fetchInvited.rawValue) else {
//            Logger.shared.warning("Can't find invited service endpoint to mock")
//            return
//        }
//
//        guard let url = URL(string: service.serviceEndpoint) else {
//            Logger.shared.warning("Can't create invited fetch url")
//            return
//        }
//
//        FireMock.register(mock: mock, forURL: url, httpMethod: .get)
//    }
//}
