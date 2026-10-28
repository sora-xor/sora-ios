import SoraUIKit
// SPDX-License-Identifier: Apache-2.0
import UIKit
import XCTest

@testable import SoraPassport

@MainActor final class LegalTextRenderingTests: XCTestCase {
  private let locale = Locale(identifier: "en")
  private func source(_ locale: Locale? = Locale(identifier: "en")) -> String {
    "Before \(R.string.localizable.tutorialTermsAndConditions3(preferredLanguages:locale?.rLanguages)) and \(R.string.localizable.tutorialPrivacyPolicy(preferredLanguages:locale?.rLanguages)) after"
  }
  private func legal(_ redesign: Bool, locale: Locale? = Locale(identifier: "en"))
    -> NSAttributedString
  {
    (redesign
      ? CompoundAttributedStringDecorator.legalRedesign(for: locale)
      : CompoundAttributedStringDecorator.legal(for: locale)).decorate(
        attributedString: NSAttributedString(string: source(locale)))
  }
  private func attribute(_ key: NSAttributedString.Key, phrase: String, in text: NSAttributedString)
    -> Any?
  {
    let r = (text.string as NSString).range(of: phrase)
    XCTAssertNotEqual(r.location, NSNotFound)
    guard r.location != NSNotFound else { return nil }
    return text.attribute(key, at: r.location, effectiveRange: nil)
  }
  func testLegacyLegalPreservesTheEntireLocalizedText() {
    XCTAssertEqual(legal(false).string, source())
  }
  func testLegacyLegalUnderlinesTerms() {
    XCTAssertEqual(
      attribute(
        .underlineStyle,
        phrase: R.string.localizable.tutorialTermsAndConditions3(
          preferredLanguages: locale.rLanguages), in: legal(false)) as? Int,
      NSUnderlineStyle.single.rawValue)
  }
  func testLegacyLegalUnderlinesPrivacy() {
    XCTAssertEqual(
      attribute(
        .underlineStyle,
        phrase: R.string.localizable.tutorialPrivacyPolicy(preferredLanguages: locale.rLanguages),
        in: legal(false)) as? Int, NSUnderlineStyle.single.rawValue)
  }
  func testLegacyLegalDoesNotUnderlineOrdinaryText() {
    XCTAssertNil(legal(false).attribute(.underlineStyle, at: 0, effectiveRange: nil))
  }
  func testLegacyLegalAppliesReadableBaseFont() {
    XCTAssertNotNil(legal(false).attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
  }
  func testRedesignLegalHighlightsTermsWithTheAccent() {
    XCTAssertEqual(
      attribute(
        .foregroundColor,
        phrase: R.string.localizable.tutorialTermsAndConditions3(
          preferredLanguages: locale.rLanguages), in: legal(true)) as? UIColor,
      SoramitsuUI.shared.theme.palette.color(.accentPrimary))
  }
  func testRedesignLegalHighlightsPrivacyWithTheAccent() {
    XCTAssertEqual(
      attribute(
        .foregroundColor,
        phrase: R.string.localizable.tutorialPrivacyPolicy(preferredLanguages: locale.rLanguages),
        in: legal(true)) as? UIColor, SoramitsuUI.shared.theme.palette.color(.accentPrimary))
  }
  func testRedesignLegalKeepsOrdinaryTextInPrimaryColor() {
    XCTAssertEqual(
      legal(true).attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor,
      SoramitsuUI.shared.theme.palette.color(.fgPrimary))
  }
  func testRedesignLegalUsesTheSmallTextFont() {
    XCTAssertEqual(
      legal(true).attribute(.font, at: 0, effectiveRange: nil) as? UIFont, FontType.textXS.font)
  }
  func testLegalUsesTheRequestedJapaneseTranslation() {
    let jp = Locale(identifier: "ja")
    let decorated = legal(true, locale: jp)
    XCTAssertEqual(decorated.string, source(jp))
    XCTAssertNotNil(
      attribute(
        .foregroundColor,
        phrase: R.string.localizable.tutorialPrivacyPolicy(preferredLanguages: jp.rLanguages),
        in: decorated))
  }
  func testLegalDefaultLocalePreservesItsText() {
    XCTAssertEqual(legal(true, locale: nil).string, source(nil))
  }
  func testLegacyContactHighlightsOnlyItsContactPhrase() {
    let phrase = R.string.localizable.claimContact2(preferredLanguages: locale.rLanguages)
    let result = CompoundAttributedStringDecorator.contact(for: locale).decorate(
      attributedString: NSAttributedString(string: "Before \(phrase) after"))
    XCTAssertEqual(result.string, "Before \(phrase) after")
    XCTAssertEqual(
      attribute(.foregroundColor, phrase: phrase, in: result) as? UIColor,
      R.color.baseContentPrimary())
    XCTAssertEqual(
      result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor,
      R.color.baseContentQuaternary())
  }
  func testRedesignContactPreservesItsFontAndPrimaryBase() {
    let phrase = R.string.localizable.claimContact2(preferredLanguages: locale.rLanguages)
    let result = CompoundAttributedStringDecorator.contactRedesign(for: locale).decorate(
      attributedString: NSAttributedString(string: "Before \(phrase) after"))
    XCTAssertEqual(
      result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont, FontType.textXS.font)
    XCTAssertEqual(
      result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor,
      SoramitsuUI.shared.theme.palette.color(.fgPrimary))
    XCTAssertEqual(
      attribute(.foregroundColor, phrase: phrase, in: result) as? UIColor,
      R.color.baseContentPrimary())
  }
  func testMissingHighlightLeavesAllTextIntact() {
    let source = NSAttributedString(string: "Unrelated text", attributes: [.kern: 2])
    let result = HighlightingAttributedStringDecorator(
      pattern: "absent", attributes: [.underlineStyle: 1]
    ).decorate(attributedString: source)
    XCTAssertEqual(result, source)
  }
  func testUnicodeHighlightUsesTheCorrectUtf16Range() {
    let source = NSAttributedString(string: "🦊 Terms 👩🏽‍💻")
    let result = HighlightingAttributedStringDecorator(
      pattern: "Terms", attributes: [.underlineStyle: 1]
    ).decorate(attributedString: source)
    XCTAssertEqual(result.attribute(.underlineStyle, at: 3, effectiveRange: nil) as? Int, 1)
    XCTAssertNil(result.attribute(.underlineStyle, at: 0, effectiveRange: nil))
  }
  func testDecorationNeverMutatesTheOriginal() {
    let source = NSAttributedString(string: "Terms")
    _ = HighlightingAttributedStringDecorator(pattern: "Terms", attributes: [.underlineStyle: 1])
      .decorate(attributedString: source)
    XCTAssertNil(source.attribute(.underlineStyle, at: 0, effectiveRange: nil))
  }
  func testRangeDecoratorChangesOnlyTheRequestedRange() {
    let source = NSAttributedString(string: "abc")
    let result = RangeAttributedStringDecorator(
      attributes: [.kern: 3], range: NSRange(location: 1, length: 1)
    ).decorate(attributedString: source)
    XCTAssertNil(result.attribute(.kern, at: 0, effectiveRange: nil))
    XCTAssertEqual(result.attribute(.kern, at: 1, effectiveRange: nil) as? Int, 3)
    XCTAssertNil(result.attribute(.kern, at: 2, effectiveRange: nil))
  }
  func testCompoundDecorationAppliesLaterOverrides() {
    let result = CompoundAttributedStringDecorator(decorators: [
      RangeAttributedStringDecorator(attributes: [.kern: 1]),
      HighlightingAttributedStringDecorator(pattern: "b", attributes: [.kern: 2]),
    ]).decorate(attributedString: NSAttributedString(string: "abc"))
    XCTAssertEqual(result.attribute(.kern, at: 0, effectiveRange: nil) as? Int, 1)
    XCTAssertEqual(result.attribute(.kern, at: 1, effectiveRange: nil) as? Int, 2)
  }
}
