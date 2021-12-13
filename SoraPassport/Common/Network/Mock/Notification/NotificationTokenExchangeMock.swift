import Foundation
import FireMock
import SoraFoundation

enum NotificationTokenExchangeMock: FireMockProtocol {
    case success
    case userNotFound

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
        case .userNotFound:
            return R.file.notificationUserNotFoundResponseJson.fullName
        }
    }
}

//extension NotificationTokenExchangeMock {
//    static func register(mock: NotificationTokenExchangeMock, notificationUnit: ServiceUnit) {
//        guard let service = notificationUnit.service(for: NotificationServiceType.exchangeTokens.rawValue) else {
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
