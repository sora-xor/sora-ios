// SPDX-License-Identifier: Apache-2.0
import BigInt
import Foundation
import IrohaCrypto
import RobinHood
import SoraFoundation
import SoraUIKit
import SSFUtils
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class ReferralEntryFlowTests: XCTestCase {
    private func descendants<T:UIView>(_ type:T.Type,_ root:UIView)->[T] { ((root as? T).map{[$0]} ?? []) + root.subviews.flatMap{descendants(type,$0)} }
    private func settle() async { for _ in 0..<6 { await Task.yield() }; try? await Task.sleep(nanoseconds:30_000_000) }
    private func model(_ input: ReferralEntryInput, enabled: Bool? = false) -> ReferrerLinkViewModel { ReferrerLinkViewModel(isEnabled:enabled,interactor:input) }
    private func bound(_ value:ReferrerLinkViewModel)->ReferrerLinkCell { let cell = ReferrerLinkCell(style:.default,reuseIdentifier:nil); cell.bind(viewModel:value); return cell }
    private func button(_ cell:UIView) throws -> SoramitsuButton { try XCTUnwrap(descendants(SoramitsuButton.self,cell).first) }
    private func field(_ cell:UIView) throws -> UITextField { try XCTUnwrap(descendants(UITextField.self,cell).first) }
    func testValidAddressEnablesTheAction() { let input = ReferralEntryInput(), m = model(input); m.userChangeTextField(with:"friend"); XCTAssertEqual(m.address,"friend"); XCTAssertEqual(m.isEnabled,true) }
    func testReferralURLExtractsItsAddress() { let input = ReferralEntryInput(), m = model(input); m.userChangeTextField(with:"https://sora.org/referral/friend"); XCTAssertEqual(m.address,"friend"); XCTAssertEqual(m.isEnabled,true) }
    func testInvalidAddressDisablesTheAction() { let input = ReferralEntryInput(), m = model(input); m.userChangeTextField(with:"invalid"); XCTAssertEqual(m.isEnabled,false) }
    func testCurrentWalletCannotBecomeItsOwnReferrer() { let input = ReferralEntryInput(), m = model(input); m.userChangeTextField(with:"self"); XCTAssertEqual(m.isEnabled,false); m.userTappedOnActivate(); XCTAssertTrue(input.sent.isEmpty) }
    func testMissingInteractorCannotEnableOrSubmit() { let m = ReferrerLinkViewModel(isEnabled:true,interactor:nil); m.userChangeTextField(with:"friend"); XCTAssertEqual(m.isEnabled,false); m.userTappedOnActivate() }
    func testValidActivationSendsTheExactDecodedAccountId() { let input = ReferralEntryInput(), m = model(input); m.userChangeTextField(with:"friend"); m.userTappedOnActivate(); XCTAssertEqual(input.sent,["0x01020304"]) }
    func testInvalidActivationCannotSendEvenWithStaleEnabledFlag() { let input = ReferralEntryInput(), m = model(input,enabled:true); m.address = "invalid"; m.userTappedOnActivate(); XCTAssertTrue(input.sent.isEmpty) }
    func testActivationRechecksWhetherTheSelectedWalletChanged() { let input = ReferralEntryInput(), m = model(input); m.userChangeTextField(with:"friend"); input.current = "friend"; m.userTappedOnActivate(); XCTAssertTrue(input.sent.isEmpty) }
    func testCellShowsTheBoundAddressAndEnabledState() throws { let input = ReferralEntryInput(), m = model(input,enabled:true); m.address = "friend"; let c = bound(m); XCTAssertEqual(try field(c).text,"friend"); XCTAssertTrue(try button(c).isEnabled) }
    func testCellTypingUpdatesTheRealModel() throws { let input = ReferralEntryInput(), m = model(input); let c = bound(m), f = try field(c); f.text = "https://sora.org/referral/friend"; f.sendActions(for:.editingChanged); XCTAssertEqual(m.address,"friend"); XCTAssertEqual(m.isEnabled,true) }
    func testCellValidActivationReachesItsInteractorOnce() throws { let input = ReferralEntryInput(), m = model(input,enabled:true); m.address = "friend"; let c = bound(m); try button(c).sendActions(for:.touchUpInside); XCTAssertEqual(input.sent,["0x01020304"]) }
    func testCellAppliesCurrentPublishedValidation() async throws { let input = ReferralEntryInput(), m = model(input); let c = bound(m); m.isEnabled = true; await settle(); XCTAssertTrue(try button(c).isEnabled); m.isEnabled = false; await settle(); XCTAssertFalse(try button(c).isEnabled) }
    func testCellRebindingIgnoresTheOldModelsPublishedValidation() async throws { let input = ReferralEntryInput(), first = model(input), second = model(input,enabled:true); let c = bound(first); c.bind(viewModel:second); await settle(); first.isEnabled = false; await settle(); XCTAssertTrue(try button(c).isEnabled) }
    func testCellRebindingReleasesTheOldModel() { let input = ReferralEntryInput(); var old:ReferrerLinkViewModel? = model(input); weak var observed = old; let c = bound(old!); let current = model(input); c.bind(viewModel:current); old = nil; XCTAssertNil(observed) }
    func testRepeatedCellBindingDoesNotDuplicateActions() throws { let input = ReferralEntryInput(), m = model(input,enabled:true); m.address = "friend"; let c = bound(m); c.bind(viewModel:m); try button(c).sendActions(for:.touchUpInside); XCTAssertEqual(input.sent.count,1) }
    func testReplacementCellModelOwnsActivation() throws { let first = ReferralEntryInput(), second = ReferralEntryInput(), a = model(first,enabled:true), b = model(second,enabled:true); a.address = "friend"; b.address = "friend"; let c = bound(a); c.bind(viewModel:b); try button(c).sendActions(for:.touchUpInside); XCTAssertTrue(first.sent.isEmpty); XCTAssertEqual(second.sent.count,1) }
    func testReferralTextFieldDoesNotAutocorrectAddresses() throws { let c = bound(model(ReferralEntryInput())); let f = try field(c); XCTAssertEqual(f.autocorrectionType,.no); XCTAssertEqual(f.autocapitalizationType,.none) }
    func testInputScreenRequestsItsModelOnceOnLoad() { let p = ReferralEntryPresenter(), c = InputLinkViewController(presenter:p); c.loadViewIfNeeded(); c.loadViewIfNeeded(); XCTAssertEqual(p.loads,1) }
    func testInputScreenRendersTheBoundReferrerCell() throws { let p = ReferralEntryPresenter(), c = InputLinkViewController(presenter:p), input = ReferralEntryInput(), m = model(input); m.address = "friend"; c.loadViewIfNeeded(); c.setup(with:[m]); let t = try XCTUnwrap(descendants(UITableView.self,c.view).first); XCTAssertEqual(c.tableView(t,numberOfRowsInSection:0),1); let row = c.tableView(t,cellForRowAt:IndexPath(row:0,section:0)); XCTAssertEqual(try field(row).text,"friend") }
    func testInputScreenReplacingModelsDoesNotKeepOldRows() throws { let c = InputLinkViewController(presenter:ReferralEntryPresenter()); c.loadViewIfNeeded(); c.setup(with:[model(ReferralEntryInput())]); c.setup(with:[]); let t = try XCTUnwrap(descendants(UITableView.self,c.view).first); XCTAssertEqual(c.tableView(t,numberOfRowsInSection:0),0) }
    func testKeyboardAppearanceReservesTheCoveredHeight() throws { let c = InputLinkViewController(presenter:ReferralEntryPresenter()); c.loadViewIfNeeded(); let t = try XCTUnwrap(descendants(UITableView.self,c.view).first); NotificationCenter.default.post(name:UIResponder.keyboardWillShowNotification,object:nil,userInfo:[UIResponder.keyboardFrameEndUserInfoKey:NSValue(cgRect:CGRect(x:0,y:400,width:300,height:250))]); XCTAssertEqual(t.contentInset.bottom,250) }
    func testKeyboardDismissalWithoutFrameRestoresTheTableInset() throws { let c = InputLinkViewController(presenter:ReferralEntryPresenter()); c.loadViewIfNeeded(); let t = try XCTUnwrap(descendants(UITableView.self,c.view).first); t.contentInset.bottom = 250; NotificationCenter.default.post(name:UIResponder.keyboardWillHideNotification,object:nil); XCTAssertEqual(t.contentInset.bottom,0) }
    func testInputScreenPopReturnsToItsPreviousScreen() { let root = UIViewController(), c = InputLinkViewController(presenter:ReferralEntryPresenter()); let n = UINavigationController(rootViewController:root); n.pushViewController(c,animated:false); c.pop(); XCTAssertTrue(n.topViewController === root) }
    func testInputScreenPopWithoutNavigationIsSafe() { let c = InputLinkViewController(presenter:ReferralEntryPresenter()); c.pop(); XCTAssertNil(c.navigationController) }
    func testExistingReferrerCellDisplaysTheFullBoundAddress() { let d = ReferralCloseRecorder(), c = YourReferrerCell(style:.default,reuseIdentifier:nil); c.bind(viewModel:YourReferrerViewModel(referrer:"exact-referrer-address",delegate:d)); XCTAssertTrue(descendants(UILabel.self,c).contains{$0.text == "exact-referrer-address"}) }
    func testExistingReferrerCloseUsesOnlyTheCurrentDelegate() throws { let first = ReferralCloseRecorder(), second = ReferralCloseRecorder(), c = YourReferrerCell(style:.default,reuseIdentifier:nil); c.bind(viewModel:YourReferrerViewModel(referrer:"one",delegate:first)); c.bind(viewModel:YourReferrerViewModel(referrer:"two",delegate:second)); try button(c).sendActions(for:.touchUpInside); XCTAssertEqual(first.calls,0); XCTAssertEqual(second.calls,1) }
    func testExistingReferrerControllerLoadsAndRendersItsModel() throws { let p = ExistingReferralPresenter(), c = YourReferrerViewController(presenter:p); c.loadViewIfNeeded(); let m = YourReferrerViewModel(referrer:"visible-address",delegate:ReferralCloseRecorder()); c.setup(with:[m]); let t = try XCTUnwrap(descendants(UITableView.self,c.view).first); XCTAssertEqual(p.loads,1); XCTAssertEqual(c.tableView(t,numberOfRowsInSection:0),1); XCTAssertTrue(descendants(UILabel.self,c.tableView(t,cellForRowAt:IndexPath(row:0,section:0))).contains{$0.text == "visible-address"}) }
    func testInteractorRecognizesTheSelectedAccountAcrossSS58Prefixes() throws { let key = Data(repeating:3,count:32), factory = SS58AddressFactory(); let selected = try factory.addressFromAccountId(data:key,type:Chain.sora.addressType()), alias = try factory.addressFromAccountId(data:key,type:42); let i = interactor(selected:selected); XCTAssertTrue(i.isCurrentUserAddress(with:alias)) }
    func testInteractorDecodesAValidPublicSoraAddressExactly() throws { let key = Data(repeating:4,count:32), factory = SS58AddressFactory(); let address = try factory.addressFromAccountId(data:key,type:Chain.sora.addressType()); XCTAssertEqual(interactor(selected:"unselected").getAccountId(from:address),key) }
    func testInteractorRejectsInvalidAddressText() { let i = interactor(selected:"wallet"); for value in ["", "invalid", "0x1234"] { XCTAssertNil(i.getAccountId(from:value)) } }
    func testInteractorDoesNotTreatOtherKeysAsTheCurrentWallet() throws { let factory = SS58AddressFactory(); let a = try factory.addressFromAccountId(data:Data(repeating:3,count:32),type:Chain.sora.addressType()), b = try factory.addressFromAccountId(data:Data(repeating:4,count:32),type:42); XCTAssertFalse(interactor(selected:a).isCurrentUserAddress(with:b)) }
    private func interactor(selected:String)->InputLinkInteractor { InputLinkInteractor(operationManager:OperationManager(),operationFactory:ReferralEntryOperations(),addressFactory:SS58AddressFactory(),selectedAccountAddress:selected) }
}
private final class ReferralEntryInput: InputLinkInteractorInputProtocol {
    var current = "self", sent = [String]()
    func sendSetReferrerRequest(with referrerAddress:String) { sent.append(referrerAddress) }
    func isCurrentUserAddress(with address:String)->Bool { address == current }
    func getAccountId(from address:String)->Data? { ["friend","self"].contains(address) ? Data([1,2,3,4]) : nil }
}
private final class ReferralEntryPresenter: InputLinkViewOutput { var loads = 0; func willMove(){loads += 1} }
private final class ExistingReferralPresenter: YourReferrerViewOutput { var loads = 0; func willMove(){loads += 1} }
private final class ReferralCloseRecorder: YourReferrerCellDelegate { var calls = 0; func closeTapped(){calls += 1} }
private final class ReferralEntryOperations: ReferralsOperationFactoryProtocol {
    func createReferrerBalancesOperation()->JSONRPCListOperation<JSONScaleDecodable<Balance>>? { nil }
    func createExtrinsicSetReferrerOperation(with address:String)->BaseOperation<String> { XCTFail("No transport permitted"); return ClosureOperation { "" } }
    func createExtrinsicReserveReferralBalanceOperation(with balance:BigUInt)->BaseOperation<String> { XCTFail("No transport permitted"); return ClosureOperation { "" } }
    func createExtrinsicUnreserveReferralBalanceOperation(with balance:BigUInt)->BaseOperation<String> { XCTFail("No transport permitted"); return ClosureOperation { "" } }
    func createReferrerOperation()->JSONRPCListOperation<String?>? { nil }
}

