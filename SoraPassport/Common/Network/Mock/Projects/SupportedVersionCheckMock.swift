import Foundation
import FireMock
import SoraFoundation

enum SupportedVersionCheckMock: FireMockProtocol {
    case supported
    case unsupported
    case notFound

    var afterTime: TimeInterval {
        return 1.0
    }

    var statusCode: Int {
        switch self {
        case .supported:
            return 200
        case .unsupported:
            return 200
        case .notFound:
            return 404
        }

    }

    func mockFile() -> String {
        switch self {
        case .supported:
            return R.file.supportedVersionSuccessResponseJson.fullName
        case .unsupported:
            return R.file.supportedVersionFailedResponseJson.fullName
        case .notFound:
            return R.file.emptyResponseJson.fullName
        }
    }
}

//extension SupportedVersionCheckMock {
//    static func register(mock: SupportedVersionCheckMock, projectUnit: ServiceUnit) {
//        guard let service = projectUnit.service(for: ProjectServiceType.supportedVersion.rawValue) else {
//            Logger.shared.warning("Can't find supported version service endpoint to mock")
//            return
//        }
//
//        guard let regex = try? EndpointBuilder(urlTemplate: service.serviceEndpoint).buildRegex() else {
//            Logger.shared.warning("Can't create supported version fetch regex")
//            return
//        }
//
//        FireMock.register(mock: mock, regex: regex, httpMethod: .get)
//    }
//}
