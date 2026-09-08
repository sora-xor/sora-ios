// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import UIKit
import XCTest
import SoraUIKit
import SoraKeystore
import CoreData
import Darwin
@testable import SoraPassport

final class WalletUXTests: XCTestCase {
    func testStartupRetryReportsCurrentFailureWithoutReplacingRecoveryMarker() throws {
        let settings = InMemorySettingsManager()
        let reason = UserStorageMigrationError.privacySafeRecoveryDescription(for: KeystoreError.unexpectedFail)
        settings.setWalletMigrationRecovery(reason: reason)
        let original = WalletMigrationRecoveryMarker.capture(settings)
        let secret = "PRIVATE-wallet-address-path-and-phrase"
        let failures: [(Error, WalletStartupDiagnostic.Cause, Int?)] = [
            (UserStorageMigrationError.backupVerificationFailed(secret), .backupVerification, nil),
            (WalletNetworkMigrationError.legacyIdentityMismatch(secret), .legacyIdentityMismatch, nil),
            (WalletIntegrityError.selectedAccountSecretMissing(address: secret), .missingSecret, nil),
            (KeystoreSystemError(status: -25308), .keychainSystem, -25308),
            (NSError(domain: NSCocoaErrorDomain, code: 134100,
                userInfo: [NSLocalizedDescriptionKey: secret, NSFilePathErrorKey: secret]), .cocoa, 134100),
            (NSError(domain: secret, code: 7, userInfo: [NSLocalizedDescriptionKey: secret]), .unexpected, nil)
        ]
        for (error, cause, systemCode) in failures {
            var migrated = false
            XCTAssertEqual(WalletStorageStartup.run(settings: settings, accountCommitRecovery: {
                try WalletStartupDiagnostic.check(.databaseInventory) { throw error }
            }, migration: { migrated = true }), .recoveryRequired)
            XCTAssertFalse(migrated)
            XCTAssertEqual(WalletMigrationRecoveryMarker.capture(settings), original)
            let diagnostic = try XCTUnwrap(WalletStartupDiagnostic.current(settings))
            XCTAssertEqual(diagnostic.phase, .databaseInventory)
            XCTAssertEqual(diagnostic.cause, cause)
            XCTAssertEqual(diagnostic.systemCode, systemCode)
            XCTAssertFalse(diagnostic.summary.contains(secret))
            XCTAssertFalse(try String(decoding: JSONEncoder().encode(diagnostic), as: UTF8.self).contains(secret))
        }
        settings.setWalletMigrationRecovery(reason: "A newer integrity failure")
        XCTAssertNil(WalletStartupDiagnostic.current(settings), "A new marker must not display the previous attempt's diagnostic")

        let fresh = InMemorySettingsManager()
        XCTAssertEqual(WalletStorageStartup.run(settings: fresh, migration: {
            throw KeystoreSystemError(status: -34018)
        }), .recoveryRequired)
        XCTAssertEqual(WalletStartupDiagnostic.current(fresh)?.phase, .databaseMigration)
        XCTAssertEqual(WalletStartupDiagnostic.current(fresh)?.systemCode, -34018)
        XCTAssertEqual(fresh.walletMigrationRecoveryReason, reason)
    }

