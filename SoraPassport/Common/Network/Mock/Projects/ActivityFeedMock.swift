import Foundation
import FireMock
import SoraFoundation

enum ActivityFeedMock: FireMockProtocol {
    case success
    case empty
    case internalError

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        switch self {
        case .success, .empty:
            return 200
        case .internalError:
            return 500
        }
    }

    func mockFile() -> String {
        switch self {
        case .success:
            return R.file.activityFeedResponseJson.fullName
        case .empty:
            return R.file.activityFeedEmptyResponseJson.fullName
        case .internalError:
            return R.file.activityFeedEmptyResponseJson.fullName
        }
    }
}

//extension ActivityFeedMock {
//    static func register(mock: ActivityFeedMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.activityFeed.rawValue) else {
//            Logger.shared.warning("Can't find activity feed fetch endpoint to mock")
//            return
//        }
//
//        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
//            Logger.shared.warning("Can't create activity feed regex")
//            return
//        }
//
//        FireMock.register(mock: mock, regex: regex, httpMethod: .get)
//    }
//}
