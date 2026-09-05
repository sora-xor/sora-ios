import Foundation

public protocol XcmConfigProtocol {
    var chainsSourceUrl: URL { get }
    var chainTypesSourceUrl: URL { get }
    var destinationFeeSourceUrl: URL { get }
    var tokenLocationsSourceUrl: URL { get }
}

final class XcmConfig: XcmConfigProtocol {
    static let shared = XcmConfig()
    private init() {}

    var chainsSourceUrl: URL {
        #if DEBUG || F_DEV
            GitHubUrl.url(suffix: "chains/v4/chains_dev.json", branch: .rococo)
        #else
            GitHubUrl.url(suffix: "chains/v2/chains.json")
        #endif
    }

    var chainTypesSourceUrl: URL {
        GitHubUrl.url(suffix: "chains/all_chains_types.json", branch: .rococo)
    }

    var destinationFeeSourceUrl: URL {
        GitHubUrl.url(suffix: "xcm/v2/xcm_fees.json", branch: .rococo)
    }

    var tokenLocationsSourceUrl: URL {
        GitHubUrl.url(suffix: "xcm/v2/xcm_token_locations.json")
    }
}

private enum GitHubUrl {
    private static var baseUrl: URL {
        URL(string: "https://raw.githubusercontent.com/soramitsu/shared-features-utils/")!
    }

    enum DefaultBranch: String {
        case master
        case develop
        case developFree = "develop-free"
        case xcmLocationDevelop = "updated-xcm-locations"
        case rococo = "feature/rococo"
    }

    static func url(suffix: String, branch: DefaultBranch = .master) -> URL {
        baseUrl.appendingPathComponent(branch.rawValue).appendingPathComponent(suffix)
    }
}
