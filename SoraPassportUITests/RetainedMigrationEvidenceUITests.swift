import CryptoKit
import XCTest

/// Out-of-process observation only. After this runner is built, the protected
/// host controller installs a registered-device-signed clone extracted from
/// the exact production IPA and proves canonical equality to that IPA. This
/// test never prepares wallet state, signs an authorization, or treats its
/// own rebuilt application product as evidence.
final class RetainedMigrationEvidenceUITests: XCTestCase {
    private enum RunnerFailure: Error {
        case rejectedStatus(String)
        case launchTimedOut
        case malformedReceiptProjection
    }

    private static let bundleIdentifier = "co.jp.soramitsu.sora"
    private static let statusIdentifier =
        "sora.migrationEvidence.v3.status"
    private static let receiptShaIdentifier =
        "sora.migrationEvidence.v3.receiptSha256"
    private static let receiptBase64Identifier =
        "sora.migrationEvidence.v3.receiptBase64"
    private static let continueUpgradeIdentifier =
        "sora.migrationEvidence.v3.continueUpgrade"
    private static let recoveryExportIdentifier =
        "sora.migrationEvidence.v3.recoveryExport"
    private static let recoveryExportConfirmIdentifier =
        "sora.migrationEvidence.v3.recoveryExportConfirm"
    private static let recoveryExportSuccessIdentifier =
        "sora.migrationEvidence.v3.recoveryExportSuccess"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testExecuteAuthorizedRetainedMigrationCase() throws {
        var launches = 0
        while launches < 8 {
            launches += 1
            let application = XCUIApplication(
                bundleIdentifier: Self.bundleIdentifier
            )
            application.launch()

            let terminal = try driveLaunch(application)
            if terminal {
                try attachCanonicalReceipt(from: application)
                return
            }

            application.terminate()
        }
        throw RunnerFailure.launchTimedOut
    }

    private func driveLaunch(
        _ application: XCUIApplication
    ) throws -> Bool {
        var confirmedUpgrade = false
        var requestedRecoveryExport = false
        let deadline = Date(timeIntervalSinceNow: 300)
        while Date() < deadline {
            let statusElement = application.staticTexts[
                Self.statusIdentifier
            ]
            if statusElement.waitForExistence(timeout: 1) {
                let status = statusElement.label
                if status.hasPrefix("terminal-observed:") {
                    guard
                        status == "terminal-observed:passed" ||
                        status == "terminal-observed:observed"
                    else {
                        throw RunnerFailure.rejectedStatus(status)
                    }
                    if requestedRecoveryExport {
                        try requireRecoveryExportSuccess(application)
                    }
                    return true
                }
                if status.hasPrefix("checkpoint-reached:") {
                    return false
                }
                if status == "authorization-rejected" ||
                    status == "harness-failed-closed" ||
                    status == "inactive" ||
                    status == "awaiting-signed-authorization" {
                    throw RunnerFailure.rejectedStatus(status)
                }
                if status == "awaiting-legacy-upgrade-confirmation",
                   !confirmedUpgrade {
                    let button = application.buttons[
                        Self.continueUpgradeIdentifier
                    ]
                    guard button.waitForExistence(timeout: 30) else {
                        throw RunnerFailure.launchTimedOut
                    }
                    button.tap()
                    confirmedUpgrade = true
                }
                if status == "awaiting-recovery-archive-export",
                   !requestedRecoveryExport {
                    let export = application.buttons[
                        Self.recoveryExportIdentifier
                    ]
                    guard export.waitForExistence(timeout: 30) else {
                        throw RunnerFailure.launchTimedOut
                    }
                    export.tap()
                    let confirmation = application.alerts[
                        Self.recoveryExportConfirmIdentifier
                    ]
                    guard confirmation.waitForExistence(timeout: 30) else {
                        throw RunnerFailure.launchTimedOut
                    }
                    confirmation.buttons["Create export"].tap()
                    requestedRecoveryExport = true
                }
                if status == "recovery-archive-export-verified" {
                    try requireRecoveryExportSuccess(application)
                }
            }
        }
        throw RunnerFailure.launchTimedOut
    }

    private func requireRecoveryExportSuccess(
        _ application: XCUIApplication
    ) throws {
        let success = application.staticTexts[
            Self.recoveryExportSuccessIdentifier
        ]
        guard success.waitForExistence(timeout: 30),
              success.label.hasPrefix("Protected export created.") else {
            throw RunnerFailure.malformedReceiptProjection
        }
    }

    private func attachCanonicalReceipt(
        from application: XCUIApplication
    ) throws {
        let shaElement = application.staticTexts[
            Self.receiptShaIdentifier
        ]
        let base64Element = application.staticTexts[
            Self.receiptBase64Identifier
        ]
        guard
            shaElement.waitForExistence(timeout: 30),
            base64Element.waitForExistence(timeout: 30)
        else {
            throw RunnerFailure.malformedReceiptProjection
        }
        let expectedSha = shaElement.label
        let encoded = base64Element.label
        guard
            expectedSha.utf8.count == 64,
            expectedSha.utf8.allSatisfy({
                (48 ... 57).contains($0) || (97 ... 102).contains($0)
            }),
            let receipt = Data(base64Encoded: encoded, options: []),
            !receipt.isEmpty,
            receipt.count <= 256 * 1_024,
            receipt.base64EncodedString() == encoded,
            receipt.last == 0x0A
        else {
            throw RunnerFailure.malformedReceiptProjection
        }
        let actualSha = Data(SHA256.hash(data: receipt)).map {
            String(format: "%02x", $0)
        }.joined()
        guard actualSha == expectedSha else {
            throw RunnerFailure.malformedReceiptProjection
        }
        guard
            let root = try JSONSerialization.jsonObject(
                with: receipt,
                options: []
            ) as? [String: Any],
            root["contractId"] as? String ==
                "sora-ios-wallet-migration-case-operation-receipt-v3",
            root["platform"] as? String == "ios",
            root["status"] as? String == "observed",
            root["releaseAuthorized"] as? Bool == false,
            ["passed", "observed"].contains(
                root["outcome"] as? String ?? ""
            ),
            JSONSerialization.isValidJSONObject(root)
        else {
            throw RunnerFailure.malformedReceiptProjection
        }
        var canonical = try JSONSerialization.data(
            withJSONObject: root,
            options: [.sortedKeys]
        )
        canonical.append(0x0A)
        guard canonical == receipt else {
            throw RunnerFailure.malformedReceiptProjection
        }

        let attachment = XCTAttachment(
            data: receipt,
            uniformTypeIdentifier: "public.json"
        )
        attachment.name = "case-operation-receipt-v3-\(expectedSha).json"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
