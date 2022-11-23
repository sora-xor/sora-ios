import Foundation
@testable import SoraPassport

func createRandomCurrencyData() -> CurrencyData {
    let sectionName = UUID().uuidString
    let itemsCount = Int32.random(in: 4...10)
    var items: [String: CurrencyItemData] = [:]

    (0...itemsCount).forEach { index in
        let item = createRandomCurrencyItem()
        items[String(index)] = item
    }

    return CurrencyData(sectionName: sectionName,
                        topics: items)
}

func createEmptyCurrencyData() -> CurrencyData {
    return CurrencyData(sectionName: UUID().uuidString,
                        topics: [:])
}

func createRandomCurrencyItem() -> CurrencyItemData {
    let ratio = Double(Int32.random(in: 1000...10000)) / 1000.0
    let code = UUID().uuidString.prefix(3).uppercased()
    let name = UUID().uuidString
    let symbol = UUID().uuidString.prefix(1).uppercased()

    return CurrencyItemData(code: code,
                            name: name,
                            symbol: symbol,
                            ratio: String(ratio))
}
