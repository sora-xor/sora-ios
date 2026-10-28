// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import SoraFoundation

extension InputHandling {
    /// Forwards an edit reported by a `UITextView` or `UITextField` delegate to
    /// `didReceiveReplacement(_:for:)`, which requires `range` to lie inside `value`.
    ///
    /// UIKit computes `range` against the text the field shows, and that text can differ from
    /// `value` while a keyboard composes (Japanese kana, Chinese pinyin): marked text can reach the
    /// field without the delegate, and a field that rewrites its text mid-composition makes UIKit
    /// insert the composition again. Passing such a range on raised "Range or index out of bounds"
    /// in `NSString.replacingCharacters(in:with:)`.
    ///
    /// While the field shows `value`, the edit is forwarded unchanged. Otherwise the field's text
    /// with the edit applied is offered to the handler as a replacement for its whole value, so
    /// the handler's character set, length limits and processor still decide what it keeps.
    ///
    /// - Returns: `true` if the field may apply the edit itself. On `false` the caller shows the
    ///   handler's value again, as after any rejected edit.
    func didReceiveReplacement(_ string: String, for range: NSRange, displayedText: String) -> Bool {
        let current = value as NSString

        if displayedText == value, range.clamped(toLength: current.length) == range {
            return didReceiveReplacement(string, for: range)
        }

        let displayed = displayedText as NSString
        let editRange = range.clamped(toLength: displayed.length)
        let edited = displayed.replacingCharacters(in: editRange, with: string)
        let accepted = didReceiveReplacement(edited, for: NSRange(location: 0, length: current.length))

        return accepted && editRange == range
    }
}

private extension NSRange {
    /// The part of the range that lies inside a string of `length` UTF-16 units.
    func clamped(toLength length: Int) -> NSRange {
        let start = Swift.min(Swift.max(location, 0), length)
        return NSRange(location: start, length: Swift.min(Swift.max(self.length, 0), length - start))
    }
}