@MainActor
final class ReferralPresentationLifecycleTests: XCTestCase {
    private func fixture() -> (InputLinkPresenter, ReferralPresenterView, ReferralPresenterOutput) {
        let presenter = InputLinkPresenter(), view = ReferralPresenterView(), output = ReferralPresenterOutput()
        presenter.view = view; presenter.output = output; presenter.interactor = ReferralEntryInput()
        return (presenter, view, output)
    }
    private func settle() async { for _ in 0..<5 { await Task.yield() }; try? await Task.sleep(nanoseconds: 20_000_000) }
    func testPresenterProvidesADisabledReferralEditorOnEntry() async throws {
        let (p, v, _) = fixture(); p.willMove(); await settle()
        let model = try XCTUnwrap(v.models.first as? ReferrerLinkViewModel)
        XCTAssertEqual(v.models.count, 1); XCTAssertEqual(model.isEnabled, false); XCTAssertTrue(p.viewModel === model)
    }
    func testSuccessfulSetReferrerShowsTheReceiptBeforeAdvancing() async throws {
        let (p, v, o) = fixture(); p.willMove(); await settle(); p.viewModel?.address = "friend"
        p.setReferralRequestReceived(with: .success("transaction-hash")); await settle()
        XCTAssertEqual(o.referrers, ["friend"]); XCTAssertEqual(o.addresses, ["friend"])
        XCTAssertTrue((o.controllers.first ?? nil) === v.controller); XCTAssertEqual(o.advances, 0)
        XCTAssertEqual(try o.results.first?.get(), "transaction-hash")
        o.completion?(); XCTAssertEqual(o.advances, 1); XCTAssertEqual(v.pops, 0)
    }
    func testFailedSetReferrerNeverPersistsTheAddressAndReturnsToEntry() async {
        let (p, v, o) = fixture(); p.willMove(); await settle(); p.viewModel?.address = "friend"
        p.setReferralRequestReceived(with: .failure(ReferralLifecycleFailure.offline)); await settle()
        XCTAssertTrue(o.referrers.isEmpty); XCTAssertEqual(o.results.count, 1)
        o.completion?(); XCTAssertEqual(v.pops, 1); XCTAssertEqual(o.advances, 0)
    }
    func testResultBeforeEditorExistsCannotInventAReferrer() async {
        let (p, _, o) = fixture(); p.setReferralRequestReceived(with: .success("hash")); await settle()
        XCTAssertTrue(o.referrers.isEmpty); XCTAssertTrue(o.results.isEmpty)
    }
    func testPresenterDoesNotRetainTheScreenOrOutput() {
        let presenter = InputLinkPresenter()
        var view: ReferralPresenterView? = ReferralPresenterView(), output: ReferralPresenterOutput? = ReferralPresenterOutput()
        weak var oldView = view; weak var oldOutput = output
        presenter.view = view; presenter.output = output; view = nil; output = nil
        XCTAssertNil(oldView); XCTAssertNil(oldOutput)
        presenter.handleCompletion(.failure(ReferralLifecycleFailure.offline))
    }
}
private final class ReferralPresenterView: InputLinkViewInput {
    var isSetup: Bool { true }
    let controller = UIViewController(); var models: [CellViewModel] = []; var pops = 0
    func setup(with models: [CellViewModel]) { self.models = models }
    func dismiss(with completion: @escaping () -> Void) { completion() }
    func pop() { pops += 1 }
}
private final class ReferralPresenterOutput: InputLinkPresenterOutput {
    var referrers: [String] = [], addresses: [String] = [], controllers: [UIViewController?] = []
    var results: [Result<String, Error>] = []; var completion: (() -> Void)?; var advances = 0
    func setupReferrer(_ referrer: String) { referrers.append(referrer) }
    func showAlert(withSuccess isSuccess: Bool) { XCTFail("Receipt presentation owns completion") }
    func showTransactionDetails(from controller: UIViewController?, result: Result<String, Error>, peerAddress: String, completion: (() -> Void)?) {
        controllers.append(controller); results.append(result); addresses.append(peerAddress); self.completion = completion
    }
    func moveForward(controller: UIViewController?) { advances += 1 }
}
private enum ReferralLifecycleFailure: Error { case offline }

