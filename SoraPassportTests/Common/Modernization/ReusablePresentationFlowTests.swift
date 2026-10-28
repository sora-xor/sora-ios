// SPDX-License-Identifier: Apache-2.0
import SoraFoundation
import SoraUIKit
import UIKit
import XCTest

@testable import SoraPassport

@MainActor
@available(iOS 17.0, *)
final class ReusablePresentationFlowTests: XCTestCase {
  private func all<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
    ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { all(type, in: $0) }
  }
  private func pool(_ id: String) -> PoolViewModel {
    .init(identifier: id, title: "Pool \(id)", subtitle: "Shares \(id)", fiatText: "$\(id)")
  }
  private func pooled(_ ids: [String], _ action: ((String) -> Void)? = nil) -> PooledItem {
    let item = PooledItem(assetSymbol: "XOR", poolViewModels: ids.map(pool))
    item.openPoolDetailsHandler = action
    return item
  }
  func testPooledCellDisplaysEveryPoolWithAssociatedAmounts() {
    let cell = PooledCell(style: .default, reuseIdentifier: nil)
    cell.set(item: pooled(["1", "2"]), context: nil)
    let rows = all(PoolView.self, in: cell)
    XCTAssertEqual(rows.count, 2)
    XCTAssertEqual(rows.map { $0.titleLabel.sora.text }, ["Pool 1", "Pool 2"])
    XCTAssertEqual(rows.map { $0.subtitleLabel.sora.text }, ["Shares 1", "Shares 2"])
    XCTAssertEqual(rows.map { $0.amountUpLabel.sora.text }, ["$1", "$2"])
  }
  func testPooledReuseReplacesRowsWithoutAccumulatingOldControls() {
    let cell = PooledCell(style: .default, reuseIdentifier: nil)
    cell.set(item: pooled(["1", "2"]), context: nil)
    cell.set(item: pooled(["3"]), context: nil)
    XCTAssertEqual(all(PoolView.self, in: cell).map { $0.titleLabel.sora.text }, ["Pool 3"])
  }
  func testPooledReuseWithNoPositionsClearsAllOldRows() {
    let cell = PooledCell(style: .default, reuseIdentifier: nil)
    cell.set(item: pooled(["1"]), context: nil)
    cell.set(item: pooled([]), context: nil)
    XCTAssertTrue(all(PoolView.self, in: cell).isEmpty)
  }
  func testPooledTapDeliversOnlySelectedPoolIdentifier() throws {
    var ids = [String]()
    let cell = PooledCell(style: .default, reuseIdentifier: nil)
    cell.set(item: pooled(["1", "2"]) { ids.append($0) }, context: nil)
    try XCTUnwrap(all(PoolView.self, in: cell).last).sendActions(for: .touchUpInside)
    XCTAssertEqual(ids, ["2"])
  }
  func testPooledReuseUpdatesTheActionOwner() throws {
    var old = [String]()
    var fresh = [String]()
    let cell = PooledCell(style: .default, reuseIdentifier: nil)
    cell.set(item: pooled(["1"]) { old.append($0) }, context: nil)
    cell.set(item: pooled(["2"]) { fresh.append($0) }, context: nil)
    try XCTUnwrap(all(PoolView.self, in: cell).first).sendActions(for: .touchUpInside)
    XCTAssertTrue(old.isEmpty)
    XCTAssertEqual(fresh, ["2"])
  }
  func testPoolRowsAreImmediatelyReadableWithoutLoadingPlaceholders() throws {
    let cell = PooledCell(style: .default, reuseIdentifier: nil)
    cell.set(item: pooled(["1"]), context: nil)
    let row = try XCTUnwrap(all(PoolView.self, in: cell).first)
    XCTAssertEqual(row.titleLabel.sora.loadingPlaceholder.type, .none)
    XCTAssertEqual(row.amountUpLabel.sora.loadingPlaceholder.type, .none)
  }
  func testSegmentReuseChangesTheDisplayedTab() {
    let cell = SegmentCell(frame: .zero)
    for tab in ExploreTabs.allCases {
      cell.set(item: SegmentItem(tab: tab))
      XCTAssertEqual(cell.titleLabel.sora.text, tab.title)
    }
  }
  func testSegmentSelectionColorsFollowTheCurrentItem() {
    let cell = SegmentCell(frame: .zero)
    cell.set(item: SegmentItem(tab: .assets, isSelected: true))
    let selected = cell.titleLabel.textColor
    cell.set(item: SegmentItem(tab: .pools, isSelected: false))
    XCTAssertNotEqual(cell.titleLabel.textColor, selected)
    cell.set(item: SegmentItem(tab: .farms, isSelected: true))
    XCTAssertEqual(cell.titleLabel.textColor, selected)
  }
  func testNodeButtonReuseChangesTitleAndEnabledState() throws {
    let cell = ButtonCell(style: .default, reuseIdentifier: nil)
    let recorder = CellButtonRecorder()
    cell.bind(viewModel: ButtonViewModel(title: "Save", delegate: recorder))
    let button = try XCTUnwrap(all(SoramitsuButton.self, in: cell).first)
    XCTAssertEqual(button.sora.title, "Save")
    XCTAssertTrue(button.sora.isEnabled)
    cell.bind(viewModel: ButtonViewModel(title: "Retry", isEnabled: false, delegate: recorder))
    XCTAssertEqual(button.sora.title, "Retry")
    XCTAssertFalse(button.sora.isEnabled)
  }
  func testNodeButtonUsesOnlyTheCurrentDelegate() throws {
    let cell = ButtonCell(style: .default, reuseIdentifier: nil)
    let first = CellButtonRecorder()
    let second = CellButtonRecorder()
    cell.bind(viewModel: ButtonViewModel(title: "First", delegate: first))
    cell.bind(viewModel: ButtonViewModel(title: "Second", delegate: second))
    try XCTUnwrap(all(SoramitsuButton.self, in: cell).first).sendActions(for: .touchUpInside)
    XCTAssertEqual(first.count, 0)
    XCTAssertEqual(second.count, 1)
  }
  func testNodeButtonHonorsViewModelColorsOnReuse() throws {
    let cell = ButtonCell(style: .default, reuseIdentifier: nil)
    let recorder = CellButtonRecorder()
    let color = SoramitsuColor.custom(uiColor: .red)
    cell.bind(
      viewModel: ButtonViewModel(
        title: "Delete", titleColor: color, backgroundColor: .custom(uiColor: .green),
        delegate: recorder))
    let button = try XCTUnwrap(all(SoramitsuButton.self, in: cell).first)
    XCTAssertEqual(button.backgroundColor, .green)
    XCTAssertEqual(
      all(UILabel.self, in: button).first?.attributedText?.attribute(
        .foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .red)
  }
  func testNodeHeaderReuseShowsOnlyTheCurrentSectionTitle() {
    let cell = NodesHeaderCell(style: .default, reuseIdentifier: nil)
    cell.bind(viewModel: NodesHeaderViewModel(title: "Recommended"))
    cell.bind(viewModel: NodesHeaderViewModel(title: "Custom"))
    XCTAssertEqual(all(UILabel.self, in: cell).compactMap(\.text), ["Custom"])
  }
  private func sent(_ symbol: String, _ amount: String, balance: String = "12", fiat: String = "$3")
    -> SendAssetItem
  { .init(imageViewModel: nil, symbol: symbol, amount: amount, balance: balance, fiat: fiat) }
  func testSentAssetDisplaysSeparateSymbolAmountBalanceAndFiat() throws {
    let cell = SendAssetCell(style: .default, reuseIdentifier: nil)
    cell.set(item: sent("XOR", "1.25"), context: nil)
    let row = try XCTUnwrap(all(SendAssetView.self, in: cell).first)
    XCTAssertEqual(row.symbolLabel.sora.text, "XOR")
    XCTAssertEqual(row.amountLabel.sora.text, "1.25")
    XCTAssertEqual(row.balanceLabel.sora.text, "12")
    XCTAssertEqual(row.fiatLabel.sora.text, "$3")
  }
  func testSentAssetReuseClearsPriorAmounts() throws {
    let cell = SendAssetCell(style: .default, reuseIdentifier: nil)
    cell.set(item: sent("XOR", "1.25"), context: nil)
    cell.set(item: sent("VAL", "0", balance: "", fiat: ""), context: nil)
    let row = try XCTUnwrap(all(SendAssetView.self, in: cell).first)
    XCTAssertEqual(row.symbolLabel.sora.text, "VAL")
    XCTAssertEqual(row.amountLabel.sora.text, "0")
    XCTAssertEqual(row.balanceLabel.sora.text, "")
    XCTAssertEqual(row.fiatLabel.sora.text, "")
  }
  func testSentAssetWithoutImageClearsAnImageFromAnEarlierBinding() throws {
    let cell = SendAssetCell(style: .default, reuseIdentifier: nil)
    let row = try XCTUnwrap(all(SendAssetView.self, in: cell).first)
    row.assetImageView.image = UIImage(systemName: "star")
    cell.set(item: sent("VAL", "1"), context: nil)
    XCTAssertNil(row.assetImageView.image)
  }
  func testRecipientReuseChangesAddressAndKeepsItNonNavigable() {
    let cell = RecipientAddressCell(style: .default, reuseIdentifier: nil)
    cell.set(item: RecipientAddressItem(address: "first"), context: nil)
    cell.set(item: RecipientAddressItem(address: "second"), context: nil)
    XCTAssertEqual(cell.recipientView.contactView.accountTitle.sora.text, "second")
    XCTAssertTrue(cell.recipientView.contactView.arrowImageView.isHidden)
  }
  func testInvalidRecipientClearsAnyPreviouslyRenderedIcon() {
    let cell = RecipientAddressCell(style: .default, reuseIdentifier: nil)
    cell.recipientView.contactView.accountImageView.image = UIImage(systemName: "star")
    cell.set(item: RecipientAddressItem(address: "invalid"), context: nil)
    XCTAssertNil(cell.recipientView.contactView.accountImageView.image)
  }
  func testSettingsReuseRemovesArrowWhenSwitchIsShown() {
    let cell = AppSettingsCell(style: .default, reuseIdentifier: nil)
    cell.set(item: AppSettingsItem(title: "Arrow", rightItem: .arrow), context: nil)
    cell.set(item: AppSettingsItem(title: "Toggle", rightItem: .switcher(state: .on)), context: nil)
    XCTAssertFalse(cell.menuItem.horizontalStack.arrangedSubviews.contains(cell.menuItem.arrow))
    XCTAssertTrue(cell.menuItem.horizontalStack.arrangedSubviews.contains(cell.menuItem.switcher))
  }
  func testSettingsReuseRemovesSwitchWhenArrowIsShown() {
    let cell = AppSettingsCell(style: .default, reuseIdentifier: nil)
    cell.set(item: AppSettingsItem(title: "Toggle", rightItem: .switcher(state: .on)), context: nil)
    cell.set(item: AppSettingsItem(title: "Arrow", rightItem: .arrow), context: nil)
    XCTAssertFalse(cell.menuItem.horizontalStack.arrangedSubviews.contains(cell.menuItem.switcher))
    XCTAssertTrue(cell.menuItem.horizontalStack.arrangedSubviews.contains(cell.menuItem.arrow))
  }
  func testSettingsSwitchReuseRestoresEnabledState() {
    let cell = AppSettingsCell(style: .default, reuseIdentifier: nil)
    cell.set(
      item: AppSettingsItem(title: "Locked", rightItem: .switcher(state: .disabled)), context: nil)
    XCTAssertFalse(cell.menuItem.switcher.isEnabled)
    cell.set(
      item: AppSettingsItem(title: "Enabled", rightItem: .switcher(state: .off)), context: nil)
    XCTAssertTrue(cell.menuItem.switcher.isEnabled)
    XCTAssertFalse(cell.menuItem.switcher.isOn)
  }
  func testSettingsTapOnlyCallsCurrentOwner() {
    var first = 0
    var second = 0
    let cell = AppSettingsCell(style: .default, reuseIdentifier: nil)
    cell.set(
      item: AppSettingsItem(title: "A", rightItem: .arrow, onTap: { first += 1 }), context: nil)
    cell.set(
      item: AppSettingsItem(title: "B", rightItem: .arrow, onTap: { second += 1 }), context: nil)
    cell.menuItem.didTap()
    XCTAssertEqual(first, 0)
    XCTAssertEqual(second, 1)
  }
  func testSettingsRepeatedRebindDoesNotDuplicateSwitchCallbacks() {
    var values = [Bool]()
    let cell = AppSettingsCell(style: .default, reuseIdentifier: nil)
    for _ in 0..<4 {
      cell.set(
        item: AppSettingsItem(
          title: "Switch", rightItem: .switcher(state: .off), onSwitch: { values.append($0) }),
        context: nil)
    }
    cell.menuItem.switcher.isOn = true
    cell.menuItem.switcher.sendActions(for: .valueChanged)
    XCTAssertEqual(values, [true])
  }
  func testAppearanceRebindReplacesChoiceLabelsAndSelection() {
    let cell = AppAppearanceCell(style: .default, reuseIdentifier: nil)
    cell.set(
      item: AppAppearanceItem(
        title: "First", choices: ["A", "B", "C"], selectedIndex: 2, onSelect: { _ in }),
      context: nil)
    cell.set(
      item: AppAppearanceItem(
        title: "Current", choices: ["X", "Y"], selectedIndex: 0, onSelect: { _ in }), context: nil)
    XCTAssertEqual(cell.selector.numberOfSegments, 2)
    XCTAssertEqual(cell.selector.titleForSegment(at: 1), "Y")
    XCTAssertEqual(cell.selector.selectedSegmentIndex, 0)
    XCTAssertEqual(cell.selector.accessibilityLabel, "Current")
  }
  func testAppearanceSelectionUsesCurrentCallback() {
    var old = [Int]()
    var fresh = [Int]()
    let cell = AppAppearanceCell(style: .default, reuseIdentifier: nil)
    cell.set(
      item: AppAppearanceItem(
        title: "Old", choices: ["A", "B"], selectedIndex: 0, onSelect: { old.append($0) }),
      context: nil)
    cell.set(
      item: AppAppearanceItem(
        title: "New", choices: ["X", "Y"], selectedIndex: 0, onSelect: { fresh.append($0) }),
      context: nil)
    cell.selector.selectedSegmentIndex = 1
    cell.selector.sendActions(for: .valueChanged)
    XCTAssertTrue(old.isEmpty)
    XCTAssertEqual(fresh, [1])
  }
  func testAppearanceAccessibilityLayoutShowsOnlyOneControlSet() async throws {
    let host = UIViewController()
    let parent = UIViewController()
    let scene = try XCTUnwrap(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let oldWindow = scene.windows.first { $0.isKeyWindow }
    let window = UIWindow(windowScene: scene)
    window.rootViewController = parent
    window.frame = scene.coordinateSpace.bounds
    window.makeKeyAndVisible()
    defer {
      window.isHidden = true
      window.rootViewController = nil
      oldWindow?.makeKeyAndVisible()
    }
    parent.addChild(host)
    parent.view.addSubview(host.view)
    host.didMove(toParent: parent)
    let cell = AppAppearanceCell(style: .default, reuseIdentifier: nil)
    cell.set(
      item: AppAppearanceItem(
        title: "Theme", choices: ["Light", "Dark"], selectedIndex: 1, onSelect: { _ in }),
      context: nil)
    host.view.addSubview(cell)
    parent.setOverrideTraitCollection(
      UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
      forChild: host)
    window.layoutIfNeeded()
    try await Task.sleep(nanoseconds: 35_000_000)
    cell.traitCollectionDidChange(nil)
    XCTAssertTrue(cell.traitCollection.preferredContentSizeCategory.isAccessibilityCategory)
    XCTAssertNil(cell.selector.superview)
    let buttons = all(UIButton.self, in: cell).filter {
      $0.title(for: .normal) == "Light" || $0.title(for: .normal) == "Dark"
    }
    XCTAssertEqual(buttons.count, 2)
    XCTAssertEqual(
      buttons.filter { $0.accessibilityTraits.contains(.selected) }.map { $0.title(for: .normal) },
      ["Dark"])
  }
  func testAppearanceReturnsToSegmentsAfterAccessibilitySizeShrinks() async throws {
    let host = UIViewController()
    let parent = UIViewController()
    let scene = try XCTUnwrap(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let oldWindow = scene.windows.first { $0.isKeyWindow }
    let window = UIWindow(windowScene: scene)
    window.rootViewController = parent
    window.frame = scene.coordinateSpace.bounds
    window.makeKeyAndVisible()
    defer {
      window.isHidden = true
      window.rootViewController = nil
      oldWindow?.makeKeyAndVisible()
    }
    parent.addChild(host)
    parent.view.addSubview(host.view)
    host.didMove(toParent: parent)
    let cell = AppAppearanceCell(style: .default, reuseIdentifier: nil)
    cell.set(
      item: AppAppearanceItem(
        title: "Theme", choices: ["Light", "Dark"], selectedIndex: 1, onSelect: { _ in }),
      context: nil)
    host.view.addSubview(cell)
    parent.setOverrideTraitCollection(
      UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge),
      forChild: host)
    window.layoutIfNeeded()
    try await Task.sleep(nanoseconds: 35_000_000)
    cell.traitCollectionDidChange(nil)
    parent.setOverrideTraitCollection(
      UITraitCollection(preferredContentSizeCategory: .large), forChild: host)
    window.layoutIfNeeded()
    try await Task.sleep(nanoseconds: 35_000_000)
    cell.traitCollectionDidChange(nil)
    XCTAssertNotNil(cell.selector.superview)
    XCTAssertEqual(cell.selector.selectedSegmentIndex, 1)
  }
  func testLateImageFromPreviousBindingCannotReplaceCurrentAsset() throws {
    let cell = SendAssetCell(style: .default, reuseIdentifier: nil)
    let old = ReuseImageLoader()
    let fresh = ReuseImageLoader()
    cell.set(
      item: SendAssetItem(imageViewModel: old, symbol: "OLD", amount: "1", balance: "2", fiat: "3"),
      context: nil)
    cell.set(
      item: SendAssetItem(
        imageViewModel: fresh, symbol: "NEW", amount: "4", balance: "5", fiat: "6"), context: nil)
    let expected = UIImage(systemName: "circle")!
    fresh.complete(expected)
    old.complete(UIImage(systemName: "star"))
    XCTAssertTrue(
      try XCTUnwrap(all(SendAssetView.self, in: cell).first).assetImageView.image === expected)
  }
  func testLateImageCannotPopulateAnAssetWithNoImage() throws {
    let cell = SendAssetCell(style: .default, reuseIdentifier: nil)
    let loader = ReuseImageLoader()
    cell.set(
      item: SendAssetItem(
        imageViewModel: loader, symbol: "OLD", amount: "1", balance: "2", fiat: "3"), context: nil)
    cell.set(item: sent("NEW", "1"), context: nil)
    loader.complete(UIImage(systemName: "star"))
    XCTAssertNil(try XCTUnwrap(all(SendAssetView.self, in: cell).first).assetImageView.image)
  }
  func testPreparingAReusedCellInvalidatesItsPendingImage() throws {
    let cell = SendAssetCell(style: .default, reuseIdentifier: nil)
    let loader = ReuseImageLoader()
    cell.set(
      item: SendAssetItem(
        imageViewModel: loader, symbol: "OLD", amount: "1", balance: "2", fiat: "3"), context: nil)
    cell.prepareForReuse()
    loader.complete(UIImage(systemName: "star"))
    XCTAssertNil(try XCTUnwrap(all(SendAssetView.self, in: cell).first).assetImageView.image)
  }
  func testCurrentImageFailureLeavesTheAssetBlank() throws {
    let cell = SendAssetCell(style: .default, reuseIdentifier: nil)
    let loader = ReuseImageLoader()
    cell.set(
      item: SendAssetItem(
        imageViewModel: loader, symbol: "NEW", amount: "1", balance: "2", fiat: "3"), context: nil)
    loader.complete(nil)
    XCTAssertNil(try XCTUnwrap(all(SendAssetView.self, in: cell).first).assetImageView.image)
  }

}
private final class CellButtonRecorder: ButtonCellDelegate {
  var count = 0
  func buttonTapped() { count += 1 }
}

private final class ReuseImageLoader: WalletImageViewModelProtocol {
  var image: UIImage?
  private var callback: ((UIImage?, Error?) -> Void)?
  func loadImage(with completionBlock: @escaping (UIImage?, Error?) -> Void) {
    callback = completionBlock
  }
  func complete(_ image: UIImage?) { callback?(image, nil) }
  func cancel() {}
}
