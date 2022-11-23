import Foundation

struct ReputationDetailsItemData: Codable, Equatable {
    var title: String
    var description: String
}

struct ReputationDetailsData: Codable, Equatable {
    var sectionName: String
    var topics: [String: ReputationDetailsItemData]
}
