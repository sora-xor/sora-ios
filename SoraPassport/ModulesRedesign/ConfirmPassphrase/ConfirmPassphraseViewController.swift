import Foundation
import UIKit
import SoraUIKit

protocol ConfirmPassphraseViewProtocol: ControllerBackedProtocol {
    func setup(items: [SoramitsuTableViewItemProtocol])
    func update(items: [SoramitsuTableViewItemProtocol])
}

final class ConfirmPassphraseViewController: SoramitsuViewController, ControllerBackedProtocol {

    private lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView()
        tableView.sora.backgroundColor = .custom(uiColor: .clear)
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        tableView.sora.context = SoramitsuTableViewContext(scrollView: tableView, viewController: self)
        tableView.sectionHeaderHeight = .zero
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 30, right: 0)
        return tableView
    }()

    var viewModel: ConfirmPassphraseViewModelProtocol

    init(viewModel: ConfirmPassphraseViewModelProtocol) {
        self.viewModel = viewModel
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = R.color.neumorphism.base()
        appearance.shadowColor = .clear
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.title = R.string.localizable.accountConfirmationTitleV2(preferredLanguages: .currentLocale)

        setupView()
        setupConstraints()
        viewModel.setup()
    }

    private func setupView() {
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
}

extension ConfirmPassphraseViewController: ConfirmPassphraseViewProtocol {
    func setup(items: [SoramitsuTableViewItemProtocol]) {
        tableView.sora.sections = [ SoramitsuTableViewSection(rows: items) ]
    }
    
    func update(items: [SoramitsuTableViewItemProtocol]) {
        UIView.performWithoutAnimation {
            self.tableView.reloadItems(items: items)
        }
    }
}
