import Foundation
import UIKit
import SoraUIKit
import SoraFoundation

protocol RedesignWalletViewProtocol: ControllerBackedProtocol {}

final class RedesignWalletViewController: SoramitsuViewController {

    private lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView()
        tableView.sora.backgroundColor = .bgPage
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        tableView.sora.tableViewHeader = nil
        tableView.delaysContentTouches = true
        tableView.canCancelContentTouches = true
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 30, right: 0)
        if #available(iOS 15.0, *) {
              tableView.sectionHeaderTopPadding = 0
         }
        return tableView
    }()

    let viewModel: RedesignWalletViewModel

    init(viewModel: RedesignWalletViewModel) {
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

        viewModel.reloadItem = { [weak self] items in
            DispatchQueue.main.async {
                self?.tableView.reloadItems(items: items )
            }
        }
        
        viewModel.setupItems = { [weak self] items in
            self?.tableView.sora.sections = [ SoramitsuTableViewSection(rows: items) ]
        }

        viewModel.fetchAssets { [weak self] items in
            self?.tableView.sora.sections = [ SoramitsuTableViewSection(rows: items) ]
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.updateAssets()
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .bgPage
        view.addSubview(tableView)
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshContent), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    @objc
    func refreshContent(refreshControl: UIRefreshControl) {
        viewModel.updateAssets()
        refreshControl.endRefreshing()
    }
}

extension RedesignWalletViewController: RedesignWalletViewProtocol {}

extension RedesignWalletViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }
    
    func applyLocalization() {
        tableView.reloadData()
    }
}
