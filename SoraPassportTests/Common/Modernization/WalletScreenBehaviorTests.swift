// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import Combine
import SoraFoundation
import SoraUIKit
import SSFCloudStorage
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class WalletScreenBehaviorTests: XCTestCase {
    private var window: UIWindow!
    private var previousWindow: UIWindow?
    private var cleanup: (() -> Void)?
    private let words = (1...24).map { "fixtureword\($0)" }

    override func setUp() async throws {
        try await super.setUp()
        let theme = SoramitsuUI.shared.themeMode
        let language = LocalizationManager.shared.selectedLocalization
        let animations = UIView.areAnimationsEnabled
        cleanup = {
            SoramitsuUI.shared.themeMode = theme
            LocalizationManager.shared.selectedLocalization = language
            UIView.setAnimationsEnabled(animations)
        }
        SoramitsuUI.shared.themeMode = .manual(.light)
        LocalizationManager.shared.selectedLocalization = "en"
        UIView.setAnimationsEnabled(false)
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        previousWindow = scene?.windows.first { $0.isKeyWindow }
        window = scene.map(UIWindow.init(windowScene:)) ?? UIWindow(frame: UIScreen.main.bounds)
        window.frame = scene?.coordinateSpace.bounds ?? UIScreen.main.bounds
    }

    override func tearDown() async throws {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        previousWindow?.makeKeyAndVisible()
        cleanup?()
        cleanup = nil
        try await super.tearDown()
    }

    private func mount(_ controller: UIViewController) {
        window.rootViewController = UINavigationController(rootViewController: controller)
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        window.layoutIfNeeded()
    }

    private func all<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { all(type, in: $0) }
    }

    private func title(_ button: UIButton) -> String? {
        button.currentTitle ?? button.configuration?.attributedTitle.map { String($0.characters) } ?? button.accessibilityLabel
    }

    private func settle() async {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)
        window.layoutIfNeeded()
    }

    func testRecoveryQuizCoversEverySupportedMnemonicLengthAndUsesDistinctPositions() {
        for count in [12, 15, 18, 21, 24] {
            var generator = SeededQuizRandom(seed: UInt64(count))
            var selected = Set<Int>()
            for _ in 0..<64 {
                let quiz = Quiz(words: Array(words.prefix(count)), using: &generator)
                XCTAssertEqual(quiz.correctAnswers.count, 3)
                XCTAssertEqual(Set(quiz.correctAnswers).count, 3)
                XCTAssertEqual(quiz.quizArray.count, 3)
                for (index, choices) in zip(quiz.correctAnswers, quiz.quizArray) {
                    XCTAssertTrue((1...count).contains(index))
                    XCTAssertEqual(choices.count, 3)
                    XCTAssertEqual(Set(choices).count, choices.count)
                    XCTAssertTrue(choices.contains(words[index - 1]))
                    XCTAssertTrue(choices.allSatisfy(Array(words.prefix(count)).contains))
                    selected.insert(index)
                }
            }
            XCTAssertEqual(selected, Set(1...count), "Every recovery word must be eligible for confirmation")
        }
    }

    func testRecoveryQuizHandlesRepeatedWordsWithoutDuplicateButtons() {
        var generator = SeededQuizRandom(seed: 7)
        let repeated = Array(repeating: "abandon", count: 11) + ["about"]
        let quiz = Quiz(words: repeated, using: &generator)
        for (position, options) in zip(quiz.correctAnswers, quiz.quizArray) {
            XCTAssertEqual(Set(options).count, options.count)
            XCTAssertTrue(options.contains(repeated[position - 1]))
            XCTAssertEqual(Set(options), Set(["abandon", "about"]))
        }
    }

    func testInvalidRecoveryWordCountDoesNotOfferConfirmation() {
        for count in [0, 1, 11, 13, 25] {
            let quiz = Quiz(words: Array(repeating: "fixture", count: count))
            XCTAssertTrue(quiz.correctAnswers.isEmpty)
            XCTAssertTrue(quiz.quizArray.isEmpty)
            let model = ConfirmPassphraseViewModel(mnemonic: Array(repeating: "fixture", count: count))
            let interactor = ConfirmationRecorder()
            model.interactor = interactor
            model.setup()
            XCTAssertNil(model.numbersItem)
            XCTAssertEqual(interactor.completions, 0)
        }
    }

    func testRecoveryConfirmationAdvancesOnlyCorrectWordsAndCompletesOnce() throws {
        let model = ConfirmPassphraseViewModel(mnemonic: Array(words.prefix(12)))
        let interactor = ConfirmationRecorder()
        let wireframe = ConfirmationRouteRecorder()
        model.interactor = interactor
        model.wireframe = wireframe
        let view = ConfirmPassphraseViewController(viewModel: model)
        model.view = view
        mount(view)
        let item = try XCTUnwrap(model.numbersItem)
        XCTAssertEqual(model.currentStage, 0)
        XCTAssertFalse(all(WordNumberCell.self, in: view.view).isEmpty)
        item.tryHandler?("not a recovery word")
        XCTAssertEqual(model.currentStage, 0)
        XCTAssertEqual(wireframe.alerts.count, 1)
        wireframe.alerts.first?.actions.first?.handler?()
        for expectedStage in 1...3 {
            let index = try XCTUnwrap(model.quiz?.correctAnswers[model.currentStage])
            item.tryHandler?(model.mnemonic[index - 1])
            XCTAssertEqual(model.currentStage, expectedStage)
            XCTAssertEqual(item.currentStage, expectedStage)
        }
        XCTAssertEqual(interactor.completions, 1)
        item.tryHandler?(words[0])
        item.tryHandler?("stale event")
        XCTAssertEqual(interactor.completions, 1)
        XCTAssertEqual(wireframe.alerts.count, 1)
    }

    func testRecoverySetupRestartsProgressAndIgnoresDetachedCellEvents() throws {
        let model = ConfirmPassphraseViewModel(mnemonic: Array(words.prefix(12)))
        let interactor = ConfirmationRecorder()
        model.interactor = interactor
        model.setup()
        let old = try XCTUnwrap(model.numbersItem)
        old.tryHandler?(model.mnemonic[old.index - 1])
        XCTAssertEqual(model.currentStage, 1)
        model.setup()
        XCTAssertEqual(model.currentStage, 0)
        let replacement = try XCTUnwrap(model.numbersItem)
        XCTAssertFalse(replacement === old)
        old.tryHandler?(model.mnemonic[replacement.index - 1])
        XCTAssertEqual(model.currentStage, 0)
        replacement.tryHandler?(model.mnemonic[replacement.index - 1])
        XCTAssertEqual(model.currentStage, 1)
        XCTAssertEqual(interactor.completions, 0)
    }

    func testRecoveryScreenAndChoiceItemsReleaseWhenClosed() {
        weak var releasedView: ConfirmPassphraseViewController?
        weak var releasedItem: WordNumberItem?
        autoreleasepool {
            let model = ConfirmPassphraseViewModel(mnemonic: Array(words.prefix(12)))
            let view = ConfirmPassphraseViewController(viewModel: model)
            model.view = view
            view.loadViewIfNeeded()
            releasedView = view
            releasedItem = model.numbersItem
        }
        XCTAssertNil(releasedView, "Recovery phrases must not be retained by a view/model cycle")
        XCTAssertNil(releasedItem, "A cell callback must not retain its own recovery-word item")
    }

    func testWelcomeButtonsDispatchCreateAndRestoreWithoutOpeningCloudConnection() throws {
        let presenter = WelcomeRecorder()
        let view = WelcomeViewController()
        view.presenter = presenter
        mount(view)
        XCTAssertEqual(presenter.setups, 1)
        XCTAssertGreaterThanOrEqual(presenter.appearances, 1)
        let buttons = all(UIButton.self, in: view.view)
        try XCTUnwrap(buttons.first { title($0) == R.string.localizable.create_account_title(preferredLanguages: ["en"]) })
            .sendActions(for: .touchUpInside)
        try XCTUnwrap(buttons.first { title($0) == R.string.localizable.recoveryTitleV2(preferredLanguages: ["en"]) })
            .sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.actions, ["create", "restore"])
        XCTAssertEqual(view.logo.image?.size, R.image.soraLogoBig()?.size)
        view.showLoading()
        view.hideLoading()
    }

    func testWalletNameScreenPassesEditedNameAndUsesInputHandler() throws {
        let presenter = WalletNameRecorder()
        let view = SetupAccountNameViewController()
        view.presenter = presenter
        mount(view)
        XCTAssertEqual(presenter.setups, 1)
        let field = try XCTUnwrap(all(UITextField.self, in: view.view).first)
        XCTAssertEqual(field.textContentType, .nickname)
        let handler = InputHandler(value: "", required: false, predicate: NSPredicate.notEmpty,
                                   processor: ByteLengthProcessor.username)
        view.set(viewModel: InputViewModel(inputHandler: handler))
        XCTAssertTrue(view.textField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "Savings"))
        field.text = handler.value
        XCTAssertEqual(field.text, "Savings")
        XCTAssertFalse(view.textFieldShouldReturn(field))
        let button = try XCTUnwrap(all(UIButton.self, in: view.view).first {
            title($0) == R.string.localizable.transactionContinue(preferredLanguages: ["en"])
        })
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.userName, "Savings")
        XCTAssertEqual(presenter.proceeds, 1)
    }

    func testInformationFactoryRendersAllSectionsAndLocalizationRefresh() async throws {
        let view = try XCTUnwrap(SettingsInformationFactory.createInformation().controller as? SettingsInformationViewController)
        mount(view)
        await settle()
        let table = try XCTUnwrap(all(UITableView.self, in: view.view).first)
        XCTAssertEqual(table.numberOfSections, 3)
        XCTAssertEqual(table.numberOfRows(inSection: 0), 2)
        XCTAssertGreaterThanOrEqual(table.numberOfRows(inSection: 1), 3)
        XCTAssertGreaterThanOrEqual(table.numberOfRows(inSection: 2), 3)
        for section in 0..<table.numberOfSections {
            for row in 0..<table.numberOfRows(inSection: section) {
                let cell = try XCTUnwrap(table.dataSource?.tableView(table, cellForRowAt: IndexPath(row: row, section: section)))
                XCTAssertTrue(cell is SettingsInformationCell)
                XCTAssertFalse(all(UILabel.self, in: cell).compactMap(\.text).isEmpty)
            }
        }
        XCTAssertEqual(view.navigationItem.title, R.string.localizable.settingsInformationTitle(preferredLanguages: ["en"]))
        (view.presenter as? SettingsInformationPresenter)?.applyLocalization()
        await settle()
        XCTAssertEqual(table.numberOfSections, 3)
    }

    func testInformationRowsDispatchOnlyTheirOwnAction() async throws {
        let view = SettingsInformationViewController()
        mount(view)
        var actions: [String] = []
        let items = [InformationItem(title: "First", subtitle: "Details", rightItem: .arrow, onTap: { actions.append("first") }),
                     InformationItem(title: "Second", rightItem: .link, onTap: { actions.append("second") })]
        items[0].position = .first
        items[1].position = .last
        let section = SettingsInformationSection(items: items)
        var snapshot = SettingsInformationSnapshot()
        snapshot.appendSections([section])
        snapshot.appendItems(items, toSection: section)
        view.update(snapshot: snapshot)
        await settle()
        let table = try XCTUnwrap(all(UITableView.self, in: view.view).first)
        view.tableView(table, didSelectRowAt: IndexPath(row: 1, section: 0))
        view.tableView(table, didSelectRowAt: IndexPath(row: 99, section: 0))
        XCTAssertEqual(actions, ["second"])
        XCTAssertNotNil(view.tableView(table, viewForFooterInSection: 0))
    }

    func testImportCompletionRendersAccountAndRoutesContinueToPin() async throws {
        let wireframe = ImportedAccountRecorder()
        let address = "screen-fixture-\(UUID().uuidString)"
        let model = AccountImportedViewModel(importedAccountAddress: address,
            backedUpAccounts: [.init(name: "Imported savings", address: address)], wireframe: wireframe)
        let view = AccountImportedViewController()
        view.viewModel = model
        mount(view)
        await settle()
        XCTAssertEqual(model.snapshot.numberOfItems, 1)
        guard case let .accountImported(item) = try XCTUnwrap(model.snapshot.itemIdentifiers.first) else {
            return XCTFail("Expected imported account row")
        }
        XCTAssertEqual(item.accountName, "Imported savings")
        XCTAssertEqual(item.accountAddress, address)
        item.continueTapHandler?()
        XCTAssertEqual(wireframe.pinSetups, 1)
        item.loadMoreTapHandler?()
        XCTAssertEqual(wireframe.backups.map(\.address), [address])
        let table = try XCTUnwrap(all(UITableView.self, in: view.view).first)
        XCTAssertEqual(table.numberOfRows(inSection: 0), 1)
    }

    func testImportIntoExistingSessionDismissesAndInvokesCompletion() {
        let wireframe = ImportedAccountRecorder()
        var completions = 0
        let model = AccountImportedViewModel(importedAccountAddress: "absent", backedUpAccounts: [],
                                            wireframe: wireframe, endAddingBlock: { completions += 1 })
        model.reload()
        guard case let .accountImported(item) = model.snapshot.itemIdentifiers.first else {
            return XCTFail("Expected imported account row")
        }
        XCTAssertEqual(item.accountName, "")
        XCTAssertEqual(item.accountAddress, "")
        item.continueTapHandler?()
        XCTAssertEqual(wireframe.dismissals, 1)
        XCTAssertEqual(wireframe.pinSetups, 0)
        XCTAssertEqual(completions, 1)
    }
}

