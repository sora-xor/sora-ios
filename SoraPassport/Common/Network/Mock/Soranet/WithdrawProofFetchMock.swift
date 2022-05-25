import Foundation
import FireMock
import SoraFoundation

enum WithdrawProofFetchMock: FireMockProtocol {
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
            return R.file.withdrawProofResponseJson.fullName
        }
    }
}

//extension WithdrawProofFetchMock {
//    static func register(mock: WithdrawProofFetchMock, soranetUnit: ServiceUnit) {
//        guard let service = soranetUnit.service(for: SoranetServiceType.withdrawProof.rawValue) else {
//            Logger.shared.warning("Can't find soranet withdraw proof service endpoint to mock")
//            return
//        }
//
//        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
//            Logger.shared.warning("Can't create withdraw fetch regex")
//            return
//        }
//
//        FireMock.register(mock: mock, regex: regex, httpMethod: .get)
//    }
//}
