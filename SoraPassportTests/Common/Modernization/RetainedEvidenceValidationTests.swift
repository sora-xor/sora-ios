import CryptoKit
import Darwin
import Foundation
import XCTest
@testable import SoraPassport

/// Tests only pure validation and isolated temporary trees. No harness bootstrap,
/// enrollment, authorization installation, wallet store or Keychain is touched.
final class RetainedEvidenceValidationTests: XCTestCase {
    private typealias Request = RetainedMigrationEvidenceHarness.AuthorizationRequest
    private let now: Int64 = 1_800_000_000
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    }
    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
        directory = nil
    }
    private func request(_ changes: [String: Any] = [:]) -> [String: Any] {
        var root: [String: Any] = [
            "schemaVersion": 3, "contractId": "sora-ios-wallet-migration-evidence-authorization-v3",
            "platform": "ios", "purpose": "retained-wallet-migration-observation", "releaseAuthorized": false,
            "authorizationId": "3a5398ab-e5e4-47ba-9fb4-d17972fc66cb", "authorizationKeyId": "fixture-key.1",
            "signatureAlgorithm": "ecdsa-p256-sha256", "runId": "c5326e4f-bb03-468d-849d-6054d7dd86ce",
            "sourceRevision": String(repeating: "a", count: 40), "caseKind": "keychain", "caseId": "mnemonic-12",
            "issuedAtEpochSeconds": now - 60, "expiresAtEpochSeconds": now + 60, "maximumLaunchCount": 2
        ]
        for key in Request.exactKeys where key.hasSuffix("Sha256") { root[key] = String(repeating: "a", count: 64) }
        root.merge(changes) { _, new in new }
        return root
    }
    private func bytes(_ root: [String: Any]) throws -> Data {
        var value = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
        value.append(10)
        return value
    }
    private func parse(_ changes: [String: Any] = [:]) throws -> Request {
        try Request.parse(canonicalData: bytes(request(changes)), now: now)
    }
    @discardableResult private func write(_ path: String, data: Data = Data("fixture".utf8), mode: mode_t = 0o600) throws -> URL {
        let url = directory.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
        XCTAssertEqual(chmod(url.path, mode), 0)
        return url
    }
    private func scan(empty: Bool = false, ascii: Bool = false) throws -> [EvidenceTreeFile] {
        try EvidenceTreeScanner.scan(directory: directory, allowEmptyDirectories: empty, strictASCIIComponents: ascii)
    }

    func testCanonicalAuthorizationRetainsAllBindings() throws {
        let value = try parse()
        XCTAssertEqual(value.authorizationId, request()["authorizationId"] as? String)
        XCTAssertEqual(value.authorizationKeyId, "fixture-key.1")
        XCTAssertEqual(value.runId, request()["runId"] as? String)
        XCTAssertEqual(value.sourceRevision, String(repeating: "a", count: 40))
        XCTAssertEqual(value.maximumLaunchCount, 2)
        XCTAssertEqual(value.issuedAtEpochSeconds, now - 60)
        XCTAssertEqual(value.expiresAtEpochSeconds, now + 60)
        XCTAssertEqual(value.caseKind, .keychain)
        XCTAssertEqual(value.evidenceCase, .mnemonic12)
        XCTAssertNil(value.interruptionCheckpoint)
    }
    func testEverySupportedCaseHasAnExplicitClassification() throws {
        for c in RetainedMigrationEvidenceHarness.EvidenceCase.allCases {
            let value = try parse(["caseId": c.rawValue, "caseKind": c.kind.rawValue])
            XCTAssertEqual(value.evidenceCase, c)
            XCTAssertEqual(value.interruptionCheckpoint, c.interruptionCheckpoint)
            if c.kind == .keychain { XCTAssertNotNil(c.signingExpected) }
        }
        XCTAssertEqual(RetainedMigrationEvidenceHarness.EvidenceCase.processDeathRestart.interruptionCheckpoint, .afterCoreDataCommit)
        XCTAssertEqual(RetainedMigrationEvidenceHarness.EvidenceCase.rollback.recoveryExpected, true)
        XCTAssertEqual(RetainedMigrationEvidenceHarness.EvidenceCase.watchOnly.signingExpected, false)
        XCTAssertEqual(RetainedMigrationEvidenceHarness.EvidenceCase.watchOnly.recoveryExpected, false)
        XCTAssertNil(RetainedMigrationEvidenceHarness.EvidenceCase.processDeathRestart.recoveryExpected)
    }
    func testEveryRequiredAuthorizationFieldIsRequired() throws {
        for key in Request.exactKeys {
            var root = request(); root.removeValue(forKey: key)
            XCTAssertThrowsError(try Request.parse(canonicalData: bytes(root), now: now), key)
        }
    }
    func testUnknownAuthorizationFieldIsRejected() throws { XCTAssertThrowsError(try parse(["extra": true])) }
    func testContractAndPurposeCannotBeRepurposed() throws {
        for key in ["contractId", "platform", "purpose", "signatureAlgorithm"] {
            XCTAssertThrowsError(try parse([key: "other"]), key)
        }
    }
    func testReleaseAuthorityCannotBeEnabledByRequest() throws { XCTAssertThrowsError(try parse(["releaseAuthorized": true])) }
    func testBooleanFieldsCannotUseIntegers() throws { XCTAssertThrowsError(try parse(["releaseAuthorized": 0])) }
    func testIntegerFieldsCannotUseBooleans() throws {
        for key in ["schemaVersion", "issuedAtEpochSeconds", "expiresAtEpochSeconds", "maximumLaunchCount"] {
            XCTAssertThrowsError(try parse([key: true]), key)
        }
    }
    func testUnknownSchemaIsRejected() throws { XCTAssertThrowsError(try parse(["schemaVersion": 4])) }
    func testUUIDsMustBeCanonicalNonzero() throws {
        for key in ["authorizationId", "runId"] {
            for value in ["00000000-0000-0000-0000-000000000000", "3A5398AB-E5E4-47BA-9FB4-D17972FC66CB", "not-a-uuid"] {
                XCTAssertThrowsError(try parse([key: value]))
            }
        }
    }
    func testKeyIdentifiersCannotContainPathsOrWhitespace() throws {
        for value in ["../key", "key/path", "key name", "-key", String(repeating: "a", count: 129)] {
            XCTAssertThrowsError(try parse(["authorizationKeyId": value]))
        }
    }
    func testEveryDigestBindingRejectsZeroUppercaseAndWrongLength() throws {
        for key in Request.exactKeys where key.hasSuffix("Sha256") {
            for value in [String(repeating: "0", count: 64), String(repeating: "A", count: 64), "abcd"] {
                XCTAssertThrowsError(try parse([key: value]), key)
            }
        }
    }
    func testSourceRevisionHasExactNonzeroLowercaseHexShape() throws {
        for value in [String(repeating: "0", count: 40), String(repeating: "A", count: 40), String(repeating: "a", count: 64)] {
            XCTAssertThrowsError(try parse(["sourceRevision": value]))
        }
    }
    func testCanonicalProjectionBindingsMustAgree() throws {
        XCTAssertThrowsError(try parse(["installedCanonicalProjectionSha256": String(repeating: "b", count: 64)]))
    }
    func testCaseKindMustMatchTheCase() throws {
        XCTAssertThrowsError(try parse(["caseKind": "device"]))
        XCTAssertThrowsError(try parse(["caseId": "unsupported"]))
        XCTAssertThrowsError(try parse(["caseKind": "unsupported"]))
    }
    func testAuthorizationClockAndLifetimeBoundaries() throws {
        XCTAssertNoThrow(try parse(["issuedAtEpochSeconds": now + 300, "expiresAtEpochSeconds": now + 300]))
        XCTAssertThrowsError(try parse(["issuedAtEpochSeconds": now + 301, "expiresAtEpochSeconds": now + 301]))
        XCTAssertNoThrow(try parse(["expiresAtEpochSeconds": now]))
        XCTAssertThrowsError(try parse(["expiresAtEpochSeconds": now - 1]))
        XCTAssertThrowsError(try parse(["issuedAtEpochSeconds": 1_577_836_799]))
        XCTAssertThrowsError(try parse(["issuedAtEpochSeconds": now, "expiresAtEpochSeconds": now - 1]))
        XCTAssertNoThrow(try parse(["issuedAtEpochSeconds": now, "expiresAtEpochSeconds": now + 172_800]))
        XCTAssertThrowsError(try parse(["issuedAtEpochSeconds": now, "expiresAtEpochSeconds": now + 172_801]))
    }
    func testLaunchBudgetHasInclusiveBounds() throws {
        XCTAssertNoThrow(try parse(["maximumLaunchCount": 1]))
        XCTAssertNoThrow(try parse(["maximumLaunchCount": 8]))
        XCTAssertThrowsError(try parse(["maximumLaunchCount": 0]))
        XCTAssertThrowsError(try parse(["maximumLaunchCount": 9]))
    }
    func testAuthorizationRejectsNoncanonicalRepresentation() throws {
        let canonical = try bytes(request())
        for bad in [Data(canonical.dropLast()), Data([0xef, 0xbb, 0xbf]) + canonical, canonical + Data([10]), Data(" ".utf8) + canonical] {
            XCTAssertThrowsError(try Request.parse(canonicalData: bad, now: now))
        }
    }
    func testCanonicalJSONSortsKeysAndKeepsOneNewline() throws {
        let data = try StrictEvidenceJSON.canonicalData(object: ["b": 2, "a": true], maximumBytes: 100)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "{\"a\":true,\"b\":2}\n")
        let decoded = try StrictEvidenceJSON.object(fromCanonicalData: data, maximumBytes: data.count, label: "fixture")
        XCTAssertEqual(try StrictEvidenceJSON.integer(decoded["b"]), 2)
        XCTAssertTrue(try StrictEvidenceJSON.boolean(decoded["a"]))
    }
    func testCanonicalJSONRejectsOversizedAndEmptyInput() throws {
        XCTAssertThrowsError(try StrictEvidenceJSON.object(fromCanonicalData: Data(), maximumBytes: 10, label: "fixture"))
        let data = try bytes(["x": 1])
        XCTAssertThrowsError(try StrictEvidenceJSON.object(fromCanonicalData: data, maximumBytes: data.count - 1, label: "fixture"))
        XCTAssertThrowsError(try StrictEvidenceJSON.canonicalData(object: ["x": 1], maximumBytes: 1))
    }
    func testCanonicalJSONRejectsDuplicateKeysArraysAndFloats() throws {
        for string in ["{\"a\":1,\"a\":1}\n", "[]\n", "{\"a\":1.25}\n", "{\"a\":1e3}\n"] {
            XCTAssertThrowsError(try StrictEvidenceJSON.object(fromCanonicalData: Data(string.utf8), maximumBytes: 100, label: "fixture"))
        }
    }
    func testCanonicalJSONRejectsExcessiveDepth() throws {
        var value: Any = 1
        for _ in 0..<25 { value = [value] }
        XCTAssertThrowsError(try StrictEvidenceJSON.canonicalData(object: ["x": value], maximumBytes: 1000))
    }
    func testCanonicalJSONRejectsInvalidKeys() throws {
        for key in ["", "bad\nkey", String(repeating: "a", count: 257)] {
            XCTAssertThrowsError(try StrictEvidenceJSON.canonicalData(object: [key: 1], maximumBytes: 1000))
        }
    }
    func testCanonicalJSONLimitsObjectAndArrayCounts() throws {
        let object = Dictionary(uniqueKeysWithValues: (0..<513).map { ("k\($0)", $0) })
        XCTAssertThrowsError(try StrictEvidenceJSON.canonicalData(object: object, maximumBytes: 100_000))
        XCTAssertThrowsError(try StrictEvidenceJSON.canonicalData(object: ["x": Array(repeating: 0, count: 4097)], maximumBytes: 100_000))
    }
    func testCanonicalJSONLimitsUTF8StringSize() throws {
        XCTAssertNoThrow(try StrictEvidenceJSON.canonicalData(object: ["x": String(repeating: "a", count: 65536)], maximumBytes: 100_000))
        XCTAssertThrowsError(try StrictEvidenceJSON.canonicalData(object: ["x": String(repeating: "a", count: 65537)], maximumBytes: 100_000))
    }
    func testStringScalarValidationRejectsMissingEmptyAndOversized() throws {
        XCTAssertEqual(try StrictEvidenceJSON.string("valid"), "valid")
        for value: Any? in [nil, 1, "", String(repeating: "é", count: 2049)] {
            XCTAssertThrowsError(try StrictEvidenceJSON.string(value))
        }
    }
    func testBooleanScalarRequiresActualBoolean() throws {
        XCTAssertFalse(try StrictEvidenceJSON.boolean(false))
        for value: Any? in [nil, 0, 1, "true"] { XCTAssertThrowsError(try StrictEvidenceJSON.boolean(value)) }
    }
    func testIntegerScalarRejectsFractionalAndNonIntegerTypes() throws {
        XCTAssertEqual(try StrictEvidenceJSON.integer(Int64.min), Int64.min)
        XCTAssertEqual(try StrictEvidenceJSON.integer(Int64.max), Int64.max)
        for value: Any? in [nil, true, 1.5, "3"] { XCTAssertThrowsError(try StrictEvidenceJSON.integer(value)) }
    }
    func testIntegerScalarRejectsUnsignedOverflowInsteadOfWrapping() throws {
        XCTAssertThrowsError(try StrictEvidenceJSON.integer(NSNumber(value: UInt64.max)))
    }
    func testEncodableCanonicalRecordHasDeterministicRepresentation() throws {
        struct Record: Encodable { let z: String; let a: Int }
        let record = Record(z: "ok", a: 2)
        XCTAssertEqual(try StrictEvidenceJSON.canonicalData(encodable: record, maximumBytes: 100), Data("{\"a\":2,\"z\":\"ok\"}\n".utf8))
        XCTAssertThrowsError(try StrictEvidenceJSON.canonicalData(encodable: record, maximumBytes: 1))
    }
    func testTreeHashesNestedFilesInStablePathOrder() throws {
        try write("z", data: Data("z".utf8)); try write("a/entry", data: Data("abc".utf8))
        let files = try scan()
        XCTAssertEqual(files.map(\.relativePath), ["a/entry", "z"])
        XCTAssertEqual(files.map(\.byteCount), [3, 1])
        XCTAssertEqual(files[0].sha256, Data(SHA256.hash(data: Data("abc".utf8))))
        XCTAssertFalse(files[0].executable)
    }
    func testTreeIncludesEmptyRegularFiles() throws {
        try write("empty", data: Data())
        let value = try XCTUnwrap(scan().first)
        XCTAssertEqual(value.byteCount, 0)
        XCTAssertEqual(value.sha256, Data(SHA256.hash(data: Data())))
    }
    func testTreeRecordsExecutableBits() throws {
        try write("run", mode: 0o700)
        XCTAssertTrue(try XCTUnwrap(scan().first).executable)
    }
    func testTreeRejectsMissingAndFileRoots() throws {
        let file = try write("file")
        XCTAssertThrowsError(try EvidenceTreeScanner.scan(directory: file, allowEmptyDirectories: false))
        XCTAssertThrowsError(try EvidenceTreeScanner.scan(directory: directory.appendingPathComponent("missing"), allowEmptyDirectories: false))
    }
    func testTreeRejectsSymlinkRoot() throws {
        let target = directory.appendingPathComponent("target")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        let link = directory.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        XCTAssertThrowsError(try EvidenceTreeScanner.scan(directory: link, allowEmptyDirectories: true))
    }
    func testTreeRejectsSymlinkEntries() throws {
        let target = try write("target")
        try FileManager.default.createSymbolicLink(at: directory.appendingPathComponent("link"), withDestinationURL: target)
        XCTAssertThrowsError(try scan())
    }
    func testTreeRejectsHardLinkedFiles() throws {
        let target = try write("target")
        try FileManager.default.linkItem(at: target, to: directory.appendingPathComponent("link"))
        XCTAssertThrowsError(try scan())
    }
    func testTreeRejectsSpecialFilesWithoutOpeningThem() throws {
        XCTAssertEqual(mkfifo(directory.appendingPathComponent("pipe").path, 0o600), 0)
        XCTAssertThrowsError(try scan())
    }
    func testTreeRejectsOversizedSparseFilesBeforeReading() throws {
        let url = try write("large", data: Data())
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: 2 * 1024 * 1024 * 1024 + 1)
        try handle.close()
        XCTAssertThrowsError(try scan())
    }
    func testTreeEmptyDirectoryPolicyIsExplicit() throws {
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("empty"), withIntermediateDirectories: false)
        XCTAssertThrowsError(try scan())
        XCTAssertTrue(try scan(empty: true).isEmpty)
    }
    func testTreeRejectsControlCharactersInPaths() throws {
        try write("bad\nname")
        XCTAssertThrowsError(try scan())
    }
    func testStrictTreePathsRejectUnicodeAndLeadingPunctuation() throws {
        try write("é")
        XCTAssertNoThrow(try scan())
        XCTAssertThrowsError(try scan(ascii: true))
        try FileManager.default.removeItem(at: directory.appendingPathComponent("é"))
        try write(".hidden")
        XCTAssertThrowsError(try scan(ascii: true))
    }
    func testStrictTreePathsAcceptBoundedPortableNames() throws {
        try write("Bundle.framework/Resource_1+2@3-a.txt")
        XCTAssertEqual(try scan(ascii: true).count, 1)
    }
    func testTreeValidationCallbackSeesDirectoriesAndFiles() throws {
        try write("folder/file")
        var nodes = [String]()
        _ = try EvidenceTreeScanner.scan(directory: directory, allowEmptyDirectories: false) { path, isDirectory in
            nodes.append("\(path):\(isDirectory)")
        }
        XCTAssertEqual(nodes, ["folder:true", "folder/file:false"])
    }
    func testTreeValidationCallbackFailureIsPropagated() throws {
        try write("file")
        enum Sentinel: Error { case rejected }
        XCTAssertThrowsError(try EvidenceTreeScanner.scan(directory: directory, allowEmptyDirectories: false) { _, _ in throw Sentinel.rejected }) {
            XCTAssertTrue($0 is Sentinel)
        }
    }
    func testRawAppTreeHashHasPinnedIndependentRecord() throws {
        try write("a", data: Data("abc".utf8)); try write("b", data: Data("xy".utf8), mode: 0o700)
        XCTAssertEqual(try AppBundleTreeRecord.sha256(at: directory), "0233635fa4ab5cf4ea69ddfdc6b86468ebb45d3cf72315d29765f58e73ed1c12")
    }
    func testRawAppTreeHashChangesWithContentAndExecutableBit() throws {
        let url = try write("file", data: Data("a".utf8))
        let original = try AppBundleTreeRecord.sha256(at: directory)
        try Data("b".utf8).write(to: url)
        let changed = try AppBundleTreeRecord.sha256(at: directory)
        XCTAssertNotEqual(original, changed)
        XCTAssertEqual(chmod(url.path, 0o700), 0)
        XCTAssertNotEqual(changed, try AppBundleTreeRecord.sha256(at: directory))
    }
    func testRawAppTreeRejectsEmptyNestedDirectories() throws {
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("empty"), withIntermediateDirectories: false)
        XCTAssertThrowsError(try AppBundleTreeRecord.sha256(at: directory))
    }
    func testRollbackStoreRequiresCanonicalMainFile() throws {
        XCTAssertThrowsError(try RollbackStoreTreeRecord.sha256(storeURL: directory.appendingPathComponent("UserDataModel.sqlite")))
        XCTAssertThrowsError(try RollbackStoreTreeRecord.sha256(storeURL: write("other.sqlite")))
    }
    func testRollbackStoreRejectsEmptyOrLinkedMainFile() throws {
        let file = try write("UserDataModel.sqlite", data: Data())
        XCTAssertThrowsError(try RollbackStoreTreeRecord.sha256(storeURL: file))
        try Data("db".utf8).write(to: file)
        try FileManager.default.linkItem(at: file, to: directory.appendingPathComponent("alias"))
        XCTAssertThrowsError(try RollbackStoreTreeRecord.sha256(storeURL: file))
    }
    func testRollbackStoreIncludesWALSHMAndJournalInPinnedRecord() throws {
        let file = try write("UserDataModel.sqlite", data: Data("db".utf8))
        try write("UserDataModel.sqlite-wal", data: Data("wal".utf8))
        try write("UserDataModel.sqlite-shm", data: Data("shm".utf8))
        try write("UserDataModel.sqlite-journal", data: Data("journal".utf8))
        XCTAssertEqual(try RollbackStoreTreeRecord.sha256(storeURL: file), "f020a48b9e6dc596876a093bdd31d04a03200afb6f14f2c4338a79f598dd8756")
    }
    func testRollbackStoreIgnoresUnrelatedFilesButTracksSidecars() throws {
        let file = try write("UserDataModel.sqlite", data: Data("db".utf8))
        let original = try RollbackStoreTreeRecord.sha256(storeURL: file)
        try write("unrelated", data: Data("other".utf8))
        XCTAssertEqual(original, try RollbackStoreTreeRecord.sha256(storeURL: file))
        try write("UserDataModel.sqlite-wal", data: Data("wal".utf8))
        XCTAssertNotEqual(original, try RollbackStoreTreeRecord.sha256(storeURL: file))
    }
    func testOnlyWalletRoutesCountAsSuccessfulApplicationRoutes() {
        XCTAssertTrue(RetainedMigrationEvidenceApplicationRoute.localAuthentication.isSuccessfulWalletRoute)
        XCTAssertTrue(RetainedMigrationEvidenceApplicationRoute.pincodeSetup.isSuccessfulWalletRoute)
        XCTAssertFalse(RetainedMigrationEvidenceApplicationRoute.onboarding.isSuccessfulWalletRoute)
        XCTAssertFalse(RetainedMigrationEvidenceApplicationRoute.legacyUpgradeReady.isSuccessfulWalletRoute)
        XCTAssertFalse(RetainedMigrationEvidenceApplicationRoute.recovery.isSuccessfulWalletRoute)
    }
}
