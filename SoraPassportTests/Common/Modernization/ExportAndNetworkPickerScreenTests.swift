// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0
import SoraFoundation
import IrohaCrypto
import SoraKeystore
import SSFUtils
import TweetNacl
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class ExportAndNetworkPickerScreenTests: XCTestCase {
    private func views<T: UIView>(_ type: T.Type, in view: UIView) -> [T] { ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { views(type, in: $0) } }
    private func export() -> (AccountExportViewController, ExportScreenPresenter, [InputField], SoramitsuButton) {
        let model = ExportScreenPresenter(); let view = AccountExportViewController(); view.presenter = model; view.localizationManager = LocalizationManager.shared; view.loadViewIfNeeded(); view.applyLocalization()
        return (view, model, views(InputField.self, in: view.view), views(SoramitsuButton.self, in: view.view)[0])
    }
    private func edit(_ fields: [InputField], first: String, second: String) {
        fields[0].sora.text = first; fields[0].textField.sendActions(for: .editingChanged); fields[1].sora.text = second; fields[1].textField.sendActions(for: .editingChanged)
    }
    func testExportStartsWithSecureEmptyInputsAndDisabledDownload() {
        let (view, _, fields, button) = export(); XCTAssertEqual(fields.count, 2); XCTAssertFalse(button.isEnabled)
        XCTAssertTrue(fields.allSatisfy { $0.textField.isSecureTextEntry && $0.textField.textContentType == .newPassword }); XCTAssertNotNil(view.navigationItem.title); XCTAssertFalse((button.sora.title ?? "").isEmpty)
    }
    func testExportValidatesBothPasswordsAndCanRecoverFromMismatch() {
        let (_, _, fields, button) = export(); edit(fields, first: "public fixture", second: "wrong")
        XCTAssertFalse(button.isEnabled); XCTAssertEqual(fields[1].sora.state, .fail); XCTAssertFalse((fields[1].sora.descriptionLabelText ?? "").isEmpty)
        edit(fields, first: "public fixture", second: "public fixture"); XCTAssertTrue(button.isEnabled); XCTAssertEqual(fields[1].sora.state, .success); XCTAssertEqual(fields[1].sora.descriptionLabelText, "")
        edit(fields, first: "", second: ""); XCTAssertFalse(button.isEnabled)
    }
    func testExportActionRejectsEmptyOrMismatchingCurrentInputs() {
        let (view, model, fields, _) = export(); view.downloadTapped(); edit(fields, first: "one", second: "two"); view.downloadTapped(); XCTAssertTrue(model.passwords.isEmpty)
    }
    func testExportActionPassesTheExactMatchingPasswordToItsPresenter() {
        let (view, model, fields, _) = export(); edit(fields, first: " public fixture ", second: " public fixture "); view.downloadTapped(); XCTAssertEqual(model.passwords, [" public fixture "])
    }
    func testExportExplainsAndRefusesShortRepeatedSequentialAndCommonPasswords() {
        let (view, model, fields, button) = export()
        XCTAssertEqual(fields[0].sora.descriptionLabelText, R.string.localizable.backupPasswordPolicyRequirements(preferredLanguages: view.localizationManager?.preferredLocalizations))
        let refused: [(String, BackupPasswordPolicy.Violation)] = [("fixture-pas", .tooShort), ("bbbbbbbbbbbb", .repeatedCharacter), ("abcdefghijkl", .sequence), ("qwerty123456", .commonPassword)]
        for (password, violation) in refused {
            edit(fields, first: password, second: password); view.downloadTapped()
            XCTAssertFalse(button.isEnabled, password); XCTAssertEqual(fields[0].sora.state, .fail, password)
            XCTAssertEqual(fields[0].sora.descriptionLabelText, BackupPasswordPolicy.guidance(for: violation, preferredLanguages: view.localizationManager?.preferredLocalizations), password)
        }
        XCTAssertTrue(model.passwords.isEmpty)
        edit(fields, first: "fixture-pass", second: "fixture-pass"); XCTAssertTrue(button.isEnabled); XCTAssertEqual(fields[0].sora.state, .success)
        XCTAssertEqual(fields[0].sora.descriptionLabelText, BackupPasswordPolicy.guidance(for: nil, preferredLanguages: view.localizationManager?.preferredLocalizations))
        view.downloadTapped(); XCTAssertEqual(model.passwords, ["fixture-pass"])
    }
    func testExportPresenterOnlySharesTheReturnedFileAndDoesNotGenerateAnotherOne() {
        let presenter = AccountExportPresenter(); let source = ExportScreenSource(); let route = ExportScreenRoute(); presenter.interactor = source; presenter.wireframe = route
        source.url = NSURL(fileURLWithPath: "/tmp/sora-fixture-export.json"); presenter.exportWith(password: "fixture")
        XCTAssertEqual(source.passwords, ["fixture"]); XCTAssertEqual(route.urls, [source.url!])
    }
    func testExportPresenterDoesNotShareWhenEncryptionFails() {
        let presenter = AccountExportPresenter(); let source = ExportScreenSource(); let route = ExportScreenRoute(); presenter.interactor = source; presenter.wireframe = route
        presenter.exportWith(password: "fixture"); XCTAssertEqual(source.passwords, ["fixture"]); XCTAssertTrue(route.urls.isEmpty)
    }
    func testPasswordChoiceRendersAndClearsItsSelectionIndicator() {
        let view = PasswordView(title: "Use fixture password"); XCTAssertTrue(views(UILabel.self, in: view).contains { $0.text == "Use fixture password" })
        view.isSelected = true; XCTAssertTrue(views(UIImageView.self, in: view).contains { $0.image != nil })
        view.isSelected = false; XCTAssertTrue(views(UIImageView.self, in: view).allSatisfy { $0.image == nil })
    }
    private func choice(_ network: NetworkId, available: Bool = true, balance: String? = "12") -> WalletNetworkChoice {
        let account = NetworkAccount(walletId: "fixture", networkId: network, derivationVersion: 1, publicKey: Data(repeating: 1, count: 32), address: "0123456789ABCDEFGHIJKLMNOPQRSTUV")
        return WalletNetworkChoice(account: account, network: WalletNetworkDirectory.current.info(network), tag: WalletNetworkDirectory.current.tag(for: network, main: .sora2), balance: balance, unavailableReason: available ? nil : "Read only")
    }
    func testNetworkPickerRendersEveryAddressBalanceAndNetworkTag() throws {
        let choices = [choice(.sora2), choice(.minamoto), choice(.taira)]
        let view = WalletNetworkPickerViewController(action: .receive, choices: choices, onPick: { _ in XCTFail("No selection") }); view.loadViewIfNeeded()
        XCTAssertEqual(view.numberOfSections(in: view.tableView), 1); XCTAssertEqual(view.tableView(view.tableView, numberOfRowsInSection: 0), 3)
        for (index, expected) in choices.enumerated() {
            let cell = view.tableView(view.tableView, cellForRowAt: IndexPath(row: index, section: 0)); let content = try XCTUnwrap(cell.contentConfiguration as? UIListContentConfiguration)
            XCTAssertEqual(content.text, expected.network.name); XCTAssertTrue(content.secondaryText?.contains("0123456789…OPQRSTUV") == true)
            XCTAssertTrue(content.secondaryText?.contains(expected.network.isLive ? "12 XOR" : WalletUX.text("Address ready")) == true)
            XCTAssertEqual(cell.accessoryView?.accessibilityLabel, expected.tag?.title); XCTAssertEqual(cell.accessibilityIdentifier, "wallet.network-choice.\(expected.network.id.rawValue)")
        }
    }
    func testUnavailableNetworkCannotBeSelectedAndHasDisabledAccessibility() throws {
        var selections = 0; let view = WalletNetworkPickerViewController(action: .send, choices: [choice(.taira, available: false)], onPick: { _ in selections += 1 }); view.loadViewIfNeeded()
        let index = IndexPath(row: 0, section: 0); let cell = view.tableView(view.tableView, cellForRowAt: index)
        XCTAssertEqual(cell.selectionStyle, .none); XCTAssertTrue(cell.accessibilityTraits.contains(.notEnabled)); view.tableView(view.tableView, willDisplay: cell, forRowAt: index)
        XCTAssertEqual(cell.accessoryView?.alpha, 0.5); XCTAssertTrue((cell.contentConfiguration as? UIListContentConfiguration)?.secondaryText?.contains("Read only") == true)
        view.tableView(view.tableView, didSelectRowAt: index); XCTAssertEqual(selections, 0)
    }
    func testReceiveAndSendPickerExplainTheCorrectAddressDirection() {
        for action in [WalletNetworkAction.receive, .send] {
            let view = WalletNetworkPickerViewController(action: action, choices: [], onPick: { _ in XCTFail("No selection") }); view.loadViewIfNeeded()
            XCTAssertEqual(view.tableView.accessibilityIdentifier, action == .receive ? "wallet.network-picker.receive" : "wallet.network-picker.send")
            XCTAssertEqual(view.title, WalletUX.text(action == .receive ? "Receive on" : "Send on")); XCTAssertNotNil(view.navigationItem.rightBarButtonItem)
            XCTAssertFalse((view.tableView(view.tableView, titleForFooterInSection: 0) ?? "").isEmpty); XCTAssertEqual(view.tableView(view.tableView, numberOfRowsInSection: 0), 0)
        }
    }
    func testUnknownBalanceIsOmittedWithoutInventingAZero() throws {
        let view = WalletNetworkPickerViewController(action: .receive, choices: [choice(.sora2, balance: nil)], onPick: { _ in }); view.loadViewIfNeeded()
        let cell = view.tableView(view.tableView, cellForRowAt: IndexPath(row: 0, section: 0)); let content = try XCTUnwrap(cell.contentConfiguration as? UIListContentConfiguration)
        XCTAssertEqual(content.secondaryText, "0123456789…OPQRSTUV"); XCTAssertFalse(cell.accessibilityTraits.contains(.notEnabled))
    }
    func testAddressAbbreviationUsesCharactersAndKeepsShortAddressesUnchanged() {
        XCTAssertEqual(WalletNetworkAccounts.shortAddress("short"), "short"); let short = String(repeating: "a", count: 24); XCTAssertEqual(WalletNetworkAccounts.shortAddress(short), short)
        let value = String(repeating: "🙂", count: 30); XCTAssertEqual(WalletNetworkAccounts.shortAddress(value), String(repeating: "🙂", count: 10) + "…" + String(repeating: "🙂", count: 8))
    }
    func testNetworkTagsHaveAccessibleTitlesAndPositiveIntrinsicSizes() {
        for tag in [WalletNetworkTag.main, .comingSoon, .testnet] { let view = WalletNetworkTagView(networkTag: tag); view.sizeToContent(); XCTAssertEqual(view.accessibilityLabel, tag.title); XCTAssertTrue(view.isAccessibilityElement); XCTAssertGreaterThan(view.bounds.width, 0); XCTAssertGreaterThan(view.bounds.height, 0) }
    }
}
private final class ExportScreenPresenter: AccountExportPresenterProtocol { var passwords: [String] = []; func exportWith(password: String) { passwords.append(password) } }
private final class ExportScreenSource: AccountExportInteractorInputProtocol { var passwords: [String] = []; var url: NSURL?; func exportToFileWith(password: String) -> NSURL? { passwords.append(password); return url } }
private final class ExportScreenRoute: AccountExportWireframeProtocol { var urls: [NSURL] = []; func showShareFile(url: NSURL, in viewController: AccountExportViewProtocol?) { urls.append(url) } }
private final class ExportShareHost: UIViewController, AccountExportViewProtocol {
    var shown = [UIViewController]()
    override func present(_ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)? = nil) { shown.append(viewControllerToPresent); completion?() }
}