private struct SeededQuizRandom: RandomNumberGenerator {
    var seed: UInt64
    mutating func next() -> UInt64 {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return seed
    }
}

private final class ConfirmationRecorder: AccountConfirmInteractorInputProtocol {
    var completions = 0
    func requestWords() {}
    func confirm(words: [String]) {}
    func skipConfirmation() { completions += 1 }
}

private final class ConfirmationRouteRecorder: ConfirmPassphraseWireframeProtocol {
    var alerts: [AlertPresentableViewModel] = []
    func proceed(on controller: UIViewController?) {}
    func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?) {
        alerts.append(viewModel)
    }
}

private final class WelcomeRecorder: OnboardingMainPresenterProtocol {
    var setups = 0
    var appearances = 0
    var actions: [String] = []
    func setup() { setups += 1 }
    func viewWillAppear() { appearances += 1 }
    func activateSignup() { actions.append("create") }
    func activateAccountRestore() { actions.append("restore") }
    func activateCloudStorageConnection() { actions.append("cloud") }
}

private final class WalletNameRecorder: UsernameSetupPresenterProtocol {
    var userName: String?
    var setups = 0
    var proceeds = 0
    func setup() { setups += 1 }
    func proceed() { proceeds += 1 }
    func endEditing() {}
    func activateURL(_ url: URL) {}
}

