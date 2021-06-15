import Foundation
import FireMock
import SoraFoundation

enum ApplyInvitationMock: FireMockProtocol {
    case success
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
            return R.file.successResultJson.fullName
        case .notFound:
            return R.file.invitationCodeNotFoundJson.fullName
        }
    }
}

//extension ApplyInvitationMock {
//    static func register(mock: ApplyInvitationMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.applyInvitation.rawValue) else {
//            Logger.shared.warning("Can't find invitation apply service endpoint to mock")
//            return
//        }
//
//        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
//            Logger.shared.warning("Can't create invitation apply regex")
//            return
//        }
//
//        FireMock.register(mock: mock, regex: regex, httpMethod: .post)
//    }
//}
