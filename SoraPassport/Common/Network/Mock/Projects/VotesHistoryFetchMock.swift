import Foundation
import FireMock
import SoraFoundation

enum VotesHistoryFetchMock: FireMockProtocol {
    case success

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        return R.file.votesHistoryResponseJson.fullName
    }
}

//extension VotesHistoryFetchMock {
//    static func register(mock: VotesHistoryFetchMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.votesHistory.rawValue) else {
//            Logger.shared.warning("Can't find votes history fetch endpoint to mock")
//            return
//        }
//
//        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
//            Logger.shared.warning("Can't create votes history regex")
//            return
//        }
//
//        FireMock.register(mock: mock, regex: regex, httpMethod: .get)
//    }
//}