private final class ImportedAccountRecorder: AccountImportedWireframeProtocol {
    var pinSetups = 0
    var dismissals = 0
    var backups: [OpenBackupAccount] = []
    func showSetupPinCode() { pinSetups += 1 }
    func showBackepedAccounts(accounts: [OpenBackupAccount]) { backups = accounts }
    func dismiss(completion: (() -> Void)?) { dismissals += 1; completion?() }
}

extension WalletScreenBehaviorTests {
    func testAssetListRendersRowsSearchEmptyStateAndEditingMode() async throws {
        let model = ScreenProductRecorder()
        let view = ProductListViewController(viewModel: model)
        mount(view)
        let asset = AssetInfo(id: WalletAssetId.xor.rawValue, symbol: "XOR", chainId: "", precision: 18,
                              icon: nil, displayName: "SORA", visible: true)
        var presentation = AssetViewModel(identifier: asset.assetId, title: "SORA", subtitle: "12 XOR",
                                          fiatText: "$2", icon: nil, mode: .view)
        presentation.priceLoadFinished = true
        model.setupItems?([AssetListItem(assetInfo: asset, assetViewModel: presentation, balance: 12)])
        await settle()
        let table = try XCTUnwrap(all(UITableView.self, in: view.view).first)
        XCTAssertEqual(table.numberOfRows(inSection: 0), 1)
        XCTAssertTrue(all(UILabel.self, in: view.view).contains { $0.text == "SORA" })
        let search = try XCTUnwrap(view.navigationItem.searchController)
        view.willPresentSearchController(search)
        search.searchBar.text = "missing token"
        view.updateSearchResults(for: search)
        XCTAssertEqual(model.searchText, "missing token")
        XCTAssertTrue(model.isActiveSearch)
        model.setupItems?([])
        await settle()
        XCTAssertEqual(table.numberOfRows(inSection: 0), 0)
        XCTAssertTrue(all(UILabel.self, in: view.view).contains {
            !$0.isHidden && $0.text == R.string.localizable.searchEmptyState(preferredLanguages: ["en"])
        })
        view.willDismissSearchController(search)
        XCTAssertFalse(model.isActiveSearch)
        view.editTapped()
        XCTAssertEqual(model.mode, .edit)
        XCTAssertTrue(table.dragInteractionEnabled)
        XCTAssertNil(view.navigationItem.rightBarButtonItem)
        view.doneTapped()
        XCTAssertEqual(model.mode, .view)
        XCTAssertFalse(table.dragInteractionEnabled)
        XCTAssertNotNil(view.navigationItem.rightBarButtonItem)
        view.crossButtonTapped()
        XCTAssertEqual(model.dismissals, 1)
    }

