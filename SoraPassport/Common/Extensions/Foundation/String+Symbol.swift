import Foundation

extension String {
    static var xor: String {
        return "XOR"//String(Character("\u{E000}"))
    }

    static var val: String {
        return "VAL"//String(Character("\u{225A}"))
    }

    static var eth: String {
        return "ETH"
    }

    static var amountIncrease: String {
        return "+"
    }

    static var amountDecrease: String {
        return "−"
    }

    static var space: String { " " }

    static var returnKey: String { "\n" }

    static var lokalizableSeparator: String { "%%" }

    func nonEmptyComponents<T>(separatedBy separator: T) -> [String] where T: StringProtocol {
        return self.components(separatedBy: separator).filter {!$0.isEmpty}
    }
}
