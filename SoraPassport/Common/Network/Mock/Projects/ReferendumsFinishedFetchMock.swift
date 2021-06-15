import Foundation
import RobinHood
import FireMock

enum ReferendumsFinishedFetchMock: FireMockProtocol {
    case success

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        return R.file.completedReferendumsResponseJson.fullName
    }
}

//extension ReferendumsFinishedFetchMock {
//    static func register(mock: ReferendumsFinishedFetchMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.referendumsFinished.rawValue) else {
//            Logger.shared.warning("Can't find finished referendums fetch service endpoint to mock")
//            return
//        }
//
//        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
//            Logger.shared.warning("Can't create finished referendums fetch regex")
//            return
//        }
//
//        FireMock.register(mock: mock, regex: regex, httpMethod: .get)
//    }
//}
