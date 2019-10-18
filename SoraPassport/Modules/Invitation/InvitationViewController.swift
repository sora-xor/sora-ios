/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraUI

final class InvitationViewController: UIViewController, AdaptiveDesignable, HiddableBarWhenPushed {
    private struct Constants {
        static let defaultInvitationHeight: CGFloat = 47.0
        static let inviteTableViewCellHeight: CGFloat = 56.0
        static let inviteTableViewBottomMargin: CGFloat = 10.0
    }

    var presenter: InvitationPresenterProtocol!

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var invitationContentView: RoundedView!
    @IBOutlet private var invitationTableView: UITableView!
    @IBOutlet private var leftInvitationLabel: UILabel!
    @IBOutlet private var parentLabel: UILabel!
    @IBOutlet private var invitationHeight: NSLayoutConstraint!
    @IBOutlet private var acceptedInvitationsTopParent: NSLayoutConstraint!
    @IBOutlet private var acceptedInvitationsTopActions: NSLayoutConstraint!

    var parentLabelApperanceAnimation: ViewAnimatorProtocol = TransitionAnimator(type: .fade)
    var parentLabelDismissAnimation: ViewAnimatorProtocol = TransitionAnimator(type: .fade)
    var changesAnimation: BlockViewAnimatorProtocol = BlockViewAnimator()

    private var invitedViewModels: [InvitedViewModelProtocol]?

    // MARK: Initialization

    override func viewDidLoad() {
        super.viewDidLoad()

        configureInvitationTableView()
        setupCompactBar(with: .initial)

        presenter.viewIsReady()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        presenter.viewDidAppear()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        let invitationMaxPosition = view.convert(CGPoint(x: view.bounds.maxX, y: view.bounds.maxY),
                                                 to: scrollView)

        let minimumHeight = max(Constants.defaultInvitationHeight,
                                invitationMaxPosition.y - invitationContentView.frame.origin.y)

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

    private func animateParentLabelAppearance() {
        parentLabel.isHidden = false

        parentLabelApperanceAnimation.animate(view: parentLabel, completionBlock: nil)

        changesAnimation.animate(block: {
            self.acceptedInvitationsTopActions.isActive = false
            self.acceptedInvitationsTopParent.isActive = true
            self.view.layoutIfNeeded()
        }, completionBlock: { _ in
            self.view.setNeedsLayout()
        })
    }

    private func animateParentLabelDismiss() {
        parentLabel.isHidden = true

        parentLabelDismissAnimation.animate(view: parentLabel, completionBlock: nil)

        changesAnimation.animate(block: {
            self.acceptedInvitationsTopActions.isActive = true
            self.acceptedInvitationsTopParent.isActive = false
            self.view.layoutIfNeeded()
        }, completionBlock: { _ in
            self.view.setNeedsLayout()
        })
    }

    // MARK: Actions

    @IBAction private func actionSendInvite(sender: AnyObject) {
        presenter.sendInvitation()
    }

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
    func didReceive(parentTitle: String) {
        parentLabel.text = parentTitle

        if parentLabel.isHidden, parentTitle.count > 0 {
            animateParentLabelAppearance()
        } else if !parentLabel.isHidden, parentTitle.count == 0 {
            animateParentLabelDismiss()
        }
    }

    func didReceive(leftInvitations: String) {
        leftInvitationLabel.text = R.string.localizable.inviteInvitationLeft(leftInvitations)
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
        return R.string.localizable.invitationsEmptyTitle()
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
        return UIEdgeInsets(top: 38.0, left: 0.0, bottom: 0.0, right: 0.0)
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
        return R.string.localizable.tabbarFriendsTitle()
    }
}
