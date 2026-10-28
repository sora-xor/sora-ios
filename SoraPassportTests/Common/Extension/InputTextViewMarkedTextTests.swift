// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import UIKit
import XCTest
import SoraUIKit
@testable import SoraPassport

/// `InputTextView` copies its text into `SoramitsuTextView.sora.text` on every change, which
/// rewrites the text view's attributed text. While a keyboard composes (Japanese kana, Chinese
/// pinyin) that dropped the marked range the keyboard still held, so UIKit inserted the composition
/// again or lost letters: "abandon ability able" typed with the kana keyboard became
/// "aandonabilityable".
final class InputTextViewMarkedTextTests: XCTestCase {

    @MainActor
    func testMarkedTextSurvivesTextViewDidChange() {
        let host = HostedField()
        defer { host.tearDown() }
        let textView = host.field.textView

        textView.setMarkedText("a", selectedRange: NSRange(location: 1, length: 0))

        XCTAssertEqual(host.spy.changes.count, 1, "UIKit reports marked text through textViewDidChange")
        XCTAssertEqual(host.spy.changes.first?.hadMarkedText, true)
        XCTAssertNotNil(textView.markedTextRange, "textViewDidChange must not drop the marked range")
        XCTAssertEqual(textView.text, "a")

        textView.setMarkedText("ab", selectedRange: NSRange(location: 2, length: 0))

        XCTAssertNotNil(textView.markedTextRange)
        XCTAssertEqual(textView.text, "ab", "The keyboard replaces its composition instead of inserting it again")
    }

    /// Each key extends the composition the keyboard holds; committing it keeps every letter and
    /// syncs the committed text into `sora.text`.
    @MainActor
    func testComposedWordsKeepEveryLetter() {
        let host = HostedField()
        defer { host.tearDown() }
        let textView = host.field.textView

        compose("abandon", in: textView)
        XCTAssertEqual(textView.text, "abandon")
        textView.unmarkText()
        XCTAssertNil(textView.markedTextRange)
        XCTAssertEqual(textView.text, "abandon")

        textView.insertText(" ")
        compose("ability", in: textView)
        textView.unmarkText()

        XCTAssertEqual(textView.text, "abandon ability")
        XCTAssertEqual(textView.sora.text, "abandon ability", "The committed text is synced")
        XCTAssertTrue(host.spy.changes.contains { !$0.hadMarkedText && $0.text == "abandon ability" },
                      "UIKit calls textViewDidChange when the composition is committed")
    }

    /// Marked text is drawn with the typing attributes, before `sora.text` restyles the text. It
    /// must already have the field's font and colour: in an empty field, after committed text, after
    /// the field was emptied and after a theme change, in both themes.
    @MainActor
    func testMarkedTextHasTheFieldsFontAndColourInBothThemes() {
        let previous = SoramitsuUI.shared.themeMode
        defer { SoramitsuUI.shared.themeMode = previous }

        for theme in [SoramitsuThemeType.light, .dark] {
            for dynamicTextStyle in [nil, UIFont.TextStyle.body] {
                SoramitsuUI.shared.themeMode = .manual(theme)
                let host = HostedField(dynamicTextStyle: dynamicTextStyle)
                defer { host.tearDown() }
                let textView = host.field.textView
                let context = "\(theme), dynamicTextStyle \(String(describing: dynamicTextStyle))"
                let expected = host.committedAttributes(of: "a")
                XCTAssertEqual(expected.color, theme.palette.color(.fgPrimary), context)

                compose("a", in: textView)
                assertMarkedText(in: textView, has: expected, "empty field, \(context)")
                textView.unmarkText()

                compose("b", in: textView)
                assertMarkedText(in: textView, has: expected, "after committed text, \(context)")
                textView.unmarkText()

                textView.deleteBackward()
                textView.deleteBackward()
                XCTAssertEqual(textView.text, "")
                compose("c", in: textView)
                assertMarkedText(in: textView, has: expected, "emptied field, \(context)")
                textView.unmarkText()
                textView.deleteBackward()

                let other: SoramitsuThemeType = theme == .light ? .dark : .light
                SoramitsuUI.shared.themeMode = .manual(other)
                compose("d", in: textView)
                assertMarkedText(in: textView,
                                 has: Attributes(font: expected.font, color: other.palette.color(.fgPrimary)),
                                 "empty field after switching to \(other), \(context)")
                textView.unmarkText()
            }
        }
    }

