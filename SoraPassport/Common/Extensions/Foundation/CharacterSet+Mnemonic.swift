import Foundation

extension CharacterSet {
    static var englishMnemonic: CharacterSet {
        return CharacterSet(charactersIn: "a"..."z").union(.whitespaces).union(.newlines).union(CharacterSet(charactersIn: "\t"))
    }
}
