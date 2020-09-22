import UIKit

struct OpenProjectContent: Withable {
    var title: String = ""
    var details: String = ""
    var fundingProgressValue: Float = 0.0
    var fundingProgressDetails: String = ""
    var remainedTimeDetails: String = ""
    var voteTitle: String = ""
    var votedFriendsDetails: String?
    var isVoted: Bool = false
    var isFavorite: Bool = false
    var isNew: Bool = false
    var favoriteDetails: String?
    var rewardDetails: String?

    var hasRewardDetails: Bool {
        return rewardDetails != nil
    }
}

struct OpenProjectLayout: Withable {
    var itemSize: CGSize = .zero
    var imageSize: CGSize = .zero
    var titleSize: CGSize = .zero
    var detailsSize: CGSize = .zero
    var fundingProgressDetailsSize: CGSize = .zero
    var remainedTimeDetailsSize: CGSize = .zero
    var voteTitleSize: CGSize = .zero
    var votedFriendsDetailsSize: CGSize = .zero
    var favoriteDetailsSize: CGSize = .zero
    var rewardDetailsSize: CGSize = .zero
}

protocol OpenProjectViewModelDelegate: class {
    func vote(model: OpenProjectViewModelProtocol) -> Bool
    func toggleFavorite(model: OpenProjectViewModelProtocol) -> Bool
}

protocol OpenProjectViewModelProtocol: class {
    var identifier: String { get }
    var content: OpenProjectContent { get }
    var layout: OpenProjectLayout { get }

    var imageViewModel: ImageViewModelProtocol? { get }

    var delegate: OpenProjectViewModelDelegate? { get }
}

final class OpenProjectViewModel: OpenProjectViewModelProtocol {
    var identifier: String

    var content: OpenProjectContent
    var layout: OpenProjectLayout

    var imageViewModel: ImageViewModelProtocol?

    weak var delegate: OpenProjectViewModelDelegate?

    init(identifier: String,
         content: OpenProjectContent,
         layout: OpenProjectLayout,
         imageViewModel: ImageViewModelProtocol?) {
        self.identifier = identifier
        self.content = content
        self.layout = layout
        self.imageViewModel = imageViewModel
    }
}
