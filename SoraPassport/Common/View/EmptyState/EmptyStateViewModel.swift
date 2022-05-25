import UIKit
import SoraUI

final class EmptyStateListViewModel: EmptyStateListViewModelProtocol {
    static let cellIdentifier: String = "emptyStateCellId"

    private(set) var displayInsetsForEmptyState: UIEdgeInsets

    private(set) var emptyStateView: UIView

    init(image: UIImage?, title: String?, spacing: CGFloat, displayInsets: UIEdgeInsets) {
        self.displayInsetsForEmptyState = displayInsets

        let emptyStateView = EmptyStateView()
        emptyStateView.image = image
        emptyStateView.title = title
        emptyStateView.titleColor = R.color.baseContentPrimary()!
        emptyStateView.titleFont = UIFont.styled(for: .paragraph3)
        emptyStateView.trimStrategy = .hideTitle
        emptyStateView.verticalSpacing = spacing

        self.emptyStateView = emptyStateView
    }
}
