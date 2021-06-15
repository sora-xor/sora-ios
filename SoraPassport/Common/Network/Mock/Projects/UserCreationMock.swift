import Foundation
import FireMock
import SoraFoundation

enum UserCreationMock: FireMockProtocol {
    case success
    case alreadyRegistered
    case alreadyVerified

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        switch self {
        case .success:
            return R.file.sendSmsCodeSuccessResponseJson.fullName
        case .alreadyRegistered:
            return R.file.userExistsResponseJson.fullName
        case .alreadyVerified:
            return R.file.userVerifiedResponseJson.fullName
        }
    }
}

//extension UserCreationMock {
//    static func register(mock: UserCreationMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.createUser.rawValue) else {
//            Logger.shared.warning("Can't find project user creation service endpoint to mock")
//            return
//        }
//
//        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
//            Logger.shared.warning("Can't create user creation regex")
//            return
//        }
//
//        FireMock.register(mock: mock, regex: regex, httpMethod: .post)
//    }
//}
