import Foundation
import RobinHood
import FireMock

enum ReferendumsVotedFetchMock: FireMockProtocol {
    case success

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        return R.file.votedReferendumsResponseJson.fullName
    }
}

//extension ReferendumsVotedFetchMock {
//    static func register(mock: ReferendumsVotedFetchMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.referendumsVoted.rawValue) else {
//            Logger.shared.warning("Can't find voted referendums fetch service endpoint to mock")
//            return
//        }
//
//        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
//            Logger.shared.warning("Can't create voted referendums fetch regex")
//            return
//        }
//
//        FireMock.register(mock: mock, regex: regex, httpMethod: .get)
//    }
//}