    @MainActor
    func testRecoveryDetailsIncludeLatestSafeDiagnosticAndRejectInvalidStoredCodes() throws {
        let settings = InMemorySettingsManager()
        let reason = UserStorageMigrationError.privacySafeRecoveryDescription(for: KeystoreError.unexpectedFail)
        settings.setWalletMigrationRecovery(reason: reason)
        let marker = WalletMigrationRecoveryMarker.capture(settings)
        WalletStartupDiagnostic.record(KeystoreSystemError(status: -25308),
            phase: .networkBootstrap, settings: settings)
        let diagnostic = try XCTUnwrap(WalletStartupDiagnostic.current(settings))
        let controller = WalletRecoveryViewController(reason: reason, diagnostic: diagnostic)
        controller.loadViewIfNeeded()
        let copy = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-recovery-copy-details" })
        copy.sendActions(for: .touchUpInside)
        let details = try XCTUnwrap(UIPasteboard.general.string)
        XCTAssertTrue(details.contains(reason))
        XCTAssertTrue(details.contains("Latest verification: network_bootstrap / keychain_system (-25308)"))
        XCTAssertEqual(WalletMigrationRecoveryMarker.capture(settings), marker)

        var stored = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(diagnostic)) as? [String: Any])
        stored["cause"] = "PRIVATE-ACCOUNT"
        let malformed = try JSONSerialization.data(withJSONObject: stored)
        settings.set(value: String(decoding: malformed, as: UTF8.self), for: "walletStartupDiagnostic")
        XCTAssertNil(WalletStartupDiagnostic.current(settings))
        XCTAssertEqual(WalletMigrationRecoveryMarker.capture(settings), marker)
    }

    @MainActor
    func testWalletRecoveryRetryRunsOnceWithoutClearingRecoveryState() throws {
        let settings = InMemorySettingsManager()
        let reason = UserStorageMigrationError.privacySafeRecoveryDescription(for: KeystoreError.invalidIdentifierFormat)
        settings.setWalletMigrationRecovery(reason: reason)
        let marker = WalletMigrationRecoveryMarker.capture(settings)
        var retries = 0
        let controller = WalletRecoveryViewController(reason: reason, onRetry: {
            XCTAssertEqual(WalletMigrationRecoveryMarker.capture(settings), marker)
            retries += 1
        })
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        controller.view.layoutIfNeeded()
        let retry = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-recovery-retry" })
        XCTAssertEqual(retry.title(for: .normal), "Try again")
        XCTAssertTrue(retry.isEnabled)
        XCTAssertFalse(retry.isHidden)
        XCTAssertFalse(retry.frame.isEmpty)
        retry.sendActions(for: .touchUpInside)
        retry.sendActions(for: .touchUpInside)
        XCTAssertEqual(retries, 1)
        XCTAssertFalse(retry.isEnabled)
        XCTAssertEqual(WalletMigrationRecoveryMarker.capture(settings), marker)
        let passiveController = WalletRecoveryViewController(reason: reason)
        passiveController.loadViewIfNeeded()
        XCTAssertTrue(try XCTUnwrap(descendants(passiveController.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-recovery-retry" }).isHidden)
    }

    @MainActor
    func testStorageRetryRemainsAvailableAfterRepeatedLowSpace() throws {
        let window = SoraWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let presenter = SplashPresenter(window: window)
        let controller = SplashViewController()
        controller.presenter = presenter
        presenter.view = controller
        var retries = 0
        for expected in 1 ... 2 {
            controller.showStorageSpaceRetry { retries += 1 }
            controller.view.layoutIfNeeded()
            let retry = try XCTUnwrap(descendants(controller.view)
                .compactMap { $0 as? UIButton }
                .first { $0.accessibilityIdentifier == "wallet-upgrade-storage-retry" })
            XCTAssertTrue(retry.isEnabled)
            XCTAssertFalse(retry.frame.isEmpty)
            retry.sendActions(for: .touchUpInside)
            XCTAssertEqual(retries, expected)
            XCTAssertFalse(retry.isEnabled)
        }
    }

    @MainActor
    func testEditableSoraTextRetainsDynamicTypeAfterChanges() throws {
        let parent = UIViewController()
        let child = UIViewController()
        parent.addChild(child)
        parent.view.addSubview(child.view)
        child.didMove(toParent: parent)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        window.rootViewController = parent
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        let field = SoramitsuTextField()
        let textView = SoramitsuTextView()
        let unchanged = SoramitsuTextField()
        [field, textView, unchanged].forEach { child.view.addSubview($0) }
        field.sora.dynamicTextStyle = .body
        textView.sora.dynamicTextStyle = .body
        let base = FontType.textM.font
        for category: UIContentSizeCategory in [.large, .accessibilityExtraExtraExtraLarge] {
            if #available(iOS 17.0, *) {
                child.traitOverrides.preferredContentSizeCategory = category
                child.updateTraitsIfNeeded()
                child.view.updateTraitsIfNeeded()
                [field, textView, unchanged].forEach { $0.updateTraitsIfNeeded() }
            } else {
                parent.setOverrideTraitCollection(UITraitCollection(preferredContentSizeCategory: category), forChild: child)
            }
            parent.view.layoutIfNeeded()
            child.view.layoutIfNeeded()
            XCTAssertEqual(field.traitCollection.preferredContentSizeCategory, category)
            XCTAssertEqual(textView.traitCollection.preferredContentSizeCategory, category)
            for input in ["First", "Edited again"] {
                field.sora.text = input
                textView.sora.text = input
                unchanged.sora.text = input
                let expected = UIFontMetrics(forTextStyle: .body).scaledFont(for: base,
                    compatibleWith: UITraitCollection(preferredContentSizeCategory: category)).pointSize
                let fieldFont = try XCTUnwrap(field.attributedText?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
                let viewFont = try XCTUnwrap(textView.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
                XCTAssertEqual(fieldFont.pointSize, expected, accuracy: 0.1)
                XCTAssertEqual(viewFont.pointSize, expected, accuracy: 0.1)
                let originalFont = try XCTUnwrap(unchanged.attributedText?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
                XCTAssertEqual(originalFont.pointSize, base.pointSize, accuracy: 0.1)
            }
        }
    }

    @MainActor
    func testRecoveryChoicesExposeSelectionAndRequireAllAcknowledgements() throws {
        let controller = AccountWarningViewController(warningType: .passphrase)
        var completions = 0
        controller.completion = { completions += 1 }
        controller.loadViewIfNeeded()
        let choices = descendants(controller.view).compactMap { $0 as? CheckView }
        XCTAssertEqual(choices.count, 3)
        controller.completeTapped()
        XCTAssertEqual(completions, 0)
        for choice in choices {
            XCTAssertTrue(choice.isAccessibilityElement)
            XCTAssertFalse(choice.accessibilityLabel?.isEmpty ?? true)
            XCTAssertFalse(choice.accessibilityTraits.contains(.selected))
            XCTAssertTrue(choice.accessibilityActivate())
            XCTAssertTrue(choice.accessibilityTraits.contains(.selected))
        }
        controller.completeTapped()
        XCTAssertEqual(completions, 1)
        XCTAssertTrue(try XCTUnwrap(choices.first).accessibilityActivate())
        controller.completeTapped()
        XCTAssertEqual(completions, 1)
    }

    func testPristineCurrentSQLiteCanRelaunchWithOrdinarySidecars() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("UserDataModel.sqlite")
        let modelURL = try XCTUnwrap(Bundle.main.url(forResource: UserStorageParams.modelVersion.rawValue,
            withExtension: "omo", subdirectory: UserStorageParams.modelDirectory)
            ?? Bundle.main.url(forResource: UserStorageParams.modelVersion.rawValue,
                withExtension: "mom", subdirectory: UserStorageParams.modelDirectory))
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL))
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let database = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil,
            at: storeURL, options: nil)
        defer { try? coordinator.remove(database) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path + "-shm"))
        let originalStore = try Data(contentsOf: storeURL)
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let gate = WalletRecoveryCapabilityGate(settings: settings,
            unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false })
        let migrator = UserStorageMigrator(targetVersion: UserStorageParams.modelVersion, storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory, keystore: keychain, settings: settings,
            fileManager: .default, recoveryGate: gate, loadWalletNetworkSnapshot: { nil })
        for _ in 0 ..< 2 {
            try migrator.performMigration()
            XCTAssertFalse(settings.hasRetainedWalletSettings())
            XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("WalletMigrationSafety").path))
            XCTAssertEqual(try Data(contentsOf: storeURL), originalStore)
        }
        try keychain.addKey(Data([1]), with: KeystoreTag.pincode.rawValue)
        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard case UserStorageMigrationError.missingWalletStore = error else {
                return XCTFail("Unexpected retained-wallet admission: \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: storeURL), originalStore)
    }

    func testFirstLaunchKeepsPristineNamespaceAndReachesOnboarding() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try makeWalletNetworkStore(baseURL: directory)
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let root = RootInteractor(settings: settings, keystore: keychain, migrators: [],
            securityLayerInteractor: WalletUXSecurityLayerStub(),
            networkAvailabilityLayerInteractor: nil, legacyUpgradeSelectedAccount: { nil },
            legacyUpgradeSnapshotLoader: { try store.load() }, legacyUpgradeUnresolvedCommitLoader: { [] })
        let presenter = WalletUXRootPresenterSpy()
        root.presenter = presenter
        for _ in 0 ..< 2 {
            try SplashInteractor.initializeWalletNetworksIfNeeded(accounts: [], selectedAddress: nil,
                store: store, keystore: keychain, settings: settings)
            XCTAssertNil(try store.load())
            XCTAssertFalse(settings.hasRetainedWalletSettings())
            root.decideModuleSynchroniously()
        }
        XCTAssertEqual(presenter.decisions, [.onboarding, .onboarding])
    }

    func testEmptyBootstrapPreservesRetainedEvidenceAndRecovery() throws {
        for kind in ["pin", "watch-only", "version", "identity"] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = try makeWalletNetworkStore(baseURL: directory)
            let settings = InMemorySettingsManager()
            let keychain = InMemoryKeychain()
            switch kind {
            case "pin": try keychain.addKey(Data([1, 2, 3]), with: KeystoreTag.pincode.rawValue)
            case "watch-only": settings.set(value: true, for: "wallet.watchOnly.retained")
            case "version": settings.set(value: 3, for: SettingsKey.walletNetworkStoreVersion.rawValue)
            default: settings.set(value: "retained-id", for: SettingsKey.decentralizedId.rawValue)
            }
            let keysBefore = Set(settings.allKeys())
            let identifiersBefore = try keychain.allKeyIdentifiers()
            try SplashInteractor.initializeWalletNetworksIfNeeded(accounts: [], selectedAddress: nil,
                store: store, keystore: keychain, settings: settings)
            XCTAssertEqual(Set(settings.allKeys()), keysBefore)
            XCTAssertEqual(try keychain.allKeyIdentifiers(), identifiersBefore)
            XCTAssertNil(try store.load())
            let root = RootInteractor(settings: settings, keystore: keychain, migrators: [],
                securityLayerInteractor: WalletUXSecurityLayerStub(),
                networkAvailabilityLayerInteractor: nil, legacyUpgradeSelectedAccount: { nil },
                legacyUpgradeSnapshotLoader: { try store.load() }, legacyUpgradeUnresolvedCommitLoader: { [] })
            let presenter = WalletUXRootPresenterSpy()
            root.presenter = presenter
            root.decideModuleSynchroniously()
            XCTAssertEqual(presenter.decisions, [.broken], kind)
        }
    }

    func testEmptyBootstrapRejectsCorruptSnapshotWithoutChangingIt() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try makeWalletNetworkStore(baseURL: directory)
        let pointer = directory.appendingPathComponent("SORA/WalletNetworks/active.json")
        let retained = Data("interrupted-pointer".utf8)
        try retained.write(to: pointer)
        XCTAssertThrowsError(try SplashInteractor.initializeWalletNetworksIfNeeded(accounts: [], selectedAddress: nil,
            store: store, keystore: InMemoryKeychain(), settings: InMemorySettingsManager()))
        XCTAssertEqual(try Data(contentsOf: pointer), retained)
    }

    private func makeWalletNetworkStore(baseURL: URL) throws -> WalletNetworkStore {
        let gate = WalletRecoveryCapabilityGate(settings: InMemorySettingsManager(),
            unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false })
        return try WalletNetworkStore(baseURL: baseURL, recoveryGate: gate)
    }

    @MainActor
    func testChartKeepsItsDescriptionAndExpandsForNarrowScreens() {
        let chart = PolkamarktLineChartView(frame: .zero)
        chart.caption = "Yes probability history"
        chart.context = "From 30% yesterday to 65% today. Vertical scale: 0% to 100%. Snapshots run from oldest to newest at equal spacing."
        chart.values = [0.3, 0.5, 0.65]
        XCTAssertTrue(chart.isAccessibilityElement)
        XCTAssertTrue(chart.accessibilityLabel?.contains(chart.context) == true)
        let wide = chart.sizeThatFits(CGSize(width: 600, height: 1000))
        let narrow = chart.sizeThatFits(CGSize(width: 320, height: 1000))
        XCTAssertGreaterThan(narrow.height, wide.height)
        XCTAssertGreaterThan(narrow.height, 180)
    }

    func testTotalRetainsExactPrecisionAndRejectsInvalidAmounts() throws {
        for (amount, fee, expected) in [
            ("12.5", "0.01", "12.51"),
            ("0.000000001", "0.000000009", "0.000000010"),
            ("999999999999999999999999999999999999999999.99", "0.01", "1000000000000000000000000000000000000000000.00")
        ] {
            XCTAssertEqual(WalletUX.total(amount: try PIQuantity(amount), fee: try PIQuantity(fee)), expected)
        }
        XCTAssertNil(WalletUX.total(amount: try PIQuantity("-1"), fee: try PIQuantity("0.01")))
        XCTAssertNil(WalletUX.total(amount: try PIQuantity("1"), fee: try PIQuantity("-0.01")))
    }

    func testLocalizationUsesSelectedLanguageThenEnglishFallback() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("bundle")
        defer { try? FileManager.default.removeItem(at: root) }
        for (language, content) in [
            ("en", "\"Greeting\" = \"Hello\";\n\"Fallback\" = \"English fallback\";"),
            ("ja", "\"Greeting\" = \"こんにちは\";")
        ] {
            let directory = root.appendingPathComponent(language + ".lproj")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try content.write(to: directory.appendingPathComponent("Localizable.strings"), atomically: true, encoding: .utf8)
        }
        let bundle = try XCTUnwrap(Bundle(url: root))
        XCTAssertEqual(WalletUX.text("Greeting", language: "ja", bundle: bundle), "こんにちは")
        XCTAssertEqual(WalletUX.text("Fallback", language: "ja", bundle: bundle), "English fallback")
        XCTAssertEqual(WalletUX.text("Greeting", language: "missing", bundle: bundle), "Hello")
    }

    @MainActor
    func testWalletSecondaryTextMeetsContrastInBothThemes() {
        let previous = SoramitsuUI.shared.themeMode
        defer { SoramitsuUI.shared.themeMode = previous }
        for mode in [SoramitsuThemeMode.manual(.light), .manual(.dark)] {
            SoramitsuUI.shared.themeMode = mode
            XCTAssertGreaterThanOrEqual(WalletUX.contrast(WalletUX.secondary, WalletUX.page), 4.5)
            XCTAssertGreaterThanOrEqual(WalletUX.contrast(WalletUX.secondary, WalletUX.surface), 4.5)
        }
    }

    @MainActor
    func testBusySendCannotStartAnotherReview() throws {
        let view = NexusSendViewController(network: "Taira · TESTNET", balance: "100")
        view.loadViewIfNeeded()
        try XCTUnwrap(descendants(view.view).compactMap { $0 as? UITextView }.first).text = "recipient"
        try XCTUnwrap(descendants(view.view).compactMap { $0 as? UITextField }.first).text = "1"
        var reviews = 0
        view.onReview = { _, _ in reviews += 1; view.setBusy(true) }
        let primary = try XCTUnwrap(button("Review send", in: view.view))
        primary.sendActions(for: .touchUpInside)
        primary.sendActions(for: .touchUpInside)
        XCTAssertEqual(reviews, 1)
    }

    @MainActor
    func testEditingReviewPreservesDraftAndRequiresAnotherQuote() throws {
        let view = NexusSendViewController(network: "Taira · TESTNET", balance: "100")
        view.loadViewIfNeeded()
        let recipient = try XCTUnwrap(descendants(view.view).compactMap { $0 as? UITextView }.first)
        let amount = try XCTUnwrap(descendants(view.view).compactMap { $0 as? UITextField }.first)
        recipient.text = "test-recipient-address"
        amount.text = "12.5"
        let quantity = try PIQuantity("12.5")
        let request = NexusTransferRequest(walletId: "test-wallet", networkId: .taira,
            sender: "test-sender", receiver: recipient.text, amount: quantity)
        let quote = NexusTransferFeeQuote(networkId: .taira, authority: "test-sender", receiver: recipient.text,
            assetDefinitionId: "test-asset", amount: quantity, fee: try PIQuantity("0.01"), quoteIdentity: "test-quote", validUntilBlock: 100)
        let prepared = NexusPreparedTransfer(request: request, canonicalReceiver: recipient.text,
            assetDefinitionID: "test-asset", availableBalance: try PIQuantity("100"), quote: quote)
        XCTAssertFalse(prepared.submissionMayHaveStarted)
        view.showReview(prepared)
        XCTAssertTrue(descendants(view.view).compactMap { ($0 as? UILabel)?.text }.contains("12.51 XOR"))
        let edit = try XCTUnwrap(button("Edit details", in: view.view))
        edit.sendActions(for: .touchUpInside)
        XCTAssertEqual(recipient.text, "test-recipient-address")
        XCTAssertEqual(amount.text, "12.5")
        var reviewedDraft: (String, String)?
        view.onReview = { reviewedDraft = ($0, $1) }
        view.onConfirm = { _ in XCTFail("Editing must invalidate the prepared quote") }
        try XCTUnwrap(button("Review send", in: view.view)).sendActions(for: .touchUpInside)
        XCTAssertEqual(reviewedDraft?.0, "test-recipient-address")
        XCTAssertEqual(reviewedDraft?.1, "12.5")

        view.showReview(prepared)
        view.setBusy(true)
        view.showUnsentError(WalletUX.sendError(NexusToriiError.quoteExpired))
        reviewedDraft = nil
        try XCTUnwrap(button("Review send", in: view.view)).sendActions(for: .touchUpInside)
        XCTAssertEqual(reviewedDraft?.0, "test-recipient-address")
        XCTAssertEqual(reviewedDraft?.1, "12.5")

        view.showReview(prepared)
        var submissions = 0
        view.onConfirm = { _ in submissions += 1; view.setBusy(true) }
        let confirm = try XCTUnwrap(button("Confirm and send", in: view.view))
        confirm.sendActions(for: .touchUpInside)
        confirm.sendActions(for: .touchUpInside)
        XCTAssertEqual(submissions, 1, "A busy confirmation must not submit twice")
        prepared.markTransportStarted()
        XCTAssertTrue(prepared.submissionMayHaveStarted)
    }

    func testAmbiguousSendNeverLooksCompletedOrInvitesResubmission() {
        XCTAssertNotEqual(WalletUX.status(.submissionUnknown), WalletUX.status(.committed))
        XCTAssertTrue(WalletUX.statusDetail(.submissionUnknown).contains("do not send it again"))
        XCTAssertTrue(WalletUX.sendError(NexusToriiError.ambiguousSubmission).contains("Activity"))
        XCTAssertNotEqual(WalletUX.status(.committedPendingReconciliation), WalletUX.status(.committed))
        XCTAssertTrue(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.ambiguousSubmission))
        XCTAssertTrue(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.confirmationAlreadySubmitted))
        XCTAssertTrue(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.transactionHashMismatch))
        XCTAssertTrue(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.httpStatus(500)))
        XCTAssertTrue(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.server))
        XCTAssertTrue(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.invalidResponse))
        XCTAssertFalse(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.insufficientBalance))
        XCTAssertFalse(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.quoteExpired))
        XCTAssertFalse(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.httpStatus(500), submissionMayHaveStarted: false),
                       "A failed read before transport must restore the draft")
        XCTAssertTrue(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.quoteExpired, submissionMayHaveStarted: true),
                      "The transport boundary takes precedence over an error classification")
        XCTAssertTrue(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.confirmationAlreadySubmitted, submissionMayHaveStarted: false))
    }

    @MainActor
    func testUncertainSubmissionOnlyOffersActivity() throws {
        let view = NexusSendViewController(network: "Taira · TESTNET", balance: "100")
        view.loadViewIfNeeded()
        view.onConfirm = { _ in XCTFail("An uncertain submission must not be sent again") }
        view.onReview = { _, _ in XCTFail("An uncertain submission must not be reviewed again") }
        view.showUncertainSubmission(WalletUX.sendError(NexusToriiError.ambiguousSubmission))
        let primary = try XCTUnwrap(button("Review send", in: view.view))
        let edit = try XCTUnwrap(button("Edit details", in: view.view))
        XCTAssertTrue(primary.isHidden)
        XCTAssertTrue(edit.isHidden)
        XCTAssertFalse(try XCTUnwrap(button("View Activity", in: view.view)).isHidden)
        primary.sendActions(for: .touchUpInside)
        edit.sendActions(for: .touchUpInside)
        XCTAssertTrue(primary.isHidden)
    }

    func testDurableAncestorSynchronizationStopsAtContainerBeforeSandboxDeniedParent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let container = root.appendingPathComponent("AppHome", isDirectory: true)
        let shallow = container.appendingPathComponent("Documents/CoreData", isDirectory: true)
        let deep = container.appendingPathComponent("Library/Application Support/SORA/WalletNetworks", isDirectory: true)
        try FileManager.default.createDirectory(at: shallow, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: deep, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let alias = root.appendingPathComponent("AppHomeAlias", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: container)
        let homeDescriptor = Darwin.open(container.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        XCTAssertGreaterThanOrEqual(homeDescriptor, 0)
        defer { _ = Darwin.close(homeDescriptor) }
        var homeIdentity = stat()
        XCTAssertEqual(Darwin.fstat(homeDescriptor, &homeIdentity), 0)
        let cases: [(URL, URL, Int)] = [
            (container, container, 0),
            (shallow, container, 2),
            (deep, container, 4),
            (alias.appendingPathComponent("Documents/CoreData"), container, 2),
            (shallow, alias, 2)
        ]
        for (start, boundary, expectedOpens) in cases {
            let descriptor = Darwin.open(start.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            XCTAssertGreaterThanOrEqual(descriptor, 0)
            defer { _ = Darwin.close(descriptor) }
            var opens = 0
            var outsideContainerAttempted = false
            try DurableFileWriter.synchronizeAncestorDirectoryEntries(from: descriptor,
                maximumDepth: 4, containerURL: boundary, openParent: { current in
                    var identity = stat()
                    guard Darwin.fstat(current, &identity) == 0 else { return -1 }
                    if identity.st_dev == homeIdentity.st_dev && identity.st_ino == homeIdentity.st_ino {
                        outsideContainerAttempted = true
                        errno = EACCES
                        return -1
                    }
                    opens += 1
                    return Darwin.openat(current, "..", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                })
            XCTAssertEqual(opens, expectedOpens)
            XCTAssertFalse(outsideContainerAttempted,
                "The app container must be recognized before openat attempts its forbidden parent")
        }
        let descriptor = Darwin.open(shallow.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        XCTAssertGreaterThanOrEqual(descriptor, 0)
        defer { _ = Darwin.close(descriptor) }
        var attempted = 0
        XCTAssertThrowsError(try DurableFileWriter.synchronizeAncestorDirectoryEntries(from: descriptor,
            maximumDepth: 4, containerURL: container, openParent: { _ in
                attempted += 1
                errno = EACCES
                return -1
            })) { error in
                guard case DurableFileWriter.Failure.fileSystemFailure = error else {
                    return XCTFail("An in-container durability failure must remain a failure")
                }
            }
        XCTAssertEqual(attempted, 1)
    }

    @MainActor
    private func descendants(_ view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }
    @MainActor
    private func button(_ title: String, in view: UIView) -> UIButton? {
        descendants(view).compactMap { $0 as? UIButton }.first {
            ($0.configuration?.title ?? $0.title(for: .normal)) == WalletUX.text(title)
        }
    }
}

private final class WalletUXSecurityLayerStub: SecurityLayerInteractorInputProtocol {
    func setup() {}
}

private final class WalletUXRootPresenterSpy: RootInteractorOutputProtocol {
    enum Decision: Equatable { case onboarding, legacyWalletUpgrade, localAuthentication, broken, pincodeSetup }
    var decisions: [Decision] = []
    func didDecideOnboarding() { decisions.append(.onboarding) }
    func didDecideLegacyWalletUpgrade() { decisions.append(.legacyWalletUpgrade) }
    func didDecideLocalAuthentication() { decisions.append(.localAuthentication) }
    func didDecideBroken() { decisions.append(.broken) }
    func didDecidePincodeSetup() { decisions.append(.pincodeSetup) }
}
