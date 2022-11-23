import Foundation
import FireMock
import SoraFoundation

enum WalletTransferMetadataFetchMock: FireMockProtocol {
    case success

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        return R.file.transferMetadataResponseJson.fullName
    }
}

//extension WalletTransferMetadataFetchMock {
//    static func register(mock: WalletTransferMetadataFetchMock, walletUnit: ServiceUnit) {
//        guard let service = walletUnit.service(for: WalletServiceType.transferMetadata.rawValue) else {
//            Logger.shared.warning("Can't find wallet transfer metadata service endpoint to mock")
//            return
//        }
//
//        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
//            Logger.shared.warning("Can't create transfer metadata fetch url")
//            return
//        }
//
//        FireMock.register(mock: mock, regex: regex, httpMethod: .get)
//    }
//}
