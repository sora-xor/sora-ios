import Foundation

public protocol StorageCodingPathProtocol: Equatable, CaseIterable, Codable {
    var moduleName: String { get }
    var itemName: String { get }
    var path: (moduleName: String, itemName: String) { get }
}