    func testReceiveCardReplacesAccountAndDispatchesEachAction() throws {
        let view = ReceiveQRView()
        let controller = UIViewController()
        controller.view = view
        mount(controller)
        var calls: [String] = []
        let address = PortfolioSampleData.mainId
        view.viewModel = ReceiveQRViewModel(name: "Savings", address: address, qrImage: UIImage(),
            shareHandler: { calls.append("share") }, scanQRHandler: { calls.append("scan") },
            accountTapHandler: { calls.append("account") })
        let account = try XCTUnwrap(all(UIControl.self, in: view).first { $0.accessibilityLabel == "Savings, " + address })
        account.sendActions(for: .touchUpInside)
        let buttons = all(SoramitsuButton.self, in: view)
        XCTAssertEqual(buttons.count, 2)
        buttons.forEach { $0.sendActions(for: .touchUpInside) }
        XCTAssertEqual(Set(calls), Set(["share", "scan", "account"]))
        XCTAssertEqual(calls.count, 3)
        view.viewModel = ReceiveQRViewModel(name: "", address: "replacement-address", qrImage: nil)
        XCTAssertFalse(all(UILabel.self, in: view).contains { !$0.isHidden && $0.text == "Savings" })
        XCTAssertEqual(account.accessibilityLabel, "replacement-address")
        account.sendActions(for: .touchUpInside)
        XCTAssertEqual(calls.count, 3, "Reused views must not call the previous account's action")
    }

