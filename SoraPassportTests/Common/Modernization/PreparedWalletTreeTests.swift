import Darwin
import Foundation
import XCTest
@testable import SoraPassport

final class PreparedWalletTreeTests: XCTestCase {
    private var directory: URL!
    private let attempt = "AE8762C2-3B37-4B7E-84D7-1DB63A473B29"
    private var documents: URL { directory.appendingPathComponent("Documents", isDirectory: true) }
    private var support: URL { directory.appendingPathComponent("Library/Application Support", isDirectory: true) }
    private var safety: String { "Documents/CoreData/WalletMigrationSafety/\(attempt)" }
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        for component in ["Documents", "Library/Application Support", "Library/Preferences"] { try makeDirectory(component) }
        try write("Documents/CoreData/UserDataModel.sqlite", text: "database")
        try write("Library/Preferences/co.jp.soramitsu.sora.plist", text: "preferences")
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory); directory = nil }
    private func makeDirectory(_ component: String) throws {
        try FileManager.default.createDirectory(at: directory.appendingPathComponent(component, isDirectory: true), withIntermediateDirectories: true)
    }
    @discardableResult private func write(_ component: String, text: String = "fixture") throws -> URL {
        let url = directory.appendingPathComponent(component)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
        XCTAssertEqual(chmod(url.path, 0o600), 0)
        return url
    }
    private func hash(_ c: RetainedMigrationEvidenceHarness.EvidenceCase = .mnemonic12) throws -> String {
        try PreparedWalletTreeRecord.sha256(for: c, home: directory, documents: documents, applicationSupport: support)
    }
    func testMinimalRetainedTreeHasStableContentHash() throws {
        let original = try hash()
        XCTAssertEqual(original, "8be4a133eebb230efc15ec57a9edddef7d390c03b4ba5c8a863f16635e980635"); XCTAssertEqual(original, try hash(.watchOnly))
        try write("Documents/CoreData/UserDataModel.sqlite", text: "changed database")
        XCTAssertNotEqual(original, try hash())
    }
    func testDigestIsIndependentOfContainerLocationAndFileCreationOrder() throws {
        let expected = try hash()
        let old = directory!
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: old) }
        for component in ["Library/Preferences", "Documents", "Library/Application Support"] { try makeDirectory(component) }
        try write("Library/Preferences/co.jp.soramitsu.sora.plist", text: "preferences")
        try write("Documents/CoreData/UserDataModel.sqlite", text: "database")
        XCTAssertEqual(try hash(), expected)
    }
    func testAllDocumentedLiveStoreSidecarsArePartOfTheDigest() throws {
        var prior = try hash()
        for suffix in ["-wal", "-shm", "-journal"] {
            try write("Documents/CoreData/UserDataModel.sqlite" + suffix)
            let current = try hash(); XCTAssertNotEqual(current, prior); prior = current
        }
    }
    func testPreferenceBytesAndExecutableBitAffectTheDigest() throws {
        let path = "Library/Preferences/co.jp.soramitsu.sora.plist"
        let original = try hash(); let url = try write(path, text: "")
        let empty = try hash(); XCTAssertNotEqual(empty, original)
        XCTAssertEqual(chmod(url.path, 0o700), 0); XCTAssertNotEqual(empty, try hash())
    }
    func testRequiredStoreAndPreferenceCannotBeAbsent() throws {
        for component in ["Documents/CoreData/UserDataModel.sqlite", "Library/Preferences/co.jp.soramitsu.sora.plist"] {
            let url = directory.appendingPathComponent(component)
            let bytes = try Data(contentsOf: url); try FileManager.default.removeItem(at: url)
            XCTAssertThrowsError(try hash()); try bytes.write(to: url)
        }
    }
    func testContainerRootsCannotPointOutsideTheirDeclaredParent() throws {
        XCTAssertThrowsError(try PreparedWalletTreeRecord.sha256(for: .mnemonic12, home: directory, documents: support, applicationSupport: support))
        XCTAssertThrowsError(try PreparedWalletTreeRecord.sha256(for: .mnemonic12, home: directory, documents: documents, applicationSupport: documents))
    }
    func testRequiredDirectoriesMustBeDirectoriesAndCannotBeSymlinks() throws {
        let url = support
        try FileManager.default.removeItem(at: url); try Data().write(to: url)
        XCTAssertThrowsError(try hash()); try FileManager.default.removeItem(at: url)
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: documents)
        XCTAssertThrowsError(try hash())
    }
    func testPreferencesCannotBeDirectorySymlinkOrHardLink() throws {
        let path = "Library/Preferences/co.jp.soramitsu.sora.plist", url = directory.appendingPathComponent(path)
        try FileManager.default.removeItem(at: url); try makeDirectory(path); XCTAssertThrowsError(try hash())
        try FileManager.default.removeItem(at: url)
        let target = try write("outside", text: "preferences")
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: target); XCTAssertThrowsError(try hash())
        try FileManager.default.removeItem(at: url)
        XCTAssertEqual(link(target.path, url.path), 0); XCTAssertThrowsError(try hash())
    }
    func testUndeclaredCoreDataFilesAndNestedDirectoriesAreRejected() throws {
        for component in ["unknown.sqlite", "UserDataModel.sqlite/child", "other/child", "WalletMigrationSafety/not-a-uuid/journal.json"] {
            let path = "Documents/CoreData/" + component
            if component.hasPrefix("UserDataModel.sqlite/") { try FileManager.default.removeItem(at: documents.appendingPathComponent("CoreData/UserDataModel.sqlite")) }
            let url = try write(path); XCTAssertThrowsError(try hash(), component)
            if component.contains("/") { try FileManager.default.removeItem(at: documents.appendingPathComponent("CoreData/" + component.components(separatedBy: "/")[0])) }
            else { try FileManager.default.removeItem(at: url) }
            if component.hasPrefix("UserDataModel.sqlite/") { try write("Documents/CoreData/UserDataModel.sqlite", text: "database") }
        }
    }
    func testRecoveryArchiveRequiresEveryRetainedComponentInOneAttempt() throws {
        let required = ["account-manifest.json", "settings-backup.plist", "journal.json", "legacy-store/UserDataModel.sqlite", "legacy-store/backup-manifest.json", "staging/UserDataModel 2.sqlite"]
        XCTAssertThrowsError(try hash(.recoveryArchiveExport))
        for component in required.dropLast() { try write(safety + "/" + component); XCTAssertThrowsError(try hash(.recoveryArchiveExport)) }
        try write(safety + "/" + required.last!); XCTAssertEqual(try hash(.recoveryArchiveExport).count, 64)
        for component in ["legacy-store/UserDataModel.sqlite-wal", "legacy-store/UserDataModel.sqlite-shm", "staging/UserDataModel 2.sqlite-wal", "staging/UserDataModel 2.sqlite-shm", "staging/UserDataModel 2.sqlite-journal"] {
            try write(safety + "/" + component); XCTAssertNoThrow(try hash(.recoveryArchiveExport))
        }
    }
    func testRecoveryArchiveRejectsUnknownPathsAndNoncanonicalAttemptNames() throws {
        for component in ["unknown.json", "legacy-store/unknown", "staging/unknown", "unknown/deep", "legacy-store/deep/file"] {
            let url = try write(safety + "/" + component); XCTAssertThrowsError(try hash())
            try FileManager.default.removeItem(at: documents.appendingPathComponent("CoreData/WalletMigrationSafety"))
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        }
        try write("Documents/CoreData/WalletMigrationSafety/" + attempt.lowercased() + "/journal.json")
        XCTAssertThrowsError(try hash())
    }
    func testWalletNetworksAndAccountCommitsUseCanonicalFlatNamespaces() throws {
        for component in ["SORA/WalletNetworks/active.json", "SORA/WalletNetworks/wallet-network-\(attempt).json", "SORA/WalletAccountCommits/wallet-account-\(attempt).json"] {
            try write("Library/Application Support/" + component); XCTAssertNoThrow(try hash())
        }
    }
    func testWalletNamespaceRejectsUnknownNamesAndNestedEntries() throws {
        for (role, name) in [("WalletNetworks", "unknown.json"), ("WalletNetworks", "wallet-network-invalid.json"),
                             ("WalletNetworks", "wallet-network-\(attempt.lowercased()).json"), ("WalletNetworks", "active.json/child"),
                             ("WalletAccountCommits", "active.json"), ("WalletAccountCommits", "wallet-account-invalid.json"),
                             ("WalletAccountCommits", "wallet-account-\(attempt.lowercased()).json"), ("WalletAccountCommits", "nested/child")] {
            try write("Library/Application Support/SORA/\(role)/\(name)")
            XCTAssertThrowsError(try hash(), name)
            try FileManager.default.removeItem(at: support.appendingPathComponent("SORA"))
        }
    }
    func testSoraSupportNamespaceCannotBeARegularFile() throws {
        try write("Library/Application Support/SORA"); XCTAssertThrowsError(try hash())
    }
}
