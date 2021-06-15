import Foundation
import RobinHood
import FireMock

enum ReferendumsOpenFetchMock: FireMockProtocol {
    case success

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        return R.file.openReferendumsResponseJson.fullName
    }
}

//extension ReferendumsOpenFetchMock {
//    static func register(mock: ReferendumsOpenFetchMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.referendumsOpen.rawValue) else {
//            Logger.shared.warning("Can't find open referendums fetch service endpoint to mock")
//            return
//        }
//
//        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
//            Logger.shared.warning("Can't create open referendums fetch regex")
//            return
//        }
//
//        FireMock.register(mock: mock, regex: regex, httpMethod: .get)
//    }
//}