    func testReceiveScreenSwitchesRequestAndReceiveWithoutShowingBoth() async throws {
        let model = ScreenReceiveRecorder()
        let view = GenerateQRViewController(viewModel: model)
        mount(view)
        await settle()
        let receive = try XCTUnwrap(all(ReceiveQRView.self, in: view.view).first)
        let request = try XCTUnwrap(all(InputSendInfoView.self, in: view.view).first)
        XCTAssertFalse(receive.isHidden)
        XCTAssertTrue(request.isHidden)
        model.updateContent?(.request)
        await settle()
        XCTAssertTrue(receive.isHidden)
        XCTAssertFalse(request.isHidden)
        model.updateContent?(.receive)
        await settle()
        XCTAssertFalse(receive.isHidden)
        XCTAssertTrue(request.isHidden)
        XCTAssertFalse(request.assetView.textField.isFirstResponder)
        view.viewWillDisappear(false)
        XCTAssertEqual(model.closes, 1)
    }

    func testSendAmountFieldRejectsPartiallyNumericPastedInput() {
        let model = ScreenAmountRecorder()
        let view = InputAssetAmountViewController(viewModel: model)
        mount(view)
        let field = view.assetView.textField
        for text in ["1garbage", "1..2", "1e2", "-1", "NaN"] {
            field.text = text
            field.sendActions(for: .editingChanged)
            XCTAssertEqual(model.inputedFirstAmount, 0, "Invalid amount: \(text)")
        }
        field.text = "12" + (Locale.current.decimalSeparator ?? ".") + "5"
        field.sendActions(for: .editingChanged)
        XCTAssertEqual(model.inputedFirstAmount, Decimal(string: "12.5"))
    }

    func testSwapAmountFieldsRejectPartiallyNumericPastedInput() throws {
        let model = ScreenSwapRecorder()
        let view = PolkaswapViewController(viewModel: model)
        model.view = view
        mount(view)
        let fields = try XCTUnwrap(all(InputAssetsView.self, in: view.view).first)
        for field in [fields.firstAsset.textField, fields.secondAsset.textField] {
            for text in ["1garbage", "1..2", "1e2", "-1"] {
                field.text = text
                field.sendActions(for: .editingChanged)
                let amount = field === fields.firstAsset.textField ? model.inputedFirstAmount : model.inputedSecondAmount
                XCTAssertEqual(amount, 0, "Invalid amount: \(text)")
            }
        }
        XCTAssertEqual(model.recalculations, [.one, .one, .one, .one, .two, .two, .two, .two])
    }

