// SPDX-License-Identifier: BSD-4-Clause
import Darwin
import Foundation
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class RetainedEvidenceFileBoundaryTests: XCTestCase {
    private typealias Harness = RetainedMigrationEvidenceHarness
    private var directory: URL!
    private var exports: [URL] = []
    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        XCTAssertEqual(chmod(directory.path, 0o700), 0)
    }
    override func tearDownWithError() throws {
        exports.forEach { try? FileManager.default.removeItem(at: $0) }
        try FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }
    private func file(_ name: String = "evidence.json", data: Data = Data("public fixture".utf8)) throws -> URL {
        let url = directory.appendingPathComponent(name); try data.write(to: url); return url
    }
    private func read(_ url: URL, limit: Int = 1_024, empty: Bool = false) throws -> Data {
        try Harness.readStableRegularFile(url, maximumBytes: limit, label: "fixture", allowEmpty: empty)
    }
    func testStableReadPreservesExactBytes() throws {
        let bytes = Data([0, 1, 255, 2, 128]); XCTAssertEqual(try read(file(data: bytes)), bytes)
    }
    func testStableReadAcceptsTheExactByteBudget() throws {
        let bytes = Data(repeating: 0xab, count: 1_024); XCTAssertEqual(try read(file(data: bytes)), bytes)
    }
    func testStableReadCrossesItsInternalReadBufferWithoutTruncation() throws {
        let bytes = Data((0..<(700 * 1_024)).map { UInt8($0 % 251) })
        XCTAssertEqual(try read(file(data: bytes), limit: bytes.count), bytes)
    }
    func testOversizedEvidenceIsRejectedBeforeReading() throws { XCTAssertThrowsError(try read(file(data: Data(repeating: 1, count: 1_025)))) }
    func testEmptyEvidenceRequiresExplicitPermission() throws {
        let url = try file(data: Data()); XCTAssertThrowsError(try read(url)); XCTAssertEqual(try read(url, limit: 0, empty: true), Data())
    }
    func testMissingEvidenceFailsClosed() { XCTAssertThrowsError(try read(directory.appendingPathComponent("missing"))) }
    func testDirectoryCannotMasqueradeAsEvidence() { XCTAssertThrowsError(try read(directory)) }
    func testEvidenceReadNeverFollowsASymbolicLink() throws {
        let original = try file(); let alias = directory.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: original)
        XCTAssertThrowsError(try read(alias)); XCTAssertEqual(try Data(contentsOf: original), Data("public fixture".utf8))
    }
    func testEvidenceReadRejectsAHardLinkedFile() throws {
        let original = try file(); let alias = directory.appendingPathComponent("alias")
        try FileManager.default.linkItem(at: original, to: alias)
        XCTAssertThrowsError(try read(original)); XCTAssertThrowsError(try read(alias))
    }
    func testEvidenceDirectoryRequiresOwnerOnlyPermissions() throws {
        try Harness.shared.requireSafeEvidenceDirectory(directory)
        XCTAssertEqual(chmod(directory.path, 0o755), 0)
        XCTAssertThrowsError(try Harness.shared.requireSafeEvidenceDirectory(directory))
    }
    func testEvidenceNamespaceRejectsDirectorySymlinks() throws {
        let alias = directory.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: directory)
        XCTAssertThrowsError(try Harness.shared.requireSafeEvidenceDirectory(alias))
    }
    func testExactDirectoryInventoryIncludesHiddenAndOrdinaryRegularEntries() throws {
        _ = try file("state.json"); _ = try file("receipt-1.bin")
        XCTAssertEqual(try Harness.shared.exactDirectoryNames(directory), ["state.json", "receipt-1.bin"])
    }
    func testEmptyEvidenceNamespaceHasAnEmptyInventory() throws { XCTAssertEqual(try Harness.shared.exactDirectoryNames(directory), []) }
    func testDirectoryInventoryRejectsUnsafeEntryNames() throws {
        _ = try file(".hidden"); XCTAssertThrowsError(try Harness.shared.exactDirectoryNames(directory))
    }
    func testDirectoryInventoryRejectsUnicodeNames() throws {
        _ = try file("receipt-証拠.json"); XCTAssertThrowsError(try Harness.shared.exactDirectoryNames(directory))
    }
    func testDirectoryInventoryRejectsSubdirectories() throws {
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("child"), withIntermediateDirectories: false)
        XCTAssertThrowsError(try Harness.shared.exactDirectoryNames(directory))
    }
    func testDirectoryInventoryRejectsSymbolicLinks() throws {
        let original = try file(); try FileManager.default.createSymbolicLink(at: directory.appendingPathComponent("alias"), withDestinationURL: original)
        XCTAssertThrowsError(try Harness.shared.exactDirectoryNames(directory))
    }
    func testDirectoryInventoryRejectsHardLinks() throws {
        let original = try file(); try FileManager.default.linkItem(at: original, to: directory.appendingPathComponent("alias"))
        XCTAssertThrowsError(try Harness.shared.exactDirectoryNames(directory))
    }
    func testCompleteProtectionWriteMustBeConfirmedByFoundationMetadata() throws {
        let url = try file()
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        let actual = try FileManager.default.attributesOfItem(atPath: url.path)[.protectionKey]
        if FileProtectionMetadata.normalized(actual) == .complete {
            XCTAssertNoThrow(try Harness.shared.setAndRequireCompleteProtection(url))
            XCTAssertNoThrow(try Harness.shared.requireCompleteProtection(url))
        } else {
            // CoreSimulator does not expose real data-protection metadata.
            // Evidence attestation must reject that absence, even after a successful setter.
            XCTAssertThrowsError(try Harness.shared.setAndRequireCompleteProtection(url))
            XCTAssertThrowsError(try Harness.shared.requireCompleteProtection(url))
        }
    }
    func testEvidenceWithWeakerProtectionIsRejected() throws {
        let url = try file(); try FileManager.default.setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: url.path)
        XCTAssertThrowsError(try Harness.shared.requireCompleteProtection(url))
    }
    private func recoveryFile(data: Data = Data("archive".utf8), id: String = UUID().uuidString) throws -> URL {
        let parent = try XCTUnwrap(FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first).appendingPathComponent("WalletRecoveryExports")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let url = parent.appendingPathComponent("SORA-Wallet-Recovery-\(id).sorarecovery.zip")
        exports.append(url); try data.write(to: url); try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        return url
    }
    func testRecoveryArchiveAdmissionRequiresVerifiedPlatformProtection() throws {
        let url = try recoveryFile()
        let actual = try FileManager.default.attributesOfItem(atPath: url.path)[.protectionKey]
        if FileProtectionMetadata.normalized(actual) == .complete {
            XCTAssertNoThrow(try Harness.requireVerifiedRecoveryArchive(url))
        } else {
            XCTAssertThrowsError(try Harness.requireVerifiedRecoveryArchive(url))
        }
    }
    func testRecoveryArchiveFromAnotherDirectoryCannotBecomeEvidence() throws {
        let url = try file("SORA-Wallet-Recovery-\(UUID().uuidString).sorarecovery.zip")
        XCTAssertThrowsError(try Harness.requireVerifiedRecoveryArchive(url))
    }
    func testRecoveryArchiveRejectsNoncanonicalUUID() throws {
        XCTAssertThrowsError(try Harness.requireVerifiedRecoveryArchive(recoveryFile(id: UUID().uuidString.lowercased())))
    }
    func testEmptyRecoveryArchiveCannotProduceAnExportReceipt() throws {
        XCTAssertThrowsError(try Harness.requireVerifiedRecoveryArchive(recoveryFile(data: Data())))
    }
    func testRecoveryArchiveRejectsWeakerProtection() throws {
        let url = try recoveryFile(); try FileManager.default.setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: url.path)
        XCTAssertThrowsError(try Harness.requireVerifiedRecoveryArchive(url))
    }
    func testRecoveryArchiveRejectsHardLinks() throws {
        let url = try recoveryFile(); try FileManager.default.linkItem(at: url, to: directory.appendingPathComponent("alias"))
        XCTAssertThrowsError(try Harness.requireVerifiedRecoveryArchive(url))
    }
    func testRecoveryArchiveRejectsSymbolicLinks() throws {
        let url = try recoveryFile(); try FileManager.default.removeItem(at: url)
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: file())
        XCTAssertThrowsError(try Harness.requireVerifiedRecoveryArchive(url))
    }
    func testRecoveryArchiveRejectsMissingFile() throws {
        let url = try recoveryFile(); try FileManager.default.removeItem(at: url)
        XCTAssertThrowsError(try Harness.requireVerifiedRecoveryArchive(url))
    }
    func testEvidenceStatusRendersAccessibleReceiptValues() throws {
        let view = RetainedMigrationEvidenceStatusView(frame: CGRect(x: 0, y: 0, width: 320, height: 50))
        view.update(status: "passed", receiptSha256: "public-hash", receiptBase64: "cHVibGlj")
        let stack = try XCTUnwrap(view.subviews.first as? UIStackView)
        let labels = stack.arrangedSubviews.compactMap { $0 as? UILabel }
        XCTAssertEqual(labels.map(\.text), ["passed", "public-hash", "cHVibGlj"])
        XCTAssertEqual(labels.map(\.accessibilityLabel), labels.map(\.text))
        XCTAssertEqual(labels.map(\.accessibilityIdentifier), [Harness.statusAccessibilityIdentifier, Harness.receiptShaAccessibilityIdentifier, Harness.receiptBase64AccessibilityIdentifier])
        XCTAssertTrue(labels.allSatisfy(\.isAccessibilityElement)); XCTAssertFalse(view.accessibilityViewIsModal)
        view.update(status: "failed", receiptSha256: "", receiptBase64: "")
        XCTAssertEqual(labels.map(\.text), ["failed", "", ""])
    }
    func testEvidenceOnlyControllerHasNoWalletControls() {
        let controller = RetainedMigrationEvidenceViewController(); controller.loadViewIfNeeded()
        XCTAssertEqual(controller.view.subviews.compactMap { ($0 as? UILabel)?.text }, ["Retained migration evidence"])
        XCTAssertTrue(controller.view.subviews.allSatisfy { !($0 is UIControl) })
    }
}
