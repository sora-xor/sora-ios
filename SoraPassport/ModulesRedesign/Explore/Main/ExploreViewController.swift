import Foundation
import UIKit
import SoraUIKit
import SoraFoundation
import Combine

final class ExploreViewController: SoramitsuViewController, ControllerBackedProtocol {
    
    var viewModel: DiscoverViewModelProtocol? {
        didSet {
            setupSubscriptions()
        }
    }
    
    private var cancellables: Set<AnyCancellable> = []
    
    private lazy var dataSource: ExploreDataSource = {
        ExploreDataSource(tableView: tableView) { tableView, indexPath, item in
            switch item {
            case .assets(let item):
                let cell: ExploreAssetsCell? = tableView.dequeueReusableCell(withIdentifier: "ExploreAssetsCell",
                                                                             for: indexPath) as? ExploreAssetsCell
                cell?.set(item: item)
                return cell ?? UITableViewCell()
            case .pools(let item):
                let cell: ExplorePoolsCell? = tableView.dequeueReusableCell(withIdentifier: "ExplorePoolsCell",
                                                                            for: indexPath) as? ExplorePoolsCell
                cell?.set(item: item)
                return cell ?? UITableViewCell()
            }
        }
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.keyboardDismissMode = .onDrag
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(ExploreAssetsCell.self, forCellReuseIdentifier: "ExploreAssetsCell")
        tableView.register(ExplorePoolsCell.self, forCellReuseIdentifier: "ExplorePoolsCell")
        return tableView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupConstraints()
        
        viewModel?.setup()
    }

    private func setupView() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.prefersLargeTitles = true
        
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubviews(tableView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    private func setupSubscriptions() {
        viewModel?.snapshotPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.dataSource.apply(snapshot, animatingDifferences: false)
            }
            .store(in: &cancellables)
    }
}

extension ExploreViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }
    
    func applyLocalization() {
        let languages = localizationManager?.preferredLocalizations
        navigationItem.title = R.string.localizable.commonExplore(preferredLanguages: languages)
    }
}

extension ExploreViewController: UITableViewDelegate {}
