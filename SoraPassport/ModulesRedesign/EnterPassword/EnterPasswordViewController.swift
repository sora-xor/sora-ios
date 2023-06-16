import SoraUIKit
import SSFCloudStorage
import Combine

final class EnterPasswordViewController: SoramitsuViewController & EnterPasswordViewProtocol {
    var viewModel: EnterPasswordViewModelProtocol? {
        didSet {
            setupSubscriptions()
        }
    }

    private var cancellables: Set<AnyCancellable> = []
    
    private lazy var dataSource: EnterPasswordDataSource = {
        EnterPasswordDataSource(tableView: tableView) { tableView, indexPath, item in
            switch item {
            case .enterPassword(let item):
                let cell: EnterPasswordCell? = tableView.dequeueReusableCell(withIdentifier: "EnterPasswordCell",
                                                                              for: indexPath) as? EnterPasswordCell
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
        tableView.register(EnterPasswordCell.self, forCellReuseIdentifier: "EnterPasswordCell")
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
        navigationItem.title = R.string.localizable.enterBackupPasswordTitle(preferredLanguages: .currentLocale)
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

extension EnterPasswordViewController: UITableViewDelegate {}

extension EnterPasswordViewController: CloudStorageUIDelegate {}
