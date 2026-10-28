// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0
import SoraFoundation
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
        let (_, _, fields, button) = export(); edit(fields, first: "fixture", second: "wrong")
        XCTAssertFalse(button.isEnabled); XCTAssertEqual(fields[1].sora.state, .fail); XCTAssertFalse((fields[1].sora.descriptionLabelText ?? "").isEmpty)
        edit(fields, first: "fixture", second: "fixture"); XCTAssertTrue(button.isEnabled); XCTAssertEqual(fields[1].sora.state, .success); XCTAssertEqual(fields[1].sora.descriptionLabelText, "")
        edit(fields, first: "", second: ""); XCTAssertFalse(button.isEnabled)
    }
    func testExportActionRejectsEmptyOrMismatchingCurrentInputs() {
        let (view, model, fields, _) = export(); view.downloadTapped(); edit(fields, first: "one", second: "two"); view.downloadTapped(); XCTAssertTrue(model.passwords.isEmpty)
    }
    func testExportActionPassesTheExactMatchingPasswordToItsPresenter() {
        let (view, model, fields, _) = export(); edit(fields, first: " fixture ", second: " fixture "); view.downloadTapped(); XCTAssertEqual(model.passwords, [" fixture "])
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
