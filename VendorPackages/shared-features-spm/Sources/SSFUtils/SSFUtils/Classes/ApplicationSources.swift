import Foundation

public protocol ApplicationSources {
    var chainsSourceUrl: URL { get }
    var chainTypesSourceUrl: URL { get }
}

public final class ApplicationSourcesImpl: ApplicationSources {
    public static let shared = ApplicationSourcesImpl()
    private init() {}

    public var chainsSourceUrl: URL {
        #if DEBUG
            GitHubUrl.url(suffix: "chains/chains.json", branch: .mwr819)
        #else
            GitHubUrl.url(suffix: "chains/v6/chains.json")
        #endif
    }

    public var chainTypesSourceUrl: URL {
        GitHubUrl.url(suffix: "chains/all_chains_types.json")
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
        case mwr819 = "MWR-819"
    }

    static func url(suffix: String, branch: DefaultBranch = .master) -> URL {
        baseUrl.appendingPathComponent(branch.rawValue).appendingPathComponent(suffix)
    }
}
