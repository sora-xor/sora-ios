import Foundation
import FireMock
import SoraFoundation

enum ProjectsToggleFavoriteMock: FireMockProtocol {
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

//extension ProjectsToggleFavoriteMock {
//    static func register(mock: ProjectsToggleFavoriteMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.toggleFavorite.rawValue) else {
//            Logger.shared.warning("Can't find toggle favorite service endpoint to mock")
//            return
//        }
//
//        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
//            Logger.shared.warning("Can't create toggle favorite regex")
//            return
//        }
//
//        FireMock.register(mock: mock, regex: regex, httpMethod: .put)
//    }
//}
