// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0
import Combine
import SoraFoundation
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class CredentialAndQRCodeScreenTests: XCTestCase {
    private var language = "en"
    private var subscriptions = Set<AnyCancellable>()
    override func setUp() { super.setUp(); language = LocalizationManager.shared.selectedLocalization; LocalizationManager.shared.selectedLocalization = "en" }
    override func tearDown() { subscriptions.removeAll(); LocalizationManager.shared.selectedLocalization = language; super.tearDown() }
    private func descendants<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { descendants(type, in: $0) }
    }
    private func settle() async { try? await Task.sleep(nanoseconds: 30_000_000) }
    private func model() -> (SetupPasswordItem, PassthroughSubject<SetupPasswordItem.Input, Never>) {
        let item = SetupPasswordItem(); let events = PassthroughSubject<SetupPasswordItem.Input, Never>()
        item.transform(input: events.eraseToAnyPublisher()).sink { _ in }.store(in: &subscriptions)
        return (item, events)
    }
    func testSetupPasswordRequiresLengthMatchingAndAcknowledgement() {
        let (item, events) = model(); XCTAssertFalse(item.isButtonEnable)
        events.send(.passwordChanged("12345")); events.send(.confirmPasswordChanged("12345")); events.send(.checkViewChanged(true)); XCTAssertFalse(item.isButtonEnable)
        events.send(.passwordChanged("123456")); XCTAssertFalse(item.isButtonEnable)
        events.send(.confirmPasswordChanged("123456")); XCTAssertTrue(item.isButtonEnable)
        events.send(.checkViewChanged(false)); XCTAssertFalse(item.isButtonEnable)
    }
    func testSetupPasswordClearingEitherFieldRevokesReadinessImmediately() {
        let (item, events) = model(); events.send(.passwordChanged("fixture")); events.send(.confirmPasswordChanged("fixture")); events.send(.checkViewChanged(true))
        XCTAssertTrue(item.isButtonEnable); events.send(.passwordChanged("")); XCTAssertFalse(item.isButtonEnable)
        events.send(.passwordChanged("fixture")); XCTAssertTrue(item.isButtonEnable); events.send(.confirmPasswordChanged("")); XCTAssertFalse(item.isButtonEnable)
    }
    func testSetupPasswordRejectsSubmissionWhileInvalid() {
        let (item, events) = model(); var submitted: [String] = []; item.setupPasswordButtonTapped = { submitted.append($0) }
        events.send(.setupPasswordButtonTapped); events.send(.passwordChanged("short")); events.send(.setupPasswordButtonTapped)
        XCTAssertTrue(submitted.isEmpty)
    }
    func testSetupPasswordSubmitsExactlyTheValidatedText() {
        let (item, events) = model(); var submitted: [String] = []; item.setupPasswordButtonTapped = { submitted.append($0) }
        events.send(.passwordChanged(" fixture ")); events.send(.confirmPasswordChanged(" fixture ")); events.send(.checkViewChanged(true)); events.send(.setupPasswordButtonTapped)
        XCTAssertEqual(submitted, [" fixture "])
    }
    func testReplacingThePasswordInputStreamDisconnectsThePreviousStream() {
        let (item, old) = model(); let current = PassthroughSubject<SetupPasswordItem.Input, Never>()
        item.transform(input: current.eraseToAnyPublisher()).sink { _ in }.store(in: &subscriptions)
        current.send(.passwordChanged("fixture")); current.send(.confirmPasswordChanged("fixture")); current.send(.checkViewChanged(true))
        XCTAssertTrue(item.isButtonEnable); old.send(.passwordChanged("")); XCTAssertTrue(item.isButtonEnable)
    }
    func testAttachingAPreviouslyValidatedModelToANewCellClearsTheOldSecret() async throws {
        let (item, events) = model(); var submitted: [String] = []; item.setupPasswordButtonTapped = { submitted.append($0) }
        events.send(.passwordChanged("old-secret")); events.send(.confirmPasswordChanged("old-secret")); events.send(.checkViewChanged(true)); XCTAssertTrue(item.isButtonEnable)
        let cell = SetupPasswordCell(style: .default, reuseIdentifier: nil); cell.set(item: item, context: nil); await settle()
        XCTAssertTrue(descendants(InputField.self, in: cell).allSatisfy { ($0.textField.text ?? "").isEmpty })
        XCTAssertFalse(item.isButtonEnable); XCTAssertFalse(cell.continueButton.isEnabled)
        cell.continueButton.sendActions(for: .touchUpInside); XCTAssertTrue(submitted.isEmpty)
    }
    private func fill(_ cell: SetupPasswordCell, password: String = "fixture") async throws {
        let fields = descendants(InputField.self, in: cell); XCTAssertEqual(fields.count, 2)
        for field in fields { field.textField.text = password; field.textField.sendActions(for: .editingChanged) }
        try XCTUnwrap(descendants(CheckView.self, in: cell).first).onActivate?(); await settle()
    }
    func testPasswordCellProtectsBothInputsAndShowsValidation() async throws {
        let cell = SetupPasswordCell(style: .default, reuseIdentifier: nil); let item = SetupPasswordItem(); cell.set(item: item, context: nil)
        let fields = descendants(InputField.self, in: cell); XCTAssertEqual(fields.count, 2)
        XCTAssertTrue(fields.allSatisfy { $0.textField.isSecureTextEntry && $0.textField.autocorrectionType == .no })
        try await fill(cell)
        XCTAssertTrue(cell.continueButton.isEnabled)
        XCTAssertTrue(fields.allSatisfy { $0.sora.state == .success })
        fields[1].textField.text = "wrong"; fields[1].textField.sendActions(for: .editingChanged); await settle()
        XCTAssertFalse(cell.continueButton.isEnabled); XCTAssertEqual(fields[1].sora.state, .fail)
    }
    func testRebindingPasswordCellCannotSubmitThroughTheOldModel() async throws {
        let cell = SetupPasswordCell(style: .default, reuseIdentifier: nil); let old = SetupPasswordItem(); let current = SetupPasswordItem()
        var oldSubmissions = 0; var currentSubmissions = 0; old.setupPasswordButtonTapped = { _ in oldSubmissions += 1 }; current.setupPasswordButtonTapped = { _ in currentSubmissions += 1 }
        cell.set(item: old, context: nil); cell.set(item: current, context: nil); try await fill(cell)
        cell.continueButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(oldSubmissions, 0); XCTAssertEqual(currentSubmissions, 1)
    }
    func testRebindingTheSamePasswordModelDoesNotDuplicateSubmit() async throws {
        let cell = SetupPasswordCell(style: .default, reuseIdentifier: nil); let item = SetupPasswordItem(); var submitted = 0; item.setupPasswordButtonTapped = { _ in submitted += 1 }
        cell.set(item: item, context: nil); cell.set(item: item, context: nil); try await fill(cell); cell.continueButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(submitted, 1)
    }
    func testNewPasswordModelClearsThePreviousSecretAndAcknowledgement() async throws {
        let cell = SetupPasswordCell(style: .default, reuseIdentifier: nil); let old = SetupPasswordItem(); let current = SetupPasswordItem()
        cell.set(item: old, context: nil); try await fill(cell); cell.set(item: current, context: nil); await settle()
        XCTAssertTrue(descendants(InputField.self, in: cell).allSatisfy { ($0.textField.text ?? "").isEmpty })
        XCTAssertFalse(try XCTUnwrap(descendants(CheckView.self, in: cell).first).isSelected); XCTAssertFalse(cell.continueButton.isEnabled)
    }
    func testEnterPasswordCellRebindingClearsThePreviousError() throws {
        let cell = EnterPasswordCell(style: .default, reuseIdentifier: nil)
        let failed = EnterPasswordItem(accountName: "Old", accountAddress: "address-one", errorText: "wrong", continueButtonHandler: nil)
        let fresh = EnterPasswordItem(accountName: "New", accountAddress: "address-two", errorText: "", continueButtonHandler: nil)
        cell.set(item: failed, context: nil); let field = try XCTUnwrap(descendants(InputField.self, in: cell).first); XCTAssertEqual(field.sora.state, .fail)
        cell.set(item: fresh, context: nil); XCTAssertEqual(field.sora.state, .default); XCTAssertTrue((field.sora.descriptionLabelText ?? "").isEmpty)
        let account = try XCTUnwrap(descendants(AccountView.self, in: cell).first); XCTAssertEqual(account.accountTitle.text, "New"); XCTAssertEqual(account.accountAddress.text, "address-two")
    }
    func testEnterPasswordUsesOnlyCurrentAccountAndPreservesEnteredWhitespace() throws {
        let cell = EnterPasswordCell(style: .default, reuseIdentifier: nil); var oldCalls = 0; var submissions: [String] = []
        let old = EnterPasswordItem(accountName: "Old", accountAddress: "one", errorText: "", continueButtonHandler: { _ in oldCalls += 1 })
        let current = EnterPasswordItem(accountAddress: "two", errorText: "", continueButtonHandler: { submissions.append($0) })
        cell.set(item: old, context: nil); cell.set(item: current, context: nil)
        let field = try XCTUnwrap(descendants(InputField.self, in: cell).first); XCTAssertTrue(field.textField.isSecureTextEntry); field.textField.text = " fixture "
        try XCTUnwrap(descendants(SoramitsuButton.self, in: cell).last).sendActions(for: .touchUpInside)
        XCTAssertEqual(oldCalls, 0); XCTAssertEqual(submissions, [" fixture "])
        XCTAssertTrue(try XCTUnwrap(descendants(AccountView.self, in: cell).first).accountTitle.isHidden)
    }
    private func image(_ color: UIColor) -> UIImage { UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { ctx in color.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4)) } }
    func testReceiveCellRebindsAddressImageAndOptionalAmount() throws {
        let cell = ReceiveCell(style: .default, reuseIdentifier: nil); let qr = image(.red)
        let first = ReceiveItem(name: "First", address: "address-one", qrImage: qr,
            sendAssetViewModel: SendAssetViewModel(symbol: "XOR", amount: "3", balance: "9", fiat: "$6", svgString: nil))
        cell.set(item: first, context: nil)
        XCTAssertTrue(descendants(UIImageView.self, in: cell).contains { $0.image === qr }); XCTAssertFalse(try XCTUnwrap(descendants(SendAssetView.self, in: cell).first).isHidden)
        let current = ReceiveItem(name: "", address: "address-two", qrImage: nil); cell.set(item: current, context: nil)
        XCTAssertFalse(descendants(UIImageView.self, in: cell).contains { $0.image === qr }); XCTAssertTrue(try XCTUnwrap(descendants(SendAssetView.self, in: cell).first).isHidden)
        XCTAssertTrue(descendants(UILabel.self, in: cell).contains { $0.text == "address-two" }); XCTAssertFalse(descendants(UILabel.self, in: cell).contains { $0.text == "address-one" })
    }
    func testReceiveCellShareAndCopyUseOnlyCurrentHandlers() throws {
        let cell = ReceiveCell(style: .default, reuseIdentifier: nil); let old = ReceiveItem(name: "old", address: "one", qrImage: nil); let current = ReceiveItem(name: "new", address: "two", qrImage: nil)
        var oldCalls = 0; var shared = 0; var copied = 0; old.shareHandler = { oldCalls += 1 }; old.accountTapHandler = { oldCalls += 1 }
        current.shareHandler = { shared += 1 }; current.accountTapHandler = { copied += 1 }; cell.set(item: old, context: nil); cell.set(item: current, context: nil)
        try XCTUnwrap(descendants(SoramitsuButton.self, in: cell).first).sendActions(for: .touchUpInside)
        descendants(SoramitsuControl.self, in: cell).forEach { $0.sendActions(for: .touchUpInside) }
        XCTAssertEqual(oldCalls, 0); XCTAssertEqual(shared, 1); XCTAssertEqual(copied, 1)
    }
    func testGeneratedQRCodeCellClearsImageAndNameOnReuse() throws {
        let cell = GenerateQRCell(style: .default, reuseIdentifier: nil); let qr = image(.blue)
        let old = GenerateQRItem(name: "Old", address: "one", qrImage: qr); let current = GenerateQRItem(name: "", address: "two", qrImage: nil)
        cell.set(item: old, context: nil); cell.set(item: current, context: nil)
        XCTAssertFalse(descendants(UIImageView.self, in: cell).contains { $0.image === qr })
        XCTAssertFalse(descendants(UILabel.self, in: cell).contains { $0.text == "Old" }); XCTAssertTrue(descendants(UILabel.self, in: cell).contains { $0.text == "two" })
    }
    func testGeneratedQRCodeCellActionsUseOnlyCurrentHandlers() throws {
        let cell = GenerateQRCell(style: .default, reuseIdentifier: nil); let old = GenerateQRItem(name: "old", address: "one", qrImage: nil); let current = GenerateQRItem(name: "new", address: "two", qrImage: nil)
        var oldCalls = 0; var shared = 0; var copied = 0; old.shareHandler = { oldCalls += 1 }; old.accountTapHandler = { oldCalls += 1 }
        current.shareHandler = { shared += 1 }; current.accountTapHandler = { copied += 1 }; cell.set(item: old, context: nil); cell.set(item: current, context: nil)
        try XCTUnwrap(descendants(SoramitsuButton.self, in: cell).first).sendActions(for: .touchUpInside)
        descendants(SoramitsuControl.self, in: cell).forEach { $0.sendActions(for: .touchUpInside) }
        XCTAssertEqual(oldCalls, 0); XCTAssertEqual(shared, 1); XCTAssertEqual(copied, 1)
    }
    func testReceiveScreenLoadsAndRendersPublishedRows() async throws {
        let model = QRReceiveScreenModel(); let screen = ReceiveViewController(viewModel: model); screen.loadViewIfNeeded()
        screen.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844); screen.view.layoutIfNeeded()
        XCTAssertEqual(model.loads, 1); XCTAssertNotNil(screen.navigationItem.title); XCTAssertNotNil(screen.navigationItem.rightBarButtonItem)
        let row = ReceiveItem(name: "Fixture", address: "public-address", qrImage: nil); model.setupItems?([row]); await settle()
        let table = try XCTUnwrap(descendants(SoramitsuTableView.self, in: screen.view).first); XCTAssertEqual(table.numberOfRows(inSection: 0), 1)
        model.reloadItems?([row]); await settle(); XCTAssertEqual(table.numberOfRows(inSection: 0), 1)
    }
}
private final class QRReceiveScreenModel: ReceiveViewModelProtocol {
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var loads = 0
    func viewDidLoad() { loads += 1 }
}
