/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import Then
import Anchorage
import SoraFoundation

final class ProfileViewController: UIViewController {
    
    private struct Style {
        static let rowHeight: CGFloat = 56
    }

    var presenter: ProfilePresenterProtocol!
    
    private lazy var tableView: UITableView = {
        UITableView().then {
            $0.separatorInset = .zero
            $0.separatorColor = .clear
            if #available(iOS 15.0, *) {
                $0.sectionHeaderTopPadding = 0
            }
            $0.backgroundColor = .clear
            $0.register(
                ProfileTableViewCell.self,
                forCellReuseIdentifier: ProfileTableViewCell.reuseIdentifier
            )
            $0.register(
                ProfileNodeTableViewCell.self,
                forCellReuseIdentifier: ProfileNodeTableViewCell.reuseIdentifier
            )
            $0.dataSource = self
            $0.delegate = self
        }
    }()

    private(set) var optionViewModels: [ProfileOptionsHeaderViewModelProtocol] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
        presenter.setup()
    }

    private func configure() {
        navigationItem.backBarButtonItem = UIBarButtonItem(
            title: "", style: .plain, target: nil, action: nil
        )
        view.backgroundColor = R.color.baseBackground()
        view.addSubview(tableView)
        tableView.edgeAnchors == view.safeAreaLayoutGuide.edgeAnchors
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
    }

}

extension ProfileViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        view.tintColor = R.color.baseBackground()
    }

    func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        view.backgroundColor = .yellow
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = R.nib.profileSectionHeader(owner: nil) else { return nil }
        header.set(title: optionViewModels[section].title.uppercased())
        return header
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return optionViewModels.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return optionViewModels[section].options.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = optionViewModels[indexPath.section].options[indexPath.row]

        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: viewModel.cellReuseIdentifier, for: indexPath
        ) as? Reusable else {
            fatalError("Could not dequeue cell with identifier: ChangeAccountTableViewCell")
        }
        cell.bind(viewModel: optionViewModels[indexPath.section].options[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        CGFloat.leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        UITableView.automaticDimension
    }
}

extension ProfileViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        let option = optionViewModels[indexPath.section].options[indexPath.row]
        return option.option != ProfileOption.biometry
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let option = optionViewModels[indexPath.section].options[indexPath.row].option
        presenter.activateOption(option)
    }
}

extension ProfileViewController: ProfileViewProtocol {
    func didLoad(optionsViewModels: [ProfileOptionsHeaderViewModelProtocol]) {
        DispatchQueue.main.async {
            self.optionViewModels = optionsViewModels
            self.tableView.reloadData()
        }
    }
}

extension ProfileViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        navigationItem.title = R.string.localizable
            .commonSettings(preferredLanguages: languages)
    }
}
