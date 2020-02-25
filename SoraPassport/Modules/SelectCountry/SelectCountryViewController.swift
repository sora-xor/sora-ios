/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraUI

final class SelectCountryViewController: UIViewController, AdaptiveDesignable {
    private struct Constants {
        static let searchCornerRadius: CGFloat = 10.0
        static let searchHeight: CGFloat = 36.0
    }

    var presenter: SelectCountryPresenterProtocol!

    var locale: Locale?

    @IBOutlet private var tableView: UITableView!
    @IBOutlet private var searchBar: UISearchBar!
    @IBOutlet private var searchBackgroundHeight: NSLayoutConstraint!

    private var state: ViewModelState<[String]> = .loading(viewModel: [])

    private var titles: [String] {
        return state.viewModel ?? []
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureTableView()
        configureSearchBar()
        setupLocalization()
        adjustLayout()

        presenter.setup()
    }

    private func adjustLayout() {
        if isAdaptiveWidthDecreased {
            searchBackgroundHeight.constant *= designScaleRatio.width
        }
    }

    private func setupLocalization() {
        title = R.string.localizable.countriesTitle(preferredLanguages: locale?.rLanguages)
        searchBar.placeholder = R.string.localizable.search(preferredLanguages: locale?.rLanguages)
    }

    private func configureSearchBar() {
        let searchBackground = UIImage()
        searchBar.setBackgroundImage(searchBackground, for: .top, barMetrics: .default)

        let searchFieldSize = CGSize(width: Constants.searchHeight, height: Constants.searchHeight)
        let searchFieldInsets = UIEdgeInsets(top: Constants.searchCornerRadius,
                                             left: Constants.searchCornerRadius,
                                             bottom: Constants.searchCornerRadius,
                                             right: Constants.searchCornerRadius)
        let searchField = UIImage.background(from: .searchBarField,
                                             size: searchFieldSize,
                                             cornerRadius: Constants.searchCornerRadius,
                                             contentScale: UIScreen.main.scale)?
            .resizableImage(withCapInsets: searchFieldInsets)
        searchBar.setSearchFieldBackgroundImage(searchField, for: .normal)
    }

    private func configureTableView() {
        tableView.register(R.nib.titleTableViewCell)

        let tableFrame = CGRect(origin: .zero,
                                size: CGSize(width: view.bounds.width, height: 1.0))
        tableView.tableFooterView = UIView(frame: tableFrame)
    }
}

extension SelectCountryViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        presenter.search(by: searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

extension SelectCountryViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return titles.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.titleCellId, for: indexPath)!
        cell.bind(title: titles[indexPath.row])
        return cell
    }
}

extension SelectCountryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        presenter.select(at: indexPath.row)
    }
}

extension SelectCountryViewController: SelectCountryViewProtocol {
    func didReceive(state: ViewModelState<[String]>) {
        self.state = state

        tableView.reloadData()

        updateEmptyState(animated: false)
    }
}

extension SelectCountryViewController: DesignableNavigationBarProtocol {
    var separatorStyle: NavigationBarSeparatorStyle {
        return .empty
    }
}

extension SelectCountryViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate {
        self
    }

    var emptyStateDataSource: EmptyStateDataSource {
        self
    }
}

extension SelectCountryViewController: EmptyStateDataSource {
    var trimStrategyForEmptyState: EmptyStateView.TrimStrategy {
        return .none
    }

    var viewForEmptyState: UIView? {
        return nil
    }

    var imageForEmptyState: UIImage? {
        return R.image.searchEmptyState()
    }

    var titleForEmptyState: String? {
        return R.string.localizable
            .countriesCountryNotFound(preferredLanguages: locale?.rLanguages)
    }

    var titleColorForEmptyState: UIColor? {
        return UIColor.emptyStateTitle
    }
    var titleFontForEmptyState: UIFont? {
        return UIFont.emptyStateTitle
    }

    var displayInsetsForEmptyState: UIEdgeInsets {
        return UIEdgeInsets(top: searchBar.frame.size.height,
                            left: 0.0, bottom: 0.0, right: 0.0)
    }

    var verticalSpacingForEmptyState: CGFloat? {
        return 40.0
    }
}

extension SelectCountryViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        if case .empty = state {
            return true
        } else {
            return false
        }
    }
}
