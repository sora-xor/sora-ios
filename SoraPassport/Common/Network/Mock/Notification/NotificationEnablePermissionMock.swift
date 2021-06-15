import Foundation
import FireMock
import SoraFoundation

enum NotificationEnablePermissionMock: FireMockProtocol {
    case success

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        return R.file.successResultJson.fullName
    }
}

//extension NotificationEnablePermissionMock {
//    static func register(mock: NotificationEnablePermissionMock, notificationUnit: ServiceUnit) {
//        guard let service = notificationUnit.service(for: NotificationServiceType.enablePermission.rawValue) else {
//            Logger.shared.warning("Can't find notification enable permission service endpoint to mock")
//            return
//        }
//
//        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
//            Logger.shared.warning("Can't create notification enable permission submit regex")
//            return
//        }
//
//        FireMock.register(mock: mock, regex: regex, httpMethod: .put)
//    }
//}
