import UIKit
import SoraUIKit
import SoraFoundation
import SnapKit

protocol EditViewProtocol: ControllerBackedProtocol {}

final class EditViewController: SoramitsuViewController {
    
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
    
    let viewModel: EditViewModelProtocol

    init(viewModel: EditViewModelProtocol) {
        self.viewModel = viewModel
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addCloseButton()
        setupView()
        setupConstraints()
        
        viewModel.reloadItems = { [weak self] items in
            DispatchQueue.main.async {
                self?.tableView.reloadItems(items: items )
            }
        }

        viewModel.setupItems = { [weak self] items in
            self?.tableView.sora.sections = [ SoramitsuTableViewSection(rows: items) ]
        }
    }
    
    private func setupView() {
        title = R.string.localizable.editView(preferredLanguages: languages)
        soramitsuView.sora.backgroundColor = .bgPage
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
}

extension EditViewController: EditViewProtocol {}

extension EditViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }
    
    func applyLocalization() {
        tableView.reloadData()
    }
}
