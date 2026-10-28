// SPDX-License-Identifier: BSD-4-Clause
import CryptoKit
import Foundation
import XCTest

@testable import SoraPassport

/// Real temporary files, archive coordination, and protection metadata. No wallet or Keychain access.
final class WalletRecoveryExporterBoundaryTests: XCTestCase {
  private var roots: [URL] = []
  private let exportID = UUID(uuidString: "10000000-0000-4000-8000-000000000001")!
  private struct Fixture {
    let root: URL, store: URL, cache: URL
    var exports: URL { cache.appendingPathComponent("WalletRecoveryExports", isDirectory: true) }
  }
  private enum FixtureError: Error { case unavailable }
  override func tearDownWithError() throws {
    for root in roots { try? FileManager.default.removeItem(at: root) }
    roots.removeAll()
  }
  private func fixture(writeStore: Bool = true) throws -> Fixture {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    let cache = root.appendingPathComponent("cache", isDirectory: true)
    try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
    roots.append(root)
    let f = Fixture(
      root: root, store: root.appendingPathComponent("UserDataModel.sqlite"), cache: cache)
    if writeStore { try Data("public-fixture-database".utf8).write(to: f.store) }
    return f
  }
  private func exporter(
    _ f: Fixture,
    manager: FileManager = .default,
    verified: @escaping WalletRecoveryExporter.VerifiedBackupProvider = { _, _ in nil },
    settings: @escaping WalletRecoveryExporter.SettingsSnapshotProvider = { [:] },
    afterRead: ((URL) throws -> Void)? = nil,
    archive: @escaping WalletRecoveryExporter.ArchiveProvider = WalletRecoveryExporter
      .coordinateArchiveForUploading,
    protection: WalletRecoveryExporter.ProtectionClassProvider? = nil,
    remove: WalletRecoveryExporter.RemoveItem? = nil
  ) -> WalletRecoveryExporter {
    WalletRecoveryExporter(
      storeURL: f.store, cacheDirectory: f.cache, fileManager: manager,
      verifiedBackupProvider: verified, settingsSnapshotProvider: settings,
      now: { Date(timeIntervalSince1970: 1_800_000_000.75) }, makeUUID: { self.exportID },
      afterInitialSourceVerification: afterRead, archiveProvider: archive,
      protectionClassProvider: protection, removeItem: remove)
  }
  private func assertNoPublished(_ f: Fixture, file: StaticString = #filePath, line: UInt = #line)
    throws
  {
    let entries = try? FileManager.default.contentsOfDirectory(
      at: f.exports, includingPropertiesForKeys: nil)
    XCTAssertTrue(
      (entries ?? []).filter { !$0.lastPathComponent.hasPrefix(".") }.isEmpty, file: file,
      line: line)
  }
  private func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
  private func source(_ url: URL, name: String? = nil) throws -> WalletRecoveryVerifiedSourceFile {
    let data = try Data(contentsOf: url)
    return WalletRecoveryVerifiedSourceFile(
      url: url, fileName: name ?? url.lastPathComponent, byteCount: data.count, sha256: digest(data)
    )
  }
  private func backup(
    _ f: Fixture, database: [WalletRecoveryVerifiedSourceFile]? = nil, settingsData: Data? = nil
  ) throws -> WalletRecoveryVerifiedMigrationBackup {
    let url = f.root.appendingPathComponent("settings-backup.plist")
    try (settingsData ?? WalletRecoveryExporter.sanitizedSettingsData(from: [:])).write(to: url)
    return try WalletRecoveryVerifiedMigrationBackup(
      migrationID: UUID(), updatedAt: Date(timeIntervalSince1970: 0),
      settingsFile: source(url), databaseFiles: database ?? [source(f.store)])
  }
  private func assertExportError(
    _ expected: String, _ operation: () throws -> Void, file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertThrowsError(try operation(), file: file, line: line) { error in
      let kind: String
      switch error {
      case WalletRecoveryExportError.unavailableStore: kind = "unavailable"
      case WalletRecoveryExportError.unsafeSource: kind = "unsafe"
      case WalletRecoveryExportError.sourceChanged: kind = "changed"
      case WalletRecoveryExportError.invalidSettings: kind = "settings"
      case WalletRecoveryExportError.publicationFailed: kind = "publication"
      case WalletRecoveryExportError.publicationWithdrawalFailed: kind = "withdrawal"
      default: kind = "other"
      }
      XCTAssertEqual(kind, expected, file: file, line: line)
    }
  }
  func testMissingDatabaseDoesNotExportOrReadSettings() throws {
    let f = try fixture(writeStore: false)
    assertExportError("unavailable") {
      _ = try exporter(
        f,
        settings: {
          XCTFail("No source to export")
          return [:]
        }
      ).createRecoveryPackage()
    }
    try assertNoPublished(f)
  }
  func testEmptyMainDatabaseCannotBecomeARecoveryPackage() throws {
    let f = try fixture()
    try Data().write(to: f.store)
    assertExportError("unsafe") { _ = try exporter(f).createRecoveryPackage() }
    try assertNoPublished(f)
  }
  func testEmptySidecarsArePreservedWithTheirExactDigests() throws {
    let f = try fixture()
    for suffix in ["-wal", "-shm"] {
      try Data().write(to: URL(fileURLWithPath: f.store.path + suffix))
    }
    let result = try exporter(f).createRecoveryPackage()
    let sidecars = result.manifest.files.filter {
      $0.relativeName.hasSuffix("-wal") || $0.relativeName.hasSuffix("-shm")
    }
    XCTAssertEqual(sidecars.count, 2)
    XCTAssertTrue(sidecars.allSatisfy { $0.byteCount == 0 && $0.sha256 == digest(Data()) })
    XCTAssertEqual(result.manifest.createdAt, Date(timeIntervalSince1970: 1_800_000_000))
  }
  func testDirectoryInPlaceOfSidecarFailsWithoutOpeningTheStore() throws {
    let f = try fixture()
    try FileManager.default.createDirectory(
      atPath: f.store.path + "-wal", withIntermediateDirectories: false)
    assertExportError("unsafe") { _ = try exporter(f).createRecoveryPackage() }
    try assertNoPublished(f)
  }
  func testSymlinkedParentIsRejectedEvenWhenItsDatabaseIsRegular() throws {
    let f = try fixture()
    let link = f.root.appendingPathComponent("linked")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: f.root)
    let aliased = Fixture(
      root: f.root, store: link.appendingPathComponent(f.store.lastPathComponent), cache: f.cache)
    assertExportError("unsafe") { _ = try exporter(aliased).createRecoveryPackage() }
    try assertNoPublished(f)
  }
  func testUnknownSettingsAreRemovedBeforePropertyListValidation() throws {
    let data = try WalletRecoveryExporter.sanitizedSettingsData(from: [
      "futurePrivateKey": NSObject(), SettingsKey.selectedLocalization.rawValue: "ja",
    ])
    let settings = try XCTUnwrap(
      PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
    XCTAssertEqual(settings, [SettingsKey.selectedLocalization.rawValue: "ja"])
  }
  func testNonPropertyListValueInAllowedSettingIsRejected() {
    assertExportError("settings") {
      _ = try WalletRecoveryExporter.sanitizedSettingsData(from: [
        SettingsKey.selectedLocalization.rawValue: NSObject()
      ])
    }
  }
  func testOversizedAllowedSettingIsRejectedBeforeWritingPrivateStaging() throws {
    let f = try fixture()
    assertExportError("settings") {
      _ = try exporter(
        f,
        settings: {
          [
            SettingsKey.selectedLocalization.rawValue: String(
              repeating: "x", count: 16 * 1_024 * 1_024)
          ]
        }
      ).createRecoveryPackage()
    }
    try assertNoPublished(f)
  }
  func testVerifiedProviderFailureNeverFallsBackToLiveDatabase() throws {
    let f = try fixture()
    var settingsRead = false
    XCTAssertThrowsError(
      try exporter(
        f, verified: { _, _ in throw FixtureError.unavailable },
        settings: {
          settingsRead = true
          return [:]
        }
      ).createRecoveryPackage())
    XCTAssertFalse(settingsRead)
    try assertNoPublished(f)
  }
  func testDuplicateVerifiedDatabaseNamesAreRejected() throws {
    let f = try fixture()
    let file = try source(f.store)
    let retained = try backup(f, database: [file, file])
    assertExportError("unsafe") {
      _ = try exporter(f, verified: { _, _ in retained }).createRecoveryPackage()
    }
    try assertNoPublished(f)
  }
  func testVerifiedDatabaseCannotEscapeItsDeclaredName() throws {
    let f = try fixture()
    let retained = try backup(f, database: [source(f.store, name: "../UserDataModel.sqlite")])
    assertExportError("unsafe") {
      _ = try exporter(f, verified: { _, _ in retained }).createRecoveryPackage()
    }
    try assertNoPublished(f)
  }
  func testVerifiedDatabaseHashMismatchNeverFallsBack() throws {
    let f = try fixture()
    let file = try source(f.store)
    let wrong = WalletRecoveryVerifiedSourceFile(
      url: file.url, fileName: file.fileName, byteCount: file.byteCount,
      sha256: String(repeating: "0", count: 64))
    let retained = try backup(f, database: [wrong])
    assertExportError("unsafe") {
      _ = try exporter(
        f, verified: { _, _ in retained },
        settings: {
          XCTFail("Must not fall back")
          return [:]
        }
      ).createRecoveryPackage()
    }
    try assertNoPublished(f)
  }
  func testVerifiedSettingsMustContainADictionary() throws {
    let f = try fixture()
    let list = try PropertyListSerialization.data(
      fromPropertyList: ["not", "settings"], format: .xml, options: 0)
    let retained = try backup(f, settingsData: list)
    assertExportError("settings") {
      _ = try exporter(f, verified: { _, _ in retained }).createRecoveryPackage()
    }
    try assertNoPublished(f)
  }
  func testSettingsChangedDuringReadLeaveNothingPublished() throws {
    let f = try fixture()
    let retained = try backup(f)
    assertExportError("changed") {
      _ = try exporter(
        f, verified: { _, _ in retained },
        afterRead: { url in
          if url == retained.settingsFile.url {
            try WalletRecoveryExporter.sanitizedSettingsData(from: [
              SettingsKey.selectedLocalization.rawValue: "ja"
            ]).write(to: url)
          }
        }
      ).createRecoveryPackage()
    }
    try assertNoPublished(f)
  }
  func testVerifiedSettingsChangedAfterArchiveCreationPreventPublication() throws {
    let f = try fixture()
    let retained = try backup(f)
    assertExportError("changed") {
      _ = try exporter(
        f, verified: { _, _ in retained },
        archive: { package, output, manager in
          try WalletRecoveryExporter.coordinateArchiveForUploading(
            packageURL: package, archiveURL: output, fileManager: manager)
          try WalletRecoveryExporter.sanitizedSettingsData(from: [
            SettingsKey.selectedLocalization.rawValue: "ja"
          ]).write(to: retained.settingsFile.url)
        }
      ).createRecoveryPackage()
    }
    try assertNoPublished(f)
  }
  func testDatabaseChangedAfterArchiveCreationPreventPublication() throws {
    let f = try fixture()
    assertExportError("changed") {
      _ = try exporter(
        f,
        archive: { package, output, manager in
          try WalletRecoveryExporter.coordinateArchiveForUploading(
            packageURL: package, archiveURL: output, fileManager: manager)
          try Data("changed-after-archive".utf8).write(to: f.store)
        }
      ).createRecoveryPackage()
    }
    try assertNoPublished(f)
  }
  func testSidecarAppearingAfterSnapshotPreventsPublication() throws {
    let f = try fixture()
    assertExportError("changed") {
      _ = try exporter(
        f,
        archive: { package, output, manager in
          try WalletRecoveryExporter.coordinateArchiveForUploading(
            packageURL: package, archiveURL: output, fileManager: manager)
          try Data("new-write-ahead-log".utf8).write(
            to: URL(fileURLWithPath: f.store.path + "-wal"))
        }
      ).createRecoveryPackage()
    }
    try assertNoPublished(f)
  }
  func testChangedRecoverableSettingsPreventPublication() throws {
    let f = try fixture()
    var reads = 0
    assertExportError("changed") {
      _ = try exporter(
        f,
        settings: {
          reads += 1
          return [SettingsKey.selectedLocalization.rawValue: reads == 1 ? "en" : "ja"]
        }
      ).createRecoveryPackage()
    }
    XCTAssertEqual(reads, 2)
    try assertNoPublished(f)
  }
  func testChangingExcludedSettingsDoesNotInvalidateSafeSnapshot() throws {
    let f = try fixture()
    var reads = 0
    let result = try exporter(
      f,
      settings: {
        reads += 1
        return [
          "private-token": "ignored-\(reads)", SettingsKey.selectedLocalization.rawValue: "en",
        ]
      }
    ).createRecoveryPackage()
    XCTAssertEqual(reads, 2)
    XCTAssertEqual(result.manifest.sourceType, .liveStoreFallback)
  }
  func testExportDirectoryCannotBeAFile() throws {
    let f = try fixture()
    try Data("existing-file".utf8).write(to: f.exports)
    assertExportError("publication") { _ = try exporter(f).createRecoveryPackage() }
    XCTAssertEqual(try Data(contentsOf: f.exports), Data("existing-file".utf8))
  }
  func testExistingProtectedExportDirectoryCanBeReused() throws {
    let f = try fixture()
    try FileManager.default.createDirectory(at: f.exports, withIntermediateDirectories: false)
    let unrelated = f.exports.appendingPathComponent("prior-export.keep")
    try Data("existing".utf8).write(to: unrelated)
    let result = try exporter(f).createRecoveryPackage()
    XCTAssertTrue(FileManager.default.fileExists(atPath: result.packageURL.path))
    XCTAssertEqual(try Data(contentsOf: unrelated), Data("existing".utf8))
  }
  private func collision(_ suffix: String) throws {
    let f = try fixture()
    try FileManager.default.createDirectory(at: f.exports, withIntermediateDirectories: false)
    let name =
      suffix == "final"
      ? "SORA-Wallet-Recovery-\(exportID.uuidString).sorarecovery.zip"
      : ".wallet-recovery-\(exportID.uuidString).\(suffix)"
    let existing = f.exports.appendingPathComponent(name)
    try Data("preexisting-entry".utf8).write(to: existing)
    assertExportError("publication") { _ = try exporter(f).createRecoveryPackage() }
    XCTAssertEqual(try Data(contentsOf: existing), Data("preexisting-entry".utf8))
  }
  func testStagingCollisionIsNeverOverwritten() throws { try collision("staging") }
  func testArchiveStagingCollisionIsNeverOverwritten() throws { try collision("archive-staging") }
  func testFinalCollisionIsNeverOverwritten() throws { try collision("final") }
  func testTruncatedArchiveSignatureCannotBePublished() throws {
    let f = try fixture()
    assertExportError("publication") {
      _ = try exporter(
        f, archive: { _, output, _ in try Data([0x50, 0x4b, 0x03, 0x04]).write(to: output) }
      ).createRecoveryPackage()
    }
    try assertNoPublished(f)
  }
  func testNonZipArchiveCannotBePublished() throws {
    let f = try fixture()
    assertExportError("publication") {
      _ = try exporter(
        f, archive: { _, output, _ in try Data("not-an-archive".utf8).write(to: output) }
      ).createRecoveryPackage()
    }
    try assertNoPublished(f)
  }
  func testProtectionInspectionFailureIsReportedBeforePublication() throws {
    let f = try fixture()
    assertExportError("publication") {
      _ = try exporter(f, protection: { _, _ in throw FixtureError.unavailable })
        .createRecoveryPackage()
    }
    try assertNoPublished(f)
  }
  private func failedWithdrawalRepair(removal: Int) throws {
    let f = try fixture()
    let manager = RecoveryRepairFailingFileManager()
    var publishedWasInspected = false
    let subject = exporter(
      f, manager: manager,
      protection: { url, manager in
        if url.lastPathComponent.hasSuffix(".sorarecovery.zip") {
          publishedWasInspected = true
          (manager as! RecoveryRepairFailingFileManager).failHiddenArchiveProtection = true
          return nil
        }
        return try FileProtectionMetadata.protectionClass(at: url, fileManager: manager)
      },
      remove: { url in
        if url.lastPathComponent.hasSuffix(".archive-staging") {
          if removal == 2 { throw FixtureError.unavailable }
          try FileManager.default.removeItem(at: url)
          if removal == 1 { throw FixtureError.unavailable }
        } else {
          try FileManager.default.removeItem(at: url)
        }
      })
    assertExportError(removal == 2 ? "withdrawal" : "publication") {
      _ = try subject.createRecoveryPackage()
    }
    XCTAssertTrue(publishedWasInspected)
    try assertNoPublished(f)
    let hidden = try FileManager.default.contentsOfDirectory(
      at: f.exports, includingPropertiesForKeys: nil
    )
    .filter { $0.lastPathComponent.hasSuffix(".archive-staging") }
    XCTAssertEqual(hidden.count, removal == 2 ? 1 : 0)
    XCTAssertEqual(try Data(contentsOf: f.store), Data("public-fixture-database".utf8))
  }
  func testUnrepairableWithdrawnArchiveIsRemovedAndAbsenceVerified() throws {
    try failedWithdrawalRepair(removal: 0)
  }
  func testRemovalReportedErrorAfterUnlinkStillAcceptsProvedAbsence() throws {
    try failedWithdrawalRepair(removal: 1)
  }
  func testFailedRemovalOfUnrepairableArchiveReportsWithdrawalFailure() throws {
    try failedWithdrawalRepair(removal: 2)
  }
}

private final class RecoveryRepairFailingFileManager: FileManager, @unchecked Sendable {
  var failHiddenArchiveProtection = false
  override func setAttributes(_ attributes: [FileAttributeKey: Any], ofItemAtPath path: String)
    throws
  {
    if failHiddenArchiveProtection && path.hasSuffix(".archive-staging") {
      throw CocoaError(.fileWriteNoPermission)
    }
    try super.setAttributes(attributes, ofItemAtPath: path)
  }
}
