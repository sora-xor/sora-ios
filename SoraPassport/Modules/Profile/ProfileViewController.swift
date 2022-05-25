import UIKit
import Then
import Anchorage
import SoraFoundation

final class ProfileViewController: UIViewController {

    var presenter: ProfilePresenterProtocol!

    private lazy var tableView: UITableView = {
        UITableView().then {
            $0.tableFooterView = UIView()
            $0.separatorStyle = .singleLine
            $0.separatorInset = .zero
            $0.backgroundColor = .clear
            $0.rowHeight = 56
            $0.register(
                ProfileTableViewCell.self,
                forCellReuseIdentifier: ProfileTableViewCell.reuseIdentifier
            )
            $0.dataSource = self
            $0.delegate = self
        }
    }()

    private(set) var optionViewModels: [ProfileOptionViewModelProtocol] = []

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

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return optionViewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: ProfileTableViewCell.reuseIdentifier, for: indexPath
        ) as? ProfileTableViewCell else {
            fatalError("Could not dequeue cell with identifier: ProfileTableViewCell")
        }

        cell.bind(viewModel: optionViewModels[indexPath.row])

        return cell
    }
}

extension ProfileViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        let option = optionViewModels[indexPath.row]
        return option.option != ProfileOption.biometry
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.activateOption(at: UInt(indexPath.row))
    }
}

extension ProfileViewController: ProfileViewProtocol {
    func didLoad(optionViewModels: [ProfileOptionViewModelProtocol]) {
        self.optionViewModels = optionViewModels
        tableView.reloadData()
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
