/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

class SelectionListViewController: UIViewController {
    var listPresenter: SelectionListPresenterProtocol!

    @IBOutlet private(set) var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        configureTableView()
    }

    private func configureTableView() {
        tableView.register(R.nib.selectionItemTableViewCell)

        let footerView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: view.bounds.width, height: 1.0)))
        tableView.tableFooterView = footerView
    }
}

extension SelectionListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return listPresenter.numberOfItems
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.selectionItemCellId,
                                                 for: indexPath)!

        cell.bind(viewModel: listPresenter.item(at: indexPath.row))

        return cell
    }
}

extension SelectionListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        listPresenter.selectItem(at: indexPath.row)
    }
}

extension SelectionListViewController: SelectionListViewProtocol {
    func didReload() {
        tableView.reloadData()
    }
}