    func testSwapUpdatesBothSidesAndInputDispatchesTheMatchingField() async throws {
        let model = ScreenSwapRecorder()
        let view = PolkaswapViewController(viewModel: model)
        model.view = view
        mount(view)
        let assets = try XCTUnwrap(all(InputAssetsView.self, in: view.view).first)
        view.updateFirstAsset(symbol: "XOR", image: nil)
        view.updateSecondAsset(symbol: "VAL", image: nil)
        view.updateFirstAsset(balance: "100 XOR")
        view.updateSecondAsset(balance: "20 VAL")
        view.updateFirstAsset(fiatText: "$3")
        view.updateSecondAsset(fiatText: "$4")
        view.set(firstAmountText: "2")
        view.set(secondAmountText: "3")
        view.update(slippageTolerance: "0.5%")
        view.update(selectedMarket: "XYK")
        view.updateMiddleButton(isEnabled: true)
        view.setupButton(isEnabled: true)
        view.updateReviewButton(title: "Review swap")
        view.updateFirstAsset(state: .default, amountColor: .fgPrimary, fiatColor: .fgSecondary)
        view.updateSecondAsset(state: .default, amountColor: .fgPrimary, fiatColor: .fgSecondary)
        view.update(isNeedLoadingState: false)
        view.setupMarketButton(isLoadingState: false)
        await settle()
        XCTAssertEqual(assets.firstAsset.sora.assetSymbol, "XOR")
        XCTAssertEqual(assets.secondAsset.sora.assetSymbol, "VAL")
        XCTAssertEqual(assets.firstAsset.textField.text, "2")
        XCTAssertEqual(assets.secondAsset.textField.text, "3")
        XCTAssertEqual(assets.firstAsset.sora.fullFiatText, "100 XOR")
        XCTAssertEqual(assets.secondAsset.sora.fullFiatText, "20 VAL")
        assets.firstAsset.textField.sendActions(for: .editingDidBegin)
        XCTAssertEqual(model.focusedField, .one)
        assets.firstAsset.textField.sendActions(for: .editingChanged)
        XCTAssertEqual(model.inputedFirstAmount, 2)
        assets.secondAsset.textField.sendActions(for: .editingDidBegin)
        assets.secondAsset.textField.sendActions(for: .editingChanged)
        XCTAssertEqual(model.focusedField, .two)
        XCTAssertEqual(model.inputedSecondAmount, 3)
        XCTAssertEqual(model.recalculations, [.one, .two])
        assets.middleButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(model.reversals, 1)
        view.set(firstAmountText: "0")
        view.set(secondAmountText: "0")
        await settle()
        XCTAssertEqual(assets.firstAsset.textField.text, "")
        XCTAssertEqual(assets.secondAsset.textField.text, "")
    }

    func testSendScreenDisplaysRecipientBalanceAndUpdatedAmount() async {
        let model = ScreenAmountRecorder()
        let view = InputAssetAmountViewController(viewModel: model)
        mount(view)
        view.updateFirstAsset(symbol: "XOR", image: nil)
        view.updateFirstAsset(balance: "100 XOR")
        view.updateFirstAsset(fiatText: "$2")
        view.updateRecipientView(with: PortfolioSampleData.savingsId)
        view.set(firstAmountText: "5")
        view.setupButton(isEnabled: true)
        view.updateFirstAsset(state: .default, amountColor: .fgPrimary, fiatColor: .fgSecondary)
        await settle()
        XCTAssertEqual(view.assetView.textField.text, "5")
        XCTAssertEqual(view.assetView.sora.assetSymbol, "XOR")
        XCTAssertEqual(view.assetView.sora.fullFiatText, "100 XOR")
        XCTAssertEqual(view.recipientView.contactView.accountTitle.text, PortfolioSampleData.savingsId)
        view.recipientView.contactView.onTap?()
        XCTAssertEqual(model.addressRequests, 1)
        view.updateRecipientView(with: "")
        XCTAssertEqual(view.recipientView.contactView.accountTitle.text, R.string.localizable.selectRecipient(preferredLanguages: ["en"]))
        view.set(firstAmountText: "0")
        await settle()
        XCTAssertEqual(view.assetView.textField.text, "")
    }
}

private final class ScreenProductRecorder: Produtable {
    let searchBarPlaceholder = "Search tokens"
    let navigationTitle = "Assets"
    var searchText = ""
    var mode: WalletViewMode = .view { didSet { setupNavigationBar?(mode) } }
    var isActiveSearch = false
    var setupNavigationBar: ((WalletViewMode) -> Void)?
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var dismiss: ((Bool) -> Void)?
    var dismissals = 0
    func viewDidLoad() { setupNavigationBar?(mode); setupItems?([]) }
    func viewdismissed() { dismissals += 1 }
}

