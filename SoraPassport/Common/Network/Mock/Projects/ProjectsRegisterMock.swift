import Foundation
import FireMock
import SoraFoundation

enum ProjectsRegisterMock: FireMockProtocol {
    case success
    case invitationInvalid

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        switch self {
        case .success:
            return R.file.successResultJson.fullName
        case .invitationInvalid:
            return R.file.invitationCodeNotFoundJson.fullName
        }
    }
}

//extension ProjectsRegisterMock {
//    static func register(mock: ProjectsRegisterMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.register.rawValue) else {
//            Logger.shared.warning("Can't find project registration service endpoint to mock")
//            return
//        }
//
//        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
//            Logger.shared.warning("Can't create registration regex")
//            return
//        }
//
//        FireMock.register(mock: mock, regex: regex, httpMethod: .post)
//    }
//}
