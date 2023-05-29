import Foundation

extension Int {
    func firstDivider(from range: [Int]) -> Int? {
        range.first { self % $0 == 0 }
    }
    
    static func getUniqueRandomNumbers(min: Int, max: Int, count: Int, requiredElement: Int) -> [Int] {
        var set = Set([requiredElement])
        while set.count < count {
            set.insert(Int.random(in: min...max))
        }
        return Array(set)
    }
}
