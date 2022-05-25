import Foundation
import FireMock

enum WalletContactsFetchMock: FireMockProtocol {
    case empty

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        return R.file.walletContactsEmptyResponseJson.fullName
    }
}

//extension WalletContactsFetchMock {
//    static func register(mock: WalletContactsFetchMock, walletUnit: ServiceUnit) {
//        guard let service = walletUnit.service(for: WalletServiceType.contacts.rawValue) else {
//            Logger.shared.warning("Can't find wallet history service endpoint to mock")
//            return
//        }
//
//        guard let url = URL(string: service.serviceEndpoint) else {
//            Logger.shared.warning("Can't create history fetch url")
//            return
//        }
//
//        FireMock.register(mock: mock, forURL: url, httpMethod: .get)
//    }
//}
