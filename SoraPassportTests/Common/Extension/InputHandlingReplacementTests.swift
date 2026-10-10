// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import UIKit
import XCTest
import SoraUIKit
import SoraFoundation
@testable import SoraPassport

/// UIKit computes the range it passes to a text delegate against the text the field shows.
/// That text can be longer than the input handler's value: marked text (Japanese kana, Chinese
/// pinyin) can reach the field without the delegate, and `InputTextView` rewrites its text while a
/// keyboard is composing, which makes UIKit insert the composition again. Such a range must never
/// reach `NSString.replacingCharacters(in:with:)`.
final class InputHandlingReplacementTests: XCTestCase {

    // MARK: Recovery phrase field (UITextView)

    /// SoraPassport-2026-10-10-134123.ips: kana typed quickly into the phrase field crashed with
    /// "-[__NSCFString replaceCharactersInRange:withString:]: Range or index out of bounds".
    @MainActor
    func testPhraseFieldRejectsCommittedKanaTheHandlerNeverSaw() throws {
        let phrase = try makePhraseImport()
        XCTAssertTrue(type("abandon ", into: phrase))
        XCTAssertEqual(phrase.handler.value, "abandon ")

        // The keyboard shows marked text; the delegate is not asked.
        phrase.textView.text = "abandon あ"

        // The keyboard commits the candidate over the marked range {8, 1}: past the handler's value.
        let applied = phrase.field.textView(
            phrase.textView,
            shouldChangeTextIn: NSRange(location: 8, length: 1),
            replacementText: "あ"
        )

        XCTAssertFalse(applied, "The phrase field only takes a–z and whitespace")
        XCTAssertEqual(phrase.handler.value, "abandon ")
        XCTAssertEqual(phrase.textView.text, "abandon ", "The field shows the handler's value again")
        XCTAssertTrue(type("ability", into: phrase), "Typing continues after the rejected candidate")
        XCTAssertEqual(phrase.handler.value, "abandon ability")
        XCTAssertEqual(phrase.textView.text, phrase.handler.value)
    }

    /// Replays the delegate calls recorded on the iOS 27 simulator while "abandon" was typed quickly
    /// with the kana keyboard. Each key arrives as marked text; `InputTextView` rewrites the text
    /// and drops the marked range, so UIKit inserts the composition again ("a" + "ab") and the next
    /// key comes with {3, 0}, past the handler's "ab". The fix takes the shown text as the base.
    @MainActor
    func testPhraseFieldReplaysRecordedKanaKeyboardSequence() throws {
        let phrase = try makePhraseImport()
        // (range, text the keyboard sends, text the field shows afterwards)
        let recorded: [(NSRange, String, String)] = [
            (NSRange(location: 0, length: 0), "a", "a"),
            (NSRange(location: 1, length: 0), "b", "aab"),
            (NSRange(location: 3, length: 0), "a", "aa"),
            (NSRange(location: 2, length: 0), "n", "aan"),
            (NSRange(location: 3, length: 0), "d", "aand"),
            (NSRange(location: 1, length: 3), "and", "aand")
        ]

        for (range, text, shownAfterwards) in recorded {
            XCTAssertTrue(phrase.field.textView(phrase.textView, shouldChangeTextIn: range, replacementText: text))
            phrase.textView.text = shownAfterwards
        }

        XCTAssertEqual(phrase.handler.value, "aand")
        XCTAssertEqual(phrase.handler.value, phrase.textView.text, "The phrase that is imported is the one shown")
    }

    /// The same commit after real marked text. UIKit inserts marked text without asking the
    /// delegate, and `InputTextView` then rewrites the text, which drops the marked range while the
    /// keyboard still holds the candidate it commits on the next key press.
    @MainActor
    func testPhraseFieldSurvivesCommitOfMarkedTextTheDelegateNeverSaw() throws {
        let phrase = try makePhraseImport()
        let previousWindow = UIApplication.shared.keyWindow
        let window = makeSceneHostedWindow()
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKeyAndVisible() }
        window.rootViewController = phrase.controller
        window.makeKeyAndVisible()
        XCTAssertTrue(phrase.textView.becomeFirstResponder())
        defer { phrase.textView.resignFirstResponder() }
        XCTAssertTrue(type("abandon ", into: phrase))

