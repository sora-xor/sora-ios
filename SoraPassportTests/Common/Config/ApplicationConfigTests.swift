import XCTest
import Foundation
@testable import SoraPassport

class ApplicationConfigTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testConfigurationIntegrity() {
        XCTAssertNotNil(ApplicationConfig(configName: "Dev"))
        XCTAssertNotNil(ApplicationConfig(configName: "Release"))
        XCTAssertNotNil(ApplicationConfig(configName: "Test"))
        XCTAssertNotNil(ApplicationConfig(configName: "Staging"))
        XCTAssertNotNil(ApplicationConfig.shared)

        XCTAssertNoThrow(ApplicationConfig.shared.termsURL)
        XCTAssertNoThrow(ApplicationConfig.shared.version)
    }

    func testSoraNetworkEndpoints() {
        XCTAssertEqual(ApplicationConfig.shared.polkaswapIndexerURL.absoluteString, "https://pi.soramitsu.io/graphql")
        XCTAssertEqual(ApplicationConfig.shared.subqueryUrl, ApplicationConfig.shared.polkaswapIndexerURL)

        let nodes = ApplicationConfig.shared.defaultChainNodes
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes.first?.url.absoluteString, "wss://mof2.sora.org")
        XCTAssertEqual(nodes.first?.name, "Sora")
        XCTAssertNil(nodes.first?.apikey)
    }

    func testRemoteConfigFallsBackFromInvalidURLs() {
        let fallback = ApplicationConfig.shared.polkaswapIndexerURL
        let config = RemoteConfig(
            polkaswapIndexerUrlString: "://not-a-valid-url",
            typesUrlString: "://not-a-valid-types-url",
            defaultNodes: []
        )

        XCTAssertEqual(config.polkaswapIndexerURL, fallback)
        XCTAssertEqual(config.subqueryURL, fallback)
        XCTAssertNil(config.typesURL)
        XCTAssertTrue(config.defaultNodes.isEmpty)
    }

    func testAppConfigExplorerURLsUseSorametrics() throws {
        let root = try repositoryRoot()
        let plistURL = root.appendingPathComponent("SoraPassport/Configs/appConfig.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        let strings = collectStrings(from: plist)
        let sorametricsURLs = strings.filter {
            $0 == "https://sorametrics.org/sorav2?tab=extrinsics&q={transaction}"
        }

        XCTAssertEqual(sorametricsURLs.count, 4)
        XCTAssertFalse(strings.contains { $0.contains("subscan") })
    }

    func testCocoaPodsArtifactsAreRemovedFromProject() throws {
        let root = try repositoryRoot()
        let fileManager = FileManager.default

        XCTAssertFalse(fileManager.fileExists(atPath: root.appendingPathComponent("Podfile").path))
        XCTAssertFalse(fileManager.fileExists(atPath: root.appendingPathComponent("Podfile.lock").path))
        XCTAssertFalse(fileManager.fileExists(atPath: root.appendingPathComponent("Pods").path))
        XCTAssertFalse(fileManager.fileExists(atPath: root.appendingPathComponent("SoraPassport.xcworkspace").path))

        let projectFile = root.appendingPathComponent("SoraPassport.xcodeproj/project.pbxproj")
        let project = try String(contentsOf: projectFile)
        XCTAssertFalse(project.contains("PODS_ROOT"))
        XCTAssertFalse(project.contains("[CP]"))
        XCTAssertFalse(project.contains("Pods-"))
        XCTAssertFalse(project.contains("pod install"))
    }

    private func repositoryRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let fileManager = FileManager.default

        while directory.path != "/" {
            if fileManager.fileExists(atPath: directory.appendingPathComponent("SoraPassport.xcodeproj").path) {
                return directory
            }

            directory.deleteLastPathComponent()
        }

        throw NSError(domain: "ApplicationConfigTests", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Unable to locate repository root from \(#filePath)"
        ])
    }

    private func collectStrings(from value: Any) -> [String] {
        if let string = value as? String {
            return [string]
        }

        if let array = value as? [Any] {
            return array.flatMap(collectStrings)
        }

        if let dictionary = value as? [String: Any] {
            return dictionary.values.flatMap(collectStrings)
        }

        return []
    }
}
