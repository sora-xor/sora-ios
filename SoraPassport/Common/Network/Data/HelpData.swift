import Foundation

struct HelpItemData: Codable, Equatable {
    var title: String
    var description: String
}

struct HelpData: Codable, Equatable {
    var sectionName: String
    var topics: [String: HelpItemData]
}