final class AccountExportFileBoundaryTests: XCTestCase {
    private let exportPassword = "public fixture"
    private func exportStore() throws -> AccountExportFileStore {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return AccountExportFileStore(temporaryDirectory: root)
    }
    private func accounts(_ count: Int = 2) throws -> (InMemoryKeychain, InMemorySettingsManager, [AccountItem]) {
        let keys = InMemoryKeychain(), settings = InMemorySettingsManager(); var accounts: [AccountItem] = []
        for index in 0..<count {
            try AccountCreationHelper.createAccountFromSeed("0x" + String(repeating: String(format: "%02x", index + 7), count: 32),
                cryptoType: .ed25519, name: "Public fixture \(index)", keychain: keys, settings: settings)
            accounts.append(try XCTUnwrap(settings.currentAccount))
        }
        return (keys, settings, accounts)
    }
    private func interactor(_ keys: InMemoryKeychain, _ settings: InMemorySettingsManager, _ accounts: [AccountItem],
                            _ store: AccountExportFileStore = AccountExportFileStore()) -> AccountExportInteractor {
        AccountExportInteractor(keystore: keys, settings: settings, accounts: accounts, fileStore: store)
    }
    private func decodeBatch(_ data: Data, password: String?) throws -> (EncodedAccounts, [KeystoreDefinition]) {
        let envelope = try JSONDecoder().decode(EncodedAccounts.self, from: data)
        let bytes = try XCTUnwrap(Data(base64Encoded: envelope.encoded)), parameters = try SoraPassport.ScryptParameters(data: bytes)
        XCTAssertEqual(parameters.scryptN, 32768); XCTAssertEqual(parameters.scryptP, 1); XCTAssertEqual(parameters.scryptR, 8)
        let key = try IRScryptKeyDeriviation().deriveKey(from: Data((password ?? "").utf8), salt: parameters.salt,
            scryptN: UInt(parameters.scryptN), scryptP: UInt(parameters.scryptP), scryptR: UInt(parameters.scryptR), length: 32)
        let nonceStart = SoraPassport.ScryptParameters.encodedLength, payloadStart = nonceStart + 24
        let opened = try NaclSecretBox.open(box: Data(bytes.dropFirst(payloadStart)), nonce: Data(bytes[nonceStart..<payloadStart]), key: key)
        return (envelope, try JSONDecoder().decode([KeystoreDefinition].self, from: opened))
    }
    private func assertRestores(_ definitions: [KeystoreDefinition], accounts: [AccountItem], password: String) throws {
        XCTAssertEqual(definitions.count, accounts.count)
        for (definition, expected) in zip(definitions, accounts) {
            let keys = InMemoryKeychain(), settings = InMemorySettingsManager()
            try AccountCreationHelper.createAccountFromKeystoreData(JSONEncoder().encode(definition), password: password,
                keychain: keys, settings: settings, networkType: .sora, cryptoType: .ed25519, username: expected.username)
            XCTAssertEqual(settings.currentAccount?.address, expected.address)
            XCTAssertEqual(settings.currentAccount?.publicKeyData, expected.publicKeyData)
        }
    }
    func testEmptyExportDoesNotCreateAFile() {
        XCTAssertNil(interactor(InMemoryKeychain(), InMemorySettingsManager(), []).exportToFileWith(password: exportPassword))
    }
    func testSingleAccountFileCanRestoreTheSamePublicIdentity() throws {
        let (keys, settings, values) = try accounts(1), expected = values[0]
        let url = try XCTUnwrap(interactor(keys, settings, values).exportToFileWith(password: exportPassword)) as URL
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(url.lastPathComponent, expected.address + ".json")
        let definition = try JSONDecoder().decode(KeystoreDefinition.self, from: Data(contentsOf: url))
        try assertRestores([definition], accounts: values, password: exportPassword)
    }
    func testBatchFileContainsOrderedMetadataAndIndividuallyRestorableAccounts() throws {
        let (keys, settings, values) = try accounts()
        let url = try XCTUnwrap(interactor(keys, settings, values).exportToFileWith(password: exportPassword)) as URL
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertTrue(url.lastPathComponent.hasPrefix("batch_exported_account_")); XCTAssertEqual(url.pathExtension, "json")
        let (envelope, definitions) = try decodeBatch(Data(contentsOf: url), password: exportPassword)
        XCTAssertEqual(envelope.accounts.map(\.address), values.map(\.address)); XCTAssertEqual(envelope.accounts.map(\.meta.name), values.map(\.username))
        XCTAssertTrue(envelope.accounts.allSatisfy { !$0.meta.genesisHash.isEmpty && $0.meta.whenCreated == 0 })
        XCTAssertEqual(envelope.encoding.content, ["batch-pkcs8"]); XCTAssertEqual(envelope.encoding.version, "3")
        try assertRestores(definitions, accounts: values, password: exportPassword)
    }
    func testExportIsProtectedExcludedFromBackupAndKeptOutOfDocuments() throws {
        let (keys, settings, values) = try accounts(1), store = try exportStore()
        let url = try XCTUnwrap(interactor(keys, settings, values, store).exportToFileWith(password: exportPassword)) as URL
        XCTAssertEqual(url.lastPathComponent, values[0].address + ".json")
        XCTAssertEqual(url.deletingLastPathComponent().standardizedFileURL.path, store.directory.standardizedFileURL.path)
        XCTAssertEqual(try FileProtectionMetadata.protectionClass(at: url, fileManager: .default), .complete)
        for item in [url, store.directory] {
            XCTAssertEqual(try URL(fileURLWithPath: item.path).resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true, item.lastPathComponent)
        }
        let documents = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        let production = AccountExportFileStore().directory
        XCTAssertEqual(production.deletingLastPathComponent().standardizedFileURL.path, FileManager.default.temporaryDirectory.standardizedFileURL.path)
        XCTAssertFalse(production.standardizedFileURL.path.hasPrefix(documents.standardizedFileURL.path))
    }
    func testStaleExportIsRemovedWhenTheScreenOpensAndBeforeTheNextExport() throws {
        let (keys, settings, values) = try accounts(1), store = try exportStore()
        func leaveStaleExport() throws -> URL {
            try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
            let url = store.directory.appendingPathComponent("batch_exported_account_0.json")
            try Data("public fixture".utf8).write(to: url); return url
        }
        let beforeOpening = try leaveStaleExport(), exporter = interactor(keys, settings, values, store)
        XCTAssertFalse(FileManager.default.fileExists(atPath: beforeOpening.path))
        let beforeExport = try leaveStaleExport()
        let url = try XCTUnwrap(exporter.exportToFileWith(password: exportPassword)) as URL
        XCTAssertFalse(FileManager.default.fileExists(atPath: beforeExport.path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: store.directory.path), [url.lastPathComponent])
    }
    func testExportRefusesWeakPasswordsBeforeWritingAnything() throws {
        let (keys, settings, values) = try accounts(), store = try exportStore()
        for exporter in [interactor(keys, settings, values, store), interactor(keys, settings, [values[0]], store)] {
            for password in ["fixture", "123456", "fixture-pas", "aaaaaaaaaaaa", "123456789012", "abcdefghijkl", "password1234"] {
                XCTAssertNil(exporter.exportToFileWith(password: password), password)
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.directory.path))
    }
    func testShortLegacyPasswordsStillImportExistingJSONExportsAndDriveBackups() throws {
        // Files made under the old six-character rule must stay importable:
        // the creation policy is never applied on import or restore.
        let legacy = "123456"; XCTAssertEqual(BackupPasswordPolicy.violation(for: legacy), .tooShort)
        let (keys, _, values) = try accounts(), wrapper = KeystoreExportWrapper(keystore: keys)
        let single = try wrapper.export(account: values[0], password: legacy)
        try assertRestores([JSONDecoder().decode(KeystoreDefinition.self, from: single)], accounts: [values[0]], password: legacy)
        try assertRestores(decodeBatch(wrapper.export(accounts: values, password: legacy), password: legacy).1, accounts: values, password: legacy)
        // A Google Drive backup carries the same JSON; restore opens it with the legacy password.
        let driveJSON = try XCTUnwrap(String(data: single, encoding: .utf8))
        XCTAssertFalse(try WalletCloudBackupRecoveryService.extractJSONSecret(driveJSON, password: legacy, account: values[0]).isEmpty)
        XCTAssertThrowsError(try WalletCloudBackupRecoveryService.extractJSONSecret(driveJSON, password: "1234567", account: values[0]))
    }
    func testPasswordlessBatchUsesTheDocumentedEmptyPasswordAndKeepsEveryAccount() throws {
        let (keys, _, values) = try accounts()
        let data = try KeystoreExportWrapper(keystore: keys).export(accounts: values, password: nil)
        let (envelope, definitions) = try decodeBatch(data, password: nil)
        XCTAssertEqual(envelope.accounts.map(\.address), values.map(\.address)); try assertRestores(definitions, accounts: values, password: "")
    }
    func testBatchEncryptionAuthenticatesThePasswordAndRandomizesTheCiphertext() throws {
        let (keys, _, values) = try accounts(1), wrapper = KeystoreExportWrapper(keystore: keys)
        let first = try wrapper.export(accounts: values, password: "fixture"), second = try wrapper.export(accounts: values, password: "fixture")
        XCTAssertNotEqual(first, second); XCTAssertThrowsError(try decodeBatch(first, password: "wrong"))
        XCTAssertEqual(try decodeBatch(first, password: "fixture").0.accounts.map(\.address), values.map(\.address))
    }
    func testSingleAccountWithNoRecoverableMaterialCannotExportAFile() throws {
        let (_, settings, values) = try accounts(1)
        XCTAssertNil(interactor(InMemoryKeychain(), settings, values).exportToFileWith(password: exportPassword))
    }
    func testBatchFailsAsAWholeWhenOneAccountHasNoRecoverableMaterial() throws {
        let (keys, settings, values) = try accounts()
        for tag in try keys.allKeyIdentifiers() where tag.contains(values[1].address) { try keys.deleteKey(for: tag) }
        XCTAssertNil(interactor(keys, settings, values).exportToFileWith(password: exportPassword))
    }
    func testExportPreservesTheSourceSecretsByteForByte() throws {
        let (keys, _, values) = try accounts(); let tags = try keys.allKeyIdentifiers()
        let before = try Dictionary(uniqueKeysWithValues: tags.map { ($0, try keys.fetchKey(for: $0)) })
        _ = try KeystoreExportWrapper(keystore: keys).export(accounts: values, password: "fixture")
        XCTAssertEqual(Set(try keys.allKeyIdentifiers()), Set(tags))
        for (tag, bytes) in before { XCTAssertEqual(try keys.fetchKey(for: tag), bytes) }
    }
    func testFileWriterReportsAnUnavailableSubdirectoryWithoutCreatingIt() throws {
        let store = try exportStore(), nested = UUID().uuidString
        for name in [nested + "/fixture.json", "..", ".", ""] {
            XCTAssertThrowsError(try store.write(Data("public fixture".utf8), name: name), name)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.directory.appendingPathComponent(nested).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.directory.path))
    }
    func testExportFileStoreReplacesItsExportAndRemovesOnlyItsOwnFiles() throws {
        let store = try exportStore(), outside = store.directory.deletingLastPathComponent().appendingPathComponent("outside.json")
        try Data("public fixture".utf8).write(to: outside)
        let first = try store.write(Data("first public fixture".utf8), name: "first.json")
        XCTAssertEqual(try Data(contentsOf: first), Data("first public fixture".utf8))
        XCTAssertEqual(try FileProtectionMetadata.protectionClass(at: first, fileManager: .default), .complete)
        XCTAssertEqual(try URL(fileURLWithPath: first.path).resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        let second = try store.write(Data("second public fixture".utf8), name: "second.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path)); XCTAssertTrue(FileManager.default.fileExists(atPath: second.path))
        store.remove(outside); XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
        store.remove(second); XCTAssertFalse(FileManager.default.fileExists(atPath: second.path))
        _ = try store.write(Data("third public fixture".utf8), name: "third.json"); store.removeAll()
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.directory.path)); XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
    }
    @MainActor
    func testFinishingTheShareSheetRemovesTheExportWhetherSharedOrCancelled() throws {
        let store = try exportStore(), route = AccountExportWireframe(localizationManager: LocalizationManager.shared, fileStore: store)
        for completed in [false, true] {
            let url = try store.write(Data("public fixture".utf8), name: "fixture.json"), host = ExportShareHost()
            route.showShareFile(url: url as NSURL, in: host)
            let activity = try XCTUnwrap(host.shown.last as? UIActivityViewController); XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            activity.completionWithItemsHandler?(completed ? UIActivity.ActivityType.copyToPasteboard : nil, completed, nil, nil)
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "completed: \(completed)")
        }
        let unshown = try store.write(Data("public fixture".utf8), name: "fixture.json")
        route.showShareFile(url: unshown as NSURL, in: nil); XCTAssertFalse(FileManager.default.fileExists(atPath: unshown.path))
    }
}

