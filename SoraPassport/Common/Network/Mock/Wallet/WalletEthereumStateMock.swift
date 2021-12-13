import Foundation
import FireMock

enum WalletEthereumStateMock: FireMockProtocol {
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
            return R.file.ethereumRegistrationStateJson.fullName
        case .notFound:
            return R.file.ethereumRegistrationNotFoundJson.fullName
        }
    }
}

//extension WalletEthereumStateMock {
//    static func register(mock: WalletEthereumStateMock, walletUnit: ServiceUnit) {
//        guard let service = walletUnit.service(for: WalletServiceType.ethereumState.rawValue) else {
//            Logger.shared.warning("Can't find wallet ethereum state service endpoint to mock")
//            return
//        }
//
//        guard let url = URL(string: service.serviceEndpoint) else {
//            Logger.shared.warning("Can't create transfer url")
//            return
//        }
//
//        FireMock.register(mock: mock, forURL: url, httpMethod: .get)
//    }
//}
