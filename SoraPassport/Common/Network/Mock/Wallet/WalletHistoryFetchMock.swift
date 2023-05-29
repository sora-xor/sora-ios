import Foundation
import FireMock
import SoraFoundation

enum WalletHistoryFetchMock: FireMockProtocol {
    case success

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        return R.file.walletHistoryResponseJson.fullName
    }
}
//
//extension WalletHistoryFetchMock {
//    static func register(mock: WalletHistoryFetchMock, walletUnit: ServiceUnit) {
//        guard let service = walletUnit.service(for: WalletServiceType.history.rawValue) else {
//            Logger.shared.warning("Can't find wallet history service endpoint to mock")
//            return
//        }
//
//        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
//            Logger.shared.warning("Can't create history fetch url")
//            return
//        }
//
//        FireMock.register(mock: mock, regex: regex, httpMethod: .post)
//    }
//}
