import UIKit

struct ReferendumContent: Withable {
    var title: String = ""
    var details: String = ""
    var remainedTimeDetails: String?
    var finished: Bool = false
    var votingProgress: Float = 0.0
    var supportingVotes: String = ""
    var unsupportingVotes: String = ""
}

struct ReferendumLayout: Withable {
    var itemSize: CGSize = .zero
    var imageSize: CGSize = .zero
    var titleSize: CGSize = .zero
    var detailsSize: CGSize = .zero
}

protocol ReferendumViewModelDelegate: class {
    func support(referendum: ReferendumViewModelProtocol)
    func unsupport(referendum: ReferendumViewModelProtocol)
    func handleElapsedTime(for referendum: ReferendumViewModelProtocol)
}

protocol ReferendumViewModelProtocol: class {
    var identifier: String { get }
    var content: ReferendumContent { get }
    var layout: ReferendumLayout { get }
    var remainedTimeViewModel: TimerViewModelProtocol? { get }
    var imageViewModel: ImageViewModelProtocol? { get }

    var delegate: ReferendumViewModelDelegate? { get }
}

final class ReferendumViewModel: ReferendumViewModelProtocol {
    var identifier: String

    var content: ReferendumContent
    var layout: ReferendumLayout
    var remainedTimeViewModel: TimerViewModelProtocol?

    var imageViewModel: ImageViewModelProtocol?

    weak var delegate: ReferendumViewModelDelegate?

    init(identifier: String,
         content: ReferendumContent,
         layout: ReferendumLayout,
         remainedTimeViewModel: TimerViewModelProtocol?,
         imageViewModel: ImageViewModelProtocol?) {
        self.identifier = identifier
        self.content = content
        self.layout = layout
        self.remainedTimeViewModel = remainedTimeViewModel
        self.imageViewModel = imageViewModel
    }
}