extension AccountExportFileBoundaryTests {
    @MainActor
    private func rawSeedFixture(keys: InMemoryKeychain? = nil) throws -> (AccountExportRawSeedInteractor, RawSeedExportOutput, InMemoryKeychain, AccountItem) {
        let (generatedKeys, settings, accounts) = try accounts(1)
        let source = keys ?? generatedKeys
        let output = RawSeedExportOutput()
        let interactor = AccountExportRawSeedInteractor(keystore: source, settings: settings, account: accounts[0])
        interactor.presenter = output
        return (interactor, output, source, accounts[0])
    }
    @MainActor
    func testRawSeedExportReadsTheExactProvenSeedWithoutChangingStoredKeys() throws {
        let (interactor, output, keys, _) = try rawSeedFixture()
        let tags = try keys.allKeyIdentifiers()
        let before = try Dictionary(uniqueKeysWithValues: tags.map { ($0, try keys.fetchKey(for: $0)) })
        interactor.exportRawSeed()
        XCTAssertEqual(output.values.map(\.0), ["0x" + String(repeating: "07", count: 32)])
        XCTAssertEqual(output.values.map(\.1), [""])
        XCTAssertEqual(Set(try keys.allKeyIdentifiers()), Set(tags))
        for (tag, bytes) in before { XCTAssertEqual(try keys.fetchKey(for: tag), bytes) }
    }
    @MainActor
    func testRawSeedCopyBeforeExportLeavesTheClipboardUntouched() throws {
        let original = UIPasteboard.general.items
        defer { UIPasteboard.general.items = original }
        UIPasteboard.general.string = "Public clipboard fixture"
        let (interactor, output, _, _) = try rawSeedFixture()
        interactor.copyRawSeedToClipboard()
        XCTAssertEqual(UIPasteboard.general.string, "Public clipboard fixture")
        XCTAssertTrue(output.values.isEmpty)
    }
    @MainActor
    func testRawSeedCopyUsesOnlyTheSuccessfullyExportedSeed() throws {
        let original = UIPasteboard.general.items
        defer { UIPasteboard.general.items = original }
        let (interactor, output, _, _) = try rawSeedFixture()
        interactor.exportRawSeed(); interactor.copyRawSeedToClipboard()
        XCTAssertEqual(UIPasteboard.general.string, output.values.last?.0)
    }
    @MainActor
    func testRawSeedExportWithMissingMaterialPublishesOnlyEmptyValues() throws {
        let (interactor, output, _, _) = try rawSeedFixture(keys: InMemoryKeychain())
        interactor.exportRawSeed()
        XCTAssertEqual(output.values.count, 1)
        XCTAssertEqual(output.values.first?.0, ""); XCTAssertEqual(output.values.first?.1, "")
    }
    @MainActor
    func testRawSeedExportRejectsASeedThatDoesNotMatchTheAccount() throws {
        let (interactor, output, keys, account) = try rawSeedFixture()
        try keys.saveKey(Data(repeating: 8, count: 32), with: KeystoreTag.seedTagForAddress(account.address))
        interactor.exportRawSeed()
        XCTAssertEqual(output.values.first?.0, ""); XCTAssertEqual(output.values.first?.1, "")
    }
    @MainActor
    func testFailedSecondExportClearsThePreviouslyCopyableSeed() throws {
        let original = UIPasteboard.general.items
        defer { UIPasteboard.general.items = original }
        let (interactor, output, keys, _) = try rawSeedFixture()
        interactor.exportRawSeed()
        for tag in try keys.allKeyIdentifiers() { try keys.deleteKey(for: tag) }
        interactor.exportRawSeed()
        XCTAssertEqual(output.values.count, 2); XCTAssertEqual(output.values.last?.0, "")
        UIPasteboard.general.string = "Public clipboard fixture"
        interactor.copyRawSeedToClipboard()
        XCTAssertEqual(UIPasteboard.general.string, "Public clipboard fixture")
    }
    @MainActor
    func testRawSeedPresenterDrivesTheRealInteractorAndForwardsItsValues() throws {
        let (interactor, _, _, _) = try rawSeedFixture()
        let view = RawSeedExportView(), presenter = AccountExportRawSeedPresenter()
        presenter.view = view; presenter.interactor = interactor; interactor.presenter = presenter
        presenter.exportRawSeed()
        XCTAssertEqual(view.values.map(\.0), ["0x" + String(repeating: "07", count: 32)])
        XCTAssertEqual(view.values.map(\.1), [""])
    }
    @MainActor
    func testRawSeedPresenterCopiesOnlyThroughTheInteractor() throws {
        let original = UIPasteboard.general.items
        defer { UIPasteboard.general.items = original }
        let (interactor, output, _, _) = try rawSeedFixture()
        let presenter = AccountExportRawSeedPresenter(); presenter.interactor = interactor
        presenter.exportRawSeed(); presenter.copyRawSeed()
        XCTAssertEqual(UIPasteboard.general.string, output.values.last?.0)
    }
    @MainActor
    func testRawSeedPresenterRequestsJsonOnlyWhenTheUserChoosesIt() {
        let presenter = AccountExportRawSeedPresenter(); var calls = 0
        presenter.exportJSON()
        presenter.exportJSONAction = { calls += 1 }
        XCTAssertEqual(calls, 0); presenter.exportJSON(); XCTAssertEqual(calls, 1)
    }
}
private final class RawSeedExportOutput: AccountExportRawSeedInteractorOutputProtocol {
    var values = [(String, String)]()
    func set(rawSeed: String, derivationPath: String) { values.append((rawSeed, derivationPath)) }
}
@MainActor private final class RawSeedExportView: UIViewController, AccountExportRawSeedViewProtocol {
    var values = [(String, String)]()
    func set(rawSeed: String, derivationPath: String) { values.append((rawSeed, derivationPath)) }
}
