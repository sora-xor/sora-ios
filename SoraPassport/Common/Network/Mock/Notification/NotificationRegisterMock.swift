import Foundation
import FireMock
import SoraFoundation

enum NotificationRegisterMock: FireMockProtocol {
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

//extension NotificationRegisterMock {
//    static func register(mock: NotificationRegisterMock, notificationUnit: ServiceUnit) {
//        guard let service = notificationUnit.service(for: NotificationServiceType.register.rawValue) else {
//            Logger.shared.warning("Can't find notification register service endpoint to mock")
//            return
//        }
//
//        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
//            Logger.shared.warning("Can't create notification token submit regex")
//            return
//        }
//
//        FireMock.register(mock: mock, regex: regex, httpMethod: .post)
//    }
//}
