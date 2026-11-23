// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0
import SoraUIKit
import UIKit
import XCTest

@testable import SoraPassport

@MainActor
final class WalletSelectionControlTests: XCTestCase {
  /// The switcher is a segmented control: one plain button per choice inside `PortfolioSegmentedControl`.
  private func buttons(_ view: UIView) -> [UIButton] {
    func segments(_ view: UIView) -> [PortfolioSegmentedControl] {
      view.subviews.flatMap { ($0 as? PortfolioSegmentedControl).map { [$0] } ?? segments($0) }
    }
    func plainButtons(_ view: UIView) -> [UIButton] {
      view.subviews.flatMap { ($0 as? UIButton).map { [$0] } ?? plainButtons($0) }
    }
    return segments(view).flatMap(plainButtons)
  }
  func testSwitcherInvokesOnlyTheTappedChoice() {
    let v = SwitcherView()
    var calls: [String] = []
    v.viewModel = SwitcherViewModel(buttonViewModels: [
      SwitcherButtonViewModel(
        title: "Wallet", isSelected: true, actionBlock: { calls.append("wallet") }),
      SwitcherButtonViewModel(
        title: "Address", isSelected: false, actionBlock: { calls.append("address") }),
    ])
    let controls = buttons(v)
    XCTAssertEqual(controls.count, 2)
    controls[1].sendActions(for: .touchUpInside)
    XCTAssertEqual(calls, ["address"])
    // The choice already shown is not chosen again: the presenter re-renders with the new selection.
    controls[0].sendActions(for: .touchUpInside)
    XCTAssertEqual(calls, ["address"])
  }
  func testReplacingSwitcherChoicesRemovesOldButtonsAndHandlers() {
    let v = SwitcherView()
    var oldCalls = 0
    var newCalls = 0
    v.viewModel = SwitcherViewModel(buttonViewModels: [
      SwitcherButtonViewModel(title: "Old", isSelected: true, actionBlock: { oldCalls += 1 }),
      SwitcherButtonViewModel(title: "Old other", isSelected: false, actionBlock: { oldCalls += 1 }),
    ])
    let old = buttons(v)
    v.viewModel = SwitcherViewModel(buttonViewModels: [
      SwitcherButtonViewModel(title: "New", isSelected: true, actionBlock: { newCalls += 1 }),
      SwitcherButtonViewModel(title: "New other", isSelected: false, actionBlock: { newCalls += 1 }),
    ])
    XCTAssertTrue(old.allSatisfy { $0.superview == nil })
    XCTAssertEqual(buttons(v).count, 2)
    old[1].sendActions(for: .touchUpInside)
    buttons(v)[1].sendActions(for: .touchUpInside)
    XCTAssertEqual(oldCalls, 0)
    XCTAssertEqual(newCalls, 1)
  }
  func testClearingSwitcherModelRemovesStaleActions() {
    let v = SwitcherView()
    v.viewModel = SwitcherViewModel(buttonViewModels: [
      SwitcherButtonViewModel(title: "Old account", isSelected: true)
    ])
    v.viewModel = nil
    XCTAssertTrue(buttons(v).isEmpty)
  }
  func testEmptySwitcherHasNoInteractiveChoices() {
    let v = SwitcherView()
    v.viewModel = SwitcherViewModel(buttonViewModels: [])
    XCTAssertTrue(buttons(v).isEmpty)
  }
  func testSwitcherAllowsAChoiceWithoutACallback() {
    let v = SwitcherView()
    v.viewModel = SwitcherViewModel(buttonViewModels: [
      SwitcherButtonViewModel(title: "Wallet", isSelected: true),
      SwitcherButtonViewModel(title: "Read only", isSelected: false),
    ])
    XCTAssertEqual(buttons(v).count, 2)
    buttons(v)[1].sendActions(for: .touchUpInside)
  }
  func testSwitcherExposesSelectedChoiceToAccessibility() {
    let v = SwitcherView()
    v.viewModel = SwitcherViewModel(buttonViewModels: [
      SwitcherButtonViewModel(title: "Wallet", isSelected: true),
      SwitcherButtonViewModel(title: "Address", isSelected: false),
    ])
    let controls = buttons(v)
    XCTAssertEqual(controls.count, 2)
    XCTAssertTrue(controls[0].accessibilityTraits.contains(.selected))
    XCTAssertFalse(controls[1].accessibilityTraits.contains(.selected))
    XCTAssertEqual(controls[0].accessibilityLabel, "Wallet")
    XCTAssertEqual(controls[1].accessibilityLabel, "Address")
  }
  private func progress(_ percentage: Float) -> CGFloat {
    let v = ProgressView()
    v.frame = CGRect(x: 0, y: 0, width: 64, height: 8)
    v.set(progressPercentage: percentage)
    v.layoutIfNeeded()
    return v.progressView.frame.width
  }
  func testProgressRendersZeroAsEmpty() { XCTAssertEqual(progress(0), 0, accuracy: 0.001) }
  func testProgressRendersFractionalValuesProportionally() {
    XCTAssertEqual(progress(12.5), 8, accuracy: 0.001)
  }
  func testProgressRendersCompletionAtTheTrackWidth() {
    XCTAssertEqual(progress(100), 64, accuracy: 0.001)
  }
  func testNegativeProgressNeverCreatesANegativeWidthConstraint() {
    XCTAssertEqual(progress(-50), 0, accuracy: 0.001)
  }
  func testExcessProgressNeverDrawsOutsideTheTrack() {
    XCTAssertEqual(progress(150), 64, accuracy: 0.001)
  }
  func testProgressCanMoveBackwardsWithoutAddingConstraints() {
    let v = ProgressView()
    v.frame = CGRect(x: 0, y: 0, width: 64, height: 8)
    let count = v.constraints.count
    v.set(progressPercentage: 100)
    v.set(progressPercentage: 25)
    v.layoutIfNeeded()
    XCTAssertEqual(v.progressView.frame.width, 16, accuracy: 0.001)
    XCTAssertEqual(v.constraints.count, count)
  }
  func testFarmSliderMaxButtonAndSliderDeliverTheirDistinctActions() {
    let v = FarmSliderView()
    var maxCalls = 0
    var sliderCalls = 0
    v.maxButton.addAction(UIAction { _ in maxCalls += 1 }, for: .touchUpInside)
    v.slider.addAction(UIAction { _ in sliderCalls += 1 }, for: .valueChanged)
    v.maxButton.sendActions(for: .touchUpInside)
    v.slider.value = 0.5
    v.slider.sendActions(for: .valueChanged)
    XCTAssertEqual(maxCalls, 1)
    XCTAssertEqual(sliderCalls, 1)
    XCTAssertEqual(v.slider.value, 0.5)
    XCTAssertEqual(v.percentageLabel.sora.text, "0%")
  }
}
