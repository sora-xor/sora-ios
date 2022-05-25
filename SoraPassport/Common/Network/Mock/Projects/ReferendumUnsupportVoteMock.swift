import Foundation
import RobinHood
import FireMock

enum ReferendumUnsupportVoteMock: FireMockProtocol {
    case success

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        return R.file.successResultJson.fullName
    }
}

//extension ReferendumUnsupportVoteMock {
//    static func register(mock: ReferendumUnsupportVoteMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.referendumUnsupportVote.rawValue) else {
//            Logger.shared.warning("Can't find unsupport referendum vote service endpoint to mock")
//            return
//        }
//
//        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
//            Logger.shared.warning("Can't create unsupport referendum vote regex")
//            return
//        }
//
//        FireMock.register(mock: mock, regex: regex, httpMethod: .post)
//    }
//}
