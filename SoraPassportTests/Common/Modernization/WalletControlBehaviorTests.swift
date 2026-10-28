// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause
import SoraUI
import UIKit
import XCTest

@testable import SoraPassport

@MainActor
final class WalletControlBehaviorTests: XCTestCase {
  private func details(
    _ layout: DetailsRoundedView.Layout = .largeIconTitleSubtitle, icon: Bool = false,
    action: Bool = false, width: CGFloat = 320
  ) -> DetailsRoundedView {
    let view = DetailsRoundedView(frame: CGRect(x: 0, y: 0, width: width, height: 80))
    view.layout = layout
    view.contentInsets = UIEdgeInsets(top: 7, left: 12, bottom: 9, right: 14)
    view.title = "Wallet name"
    view.subtitle = "Address"
    view.titleLabel.font = UIFont.systemFont(ofSize: 18)
    view.subtitleLabel?.font = UIFont.systemFont(ofSize: 12)
    if icon { view.iconImage = UIImage(systemName: "circle") }
    if action { view.actionImage = UIImage(systemName: "chevron.right") }
    view.layoutIfNeeded()
    return view
  }
  func testLargeLayoutAlignsTextWithoutAnIcon() {
    let v = details()
    XCTAssertEqual(v.titleLabel.frame.minX, 12)
    XCTAssertEqual(v.subtitleLabel?.frame.minX, 12)
    XCTAssertEqual(v.titleLabel.frame.maxX, 306)
    XCTAssertEqual(v.titleLabel.frame.minY, 7, accuracy: 0.000001)
    XCTAssertEqual(v.subtitleLabel?.frame.maxY, 71)
  }
  func testLargeLayoutReservesTheIconAndSpacing() {
    let v = details(icon: true)
    XCTAssertEqual(v.iconView.frame, CGRect(x: 12, y: 24, width: 32, height: 32))
    XCTAssertEqual(v.titleLabel.frame.minX, 52)
    XCTAssertEqual(v.subtitleLabel?.frame.minX, 52)
  }
  func testLargeLayoutStopsTextBeforeTheAction() {
    let v = details(icon: true, action: true)
    XCTAssertEqual(v.actionView.frame, CGRect(x: 240, y: 0, width: 80, height: 80))
    XCTAssertEqual(v.titleLabel.frame.maxX, 240)
    XCTAssertEqual(v.subtitleLabel?.frame.maxX, 240)
  }
  func testSmallLayoutLeavesTheTitleAboveItsIcon() {
    let v = details(.smallIconTitleSubtitle, icon: true)
    XCTAssertEqual(v.titleLabel.frame.minX, 12)
    XCTAssertEqual(v.subtitleLabel?.frame.minX, 52)
    XCTAssertEqual(v.iconView.center.y, v.subtitleLabel!.center.y)
  }
  func testSmallLayoutWithoutAnIconAlignsBothLabels() {
    let v = details(.smallIconTitleSubtitle, action: true)
    XCTAssertEqual(v.subtitleLabel?.frame.minX, 12)
    XCTAssertEqual(v.subtitleLabel?.frame.maxX, 240)
    XCTAssertEqual(v.titleLabel.frame.maxX, 240)
  }
  func testSingleLayoutRemovesTheSubtitleAndCentersItsTitle() {
    let v = details(.singleTitle, icon: true, action: true)
    XCTAssertNil(v.subtitleLabel)
    XCTAssertEqual(v.titleLabel.center.y, 40)
    XCTAssertEqual(v.titleLabel.frame.minX, 52)
    XCTAssertEqual(v.titleLabel.frame.maxX, 240)
  }
  func testChangingLayoutRecreatesOnlyOneSubtitle() {
    let v = details()
    let old = v.subtitleLabel
    v.layout = .singleTitle
    XCTAssertNil(old?.superview)
    v.layout = .smallIconTitleSubtitle
    let label = v.subtitleLabel
    v.layout = .largeIconTitleSubtitle
    XCTAssertTrue(v.subtitleLabel === label)
    XCTAssertEqual(v.contentView?.subviews.compactMap { $0 as? UILabel }.count, 2)
  }
  func testAddingIconsAfterAttachmentUpdatesTheTextLayout() {
    let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 80))
    let v = details(.singleTitle)
    host.addSubview(v)
    v.iconImage = UIImage(systemName: "circle")
    v.actionImage = UIImage(systemName: "chevron.right")
    v.layoutIfNeeded()
    XCTAssertEqual(v.titleLabel.frame.minX, 52)
    XCTAssertEqual(v.titleLabel.frame.maxX, 240)
  }
  func testChangingIconSizeAndSpacingReflowsTheLabels() {
    let v = details(icon: true)
    v.iconRadius = 10
    v.horizontalSpacing = 3
    v.layoutIfNeeded()
    XCTAssertEqual(v.iconView.bounds.size, CGSize(width: 20, height: 20))
    XCTAssertEqual(v.titleLabel.frame.minX, 35)
  }
  func testNarrowLargeLayoutNeverExtendsItsTextBackwards() {
    assertNarrowLayout(.largeIconTitleSubtitle)
  }
  func testNarrowSmallLayoutNeverExtendsItsTextBackwards() {
    assertNarrowLayout(.smallIconTitleSubtitle)
  }
  func testNarrowSingleLayoutNeverExtendsItsTextBackwards() { assertNarrowLayout(.singleTitle) }
  private func assertNarrowLayout(_ layout: DetailsRoundedView.Layout) {
    let v = details(layout, icon: true, action: true, width: 40)
    XCTAssertGreaterThanOrEqual(v.titleLabel.frame.width, 0)
    XCTAssertGreaterThanOrEqual(v.titleLabel.frame.minX, 12)
    if let subtitle = v.subtitleLabel {
      XCTAssertGreaterThanOrEqual(subtitle.frame.width, 0)
      XCTAssertGreaterThanOrEqual(subtitle.frame.minX, 12)
    }
  }
  func testSubtitleFontInspectionReadsTheSubtitleRatherThanTitle() {
    let v = details()
    v.titleLabel.font = UIFont(name: "Helvetica-Bold", size: 20)
    v.subtitleLabel?.font = UIFont(name: "Courier", size: 12)
    XCTAssertEqual(v.value(forKey: "_subtitleFontName") as? String, "Courier")
  }
  func testResettingSubtitleFontPreservesTheTitleFont() {
    let v = details()
    v.titleLabel.font = UIFont(name: "Helvetica-Bold", size: 20)
    v.setValue(nil, forKey: "_subtitleFontName")
    XCTAssertEqual(v.titleLabel.font.fontName, "Helvetica-Bold")
    XCTAssertEqual(v.titleLabel.font.pointSize, 20)
  }
  func testInterfaceBuilderFontSizingKeepsSeparateTitleAndSubtitleStyles() {
    let v = details()
    v.setValue("Helvetica-Bold", forKey: "_titleFontName")
    v.setValue(23, forKey: "_titleFontSize")
    v.setValue("Courier", forKey: "_subtitleFontName")
    v.setValue(11, forKey: "_subtitleFontSize")
    XCTAssertEqual(v.value(forKey: "_titleFontSize") as? CGFloat, 23)
    XCTAssertEqual(v.value(forKey: "_subtitleFontSize") as? CGFloat, 11)
    XCTAssertEqual(v.titleLabel.font.fontName, "Helvetica-Bold")
    XCTAssertEqual(v.subtitleLabel?.font.fontName, "Courier")
  }
  func testInterfaceBuilderLayoutTransitionsPreserveTheVisibleContract() {
    let v = details()
    for (raw, expected) in [(0, 0), (1, 1), (2, 2), (255, 2)] {
      v.setValue(raw, forKey: "_layout")
      XCTAssertEqual((v.value(forKey: "_layout") as? NSNumber)?.intValue, expected)
      XCTAssertEqual(v.subtitleLabel == nil, expected == 2)
    }
    v.setValue(8, forKey: "_iconRadius")
    v.setValue(5, forKey: "_horizontalSpacing")
    XCTAssertEqual(v.value(forKey: "_iconRadius") as? CGFloat, 8)
    XCTAssertEqual(v.value(forKey: "_horizontalSpacing") as? CGFloat, 5)
  }
  func testSingleLayoutSafelyIgnoresSubtitleStyling() {
    let v = details(.singleTitle)
    v.subtitle = "Ignored"
    v.subtitleColor = .red
    v.highlightedSubtitleColor = .blue
    v.setValue("Courier", forKey: "_subtitleFontName")
    v.setValue(12, forKey: "_subtitleFontSize")
    XCTAssertNil(v.subtitle)
    XCTAssertNil(v.subtitleColor)
    XCTAssertNil(v.highlightedSubtitleColor)
    XCTAssertEqual(v.value(forKey: "_subtitleFontSize") as? CGFloat, 0)
  }
  func testDetailsSelectionStyleRemainsSeparateFromTheNormalStyle() {
    let v = details()
    v.fillColor = .white
    v.highlightedFillColor = .gray
    v.strokeColor = .black
    v.highlightedStrokeColor = .blue
    v.titleColor = .red
    v.highlightedTitleColor = .green
    v.subtitleColor = .brown
    v.highlightedSubtitleColor = .orange
    v.borderWidth = 2
    v.actionTintColor = .purple
    v.isHighlighted = true
    XCTAssertEqual(v.fillColor, .white)
    XCTAssertEqual(v.highlightedFillColor, .gray)
    XCTAssertEqual(v.strokeColor, .black)
    XCTAssertEqual(v.highlightedStrokeColor, .blue)
    XCTAssertEqual(v.titleLabel.textColor, .red)
    XCTAssertEqual(v.titleLabel.highlightedTextColor, .green)
    XCTAssertEqual(v.subtitleLabel?.textColor, .brown)
    XCTAssertEqual(v.subtitleLabel?.highlightedTextColor, .orange)
    XCTAssertEqual(v.borderWidth, 2)
    XCTAssertEqual(v.actionTintColor, .purple)
  }
  func testPreparingDetailsForInterfaceBuilderDoesNotDuplicateContent() {
    let v = details(icon: true, action: true)
    let count = v.contentView!.subviews.count
    v.prepareForInterfaceBuilder()
    v.prepareForInterfaceBuilder()
    XCTAssertEqual(v.contentView?.subviews.count, count)
  }

  func testProfileHighlightAnimationsRunOnlyOnStateTransitions() {
    let v = ProfileButton(frame: .zero)
    let on = ControlAnimator()
    let off = ControlAnimator()
    v.highlitedOnAnimation = on
    v.highlitedOffAnimation = off
    v.isHighlighted = true
    v.isHighlighted = true
    v.isHighlighted = false
    v.isHighlighted = false
    XCTAssertEqual(on.views.count, 1)
    XCTAssertEqual(off.views.count, 1)
    XCTAssertTrue(on.views[0] === v)
  }
  func testProfileContentHonorsInsetsAndKeepsBothLabels() {
    let v = ProfileButton(frame: CGRect(x: 0, y: 0, width: 240, height: 80))
    v.contentInsets = UIEdgeInsets(top: 7, left: 11, bottom: 9, right: 13)
    v.layoutIfNeeded()
    XCTAssertEqual(v.contentView?.frame, CGRect(x: 11, y: 7, width: 216, height: 64))
    XCTAssertTrue(v.titleLabel.superview === v.contentView)
    XCTAssertTrue(v.subtitleLabel.superview === v.contentView)
    XCTAssertFalse(v.contentView!.isUserInteractionEnabled)
  }
  func testReconfiguringProfilePreservesLabelsAndConstraints() {
    let v = ProfileButton(frame: .zero)
    let content = v.contentView!
    let title = v.titleLabel
    let count = content.constraints.count
    v.configure()
    v.prepareForInterfaceBuilder()
    XCTAssertTrue(v.contentView === content)
    XCTAssertTrue(v.titleLabel === title)
    XCTAssertEqual(content.constraints.count, count)
  }
  func testProfileInspectablesKeepTitleAndSubtitleIndependent() {
    let v = ProfileButton(frame: .zero)
    for (key, value) in [
      ("_title", "Alice"), ("_subtitle", "cn123"), ("_titleFontName", "Helvetica-Bold"),
      ("_subtitleFontName", "Courier"),
    ] {
      v.setValue(value, forKey: key)
      XCTAssertEqual(v.value(forKey: key) as? String, value)
    }
    v.setValue(22, forKey: "_titleFontSize")
    v.setValue(12, forKey: "_subtitleFontSize")
    XCTAssertEqual(v.titleLabel.font.pointSize, 22)
    XCTAssertEqual(v.subtitleLabel.font.pointSize, 12)
    v.setValue(nil, forKey: "_subtitleFontName")
    XCTAssertEqual(v.titleLabel.font.fontName, "Helvetica-Bold")
    v.setValue(nil, forKey: "_titleFontName")
    XCTAssertNotNil(v.titleLabel.font)
  }
  func testProfileThemeIsAppliedToItsActualBackgroundAndLabels() {
    let v = ProfileButton(frame: .zero)
    applyTheme(v)
    XCTAssertEqual(v.roundedBackgroundView?.fillColor, .red)
    XCTAssertEqual(v.roundedBackgroundView?.strokeWidth, 2)
    XCTAssertEqual(v.titleLabel.textColor, .blue)
    XCTAssertEqual(v.subtitleLabel.textColor, .green)
    XCTAssertEqual(v.roundedBackgroundView?.cornerRadius, 9)
  }
  func testRoundedCellHighlightAnimationsRunOnlyOnTransitions() {
    let v = RoundedCellControlView(frame: .zero)
    let on = ControlAnimator()
    let off = ControlAnimator()
    v.highlitedOnAnimation = on
    v.highlitedOffAnimation = off
    v.isHighlighted = true
    v.isHighlighted = true
    v.isHighlighted = false
    v.isHighlighted = false
    XCTAssertEqual(on.views.count, 1)
    XCTAssertEqual(off.views.count, 1)
  }
  func testRoundedCellCanHighlightWithoutCustomAnimations() {
    let v = RoundedCellControlView(frame: .zero)
    v.isHighlighted = true
    XCTAssertTrue(v.isHighlighted)
    v.isHighlighted = false
    XCTAssertFalse(v.isHighlighted)
  }
  func testRoundedCellReconfigurationKeepsOneBorderAndOneContent() {
    let v = RoundedCellControlView(frame: CGRect(x: 0, y: 0, width: 320, height: 72))
    let content = v.contentView
    let border = v.borderView
    v.contentInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 15)
    v.prepareForInterfaceBuilder()
    v.layoutIfNeeded()
    XCTAssertTrue(v.contentView === content)
    XCTAssertTrue(v.borderView === border)
    XCTAssertEqual(v.contentView?.frame.width, 295)
    XCTAssertEqual(v.borderView.frame, v.roundedBackgroundView.bounds)
  }
  func testRoundedCellTitleAndAccessoryFontsAreIndependent() {
    let v = RoundedCellControlView(frame: .zero)
    for (key, value) in [
      ("_title", "Network"), ("_subtitle", "Taira"), ("_titleFontName", "Helvetica-Bold"),
      ("_subtitleFontName", "Courier"),
    ] {
      v.setValue(value, forKey: key)
      XCTAssertEqual(v.value(forKey: key) as? String, value)
    }
    v.setValue(20, forKey: "_titleFontSize")
    v.setValue(13, forKey: "_subtitleFontSize")
    XCTAssertEqual(v.titleAccessoryView.titleView.titleFont?.pointSize, 20)
    XCTAssertEqual(v.titleAccessoryView.accessoryLabel.font.pointSize, 13)
    v.setValue(nil, forKey: "_titleFontName")
    v.setValue(18, forKey: "_titleFontSize")
    XCTAssertEqual(v.titleAccessoryView.titleView.titleFont?.pointSize, 18)
    v.setValue(nil, forKey: "_subtitleFontName")
    XCTAssertNotNil(v.titleAccessoryView.accessoryLabel.font)
  }
  func testRoundedCellThemeAndSeparatorReachTheVisibleViews() {
    let v = RoundedCellControlView(frame: .zero)
    applyTheme(v)
    v.setValue(UIColor.orange, forKey: "_separatorColor")
    v.setValue(1.5, forKey: "_separatorWidth")
    XCTAssertEqual(v.roundedBackgroundView.fillColor, .red)
    XCTAssertEqual(v.titleAccessoryView.titleView.titleColor, .blue)
    XCTAssertEqual(v.borderView.strokeColor, .orange)
    XCTAssertEqual(v.borderView.strokeWidth, 1.5)
    XCTAssertEqual(v.value(forKey: "_separatorColor") as? UIColor, .orange)
    XCTAssertEqual(v.value(forKey: "_separatorWidth") as? CGFloat, 1.5)
  }
  func testRoundedCellUpdatesIconAndHighlightedIconWithoutReplacingContent() {
    let v = RoundedCellControlView(frame: .zero)
    let image = UIImage(systemName: "circle")!
    let highlighted = UIImage(systemName: "circle.fill")!
    v.setValue(image, forKey: "_icon")
    v.setValue(highlighted, forKey: "_highlightedIcon")
    v.setValue(14, forKey: "_spacingBetweenLabelAndIcon")
    XCTAssertTrue((v.value(forKey: "_icon") as? UIImage) === image)
    XCTAssertTrue((v.value(forKey: "_highlightedIcon") as? UIImage) === highlighted)
    XCTAssertEqual(v.value(forKey: "_spacingBetweenLabelAndIcon") as? CGFloat, 14)
  }
  private func applyTheme(_ v: NSObject) {
    let colors: [(String, UIColor)] = [
      ("_fillColor", .red), ("_highlightedFillColor", .gray), ("_strokeColor", .black),
      ("_highlightedStrokeColor", .white), ("_titleColor", .blue),
      ("_highlightedTitleColor", .orange), ("_subtitleColor", .green),
      ("_highlightedSubtitleColor", .yellow), ("_shadowColor", .purple),
    ]
    for (key, value) in colors {
      v.setValue(value, forKey: key)
      XCTAssertEqual(v.value(forKey: key) as? UIColor, value)
    }
    for (key, value) in [
      ("_strokeWidth", 2.0), ("_shadowRadius", 4.0), ("_shadowOpacity", 0.5),
      ("_cornerRadius", 9.0), ("_contentOpacityWhenHighlighted", 0.3),
    ] {
      v.setValue(value, forKey: key)
      XCTAssertEqual(
        (v.value(forKey: key) as? NSNumber)?.doubleValue ?? -1, value, accuracy: 0.0001)
    }
    v.setValue(NSValue(cgSize: CGSize(width: 2, height: 3)), forKey: "_shadowOffset")
    XCTAssertEqual(
      (v.value(forKey: "_shadowOffset") as? NSValue)?.cgSizeValue, CGSize(width: 2, height: 3))
    v.setValue(true, forKey: "_changesContentOpacityWhenHighlighted")
    XCTAssertEqual(v.value(forKey: "_changesContentOpacityWhenHighlighted") as? Bool, true)
  }
  func testLinkRendersPlainLabelsAndIcon() {
    let v = LinkView()
    v.titleText = "Documentation"
    v.linkTitleText = "SORA"
    let icon = UIImage(systemName: "book")!
    v.iconImage = icon
    v.iconTintColor = .red
    XCTAssertEqual(v.titleText, "Documentation")
    XCTAssertEqual(v.linkTitleText, "SORA")
    XCTAssertTrue(v.iconImage === icon)
    XCTAssertEqual(v.iconTintColor, .red)
  }
  func testLinkUnderlinesTheCompleteUnicodeDestination() {
    let v = LinkView()
    v.titleAttributedText = "Help"
    v.linkTitleAttributedText = "SORA 🐈 日本"
    XCTAssertEqual(v.titleAttributedText, "Help")
    XCTAssertEqual(v.linkTitleAttributedText, "SORA 🐈 日本")
    let labels = descendants(v).compactMap { $0 as? UILabel }
    let link = labels.first { $0.attributedText?.string == "SORA 🐈 日本" }!
    let text = link.attributedText!
    XCTAssertEqual(
      text.attribute(.underlineStyle, at: text.length - 1, effectiveRange: nil) as? Int, 1)
  }
  func testClearingLinkContentDoesNotRetainThePreviousDestination() {
    let v = LinkView()
    v.titleAttributedText = "Old"
    v.linkTitleAttributedText = "Old"
    v.titleAttributedText = nil
    v.linkTitleAttributedText = nil
    XCTAssertNil(v.titleAttributedText)
    XCTAssertEqual(v.linkTitleAttributedText, "")
  }
  func testLinkHighlightRestoresOpacityOnRelease() {
    let v = LinkView()
    v.isHighlighted = true
    XCTAssertEqual(v.alpha, 0.5)
    v.isHighlighted = true
    XCTAssertEqual(v.alpha, 0.5)
    v.isHighlighted = false
    v.isHighlighted = false
    XCTAssertEqual(v.alpha, 1)
  }
  func testLinkSeparatorVisibilityMatchesTheRequestedStyle() {
    for visible in [false, true] {
      let v = LinkView(separatorIsVisible: visible)
      let stack = v.contentView as! UIStackView
      XCTAssertEqual(stack.arrangedSubviews.last?.isHidden, !visible)
    }
  }
  func testLinkLayoutUsesTheFullControlBounds() {
    let v = LinkView(frame: CGRect(x: 0, y: 0, width: 320, height: 56))
    v.layoutIfNeeded()
    XCTAssertEqual(v.contentView?.frame, v.bounds)
    XCTAssertFalse(v.contentView!.isUserInteractionEnabled)
  }
  func testRepeatedLinkInterfaceBuilderPreparationDoesNotDuplicateConstraints() {
    let v = LinkView()
    let content = v.contentView
    let count = v.constraints.count
    v.prepareForInterfaceBuilder()
    v.prepareForInterfaceBuilder()
    XCTAssertTrue(v.contentView === content)
    XCTAssertEqual(v.constraints.count, count)
  }
  private func descendants(_ view: UIView) -> [UIView] {
    view.subviews.flatMap { [$0] + descendants($0) }
  }
}

private final class ControlAnimator: ViewAnimatorProtocol {
  let duration: TimeInterval = 0
  var views: [UIView] = []
  func animate(view: UIView, completionBlock: ((Bool) -> Void)?) {
    views.append(view)
    completionBlock?(true)
  }
}
