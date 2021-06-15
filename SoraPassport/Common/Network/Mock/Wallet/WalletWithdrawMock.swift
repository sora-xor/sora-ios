import Foundation
import FireMock

enum WalletWithdrawMock: FireMockProtocol {
    case success

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
        }
    }
}

//extension WalletWithdrawMock {
//    static func register(mock: WalletWithdrawMock, walletUnit: ServiceUnit) {
//        guard let service = walletUnit.service(for: WalletServiceType.withdraw.rawValue) else {
//            Logger.shared.warning("Can't find wallet withdraw service endpoint to mock")
//            return
//        }
//
//        guard let url = URL(string: service.serviceEndpoint) else {
//            Logger.shared.warning("Can't create transfer url")
//            return
//        }
//
//        FireMock.register(mock: mock, forURL: url, httpMethod: .post)
//    }
//}
