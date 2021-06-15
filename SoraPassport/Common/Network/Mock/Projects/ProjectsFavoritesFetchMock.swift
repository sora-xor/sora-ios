import Foundation
import FireMock
import SoraFoundation

enum ProjectsFavoritesFetchMock: FireMockProtocol {
    case success

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        return 200
    }

    func mockFile() -> String {
        return R.file.favoriteProjectsResponseJson.fullName
    }
}

//extension ProjectsFavoritesFetchMock {
//    static func register(mock: ProjectsFavoritesFetchMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.favorites.rawValue) else {
//            Logger.shared.warning("Can't find favorite projects fetch service endpoint to mock")
//            return
//        }
//
//        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
//            Logger.shared.warning("Can't create favorite projects fetch regex")
//            return
//        }
//
//        FireMock.register(mock: mock, regex: regex, httpMethod: .get)
//    }
//}
