// Copyright (c) 2026, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import UIKit
import XCTest
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFUtils
@testable import SoraPassport

final class WalletAccountCapabilityTests: XCTestCase {
    private func fixture(_ type: CryptoType = .sr25519) throws -> (PreparedAccount, InMemoryKeychain, InMemorySettingsManager, WalletRecoveryCapabilityGate) {
        let keys = InMemoryKeychain(), settings = InMemorySettingsManager()
        let gate = WalletRecoveryCapabilityGate(settings: settings, unresolvedMigrationJournal: { false },
            unresolvedWalletCommitJournal: { false }, credentialRepairPending: { try keys.checkKey(for: WalletCredentialRepair.pendingTag) })
        let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(fromList:
            "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about")
        let operation = AccountOperationFactory(keystore: keys, recoveryGate: gate).prepareAccountOperation(
            request: AccountCreationRequest(username: "Public capability fixture", type: .sora,
                derivationPath: "//capability", cryptoType: type), mnemonic: mnemonic)
        operation.start()
        return (try XCTUnwrap(operation.result).get(), keys, settings, gate)
    }

    func testCapabilityProofKeepsWorkingDirectKeyIndependentOfBackupsAndRejectsBadKey() throws {
        for type in [CryptoType.sr25519, .ed25519, .ecdsa] {
            let (prepared, keys, settings, gate) = try fixture(type)
            let account = prepared.account
            func status() -> WalletAccountCapability.State {
                WalletAccountCapability.evaluate(account: account, keystore: keys, settings: settings, recoveryGate: gate)
            }
            XCTAssertEqual(status(), .missingKeys)
            try prepared.persist(to: keys)
            XCTAssertEqual(status(), .signing)
            try keys.saveKey(Data([0xff]), with: KeystoreTag.entropyTagForAddress(account.address))
            try keys.saveKey(Data([0xff]), with: KeystoreTag.seedTagForAddress(account.address))
            try keys.saveKey(Data([0xff]), with: KeystoreTag.deriviationTagForAddress(account.address))
            XCTAssertEqual(status(), .signing)
            try keys.saveKey(Data([0xff]), with: KeystoreTag.secretKeyTagForAddress(account.address))
            XCTAssertEqual(status(), .invalidKeys)
            settings.set(value: true, for: "wallet.watchOnly.\(account.address)")
            XCTAssertEqual(status(), .watchOnly)
        }
    }

    func testCapabilityPreservesSnapshotWatchOnlyAndBlocksPendingRepairOrForeignJournal() throws {
        let (prepared, keys, settings, gate) = try fixture()
        let account = prepared.account
        try prepared.persist(to: keys)
        let snapshot = WalletNetworkSnapshot(schemaVersion: WalletNetworkSnapshot.currentSchemaVersion,
            selectedWalletId: account.address, wallets: [WalletIdentity(id: account.address, displayName: "Watch",
                existingSoraAddress: account.address, secretSource: .watchOnly)], accounts: [], createdAt: Date())
        XCTAssertEqual(WalletAccountCapability.evaluate(account: account, keystore: keys, settings: settings,
            recoveryGate: gate, activeSnapshot: snapshot), .watchOnly)
        try keys.saveKey(Data([1]), with: WalletCredentialRepair.pendingTag)
        XCTAssertEqual(WalletAccountCapability.evaluate(account: account, keystore: keys, settings: settings,
            recoveryGate: gate), .repairPending)
        let blocked = WalletRecoveryCapabilityGate(settings: settings, unresolvedMigrationJournal: { false },
            unresolvedWalletCommitJournal: { true })
        XCTAssertEqual(WalletAccountCapability.evaluate(account: account, keystore: keys, settings: settings,
            recoveryGate: blocked), .unavailable)
    }

    @MainActor
    func testReadOnlySwitcherBadgeShowsAndHides() throws {
        let picker = AccountMenuItemView(frame: .zero)
        let model = AccountMenuItem(title: "Public fixture", image: nil, isSelected: true, isMultiselectionMode: false)
        model.capabilityBadge = WalletAccountCapability.State.invalidKeys.badge
        picker.bind(model: model)
        let badge = try XCTUnwrap(descendants(picker).first { $0.accessibilityIdentifier == "wallet-account-capability-badge" } as? UILabel)
        XCTAssertEqual(badge.text, WalletUX.text("Read-only"))
        XCTAssertFalse(badge.isHidden)
        model.capabilityBadge = nil; picker.bind(model: model)
        XCTAssertTrue(badge.isHidden)

    }

