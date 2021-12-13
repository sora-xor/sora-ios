import Foundation
import FireMock

enum AnnouncementFetchMock: FireMockProtocol {
    case successNotEmpty
    case successEmpty

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        switch self {
        case .successNotEmpty:
            return R.file.announcementNotEmptyResponseJson.fullName
        case .successEmpty:
            return R.file.announcementEmptyResponseJson.fullName
        }
    }
}

//extension AnnouncementFetchMock {
//    static func register(mock: AnnouncementFetchMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.announcement.rawValue) else {
//            Logger.shared.warning("Can't find announcement fetch service endpoint to mock")
//            return
//        }
//
//        guard let url = URL(string: service.serviceEndpoint) else {
//            Logger.shared.warning("Can't create announcement fetch regex")
//            return
//        }
//
//        FireMock.register(mock: mock, forURL: url, httpMethod: .get)
//    }
//}
