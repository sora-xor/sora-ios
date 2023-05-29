import Foundation

struct CurrencyItemData: Codable, Equatable {
    var code: String
    var name: String
    var symbol: String
    var ratio: String
}

struct CurrencyData: Codable, Equatable {
    var sectionName: String
    var topics: [String: CurrencyItemData]
}

extension CurrencyData {
    func sortedItems() -> [CurrencyItemData] {
        return topics.enumerated().sorted(by: { (firstItem, secondItem) in
            let firstIndex = Int(firstItem.element.key) ?? 0
            let secondIndex = Int(secondItem.element.key) ?? 0

            return firstIndex < secondIndex
        })
            .map({ $0.element.value })
    }
}
