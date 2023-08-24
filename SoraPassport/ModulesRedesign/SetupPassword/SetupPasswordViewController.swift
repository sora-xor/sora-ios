import SoraUIKit
import SSFCloudStorage
import Combine

final class SetupPasswordViewController: SoramitsuViewController & SetupPasswordViewProtocol {
    var viewModel: SetupPasswordPresenterProtocol? {
        didSet {
            setupSubscriptions()
        }
    }

    private var cancellables: Set<AnyCancellable> = []
    
    private lazy var dataSource: SetupPasswordDataSource = {
        SetupPasswordDataSource(tableView: tableView) { tableView, indexPath, item in
            switch item {
            case .setupPassword(let item):
                let cell: SetupPasswordCell? = tableView.dequeueReusableCell(withIdentifier: "SetupPasswordCell",
                                                                              for: indexPath) as? SetupPasswordCell
                cell?.set(item: item, context: nil)
                return cell ?? UITableViewCell()
            }
        }
    }()
    
    private let loadingView: SoramitsuLoadingView = {
        let view = SoramitsuLoadingView()
        view.isHidden = true
        return view
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.keyboardDismissMode = .onDrag
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(SetupPasswordCell.self, forCellReuseIdentifier: "SetupPasswordCell")
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
        navigationItem.title = R.string.localizable.createBackupPasswordTitle(preferredLanguages: .currentLocale)
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        soramitsuView.addSubview(tableView)
        soramitsuView.addSubview(loadingView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: soramitsuView.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: soramitsuView.leadingAnchor),
            tableView.centerXAnchor.constraint(equalTo: soramitsuView.centerXAnchor),
            tableView.centerYAnchor.constraint(equalTo: soramitsuView.centerYAnchor),
            
            loadingView.widthAnchor.constraint(equalTo: view.widthAnchor),
            loadingView.heightAnchor.constraint(equalTo: view.heightAnchor),
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
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
    
    func showLoading() {
        loadingView.isHidden = false
    }
    
    func hideLoading() {
        loadingView.isHidden = true
    }
}

extension SetupPasswordViewController: UITableViewDelegate {}

