import Foundation
import FireMock

enum UpdateCustomerMock: FireMockProtocol {
    case success
    case resourceNotFound

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        switch self {
        case .success:
            return 200
        case .resourceNotFound:
            return 404
        }
    }

    func mockFile() -> String {
        switch self {
        case .success:
            return R.file.successResultJson.fullName
        case .resourceNotFound:
            return R.file.emptyResponseJson.fullName
        }
    }
}

//extension UpdateCustomerMock {
//    static func register(mock: UpdateCustomerMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.customerUpdate.rawValue) else {
//            Logger.shared.warning("Can't find customer update service endpoint to mock")
//            return
//        }
//
//        guard let url = URL(string: service.serviceEndpoint) else {
//            Logger.shared.warning("Can't create customer update regex")
//            return
//        }
//
//        FireMock.register(mock: mock, forURL: url, httpMethod: .put)
//    }
//}
