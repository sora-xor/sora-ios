import UIKit

enum ProjectDetailsStatus {
    case open
    case finished(successfull: Bool)

    var isFinished: Bool {
        switch self {
        case .open:
            return false
        case .finished:
            return true
        }
    }
}

protocol ProjectDetailsViewModelProtocol: class {
    var title: String { get }
    var details: String { get }
    var fundingDetails: String { get }
    var remainedTimeDetails: String { get }
    var fundingProgressValue: Float { get }
    var votingTitle: String { get }
    var status: ProjectDetailsStatus { get }
    var isFavorite: Bool { get }
    var isVoted: Bool { get }
    var rewardDetails: String? { get }
    var statisticsDetails: String? { get }
    var discussionDetails: String? { get }
    var website: String { get }
    var email: String { get }
    var mainImageViewModel: ImageViewModelProtocol? { get }
    var galleryImageViewModels: [GalleryViewModel] { get }

    var delegate: ProjectDetailsViewModelDelegate? { get }
}

protocol ProjectDetailsViewModelDelegate: class {
    func vote(for model: ProjectDetailsViewModelProtocol) -> Bool
    func toggleFavorite(for model: ProjectDetailsViewModelProtocol) -> Bool
    func openWebsite(for model: ProjectDetailsViewModelProtocol)
    func writeEmail(for model: ProjectDetailsViewModelProtocol)
    func openDiscussion(for model: ProjectDetailsViewModelProtocol)
}

final class ProjectDetailsViewModel: ProjectDetailsViewModelProtocol {
    var title: String = ""
    var details: String = ""
    var fundingDetails: String = ""
    var remainedTimeDetails: String = ""
    var fundingProgressValue: Float = 0.0
    var votingTitle: String = ""
    var status: ProjectDetailsStatus = .open
    var isFavorite: Bool = false
    var isVoted: Bool = false
    var rewardDetails: String?
    var statisticsDetails: String?
    var discussionDetails: String?
    var website: String = ""
    var email: String = ""
    var mainImageViewModel: ImageViewModelProtocol?
    var galleryImageViewModels: [GalleryViewModel] = []

    weak var delegate: ProjectDetailsViewModelDelegate?
}
