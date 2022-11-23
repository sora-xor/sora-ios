import Foundation

extension CharacterSet {
    static var personName: CharacterSet {
        CharacterSet.letters.union(CharacterSet.personNameSeparators).union(CharacterSet.emojiSet)
    }

    static var personNameSeparators: CharacterSet {
        CharacterSet.whitespaces.union(CharacterSet(charactersIn: "-'"))
    }

    static var email: CharacterSet {
        CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._%+-@"))
    }

    static var phone: CharacterSet {
        CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "+"))
    }

    static var emojiSet: CharacterSet {
        var emoji = CharacterSet()

        for codePoint in 0x0000...0x2F0000 {
            guard let scalarValue = Unicode.Scalar(codePoint) else {
                continue
            }

            if scalarValue.properties.isEmojiPresentation {
                emoji.insert(scalarValue)
//                print(scalarValue, " ", codePoint)
            }
        }
        return emoji
    }

}
