import SoraUIKit
import Combine

final class AccountImportedViewController: SoramitsuViewController & AccountImportedViewProtocol {    
    var viewModel: AccountImportedViewModelProtocol? {
        didSet {
            setupSubscriptions()
        }
    }
    
    private var cancellables: Set<AnyCancellable> = []
    
    private lazy var dataSource: AccountImportedDataSource = {
        AccountImportedDataSource(tableView: tableView) { tableView, indexPath, item in
            switch item {
            case .accountImported(let item):
                let cell: AccountImportedCell? = tableView.dequeueReusableCell(withIdentifier: "AccountImportedCell",
                                                                              for: indexPath) as? AccountImportedCell
                cell?.set(item: item, context: nil)
                return cell ?? UITableViewCell()
            }
        }
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(AccountImportedCell.self, forCellReuseIdentifier: "AccountImportedCell")
        return tableView
    }()
    
    deinit {
        print("deinited")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupConstraints()

        viewModel?.reload()
    }

    private func setupView() {
        navigationItem.title = R.string.localizable.importedAccountTitle(preferredLanguages: .currentLocale)
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        soramitsuView.addSubview(tableView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: soramitsuView.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: soramitsuView.leadingAnchor),
            tableView.centerXAnchor.constraint(equalTo: soramitsuView.centerXAnchor),
            tableView.centerYAnchor.constraint(equalTo: soramitsuView.centerYAnchor)
        ])
    }
    
    private func setupSubscriptions() {
        viewModel?.titlePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.navigationItem.title = text
            }
            .store(in: &cancellables)
        
        viewModel?.snapshotPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.dataSource.apply(snapshot, animatingDifferences: false)
            }
            .store(in: &cancellables)
    }
}

extension AccountImportedViewController: UITableViewDelegate {}