final class ReferralRewardLifecycleTests: XCTestCase {
    private func fixture() -> (InputRewardAmountInteractor, WalletNetworkOperationFactoryProtocolMock, ReferralRewardOperations, ReferralRewardOutput) {
        let network = WalletNetworkOperationFactoryProtocolMock(), operations = ReferralRewardOperations(), output = ReferralRewardOutput()
        let asset = AssetInfo(id: WalletAssetId.xor.rawValue, symbol: "XOR", chainId: "", precision: 18, icon: nil, displayName: "XOR", visible: true)
        let interactor = InputRewardAmountInteractor(networkFacade: network, operationFactory: operations, feeAsset: asset)
        interactor.presenter = output; return (interactor, network, operations, output)
    }
    func testReserveUsesExactAtomicUnitsAndDeliversTheTransactionHash() async throws {
        let (i, _, operations, output) = fixture(), done = expectation(description: "receipt")
        output.onResult = { done.fulfill() }
        i.sendReferralBalanceRequest(with: .bond, decimalBalance: Decimal(string: "1.000000000000000001")!)
        await fulfillment(of: [done], timeout: 3)
        XCTAssertEqual(operations.reserved, [BigUInt("1000000000000000001")]); XCTAssertTrue(operations.unreserved.isEmpty)
        XCTAssertEqual(try output.results.first?.get(), "referral-receipt")
    }
    func testUnbondExecutesOnlyTheUnreserveOperation() async throws {
        let (i, _, operations, output) = fixture(), done = expectation(description: "unbond receipt")
        output.onResult = { done.fulfill() }
        i.sendReferralBalanceRequest(with: .unbond, decimalBalance: 2)
        await fulfillment(of: [done], timeout: 3)
        XCTAssertEqual(operations.unreserved, [BigUInt("2000000000000000000")]); XCTAssertEqual(operations.executed, ["unreserve"])
        XCTAssertEqual(try output.results.first?.get(), "referral-receipt")
    }
    func testZeroNegativeAndSubAtomicAmountsCannotReachAnOperation() {
        for amount in [Decimal.zero, -1, Decimal(string: "0.0000000000000000001")!] {
            let (i, _, operations, output) = fixture()
            i.sendReferralBalanceRequest(with: .bond, decimalBalance: amount)
            XCTAssertTrue(operations.reserved.isEmpty); XCTAssertTrue(operations.unreserved.isEmpty)
            XCTAssertEqual(output.results.count, 1)
            guard case let .failure(error)? = output.results.first else { return XCTFail("Invalid amount admitted") }
            XCTAssertTrue(error is WalletNetworkOperationFactoryError)
        }
    }
    func testFailedReservePreservesItsError() async {
        let (i, _, operations, output) = fixture(), done = expectation(description: "failure")
        operations.failure = ReferralLifecycleFailure.offline; output.onResult = { done.fulfill() }
        i.sendReferralBalanceRequest(with: .bond, decimalBalance: 1)
        await fulfillment(of: [done], timeout: 3)
        guard case let .failure(error)? = output.results.first else { return XCTFail("Failure became success") }
        XCTAssertTrue(error is ReferralLifecycleFailure)
    }
    func testCancelledOperationDoesNotInventAReceipt() async {
        let (i, _, operations, output) = fixture(), done = expectation(description: "cancellation")
        operations.cancel = true; output.onResult = { done.fulfill() }
        i.sendReferralBalanceRequest(with: .bond, decimalBalance: 1)
        await fulfillment(of: [done], timeout: 3)
        guard case .failure? = output.results.first else { return XCTFail("Cancellation became success") }
        XCTAssertTrue(operations.executed.isEmpty)
    }
    func testBalanceReadRequestsOnlyTheFeeAssetAndPreservesPrecision() async {
        let (i, network, _, output) = fixture(), done = expectation(description: "balance")
        var requested: [String] = []; output.onBalance = { done.fulfill() }
        network.balanceClosure = { ids in requested = ids; return CompoundOperationWrapper(targetOperation: ClosureOperation { [BalanceData(identifier: WalletAssetId.xor.rawValue, balance: AmountDecimal(string: "1.000000000000000001")!)] }) }
        i.getBalance(); await fulfillment(of: [done], timeout: 3)
        XCTAssertEqual(requested, [WalletAssetId.xor.rawValue]); XCTAssertEqual(output.balances, [Decimal(string: "1.000000000000000001")!])
    }
    func testMissingOrFailedBalanceDoesNotPublishAnInventedZero() async {
        for mode in 0..<3 {
            let (i, network, _, output) = fixture(), executed = expectation(description: "read attempt")
            network.balanceClosure = { _ in CompoundOperationWrapper(targetOperation: ClosureOperation {
                defer { executed.fulfill() }
                if mode == 2 { throw ReferralLifecycleFailure.offline }
                return mode == 0 ? nil : []
            }) }
            i.getBalance(); await fulfillment(of: [executed], timeout: 3)
            try? await Task.sleep(nanoseconds: 20_000_000)
            XCTAssertTrue(output.balances.isEmpty)
        }
    }
}
private final class ReferralRewardOutput: InputRewardAmountInteractorOutputProtocol {
    var balances: [Decimal] = [], results: [Result<String, Error>] = []
    var onBalance: (() -> Void)?, onResult: (() -> Void)?
    func received(_ balance: Decimal) { balances.append(balance); onBalance?() }
    func referralBalanceOperationReceived(with result: Result<String, Error>) { results.append(result); onResult?() }
}
private final class ReferralRewardOperations: ReferralsOperationFactoryProtocol {
    var reserved: [BigUInt] = [], unreserved: [BigUInt] = [], executed: [String] = []
    var failure: Error?, cancel = false
    private func operation(_ name: String) -> BaseOperation<String> {
        let operation = ClosureOperation<String> { self.executed.append(name); if let failure = self.failure { throw failure }; return "referral-receipt" }
        if cancel { operation.cancel() }; return operation
    }
    func createReferrerBalancesOperation() -> JSONRPCListOperation<JSONScaleDecodable<Balance>>? { nil }
    func createExtrinsicSetReferrerOperation(with address: String) -> BaseOperation<String> { XCTFail("Unexpected set-referrer request"); return operation("set") }
    func createExtrinsicReserveReferralBalanceOperation(with balance: BigUInt) -> BaseOperation<String> { reserved.append(balance); return operation("reserve") }
    func createExtrinsicUnreserveReferralBalanceOperation(with balance: BigUInt) -> BaseOperation<String> { unreserved.append(balance); return operation("unreserve") }
    func createReferrerOperation() -> JSONRPCListOperation<String?>? { nil }
}
