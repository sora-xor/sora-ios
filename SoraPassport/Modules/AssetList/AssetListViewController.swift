/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import UIKit
import SoraSwiftUI

final class AssetListViewController: SoramitsuViewController {

    private let searchController = UISearchController(searchResultsController: nil)

    private lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView()
        tableView.sora.backgroundColor = .bgPage
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        tableView.sora.context = SoramitsuTableViewContext(scrollView: tableView, viewController: self)
        tableView.sectionHeaderHeight = .zero
        tableView.dragInteractionEnabled = true
        tableView.dragDelegate = self
        tableView.tableViewObserver = self
        tableView.keyboardDismissMode = .onDrag
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 200, right: 0)
        return tableView
    }()

    var viewModel: AssetListViewModelProtocol

    init(viewModel: AssetListViewModelProtocol) {
        self.viewModel = viewModel
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupConstraints()

        searchController.searchBar.placeholder = R.string.localizable.assetListSearchPlaceholder(preferredLanguages: .currentLocale)
        searchController.searchResultsUpdater = self
        searchController.delegate = self
        searchController.obscuresBackgroundDuringPresentation = false

        title = R.string.localizable.liquidAssets(preferredLanguages: .currentLocale)
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: R.image.wallet.cross(),
                                                           style: .plain,
                                                           target: self,
                                                           action: #selector(closeTapped))

        navigationItem.searchController = searchController

        //TODO: Add navigation bar to design system
        let editButton = UIBarButtonItem(title: R.string.localizable.commonEdit(), style: .plain, target: self, action: #selector(editTapped))
        editButton.setTitleTextAttributes([ .font: UIFont.systemFont(ofSize: 13, weight: .bold), .foregroundColor: UIColor(hex: "EE2233")],
                                          for: .normal)
        navigationItem.rightBarButtonItem = editButton

        viewModel.reloadItems = { [weak self] item in
            self?.tableView.reloadItems(items: item)
        }

        viewModel.setupItems = { [weak self] items in
            self?.tableView.sora.sections = [ SoramitsuTableViewSection(rows: items) ]
        }

        viewModel.setupNavigationBar = { [weak self] mode in
            self?.navigationItem.leftBarButtonItem = mode == .edit ? nil : UIBarButtonItem(image: R.image.wallet.cross(),
                                                                                           style: .plain,
                                                                                           target: self,
                                                                                           action: #selector(self?.closeTapped))

            let button = UIBarButtonItem(title: mode == .edit ? R.string.localizable.commonDone() : R.string.localizable.commonEdit(),
                                         style: .plain,
                                         target: self,
                                         action: mode == .edit ? #selector(self?.doneTapped) : #selector(self?.editTapped) )
            button.setTitleTextAttributes([ .font: UIFont.systemFont(ofSize: 13, weight: .bold), .foregroundColor: UIColor(hex: "EE2233")],
                                          for: .normal)
            self?.navigationItem.rightBarButtonItem = button
        }
    }

    @objc
    func editTapped() {
        viewModel.mode = .edit
        tableView.dragInteractionEnabled = true
    }

    @objc
    func doneTapped() {
        viewModel.mode = .view
        tableView.dragInteractionEnabled = false
    }

    @objc
    func closeTapped() {
        self.dismiss(animated: true)
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .bgPage
        view.addSubview(tableView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

extension AssetListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        viewModel.searchText = searchController.searchBar.text ?? ""
    }
}

extension AssetListViewController: UITableViewDragDelegate {
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let dragItem = UIDragItem(itemProvider: NSItemProvider())
        dragItem.localObject = viewModel.assetItems[indexPath.row].assetViewModel.title
        return [ dragItem ]
    }
}

extension AssetListViewController: UISearchControllerDelegate {
    func willPresentSearchController(_ searchController: UISearchController) {
        viewModel.isActiveSearch = true
    }

    func willDismissSearchController(_ searchController: UISearchController) {
        viewModel.isActiveSearch = false
    }
}

extension AssetListViewController: SoramitsuTableViewObserver {
    func didSelectRow(at indexPath: IndexPath) {
        //TODO: Add transition to asset detail
    }

    func didMoveRow(at sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {

        guard viewModel.canMoveAsset(from: sourceIndexPath.row, to: destinationIndexPath.row) else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.tableView.beginUpdates()
                self.tableView.moveRow(at: destinationIndexPath, to: sourceIndexPath)
                self.tableView.endUpdates()
            }
            return
        }

        viewModel.didMoveAsset(from: sourceIndexPath.row, to: destinationIndexPath.row)
    }
}
