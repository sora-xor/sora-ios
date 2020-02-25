/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraUI
import SoraFoundation

enum InvitationViewLayout {
    case `default`
    case compactWidth
}

final class InvitationViewController: UIViewController, AdaptiveDesignable, HiddableBarWhenPushed {
    private struct Constants {
        static let defaultInvitationHeight: CGFloat = 47.0
        static let inviteTableViewCellHeight: CGFloat = 56.0
        static let inviteTableViewBottomMargin: CGFloat = 10.0
    }

    var presenter: InvitationPresenterProtocol!

    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var invitationTitleLabel: UILabel!
    @IBOutlet private var invitationContentView: RoundedView!
    @IBOutlet private var invitationTableView: UITableView!
    @IBOutlet private var actionView: InvitationActionView!
    @IBOutlet private var invitationHeight: NSLayoutConstraint!

    private var invitedViewModels: [InvitedViewModelProtocol]?

    private var preferredContentWidth: CGFloat = 375.0

    // MARK: Initialization

    override func viewDidLoad() {
        super.viewDidLoad()

        actionView.delegate = self

        setupLocalization()
        adjustLayout()

        configureInvitationTableView()
        setupCompactBar(with: .initial)

        if isAdaptiveWidthDecreased {
            presenter.setup(with: .compactWidth)
        } else {
            presenter.setup(with: .default)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        presenter.viewDidAppear()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        let invitationMaxPosition = view.convert(CGPoint(x: view.bounds.maxX, y: view.bounds.maxY),
                                                 to: scrollView)

        let targetSize = CGSize(width: preferredContentWidth, height: UIView.layoutFittingCompressedSize.height)
        let actionSize = actionView.systemLayoutSizeFitting(targetSize,
                                                            withHorizontalFittingPriority: .defaultHigh,
                                                            verticalFittingPriority: .defaultLow)
        let invitationTablePosition = actionView.frame.minY + actionSize.height

        var estimatedHeight = invitationMaxPosition.y - invitationTablePosition

        if #available(iOS 11.0, *) {
            estimatedHeight -= scrollView.adjustedContentInset.bottom
        }

        let minimumHeight = max(Constants.defaultInvitationHeight, estimatedHeight)

        if let viewModels = invitedViewModels, viewModels.count > 0 {
            let tableHeight = CGFloat(viewModels.count) * Constants.inviteTableViewCellHeight
                + Constants.inviteTableViewBottomMargin
            let newHeight = Constants.defaultInvitationHeight + tableHeight
            invitationHeight.constant = max(newHeight, minimumHeight)
        } else {
            invitationHeight.constant = minimumHeight
        }
    }

    private func configureInvitationTableView() {
        let footerView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: view.bounds.width, height: 1.0)))
        invitationTableView.tableFooterView = footerView

        invitationTableView.register(UINib(resource: R.nib.invitedTableViewCell),
                                     forCellReuseIdentifier: R.reuseIdentifier.invitedCellId.identifier)
        invitationTableView.rowHeight = Constants.inviteTableViewCellHeight
    }

    private func adjustLayout() {
        preferredContentWidth *= designScaleRatio.width
    }

    private func setupLocalization() {
        let languages = localizationManager?.preferredLocalizations
        titleLabel.text = R.string.localizable
            .inviteFragmentTitle(preferredLanguages: languages)
        invitationTitleLabel.text = R.string.localizable
            .inviteAcceptedInvitationsTitle(preferredLanguages: languages)
    }

    // MARK: Actions

    @IBAction private func actionHelp(sender: AnyObject) {
        presenter.openHelp()
    }
}

extension InvitationViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return invitedViewModels?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.invitedCellId, for: indexPath)!
        cell.titleLabel.text = invitedViewModels![indexPath.row].fullName
        return cell
    }
}

extension InvitationViewController: InvitationViewProtocol {
    func didReceive(actionListViewModel: InvitationActionListViewModel) {
        actionView.bind(viewModel: actionListViewModel)
        view.setNeedsLayout()
    }

    func didChange(accessoryTitle: String, at actionIndex: Int) {
        actionView.changeAccessory(title: accessoryTitle, at: actionIndex)
    }

    func didChange(actionStyle: InvitationActionStyle, at actionIndex: Int) {
        actionView.changeAccessory(style: actionStyle, at: actionIndex)
    }

    func didReceive(invitedUsers: [InvitedViewModelProtocol]) {
        invitedViewModels = invitedUsers
        invitationTableView.reloadData()
        updateEmptyState(animated: true)

        view.setNeedsLayout()
    }
}

extension InvitationViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        if let viewModels = invitedViewModels {
            return viewModels.count == 0
        } else {
            return false
        }
    }
}

extension InvitationViewController: EmptyStateDataSource {
    var trimStrategyForEmptyState: EmptyStateView.TrimStrategy {
        return .hideTitle
    }

    var viewForEmptyState: UIView? {
        return nil
    }

    var imageForEmptyState: UIImage? {
        return R.image.invitationsEmptyIcon()
    }

    var titleForEmptyState: String? {
        let languages = localizationManager?.preferredLocalizations
        return R.string.localizable
            .inviteEmptyFriendsDescription(preferredLanguages: languages)
    }

    var titleColorForEmptyState: UIColor? {
        return UIColor.emptyStateTitle
    }

    var titleFontForEmptyState: UIFont? {
        return UIFont.emptyStateTitle
    }

    var verticalSpacingForEmptyState: CGFloat? {
        return 15.0
    }

    var appearanceAnimatorForEmptyState: ViewAnimatorProtocol? {
        return TransitionAnimator(type: .fade)
    }
}

extension InvitationViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate {
        return self
    }

    var emptyStateDataSource: EmptyStateDataSource {
        return self
    }

    var contentViewForEmptyState: UIView {
        return invitationContentView
    }

    var displayInsetsForEmptyState: UIEdgeInsets {
        return UIEdgeInsets(top: 50.0, left: 0.0, bottom: 0.0, right: 0.0)
    }
}

extension InvitationViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView === self.scrollView {
            updateScrollingState(at: scrollView.contentOffset, animated: true)
        }
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if scrollView === self.scrollView {
            let newContentOffset = completeScrolling(at: targetContentOffset.pointee,
                                                     velocity: velocity,
                                                     animated: true)
            targetContentOffset.pointee = newContentOffset
        }
    }
}

extension InvitationViewController: SoraCompactNavigationBarFloating {
    var compactBarSupportScrollView: UIScrollView {
        return scrollView
    }

    var compactBarTitle: String? {
        let languages = localizationManager?.preferredLocalizations
        return R.string.localizable.tabbarFriendsTitle(preferredLanguages: languages)
    }
}

extension InvitationViewController: InvitationActionViewDelegate {
    func invitationAction(view: InvitationActionView, didSelectActionAt index: Int) {
        presenter.didSelectAction(at: index)
    }
}

extension InvitationViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsDisplay()

            reloadEmptyState(animated: false)
            reloadCompactBar()
        }
    }
}