    // MARK: Helpers

    private struct Attributes: Equatable {
        let font: UIFont?
        let color: UIColor?
    }

    private final class DelegateSpy: InputTextViewDelegate {
        struct Change {
            let text: String
            let hadMarkedText: Bool
        }

        private(set) var changes: [Change] = []

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            true
        }

        func textViewDidChange(_ textView: UITextView) {
            changes.append(Change(text: textView.text, hadMarkedText: textView.markedTextRange != nil))
        }
    }

    /// An `InputTextView` in a window of the app's scene. It is not made first responder, so the
    /// system keyboard, which keeps a composition of its own, stays out of the test (in a first run
    /// on a freshly booted simulator it changed the field mid-test). `setMarkedText` and the
    /// delegate calls work without it.
    @MainActor
    private struct HostedField {
        let field: InputTextView
        let spy = DelegateSpy()
        private let reference: InputTextView
        private let window: UIWindow
        private let previousKeyWindow: UIWindow?

        init(dynamicTextStyle: UIFont.TextStyle? = nil) {
            previousKeyWindow = UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
            window = UIWindow.makeSoraSceneWindow()
            window.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
            let controller = UIViewController()
            window.rootViewController = controller
            window.makeKeyAndVisible()

            field = InputTextView()
            reference = InputTextView()
            for input in [field, reference] {
                input.textView.sora.isScrollEnabled = false
                input.textView.sora.dynamicTextStyle = dynamicTextStyle
                input.textView.autocorrectionType = .no
                controller.view.addSubview(input)
            }
            NSLayoutConstraint.activate([
                field.topAnchor.constraint(equalTo: controller.view.topAnchor, constant: 100),
                field.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor, constant: 16),
                reference.topAnchor.constraint(equalTo: field.bottomAnchor, constant: 16),
                reference.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor, constant: 16)
            ])
            controller.view.layoutIfNeeded()
            field.delegate = spy
            XCTAssertNotNil(window.windowScene, "The test host has an application scene")
        }

        /// The font and colour `InputTextView` gives committed text.
        func committedAttributes(of text: String) -> Attributes {
            reference.textView.sora.text = text
            return InputTextViewMarkedTextTests.attributes(of: reference.textView, at: 0)
        }

        func tearDown() {
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKeyAndVisible()
        }
    }

    /// Types `composition` one key at a time as a composing keyboard does: each key replaces the
    /// marked text with a longer one.
    @MainActor
    private func compose(_ composition: String, in textView: UITextView) {
        var marked = ""
        for character in composition {
            marked.append(character)
            textView.setMarkedText(marked, selectedRange: NSRange(location: (marked as NSString).length, length: 0))
        }
    }

    @MainActor
    private func assertMarkedText(in textView: UITextView,
                                  has expected: Attributes,
                                  _ message: String,
                                  file: StaticString = #filePath,
                                  line: UInt = #line) {
        guard let markedTextRange = textView.markedTextRange else {
            return XCTFail("No marked text: \(message)", file: file, line: line)
        }
        let location = textView.offset(from: textView.beginningOfDocument, to: markedTextRange.start)
        XCTAssertEqual(Self.attributes(of: textView, at: location), expected, message, file: file, line: line)
    }

    private static func attributes(of textView: UITextView, at location: Int) -> Attributes {
        let attributes = textView.textStorage.attributes(at: location, effectiveRange: nil)
        return Attributes(font: attributes[.font] as? UIFont, color: attributes[.foregroundColor] as? UIColor)
    }
}