        phrase.textView.setMarkedText("あ", selectedRange: NSRange(location: 1, length: 0))
        XCTAssertEqual(phrase.textView.text, "abandon あ")
        XCTAssertEqual(phrase.handler.value, "abandon ", "Marked text does not reach the handler")

        let applied = phrase.field.textView(
            phrase.textView,
            shouldChangeTextIn: NSRange(location: 8, length: 1),
            replacementText: "あ"
        )

        XCTAssertFalse(applied)
        XCTAssertEqual(phrase.handler.value, "abandon ")
        XCTAssertEqual(phrase.textView.text, "abandon ")
    }

    /// Ordinary typing keeps the handler's filters: a–z and whitespace only, runs of whitespace
    /// collapsed, at most `maxMnemonicLength` characters.
    @MainActor
    func testPhraseFieldKeepsFilteringOrdinaryTyping() throws {
        let phrase = try makePhraseImport()

        XCTAssertTrue(type("abandon", into: phrase))
        XCTAssertFalse(type("1", into: phrase))
        XCTAssertFalse(type("A", into: phrase))
        XCTAssertTrue(type(" ", into: phrase))
        XCTAssertFalse(type(" ", into: phrase), "A second space is collapsed by the processor")
        XCTAssertTrue(type("ability", into: phrase))
        XCTAssertEqual(phrase.handler.value, "abandon ability")
        XCTAssertEqual(phrase.textView.text, "abandon ability")

        XCTAssertTrue(replace(NSRange(location: 14, length: 1), with: "", in: phrase), "Backspace")
        XCTAssertEqual(phrase.handler.value, "abandon abilit")

        let tooLong = String(repeating: "a", count: AccountImportPresenter.maxMnemonicLength)
        XCTAssertFalse(replace(NSRange(location: 14, length: 0), with: tooLong, in: phrase), "Paste")
        XCTAssertEqual(phrase.handler.value, "abandon abilit")
        XCTAssertEqual(phrase.textView.text, "abandon abilit")
    }

    // MARK: Account name field (UITextField)

    /// The account name accepts any script, so a committed candidate the handler never saw as
    /// marked text is taken over instead of crashing.
    @MainActor
    func testAccountNameFieldTakesCommittedCandidateTheHandlerNeverSaw() throws {
        let handler = makeUsernameHandler()
        let controller = SetupAccountNameViewController()
        controller.set(viewModel: InputViewModel(inputHandler: handler))
        let textField = UITextField()
        textField.text = "か"

        let applied = controller.textField(
            textField,
            shouldChangeCharactersIn: NSRange(location: 0, length: 1),
            replacementString: "柿"
        )

        XCTAssertTrue(applied)
        XCTAssertEqual(handler.value, "柿")
    }

    // MARK: InputHandling.didReceiveReplacement(_:for:displayedText:)

    func testEditOnTheHandlersValueIsForwardedUnchanged() {
        let handler = InputHandler(value: "abc")

        XCTAssertTrue(handler.didReceiveReplacement("d", for: NSRange(location: 3, length: 0), displayedText: "abc"))
        XCTAssertEqual(handler.value, "abcd")
        XCTAssertTrue(handler.didReceiveReplacement("", for: NSRange(location: 0, length: 1), displayedText: "abcd"))
        XCTAssertEqual(handler.value, "bcd")
    }

    func testEditOnLongerShownTextIsAppliedToTheShownText() {
        let handler = InputHandler(value: "ab")

        XCTAssertTrue(handler.didReceiveReplacement("X", for: NSRange(location: 2, length: 2), displayedText: "abcd"))
        XCTAssertEqual(handler.value, "abX")
    }

    func testEditOnShownTextCountsUTF16Units() {
        let handler = InputHandler()

        XCTAssertTrue(handler.didReceiveReplacement("a", for: NSRange(location: 2, length: 0), displayedText: "😀"))
        XCTAssertEqual(handler.value, "😀a")
    }

    func testEditOnShownTextKeepsTheHandlersFilters() {
        let handler = InputHandler(value: "ab",
                                   maxLength: 4,
                                   validCharacterSet: CharacterSet.englishMnemonic,
                                   processor: MneminicProcessor())

        XCTAssertFalse(handler.didReceiveReplacement("か", for: NSRange(location: 2, length: 1), displayedText: "abか"))
        XCTAssertEqual(handler.value, "ab", "Invalid characters are rejected")
        XCTAssertFalse(handler.didReceiveReplacement("cde", for: NSRange(location: 2, length: 1), displayedText: "abx"))
        XCTAssertEqual(handler.value, "ab", "The length limit holds")
        XCTAssertFalse(handler.didReceiveReplacement(" ", for: NSRange(location: 3, length: 1), displayedText: "ab x"))
        XCTAssertEqual(handler.value, "ab ", "The processor collapses whitespace and the field is resynced")
    }

    func testRangeOutsideTheShownTextIsClampedAndTheFieldResynced() {
        let handler = InputHandler(value: "ab")

        XCTAssertFalse(handler.didReceiveReplacement("c", for: NSRange(location: 5, length: 3), displayedText: "ab"),
                       "UIKit must not apply an edit outside its text")
        XCTAssertEqual(handler.value, "abc")
        XCTAssertFalse(handler.didReceiveReplacement("d", for: NSRange(location: NSNotFound, length: 0), displayedText: "abc"))
        XCTAssertEqual(handler.value, "abcd")
    }

    // MARK: Helpers

    private struct PhraseImport {
        let presenter: AccountImportPresenter
        let controller: ImportAccountViewController
        let field: InputTextView
        let handler: InputHandling
        var textView: UITextView { field.textView }
    }

    /// The import screen wired to the real presenter, so the phrase field uses the production
    /// mnemonic input handler.
    @MainActor
    private func makePhraseImport() throws -> PhraseImport {
        let controller = ImportAccountViewController()
        let presenter = AccountImportPresenter(sourceType: .mnemonic, config: ApplicationConfig.shared)
        presenter.view = controller
        presenter.didReceiveAccountImport(metadata: AccountImportMetadata(
            availableSources: AccountImportSource.allCases,
            defaultSource: .mnemonic,
            availableNetworks: [.sora],
            defaultNetwork: .sora,
            availableCryptoTypes: CryptoType.allCases,
            defaultCryptoType: .sr25519
        ))
        let handler = try XCTUnwrap(presenter.sourceViewModel?.inputHandler)
        controller.loadViewIfNeeded()
        let field = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? InputTextView }.first)
        return PhraseImport(presenter: presenter, controller: controller, field: field, handler: handler)
    }

    /// The handler the account name presenters build.
    private func makeUsernameHandler() -> InputHandler {
        InputHandler(value: "",
                     required: false,
                     predicate: NSPredicate.notEmpty,
                     processor: ByteLengthProcessor.username)
    }

    /// Types `string` at the end of the field one character at a time, as a keyboard does.
    /// Returns `true` if the delegate accepted every character.
    @MainActor
    @discardableResult
    private func type(_ string: String, into phrase: PhraseImport) -> Bool {
        string.map(String.init).reduce(true) { accepted, character in
            let end = NSRange(location: (phrase.textView.text as NSString).length, length: 0)
            return replace(end, with: character, in: phrase) && accepted
        }
    }

    /// Calls the delegate as UIKit does and, when it agrees, applies the edit as UIKit would.
    @MainActor
    @discardableResult
    private func replace(_ range: NSRange, with string: String, in phrase: PhraseImport) -> Bool {
        let current = phrase.textView.text as NSString
        let applied = phrase.field.textView(phrase.textView, shouldChangeTextIn: range, replacementText: string)
        if applied {
            phrase.textView.text = current.replacingCharacters(in: range, with: string)
        }
        return applied
    }

    @MainActor
    private func makeSceneHostedWindow() -> UIWindow {
        let frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        let window: UIWindow
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: frame)
        }
        window.frame = frame
        return window
    }

    private func descendants(_ view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }
}