    @MainActor
    func testSwitcherBadgeHeightFitsTheActualInsetCellAtLargestTextSize() {
        let traits = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        traits.performAsCurrent {
            for image in [UIImage(systemName: "person.circle"), nil] {
                let model = AccountMenuItem(title: "Public account", image: image,
                    isSelected: true, isMultiselectionMode: false)
                model.capabilityBadge = "Nur lesen · Schlüssel für dieses Konto wiederherstellen"
                let width: CGFloat = 320
                let height = model.itemHeight(forWidth: width, context: nil)
                let cell = AccountTableViewCell(style: .default, reuseIdentifier: nil)
                cell.set(item: model, context: nil)
                cell.frame = CGRect(x: 0, y: 0, width: width, height: height)
                cell.contentView.frame = cell.bounds
                cell.setNeedsLayout()
                cell.layoutIfNeeded()
                let labels = descendants(cell).compactMap { $0 as? UILabel }
                guard let badge = labels.first(where: { $0.accessibilityIdentifier == "wallet-account-capability-badge" }),
                      let title = labels.first(where: { $0.text == model.title }) else {
                    return XCTFail("The actual switcher cell must render its title and capability badge")
                }
                XCTAssertGreaterThan(badge.bounds.width, 0)
                let requiredBadgeHeight = badge.sizeThatFits(
                    CGSize(width: badge.bounds.width, height: .greatestFiniteMagnitude)).height
                XCTAssertGreaterThanOrEqual(badge.bounds.height + 1, requiredBadgeHeight,
                    "The complete localized badge must fit at the label's real, inset width")
                XCTAssertGreaterThanOrEqual(title.bounds.height + 1, title.intrinsicContentSize.height,
                    "The badge must not consume the account title's height")
                let badgeFrame = badge.convert(badge.bounds, to: cell.contentView)
                XCTAssertLessThanOrEqual(badgeFrame.maxY, cell.contentView.bounds.maxY - 15,
                    "The text must preserve the cell's bottom padding")
            }
        }
    }

    @MainActor
    func testSendPreflightBlocksReadOnlyWithRepairActionAndDiscardsStaleSelection() async throws {
        let (prepared, _, _, _) = try fixture()
        let account = prepared.account
        let previous = UIApplication.shared.keyWindow
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = UIScreen.main.bounds
        let animations = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        let controller = UIViewController()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previous?.makeKeyAndVisible()
            UIView.setAnimationsEnabled(animations)
        }
        var sent = false
        WalletAccountCapability.preflightSend(from: controller, currentAccount: { account },
            capabilityProbe: { _, completion in completion(.invalidKeys) }) { sent = true }
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertFalse(sent)
        let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.message, WalletAccountCapability.State.invalidKeys.reason)
        XCTAssertTrue(alert.actions.contains { $0.title == WalletUX.text("Restore keys for this account") })
        await withCheckedContinuation { continuation in
            controller.dismiss(animated: false) { continuation.resume() }
        }
        var selected: AccountItem? = account
        var finish: ((WalletAccountCapability.State) -> Void)?
        WalletAccountCapability.preflightSend(from: controller, currentAccount: { selected },
            capabilityProbe: { _, completion in finish = completion }) { sent = true }
        selected = nil
        finish?(.signing)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertFalse(sent)
        selected = account
        WalletAccountCapability.preflightSend(from: controller, currentAccount: { selected },
            capabilityProbe: { _, completion in completion(.signing) }) { sent = true }
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(sent)
    }

    @MainActor
    func testRepairDriveSelectionDoesNotFetchAndImportPrefillUsesSecureFields() throws {
        let (prepared, keys, settings, gate) = try fixture()
        let controller = WalletCredentialRepairViewController(account: prepared.account,
            service: WalletCredentialRepair(keystore: keys, settings: settings, recoveryGate: gate,
                lifecycleCoordinator: WalletLifecycleCoordinator(recoveryGate: gate), activeSnapshot: { nil }),
            currentAccounts: { [prepared.account] }, onSuccess: { _ in XCTFail("Opening a screen cannot repair") }, startWithDrive: true)
        controller.loadViewIfNeeded()
        let controls = descendants(controller.view)
        let drive = try XCTUnwrap(controls.first { $0.accessibilityIdentifier == "wallet-repair-source-3" } as? UIButton)
        XCTAssertTrue(drive.accessibilityTraits.contains(.selected))
        let material = try XCTUnwrap(controls.first { $0.accessibilityIdentifier == "wallet-repair-material" } as? UITextView)
        XCTAssertTrue(material.isHidden)
        controller.setSuppliedMaterial(source: .seed, text: "public synthetic seed", derivationPath: "//public", backupPassword: "")
        let seed = try XCTUnwrap(controls.first { $0.accessibilityIdentifier == "wallet-repair-source-1" } as? UIButton)
        XCTAssertTrue(seed.accessibilityTraits.contains(.selected))
        XCTAssertFalse(drive.accessibilityTraits.contains(.selected))
        XCTAssertFalse(material.isHidden)
        XCTAssertTrue(material.isSecureTextEntry)
        XCTAssertEqual(material.text, "public synthetic seed")
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        XCTAssertTrue(material.text.isEmpty)
        XCTAssertFalse(try keys.checkKey(for: WalletCredentialRepair.pendingTag))
    }

    @MainActor
    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
}
