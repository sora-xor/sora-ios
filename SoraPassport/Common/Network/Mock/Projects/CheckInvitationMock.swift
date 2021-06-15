import Foundation
import FireMock

enum CheckInvitationMock: FireMockProtocol {
    case success
    case ambigious
    case notFound

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        switch self {
        case .success:
            return R.file.checkInvitationResponseJson.fullName
        case .ambigious:
            return R.file.checkInvitationAmbigiousJson.fullName
        case .notFound:
            return R.file.invitationCodeNotFoundJson.fullName
        }
    }
}

//extension CheckInvitationMock {
//    static func register(mock: CheckInvitationMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.checkInvitation.rawValue) else {
//            Logger.shared.warning("Can't find invitation check service endpoint to mock")
//            return
//        }
//
//        guard let url = URL(string: service.serviceEndpoint) else {
//            Logger.shared.warning("Can't create invitation check url")
//            return
//        }
//
//        FireMock.register(mock: mock, forURL: url, httpMethod: .post)
//    }
//}
