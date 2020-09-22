import Foundation

struct ReferendumDetailsContent {
    let title: String
    let details: String
    let remainedTimeDetails: String?
    let status: ReferendumDataStatus
    let votingProgress: Float
    let totalVotes: String?
    let supportingVotes: String
    let unsupportingVotes: String
    let mySupportingVotes: String
    let myUnsupportingVotes: String

    var finished: Bool {
        status != .open
    }
}

protocol ReferendumDetailsViewModelProtocol: class {
    var content: ReferendumDetailsContent { get }
    var remainedTimeViewModel: TimerViewModelProtocol? { get }
    var mainImageViewModel: ImageViewModelProtocol? { get }
}

final class ReferendumDetailsViewModel: ReferendumDetailsViewModelProtocol {
    let content: ReferendumDetailsContent
    let remainedTimeViewModel: TimerViewModelProtocol?
    let mainImageViewModel: ImageViewModelProtocol?

    init(content: ReferendumDetailsContent,
         remainedTimeViewModel: TimerViewModelProtocol?,
         mainImageViewModel: ImageViewModelProtocol?) {
        self.content = content
        self.remainedTimeViewModel = remainedTimeViewModel
        self.mainImageViewModel = mainImageViewModel
    }
}