private final class ScreenReceiveRecorder: GenerateQRViewModelProtocol {
    var setupSwicherView: ((SwitcherViewModel) -> Void)?
    var setupReceiveView: ((ReceiveQRViewModel) -> Void)?
    var setupRequestView: ((InputSendInfoViewModel) -> Void)?
    var updateContent: ((GenerateQRMode) -> Void)?
    var showShareContent: (([Any]) -> Void)?
    var closes = 0
    var closeHadler: (() -> Void)? { { [weak self] in self?.closes += 1 } }
    func viewDidLoad() {
        setupSwicherView?(SwitcherViewModel(buttonViewModels: [
            .init(title: "Receive", isSelected: true), .init(title: "Request", isSelected: false)]))
        setupReceiveView?(ReceiveQRViewModel(name: "Main", address: PortfolioSampleData.mainId, qrImage: UIImage()))
        updateContent?(.receive)
    }
}

private final class ScreenAmountRecorder: InputAssetAmountViewModelProtocol {
    var inputedFirstAmount: Decimal = 0
    var addressRequests = 0
    func viewDidLoad() {}
    func choiceBaseAssetButtonTapped() {}
    func reviewButtonTapped() {}
    func selectAddress() { addressRequests += 1 }
    func didSelect(variant: Decimal) {}
}

private final class ScreenSwapRecorder: LiquidityViewModelProtocol {
    weak var view: PolkaswapViewController?
    var title: String? { "Swap" }
    var imageName: String? { nil }
    var firstFieldEmptyStateFullFiatText: String? { "Pay" }
    var secondFieldEmptyStateFullFiatText: String? { "Receive" }
    var isSwap: Bool { true }
    var actionButtonImage: UIImage? { nil }
    var inputedFirstAmount: Decimal = 0
    var inputedSecondAmount: Decimal = 0
    lazy var middleButtonActionHandler: (() -> Void)? = { [weak self] in self?.reversals += 1 }
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var focusedField: FocusedField = .one
    var recalculations: [FocusedField] = []
    var reversals = 0
    func viewDidLoad() { view?.setupButton(isEnabled: false) }
    func choiсeBaseAssetButtonTapped() {}
    func choiсeTargetAssetButtonTapped() {}
    func changeSlippageTolerance() {}
    func reviewButtonTapped() {}
    func recalculate(field: FocusedField) { recalculations.append(field) }
    func didSelect(variant: Decimal) {}
}

extension WalletScreenBehaviorTests {
    private func detail(_ title: String = "Reward", fiat: String? = "$1", progress: Float? = nil) -> DetailViewModel {
        DetailViewModel(title: title,
            assetAmountText: SoramitsuTextItem(text: "10 XOR", fontData: FontType.textM, textColor: .fgPrimary),
            fiatAmountText: fiat.map { SoramitsuTextItem(text: $0, fontData: FontType.textS, textColor: .fgSecondary) },
            type: progress.map(DetailsType.progress) ?? .casual)
    }

    func testClaimSnapshotIdentityIncludesRewardAndAdmissionChanges() {
        let original = ClaimRewardsItem(rewardText: "1 XOR", amountText: "", image: nil, claimPossible: false, detailsViewModel: [])
        let changedReward = ClaimRewardsItem(rewardText: "2 XOR", amountText: "", image: nil, claimPossible: false, detailsViewModel: [])
        let changedAdmission = ClaimRewardsItem(rewardText: "1 XOR", amountText: "", image: nil, claimPossible: true, detailsViewModel: [])
        XCTAssertNotEqual(original, changedReward)
        XCTAssertNotEqual(original, changedAdmission)
        XCTAssertEqual(Set([original, changedReward, changedAdmission]).count, 3)
    }

    func testDetailSnapshotIdentityIncludesFiatTitleProgressAndInformationAvailability() {
        let original = detail()
        let changedFiat = detail(fiat: "$2")
        let changedTitle = detail("Network fee")
        let changedProgress = detail(progress: 0.5)
        let changedInfo = detail()
        changedInfo.infoHandler = {}
        XCTAssertNotEqual(original, changedFiat)
        XCTAssertNotEqual(original, changedTitle)
        XCTAssertNotEqual(original, changedProgress)
        XCTAssertNotEqual(original, changedInfo)
        XCTAssertEqual(Set([original, changedFiat, changedTitle, changedProgress, changedInfo]).count, 5)
        XCTAssertEqual(original, detail())
    }

