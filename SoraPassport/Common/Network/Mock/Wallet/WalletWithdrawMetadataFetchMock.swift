import Foundation
import FireMock
import SoraFoundation

enum WalletWithdrawMetadataFetchMock: FireMockProtocol {
    case success

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        return R.file.withdrawMetadataResponseJson.fullName
    }
}

//extension WalletWithdrawMetadataFetchMock {
//    static func register(mock: WalletWithdrawMetadataFetchMock, walletUnit: ServiceUnit) {
//        guard let service = walletUnit.service(for: WalletServiceType.withdrawalMetadata.rawValue) else {
//            Logger.shared.warning("Can't find wallet withdraw metadata service endpoint to mock")
//            return
//        }
//
//        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
//            Logger.shared.warning("Can't create withdraw metadata fetch url")
//            return
//        }
//
//        FireMock.register(mock: mock, regex: regex, httpMethod: .get)
//    }
//}
