// SPDX-License-Identifier: BSD-4-Clause
import SoraFoundation
import SoraUIKit
import UIKit
import XCTest

@testable import SoraPassport

@MainActor final class TransactionReviewRenderingTests: XCTestCase {
  private func descendants<T: UIView>(_ type: T.Type, _ root: UIView) -> [T] {
    ((root as? T).map { [$0] } ?? []) + root.subviews.flatMap { descendants(type, $0) }
  }
  private func texts(_ root: UIView) -> [String] {
    descendants(UILabel.self, root).filter { !$0.isHidden }.compactMap {
      $0.text ?? $0.attributedText?.string
    }
  }
  private func text(_ value: String) -> SoramitsuTextItem {
    .init(text: value, fontData: FontType.textM, textColor: .fgPrimary)
  }
  private func detail(_ title: String, fiat: Bool = false, image: Bool = false) -> DetailViewModel {
    .init(
      title: title, rewardAssetImage: image ? UIImage(systemName: "star") : nil,
      assetAmountText: text("3 XOR"), fiatAmountText: fiat ? text("$4") : nil)
  }
  private func button(_ cell: UITableViewCell) throws -> SoramitsuButton {
    try XCTUnwrap(descendants(SoramitsuButton.self, cell).first)
  }
  private func settle() async { try? await Task.sleep(nanoseconds: 30_000_000) }
  func testDetailRowsDisplayAmountAndFiatExactly() {
    let cell = ConfirmDetailsCell()
    let item = ConfirmDetailsItem(detailViewModels: [detail("Network fee", fiat: true)])
    cell.set(item: item, context: nil)
    XCTAssertTrue(texts(cell).contains("Network fee"))
    XCTAssertTrue(texts(cell).contains("3 XOR"))
    XCTAssertTrue(texts(cell).contains("$4"))
  }
  func testDetailRebindingReplacesPreviousRows() {
    let cell = ConfirmDetailsCell()
    cell.set(item: ConfirmDetailsItem(detailViewModels: [detail("Old")]), context: nil)
    cell.set(
      item: ConfirmDetailsItem(detailViewModels: [detail("Current"), detail("Fee")]), context: nil)
    XCTAssertFalse(texts(cell).contains("Old"))
    XCTAssertEqual(descendants(DetailView.self, cell).count, 2)
  }
  func testEmptyDetailsRemoveAllPreviousRows() {
    let cell = ConfirmDetailsCell()
    cell.set(item: ConfirmDetailsItem(detailViewModels: [detail("Old")]), context: nil)
    cell.set(item: ConfirmDetailsItem(detailViewModels: []), context: nil)
    XCTAssertTrue(descendants(DetailView.self, cell).isEmpty)
  }
  func testDetailWithoutFiatHidesTheFiatLabel() throws {
    let cell = ConfirmDetailsCell()
    cell.set(item: ConfirmDetailsItem(detailViewModels: [detail("Fee")]), context: nil)
    let row = try XCTUnwrap(descendants(DetailView.self, cell).first)
    XCTAssertTrue(row.fiatValueLabel.isHidden)
    XCTAssertTrue(row.infoButton.isHidden)
  }
  func testDetailWithAnAssetImageShowsThatImage() throws {
    let cell = ConfirmDetailsCell()
    cell.set(
      item: ConfirmDetailsItem(detailViewModels: [detail("Reward", image: true)]), context: nil)
    XCTAssertFalse(try XCTUnwrap(descendants(DetailView.self, cell).first).assetImageView.isHidden)
  }
  func testDetailWithoutAssetImageHidesItsImage() throws {
    let cell = ConfirmDetailsCell()
    cell.set(item: ConfirmDetailsItem(detailViewModels: [detail("Fee")]), context: nil)
    XCTAssertTrue(try XCTUnwrap(descendants(DetailView.self, cell).first).assetImageView.isHidden)
  }
  func testDetailInfoButtonInvokesTheCurrentInformationAction() throws {
    let cell = ConfirmDetailsCell()
    let model = detail("Fee")
    var calls = 0
    model.infoHandler = { calls += 1 }
    let item = ConfirmDetailsItem(detailViewModels: [model])
    cell.set(item: item, context: nil)
    let row = try XCTUnwrap(descendants(DetailView.self, cell).first)
    XCTAssertFalse(row.infoButton.isHidden)
    row.infoButton.sendActions(for: .touchUpInside)
    XCTAssertEqual(calls, 1)
  }
  func testDetailRebindingDoesNotRetainOldModels() {
    let cell = ConfirmDetailsCell()
    var old: DetailViewModel? = detail("Old")
    weak var reference = old
    cell.set(item: ConfirmDetailsItem(detailViewModels: [old!]), context: nil)
    old = nil
    cell.set(item: ConfirmDetailsItem(detailViewModels: [detail("New")]), context: nil)
    XCTAssertNil(reference)
  }
  func testConfirmButtonShowsItsExactTitle() throws {
    let cell = SoramitsuButtonCell()
    let item = SoramitsuButtonItem(title: text("Review 3 XOR"), handler: nil)
    cell.set(item: item, context: nil)
    XCTAssertTrue(texts(cell).contains("Review 3 XOR"))
    XCTAssertTrue(try button(cell).isEnabled)
  }
  func testDisabledConfirmButtonCannotReceiveUserInteraction() throws {
    let cell = SoramitsuButtonCell()
    cell.set(
      item: SoramitsuButtonItem(title: text("Waiting"), isEnable: false, handler: nil), context: nil
    )
    XCTAssertFalse(try button(cell).isEnabled)
  }
  func testButtonRebindingUsesOnlyTheNewHandler() throws {
    let cell = SoramitsuButtonCell()
    var old = 0
    var current = 0
    cell.set(item: SoramitsuButtonItem(title: text("Old"), handler: { old += 1 }), context: nil)
    cell.set(
      item: SoramitsuButtonItem(title: text("Current"), handler: { current += 1 }), context: nil)
    try button(cell).sendActions(for: .touchUpInside)
    XCTAssertEqual(old, 0)
    XCTAssertEqual(current, 1)
  }
  func testButtonRebindingReleasesTheOldItem() {
    let cell = SoramitsuButtonCell()
    var item: SoramitsuButtonItem? = SoramitsuButtonItem(title: text("Old"), handler: nil)
    weak var reference = item
    cell.set(item: item!, context: nil)
    item = nil
    cell.set(item: SoramitsuButtonItem(title: text("Current"), handler: nil), context: nil)
    XCTAssertNil(reference)
  }
  func testButtonWithNoCustomColorResetsThePreviousCustomColor() throws {
    let cell = SoramitsuButtonCell()
    let fresh = SoramitsuButtonCell()
    cell.set(
      item: SoramitsuButtonItem(
        title: text("Old"), buttonBackgroudColor: .statusError, handler: nil), context: nil)
    let item = SoramitsuButtonItem(title: text("Current"), handler: nil)
    cell.set(item: item, context: nil)
    fresh.set(item: item, context: nil)
    XCTAssertEqual(try button(cell).backgroundColor, try button(fresh).backgroundColor)
  }
  func testReviewTextRebindingReplacesTheOldMessage() {
    let cell = SoraTextCell()
    cell.set(item: SoraTextItem(text: text("Old warning")), context: nil)
    cell.set(item: SoraTextItem(text: text("Current message")), context: nil)
    XCTAssertTrue(texts(cell).contains("Current message"))
    XCTAssertFalse(texts(cell).contains("Old warning"))
  }
  func testReviewWarningDisplaysTheFirstProviderWarning() {
    let cell = WarningCell()
    cell.set(item: WarningItem(), context: nil)
    XCTAssertEqual(
      cell.contentLabel.sora.text,
      R.string.localizable.confirnSupplyLiquidityFirstProviderWarning(
        preferredLanguages: .currentLocale))
    XCTAssertEqual(cell.contentLabel.numberOfLines, 0)
  }
  func testAssetIdentifierDisplaysTheCompleteValue() {
    let cell = AssetIdCell()
    let id = "0x" + String(repeating: "ab", count: 32)
    cell.set(item: AssetIdItem(assetId: id, tapHandler: nil), context: nil)
    XCTAssertTrue(texts(cell).contains(id))
  }
  func testAssetIdentifierRebindingReplacesTheOldIdentifier() {
    let cell = AssetIdCell()
    cell.set(item: AssetIdItem(assetId: "old", tapHandler: nil), context: nil)
    cell.set(item: AssetIdItem(assetId: "current", tapHandler: nil), context: nil)
    XCTAssertTrue(texts(cell).contains("current"))
    XCTAssertFalse(texts(cell).contains("old"))
  }
  func testAssetIdentifierActionCallsItsCurrentHandler() {
    var calls = 0
    let item = AssetIdItem(assetId: "fixture", tapHandler: { calls += 1 })
    item.itemActionTap(with: nil)
    XCTAssertEqual(calls, 1)
  }
  func testReviewControllerLoadsItsModelOnce() {
    let model = ReviewRenderingModel()
    let view = ConfirmViewController(viewModel: model)
    view.loadViewIfNeeded()
    view.loadViewIfNeeded()
    XCTAssertEqual(model.loads, 1)
  }
  func testReviewControllerDisplaysTheModelsTitle() {
    let model = ReviewRenderingModel()
    let view = ConfirmViewController(viewModel: model)
    view.loadViewIfNeeded()
    XCTAssertEqual(view.navigationItem.title, "Review transaction")
  }
  func testReviewControllerDisplaysTheModelsLogo() {
    let model = ReviewRenderingModel()
    model.imageName = "Wallet/polkaswapLogo"
    let view = ConfirmViewController(viewModel: model)
    view.loadViewIfNeeded()
    XCTAssertTrue(view.navigationItem.titleView is UIImageView)
  }
  func testReviewControllerCallsDisappearanceForCancellation() {
    let model = ReviewRenderingModel()
    let view = ConfirmViewController(viewModel: model)
    view.loadViewIfNeeded()
    view.viewWillDisappear(false)
    XCTAssertEqual(model.disappearances, 1)
  }
  func testReviewControllerRendersThePublishedConfirmationRows() async throws {
    let model = ReviewRenderingModel()
    let view = ConfirmViewController(viewModel: model)
    view.loadViewIfNeeded()
    model.setupItems?([SoraTextItem(text: text("Review this transfer")), WarningItem()])
    await settle()
    let table = try XCTUnwrap(descendants(UITableView.self, view.view).first)
    XCTAssertEqual(table.numberOfRows(inSection: 0), 2)
  }
  func testReviewControllerReplacementRemovesThePreviousRows() async throws {
    let model = ReviewRenderingModel()
    let view = ConfirmViewController(viewModel: model)
    view.loadViewIfNeeded()
    model.setupItems?([WarningItem(), WarningItem()])
    await settle()
    model.setupItems?([SoraTextItem(text: text("Current"))])
    await settle()
    let table = try XCTUnwrap(descendants(UITableView.self, view.view).first)
    XCTAssertEqual(table.numberOfRows(inSection: 0), 1)
  }
  func testReviewCallbacksDoNotRetainTheirController() async {
    let model = ReviewRenderingModel()
    var view: ConfirmViewController? = ConfirmViewController(viewModel: model)
    view?.loadViewIfNeeded()
    weak var reference = view
    view = nil
    await settle()
    XCTAssertNil(reference)
  }
}
private final class ReviewRenderingModel: ConfirmViewModelProtocol {
  var title: String? = "Review transaction", imageName: String?
  var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?,
    reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
  var loads = 0, disappearances = 0
  func viewDidLoad() { loads += 1 }
  func viewWillDisappear() { disappearances += 1 }
}
