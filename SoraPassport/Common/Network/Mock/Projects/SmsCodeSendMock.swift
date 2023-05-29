import Foundation
import FireMock

enum SmsCodeSendMock: FireMockProtocol {
    case successEmpty
    case successWithDelay
    case tooFrequent

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        switch self {
        case .successEmpty:
            return R.file.successResultJson.fullName
        case .successWithDelay:
            return R.file.sendSmsCodeSuccessResponseJson.fullName
        case .tooFrequent:
            return R.file.sendSmsCodeTooFreqResponseJson.fullName
        }

    }
}

//extension SmsCodeSendMock {
//    static func register(mock: SmsCodeSendMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.smsSend.rawValue) else {
//            Logger.shared.warning("Can't find sms sending service endpoint to mock")
//            return
//        }
//
//        guard let url = URL(string: service.serviceEndpoint) else {
//            Logger.shared.warning("Can't create sms send regex")
//            return
//        }
//
//        FireMock.register(mock: mock, forURL: url, httpMethod: .post)
//    }
//}
