import Foundation
import UIKit
import SoraUIKit

protocol ActivityDetailsViewProtocol: ControllerBackedProtocol {
    func update(items: [SoramitsuTableViewItemProtocol])
}

final class ActivityDetailsViewController: SoramitsuViewController {

    private lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView()
        tableView.sora.backgroundColor = .custom(uiColor: .clear)
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        tableView.sora.context = SoramitsuTableViewContext(scrollView: tableView, viewController: self)
        tableView.sectionHeaderHeight = .zero
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 30, right: 0)
        tableView.scrollViewDelegate = self
        return tableView
    }()

    var viewModel: ActivityDetailsViewModelProtocol

    init(viewModel: ActivityDetailsViewModelProtocol) {
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

        setupView()
        setupConstraints()
        
        viewModel.updateContent { [weak self] items in
            self?.tableView.sora.sections = [ SoramitsuTableViewSection(rows: items) ]
        }
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

extension ActivityDetailsViewController: ActivityDetailsViewProtocol {
    func update(items: [SoramitsuTableViewItemProtocol]) {
        DispatchQueue.main.async {
            self.tableView.reloadItems(items: items )
        }
    }
}

extension ActivityDetailsViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.isTracking, scrollView.contentOffset.y < -120 {
            viewModel.dismiss()
        }
    }
}
