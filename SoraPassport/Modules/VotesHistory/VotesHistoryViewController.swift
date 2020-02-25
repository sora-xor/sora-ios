/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import RobinHood
import SoraUI

final class VotesHistoryViewController: UIViewController {
    private struct Constants {
        static let sectionHeight: CGFloat = 44.0
        static let cellHeight: CGFloat = 44.0
        static let multiplierToActivateNextLoading: CGFloat = 1.5
        static let loadingViewMargin: CGFloat = 16.0
    }

	var presenter: VotesHistoryPresenterProtocol!

    @IBOutlet private var tableView: UITableView!
    private var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(actionReload(sender:)), for: .valueChanged)
        return refreshControl
    }()

    private var pageLoadingView: PageLoadingView!

    var locale: Locale?

    override func viewDidLoad() {
        super.viewDidLoad()

        configureTableView()
        setupLocalization()

        presenter.setup()
    }

    private func configureTableView() {
        tableView.register(R.nib.votesHistoryTableViewCell)
        tableView.insertSubview(refreshControl, at: 0)

        pageLoadingView = PageLoadingView()
        pageLoadingView.verticalMargin = Constants.loadingViewMargin
        let size = pageLoadingView.intrinsicContentSize
        pageLoadingView.frame = CGRect(origin: .zero, size: size)

        tableView.tableFooterView = pageLoadingView
    }

    private func setupLocalization() {
        title = R.string.localizable.votesHistoryTitle(preferredLanguages: locale?.rLanguages)
    }

    // MARK: Action

    @objc func actionReload(sender: AnyObject) {
        presenter.reload()
    }
}

extension VotesHistoryViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return presenter.numberOfSections()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return presenter.sectionModel(at: section).items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.votesHistoryCellId,
                                                 for: indexPath)!

        let model = presenter.sectionModel(at: indexPath.section).items[indexPath.row]
        cell.bind(viewModel: model)

        return cell
    }
}

extension VotesHistoryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = R.nib.votesHistorySectionView.firstView(owner: nil)!
        headerView.titleLabel.text = presenter.sectionModel(at: section).title
        headerView.frame = CGRect(x: 0.0, y: 0.0, width: tableView.frame.size.width, height: Constants.sectionHeight)

        return headerView
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return Constants.cellHeight
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return Constants.sectionHeight
    }
}

extension VotesHistoryViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        var threshold = scrollView.contentSize.height
        threshold -= scrollView.bounds.height * Constants.multiplierToActivateNextLoading

        if scrollView.contentOffset.y > threshold {
            if presenter.loadNext() {
                pageLoadingView.start()
            } else {
                pageLoadingView.stop()
            }
        }
    }
}

extension VotesHistoryViewController: VotesHistoryViewProtocol {
    func didReload() {
        refreshControl.endRefreshing()
        updateEmptyState(animated: true)
        tableView.reloadData()
    }

    func didReceive(changes: [VotesHistoryViewModelChange]) {
        tableView.beginUpdates()

        changes.forEach { self.applySection(change: $0) }

        tableView.endUpdates()

        updateEmptyState(animated: true)
    }

    private func applySection(change: VotesHistoryViewModelChange) {
        switch change {
        case .insert(let index, _):
            tableView.insertSections([index], with: .automatic)
        case .update(let sectionIndex, let itemChange, _):
            applyRow(change: itemChange, for: sectionIndex)
        case .delete(let index, _):
            tableView.deleteSections([index], with: .automatic)
        }
    }

    private func applyRow(change: ListDifference<VotesHistoryItemViewModel>, for sectionIndex: Int) {
        switch change {
        case .insert(let index, _):
            tableView.insertRows(at: [IndexPath(row: index, section: sectionIndex)], with: .automatic)
        case .update(let index, _, _):
            tableView.reloadRows(at: [IndexPath(row: index, section: sectionIndex)], with: .automatic)
        case .delete(let index, _):
            tableView.deleteRows(at: [IndexPath(row: index, section: sectionIndex)], with: .automatic)
        }
    }
}

extension VotesHistoryViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate {
        return presenter
    }

    var emptyStateDataSource: EmptyStateDataSource {
        return self
    }
}

extension VotesHistoryViewController: EmptyStateDataSource {
    var trimStrategyForEmptyState: EmptyStateView.TrimStrategy {
        return .none
    }

    var viewForEmptyState: UIView? {
        return nil
    }

    var imageForEmptyState: UIImage? {
        return R.image.votesHistoryEmptyIcon()
    }

    var titleForEmptyState: String? {
        return R.string.localizable
            .votesEmptyHistoryDescription(preferredLanguages: locale?.rLanguages)
    }

    var titleColorForEmptyState: UIColor? {
        return UIColor.emptyStateTitle
    }
    var titleFontForEmptyState: UIFont? {
        return UIFont.emptyStateTitle
    }

    var verticalSpacingForEmptyState: CGFloat? {
        return 40.0
    }
}
