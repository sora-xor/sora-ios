import UIKit

struct FinishedProjectContent: Withable {
    var title: String = ""
    var details: String = ""
    var fundingProgressDetails: String = ""
    var completionTimeDetails: String = ""
    var favoriteDetails: String?
    var isFavorite: Bool = false
    var isVoted: Bool = false
    var isSuccessfull: Bool = false
    var votingTitle: String = ""
    var rewardDetails: String?

    var hasRewardDetails: Bool {
        return rewardDetails != nil
    }
}

struct FinishedProjectLayout: Withable {
    var itemSize: CGSize = .zero
    var imageSize: CGSize = .zero
    var titleSize: CGSize = .zero
    var detailsSize: CGSize = .zero
    var fundingProgressDetailsSize: CGSize = .zero
    var completionTimeDetailsSize: CGSize = .zero
    var favoriteDetailsSize: CGSize = .zero
    var votingTitleSize: CGSize = .zero
    var rewardDetailsSize: CGSize = .zero
}

protocol FinishedProjectViewModelDelegate: class {
    func toggleFavorite(model: FinishedProjectViewModelProtocol) -> Bool
}

protocol FinishedProjectViewModelProtocol: class {
    var identifier: String { get }
    var content: FinishedProjectContent { get }
    var layout: FinishedProjectLayout { get }

    var imageViewModel: ImageViewModelProtocol? { get }
    var delegate: FinishedProjectViewModelDelegate? { get }
}

final class FinishedProjectViewModel: FinishedProjectViewModelProtocol {
    var identifier: String
    var content: FinishedProjectContent
    var layout: FinishedProjectLayout
    var imageViewModel: ImageViewModelProtocol?

    weak var delegate: FinishedProjectViewModelDelegate?

    init(identifier: String,
         content: FinishedProjectContent,
         layout: FinishedProjectLayout,
         imageViewModel: ImageViewModelProtocol?) {
        self.identifier = identifier
        self.content = content
        self.layout = layout
        self.imageViewModel = imageViewModel
    }
}
