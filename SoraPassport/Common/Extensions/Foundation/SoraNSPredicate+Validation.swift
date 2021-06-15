import Foundation

extension NSPredicate {

    static var personName: NSPredicate {
        let format = "\\p{L}([\\s'\\-]*\\p{L})*"
        return NSPredicate { (inputText, _) -> Bool in
            guard let inputText = inputText as? String else {
                return false
            }
            let textWithoutEmoij = inputText.unicodeScalars
            .filter { !$0.properties.isEmojiPresentation}
            .reduce("") { $0 + String($1) }
            return NSPredicate(format: "SELF MATCHES %@", format).evaluate(with: textWithoutEmoij)
        }
    }

    static var invitationCode: NSPredicate {
        return NSPredicate(format: "SELF MATCHES %@", String.invitationCodePattern)
    }

    static var ethereumAddress: NSPredicate {
        let format = "0x[A-Fa-f0-9]{40}"
        return NSPredicate(format: "SELF MATCHES %@", format)
    }
}
