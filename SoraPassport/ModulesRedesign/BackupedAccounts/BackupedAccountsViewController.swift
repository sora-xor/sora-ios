import SoraUIKit
import Combine

final class BackupedAccountsViewController: SoramitsuViewController & BackupedAccountsViewProtocol {
    var viewModel: BackupedAccountsViewModelProtocol? {
        didSet {
            setupSubscriptions()
        }
    }
    
    private var cancellables: Set<AnyCancellable> = []
    
    private lazy var dataSource: BackupedAccountsDataSource = {
        BackupedAccountsDataSource(tableView: tableView) { tableView, indexPath, item in
            switch item {
            case .account(let item):
                let cell: BackupedAccountCell? = tableView.dequeueReusableCell(withIdentifier: "BackupedAccountCell",
                                                                              for: indexPath) as? BackupedAccountCell
                cell?.set(item: item, context: nil)
                return cell ?? UITableViewCell()
            case .space(let item):
                let cell: SoramitsuCell<SoramitsuTableViewSpaceView>? = tableView.dequeueReusableCell(withIdentifier: "SoramitsuCell",
                                                                                                      for: indexPath) as? SoramitsuCell<SoramitsuTableViewSpaceView>
                cell?.set(item: item, context: nil)
                return cell ?? UITableViewCell()
            case .button(let item):
                let cell: SoramitsuButtonCell? = tableView.dequeueReusableCell(withIdentifier: "SoramitsuButtonCell",
                                                                              for: indexPath) as? SoramitsuButtonCell
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
        tableView.register(BackupedAccountCell.self, forCellReuseIdentifier: "BackupedAccountCell")
        tableView.register(SoramitsuButtonCell.self, forCellReuseIdentifier: "SoramitsuButtonCell")
        tableView.register(SoramitsuCell<SoramitsuTableViewSpaceView>.self, forCellReuseIdentifier: "SoramitsuCell")
        return tableView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupConstraints()
        viewModel?.reload()
    }
    
    deinit {
        print("deinited")
    }

    private func setupView() {
        navigationItem.title = R.string.localizable.selectAccountImport(preferredLanguages: .currentLocale)
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

extension BackupedAccountsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        
        switch item {
        case .account(let item):
            viewModel?.didSelectAccount(with: item.accountAddress)
        default: break
        }
    }
}
