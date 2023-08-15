import UIKit
import SoraUIKit
import SoraFoundation
import SnapKit
import Combine

final class EditViewController: SoramitsuViewController {
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.estimatedRowHeight = UITableView.automaticDimension
        tableView.tableHeaderView = nil
        tableView.backgroundColor = .clear
        tableView.separatorColor = .clear
        tableView.delaysContentTouches = true
        tableView.canCancelContentTouches = true
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.register(EnabledCell.self, forCellReuseIdentifier: "EnabledCell")
        if #available(iOS 15.0, *) {
              tableView.sectionHeaderTopPadding = 0
        }
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    var viewModel: EditViewModelProtocol? {
        didSet {
            setupSubscription()
        }
    }
    
    private var cancellables: Set<AnyCancellable> = []
    
    private lazy var dataSource: EditViewDataSource = {
        EditViewDataSource(tableView: tableView) { tableView, indexPath, item in
            switch item {
            case .enabled(let item):
                let cell: EnabledCell? = tableView.dequeueReusableCell(withIdentifier: "EnabledCell", for: indexPath) as? EnabledCell
                cell?.set(item: item, context: nil)
                return cell ?? UITableViewCell()
            }
        }
    }()

    init(viewModel: EditViewModelProtocol?) {
        self.viewModel = viewModel
        super.init()
        setupSubscription()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addCloseButton()
        setupView()
        setupConstraints()
        
        viewModel?.reloadView()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel?.completion?()
    }
    
    private func setupView() {
        title = R.string.localizable.editView(preferredLanguages: languages)
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(tableView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    private func setupSubscription() {
        viewModel?.snapshotPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.dataSource.apply(snapshot, animatingDifferences: false)
            }
            .store(in: &cancellables)
    }
}

extension EditViewController: EditViewControllerProtocol {}

extension EditViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }
}
