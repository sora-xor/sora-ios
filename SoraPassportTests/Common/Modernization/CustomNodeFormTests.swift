// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0
import SoraFoundation
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class CustomNodeFormTests: XCTestCase {
    private func chain(nodes: Set<ChainNodeModel> = [], custom: Set<ChainNodeModel>? = nil) -> ChainModel {
        ChainModel(chainId: SoraNodeConnectionPolicy.mainnetGenesis, name: "SORA", nodes: nodes, addressPrefix: 69,
            icon: nil, selectedNode: nil, customNodes: custom, iosMinAppVersion: nil)
    }
    private func fixture(chain: ChainModel? = nil, mode: NodeAction = .add) -> (CustomNodePresenter, NodeFormView, NodeFormInteractor) {
        let presenter = CustomNodePresenter(chain: chain ?? self.chain(), mode: mode, completion: nil)
        let view = NodeFormView(); let source = NodeFormInteractor(); presenter.view = view; presenter.interactor = source; presenter.wireframe = NodeFormLoading()
        return (presenter, view, source)
    }
    private func validate(_ address: String, name: String = "Fixture") -> Bool {
        let (presenter, view, _) = fixture(); presenter.customNodeNameChange(to: name); presenter.customNodeAddressChange(to: address); return view.enabled
    }
    func testNodeFormAcceptsDomainPortPathAndQuery() {
        for value in ["wss://node.example", "ws://node.example:9944/rpc", "wss://node.example:443/path?network=sora", "wss://NODE.EXAMPLE/path"] { XCTAssertTrue(validate(value), value) }
    }
    func testNodeFormAcceptsIPv4AndIPv6WithExplicitPorts() {
        for value in ["ws://127.0.0.1:9944", "wss://192.0.2.1/rpc", "ws://[::1]:9944", "wss://[2001:db8::1]/rpc"] { XCTAssertTrue(validate(value), value) }
    }
    func testNodeFormRejectsSubstringSchemesAndUnsupportedProtocols() {
        for value in ["prefixwss://node.example", "https://node.example/wss://other.example", "https://node.example", "node.example", "wss://"] { XCTAssertFalse(validate(value), value) }
    }
    func testNodeFormRejectsInvalidIPv4InsteadOfTreatingItAsDNS() {
        for value in ["wss://999.1.1.1", "wss://256.256.256.256", "wss://1.2.3.999", "wss://1.2.3"] { XCTAssertFalse(validate(value), value) }
    }
    func testNodeFormRejectsMissingZeroNegativeAndOutOfRangePorts() {
        for value in ["wss://node.example:", "wss://node.example:0", "wss://node.example:-1", "wss://node.example:65536", "wss://node.example:999999", "wss://node.example:abc"] { XCTAssertFalse(validate(value), value) }
    }
    func testNodeFormRejectsCredentialsAndFragments() {
        for value in ["wss://user@node.example", "wss://user:pass@node.example", "wss://node.example#fragment", "wss://node.example/#fragment"] { XCTAssertFalse(validate(value), value) }
    }
    func testNodeFormRejectsCompromisedHostsWithAllSupportedSpellings() {
        for host in ["mof.sora.org", "ws.mof.sora.org", "mof3.sora.org", "207.254.29.218", "MOF.SORA.ORG."] { XCTAssertFalse(validate("wss://\(host)"), host) }
    }
    func testNodeFormRequiresANonblankName() {
        XCTAssertFalse(validate("wss://node.example", name: "")); XCTAssertFalse(validate("wss://node.example", name: "  \n"))
    }
    func testNodeFormRejectsDuplicateBundledAndCustomNames() {
        let defaultNode = ChainNodeModel(url: URL(string: "wss://default.example")!, name: "Default", apikey: nil)
        let customNode = ChainNodeModel(url: URL(string: "wss://custom.example")!, name: "Custom", apikey: nil)
        let (presenter, view, _) = fixture(chain: chain(nodes: [defaultNode], custom: [customNode]))
        presenter.customNodeAddressChange(to: "wss://new.example")
        for name in ["Default", "Custom"] { presenter.customNodeNameChange(to: name); XCTAssertFalse(view.enabled); XCTAssertFalse(view.nameErrors.isEmpty) }
    }
    func testNodeFormComparesOnlySchemeAndHostCaseInsensitivelyForDuplicates() {
        let node = ChainNodeModel(url: URL(string: "wss://NODE.EXAMPLE/CaseSensitive")!, name: "Saved", apikey: nil)
        let (presenter, view, _) = fixture(chain: chain(custom: [node]))
        presenter.customNodeNameChange(to: "Other"); presenter.customNodeAddressChange(to: "wss://node.example/CaseSensitive"); XCTAssertFalse(view.enabled)
        presenter.customNodeAddressChange(to: "wss://node.example/casesensitive"); XCTAssertTrue(view.enabled)
    }
    func testEditingNodeCanKeepItsOwnNameAndAddress() {
        let node = ChainNodeModel(url: URL(string: "wss://saved.example")!, name: "Saved", apikey: nil)
        let (presenter, view, _) = fixture(chain: chain(custom: [node]), mode: .edit(node: node))
        presenter.setup(); XCTAssertEqual(view.name, "Saved"); XCTAssertEqual(view.address, "wss://saved.example")
        presenter.customNodeNameChange(to: "Saved"); XCTAssertTrue(view.enabled)
    }
    func testInvalidNodeCannotBeSubmittedByAnObsoleteButtonAction() {
        let (presenter, _, source) = fixture(); presenter.customNodeNameChange(to: "Fixture"); presenter.customNodeAddressChange(to: "https://invalid.example")
        presenter.submitButtonTapped(); XCTAssertTrue(source.updates.isEmpty)
    }
    func testValidNodeSubmissionPassesExactCaseSensitivePath() {
        let (presenter, _, source) = fixture(); presenter.customNodeNameChange(to: "Fixture"); presenter.customNodeAddressChange(to: "wss://node.example/Rpc?Token=AbC")
        presenter.submitButtonTapped(); XCTAssertEqual(source.updates.first?.0.absoluteString, "wss://node.example/Rpc?Token=AbC"); XCTAssertEqual(source.updates.first?.1, "Fixture")
    }
    func testInvalidNodeErrorIsShownOnTheAddressField() {
        let (presenter, view, _) = fixture(); presenter.didReceive(error: .noSigningRoute)
        XCTAssertEqual(view.addressErrors.last, Sora2NodeSigningRoute.missingRouteFieldText)
    }
    func testScreenForwardsEditsAndButtonsWithoutOpeningExternalApps() {
        let spy = NodeFormPresenter(); let screen = CustomNodeViewController(presenter: spy); screen.loadViewIfNeeded()
        XCTAssertEqual(spy.calls, ["setup"])
        screen.nodeNameTextField.textField.text = "New"; screen.nodeNameTextField.textField.sendActions(for: .editingChanged)
        screen.nodeAddressTextField.textField.text = "wss://node.example"; screen.nodeAddressTextField.textField.sendActions(for: .editingChanged)
        screen.submitTapped(); screen.howToRunTapped(); screen.chestTapped()
        XCTAssertEqual(spy.names, ["New"]); XCTAssertEqual(spy.addresses, ["wss://node.example"]); XCTAssertEqual(spy.calls, ["setup", "submit", "help", "close"])
    }
    func testScreenCanShowAndClearErrorsOnBothInputs() {
        let screen = CustomNodeViewController(presenter: NodeFormPresenter()); screen.loadViewIfNeeded()
        screen.showNameTextField("Duplicate"); screen.showAddressTextField("Invalid")
        XCTAssertEqual(screen.nodeNameTextField.sora.state, .fail); XCTAssertEqual(screen.nodeAddressTextField.sora.state, .fail)
        screen.resetState(); XCTAssertEqual(screen.nodeNameTextField.sora.state, .default); XCTAssertEqual(screen.nodeAddressTextField.sora.state, .default)
        screen.changeSubmitButton(to: true); XCTAssertTrue(screen.submitButton.isEnabled); screen.changeSubmitButton(to: false); XCTAssertFalse(screen.submitButton.isEnabled)
    }
    func testScreenInitialFieldsRetainExactURL() {
        let screen = CustomNodeViewController(presenter: NodeFormPresenter()); screen.loadViewIfNeeded()
        screen.updateFields(name: "Node", url: "wss://node.example/Case")
        XCTAssertEqual(screen.nodeNameTextField.textField.text, "Node"); XCTAssertEqual(screen.nodeAddressTextField.textField.text, "wss://node.example/Case")
    }
}
private final class NodeFormView: UIViewController, CustomNodeViewProtocol {
    var controller: UIViewController { self }; var enabled = false; var nameErrors: [String] = []; var addressErrors: [String] = []; var name = ""; var address = ""
    func changeSubmitButton(to isEnabled: Bool) { enabled = isEnabled }
    func showNameTextField(_ error: String) { nameErrors.append(error) }
    func showAddressTextField(_ error: String) { addressErrors.append(error) }
    func updateFields(name: String, url: String) { self.name = name; address = url }
    func resetState() {}
}
private final class NodeFormInteractor: CustomNodeInteractorInputProtocol { var updates: [(URL, String)] = []; func updateCustomNode(url: URL, name: String) { updates.append((url, name)) } }
private final class NodeFormLoading: Loadable { var activityIndicatorWindow: UIWindow?; func showActivityIndicator() {}; func hideActivityIndicator() {} }
private final class NodeFormPresenter: CustomNodePresenterProtocol {
    var calls: [String] = []; var names: [String] = []; var addresses: [String] = []
    func setup() { calls.append("setup") }
    func chestButtonTapped() { calls.append("close") }
    func howToRunButtonTapped() { calls.append("help") }
    func customNodeNameChange(to text: String) { names.append(text) }
    func customNodeAddressChange(to text: String) { addresses.append(text) }
    func submitButtonTapped() { calls.append("submit") }
}
