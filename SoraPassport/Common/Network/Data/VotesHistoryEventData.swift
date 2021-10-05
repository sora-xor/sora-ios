import Foundation

struct VotesHistoryEventData: Codable, Equatable {
    var timestamp: Int64
    var message: String
    var votes: String
}