    func testClaimScreenRefreshesUnpricedRewardAndButtonWhenSnapshotChanges() async throws {
        let model = ScreenClaimRecorder()
        let view = ClaimRewardsViewController(viewModel: model)
        mount(view)
        var claims: [String] = []
        let first = ClaimRewardsItem(rewardText: "1 XOR", amountText: "", image: nil, claimPossible: false,
                                    detailsViewModel: [detail(), detail("Staked", fiat: nil, progress: 0.25)])
        first.onClaim = { claims.append("old") }
        model.show(first)
        await settle()
        let table = try XCTUnwrap(all(UITableView.self, in: view.view).first)
        XCTAssertEqual(table.numberOfRows(inSection: 0), 1)
        var cell = try XCTUnwrap(table.cellForRow(at: IndexPath(row: 0, section: 0)) as? ClaimRewardsCell)
        XCTAssertTrue(all(UILabel.self, in: cell).contains { $0.text == "1 XOR" })
        XCTAssertFalse(try XCTUnwrap(all(SoramitsuButton.self, in: cell).first).isEnabled)
        let second = ClaimRewardsItem(rewardText: "2 XOR", amountText: "", image: nil, claimPossible: true,
                                     detailsViewModel: first.detailsViewModel)
        second.onClaim = { claims.append("new") }
        model.show(second)
        await settle()
        cell = try XCTUnwrap(table.cellForRow(at: IndexPath(row: 0, section: 0)) as? ClaimRewardsCell)
        XCTAssertTrue(all(UILabel.self, in: cell).contains { $0.text == "2 XOR" })
        let button = try XCTUnwrap(all(SoramitsuButton.self, in: cell).first)
        XCTAssertTrue(button.isEnabled)
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(claims, ["new"])
    }

    func testFarmCellTracksEachAssetIconLoadingStateIndependently() throws {
        for (first, second) in [(UIImage(), nil as UIImage?), (nil, UIImage())] {
            let item = FarmDetailsItem(title: "XOR / VAL", subtitle: "Farm", firstAssetImage: first,
                secondAssetImage: second, rewardAssetImage: nil, detailsViewModel: [], typeImage: .activeFarming,
                stackingState: .startStacking, areThereRewards: false, supplyItem: nil)
            let cell = FarmDetailsCell(style: .default, reuseIdentifier: nil)
            cell.set(item: item, context: nil)
            let header = try XCTUnwrap(all(PoolDetailsHeaderView.self, in: cell).first)
            XCTAssertEqual(header.firstCurrencyImageView.sora.loadingPlaceholder.type, first == nil ? .shimmer : .none)
            XCTAssertEqual(header.secondCurrencyImageView.sora.loadingPlaceholder.type, second == nil ? .shimmer : .none)
        }
    }

    func testFarmCellRebindingChangesActionsAndRendersAllStakingStates() throws {
        let cell = FarmDetailsCell(style: .default, reuseIdentifier: nil)
        var calls: [Int] = []
        for (index, state) in [FarmDetailsBottomButtonState.startStacking, .startStackingWithRewards, .editFarm, .stackingUnavailable].enumerated() {
            let item = FarmDetailsItem(title: "Farm \(index)", subtitle: "XOR / VAL", firstAssetImage: UIImage(),
                secondAssetImage: UIImage(), rewardAssetImage: UIImage(), detailsViewModel: [detail(), detail("Share", progress: 0.75)],
                typeImage: index.isMultiple(of: 2) ? .activeFarming : .incativeFarming,
                stackingState: state, areThereRewards: index.isMultiple(of: 2), supplyItem: nil)
            item.onTapTopButton = { calls.append(index * 10) }
            item.onTapBottomButton = { calls.append(index) }
            cell.set(item: item, context: nil)
            let buttons = all(SoramitsuButton.self, in: cell.containerView)
            XCTAssertEqual(buttons.count, 2)
            XCTAssertEqual(buttons[0].isHidden, !item.areThereRewards)
            XCTAssertEqual(buttons[1].isUserInteractionEnabled, state != .stackingUnavailable)
            XCTAssertEqual(all(DetailView.self, in: cell).count, 2, "Rebinding must replace prior details")
            buttons[0].sendActions(for: .touchUpInside)
            buttons[1].sendActions(for: .touchUpInside)
            XCTAssertEqual(Array(calls.suffix(2)), [index * 10, index])
        }
    }
}

private final class ScreenClaimRecorder: ClaimRewardsViewModelProtocol {
    @Published private var snapshot = ClaimRewardsSnapshot()
    var snapshotPublisher: Published<ClaimRewardsSnapshot>.Publisher { $snapshot }
    private let section = ClaimRewardsSection(items: [])
    func show(_ item: ClaimRewardsItem) {
        var next = ClaimRewardsSnapshot()
        next.appendSections([section])
        next.appendItems([.claim(item)], toSection: section)
        snapshot = next
    }
    func claimButtonTapped() {}
    func networkFeeInfoButtonTapped() {}
    func viewDidLoad() {}
}
