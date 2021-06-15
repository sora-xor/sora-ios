import Foundation
import FireMock

enum WalletBalanceFetchMock: FireMockProtocol {
    case invalidParameters
    case zero
    case success

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        switch self {
        case .invalidParameters:
            return 400
        default:
            return 200
        }
    }

    func mockFile() -> String {
        switch self {
        case .invalidParameters:
            return R.file.emptyResponseJson.fullName
        case .zero:
            return R.file.walletBalanceZeroResponseJson.fullName
        case .success:
            return R.file.walletBalanceResponseJson.fullName
        }
    }
}

//extension WalletBalanceFetchMock {
//    static func register(mock: WalletBalanceFetchMock, walletUnit: ServiceUnit) {
//        guard let service = walletUnit.service(for: WalletServiceType.balance.rawValue) else {
//            Logger.shared.warning("Can't find wallet balance service endpoint to mock")
//            return
//        }
//
//        guard let url = URL(string: service.serviceEndpoint) else {
//            Logger.shared.warning("Can't create balance fetch url")
//            return
//        }
//
//        FireMock.register(mock: mock, forURL: url, httpMethod: .post)
//    }
//}
