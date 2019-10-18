/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

final class ProfileViewController: UIViewController, HiddableBarWhenPushed {
    private struct Constants {
        static let cellHeight: CGFloat = 59.0
    }

    var presenter: ProfilePresenterProtocol!

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var tableView: UITableView!
    @IBOutlet private var tableViewHeightConstraint: NSLayoutConstraint!

    @IBOutlet private var profileButton: ProfileButton!

    private(set) var optionViewModels: [ProfileOptionViewModelProtocol] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        configureTableView()
        setupCompactBar(with: .initial)

        presenter.viewIsReady()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        presenter.viewDidAppear()
    }

    private func configureTableView() {
        let footerView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: view.bounds.width, height: 1.0)))
        tableView.tableFooterView = footerView

        tableView.register(UINib(resource: R.nib.profileTableViewCell),
                                     forCellReuseIdentifier: R.reuseIdentifier.profileCellId.identifier)
        tableView.rowHeight = Constants.cellHeight
    }

    // MARK: View Display

    private func updateUserDetails(from viewModel: ProfileUserViewModelProtocol) {
        profileButton.titleLabel.text = viewModel.name
        profileButton.subtitleLabel.text = viewModel.details
    }

    private func updateOptions() {
        tableViewHeightConstraint.constant = Constants.cellHeight * CGFloat(optionViewModels.count)
        scrollView.setNeedsLayout()

        tableView.reloadData()
    }

    // MARK: Action

    @IBAction private func actionHelp(sender: AnyObject) {
        presenter.activateHelp()
    }

    @IBAction private func actionUserDetails(sender: AnyObject) {
        presenter.activateUserDetails()
    }
}

extension ProfileViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return optionViewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.profileCellId,
                                                 for: indexPath)!

        cell.bind(viewModel: optionViewModels[indexPath.row])

        return cell
    }
}

extension ProfileViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        presenter.activateOption(at: UInt(indexPath.row))
    }
}

extension ProfileViewController: ProfileViewProtocol {
    func didLoad(userViewModel: ProfileUserViewModelProtocol) {
        updateUserDetails(from: userViewModel)
    }

    func didLoad(optionViewModels: [ProfileOptionViewModelProtocol]) {
        self.optionViewModels = optionViewModels
        updateOptions()
    }
}

extension ProfileViewController: UIScrollViewDelegate {
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

extension ProfileViewController: SoraCompactNavigationBarFloating {
    var compactBarSupportScrollView: UIScrollView {
        return scrollView
    }

    var compactBarTitle: String? {
        return R.string.localizable.tabbarProfileTitle()
    }
}
