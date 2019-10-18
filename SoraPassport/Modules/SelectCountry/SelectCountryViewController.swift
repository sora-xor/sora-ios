/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

final class SelectCountryViewController: UIViewController, AdaptiveDesignable {
    private struct Constants {
        static let searchCornerRadius: CGFloat = 10.0
        static let searchHeight: CGFloat = 36.0
    }

    var presenter: SelectCountryPresenterProtocol!

    @IBOutlet private var tableView: UITableView!
    @IBOutlet private var searchBar: UISearchBar!
    @IBOutlet private var searchBackgroundHeight: NSLayoutConstraint!

    private var viewModels: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        configureTableView()
        configureSearchBar()
        adjustLayout()

        presenter.setup()
    }

    private func adjustLayout() {
        if isAdaptiveWidthDecreased {
            searchBackgroundHeight.constant *= designScaleRatio.width
        }
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
        return viewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.titleCellId, for: indexPath)!
        cell.bind(title: viewModels[indexPath.row])
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
    func didReceive(viewModels: [String]) {
        self.viewModels = viewModels
        tableView.reloadData()
    }
}

extension SelectCountryViewController: DesignableNavigationBarProtocol {
    var separatorStyle: NavigationBarSeparatorStyle {
        return .empty
    }
}
