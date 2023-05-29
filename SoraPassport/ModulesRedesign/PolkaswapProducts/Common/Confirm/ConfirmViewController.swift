import Foundation
import UIKit
import SoraUIKit

protocol ConfirmViewProtocol: ControllerBackedProtocol {
    func dissmiss(competion: (() -> Void)?)
}

final class ConfirmViewController: SoramitsuViewController {

    private lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView()
        tableView.sora.backgroundColor = .custom(uiColor: .clear)
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        tableView.sora.context = SoramitsuTableViewContext(scrollView: tableView, viewController: self)
        tableView.sectionHeaderHeight = .zero
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 30, right: 0)
        tableView.sora.cancelsTouchesOnDragging = true
        return tableView
    }()

    var viewModel: ConfirmViewModelProtocol

    init(viewModel: ConfirmViewModelProtocol) {
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
        
        if let imageName = viewModel.imageName {
            let logo = UIImage(named: imageName)
            let imageView = UIImageView(image: logo)
            navigationItem.titleView = imageView
        }
        
        if let title = viewModel.title {
            navigationItem.title = title
        }

        addCloseButton()

        viewModel.setupItems = { [weak self] items in
            DispatchQueue.main.async {
                self?.tableView.sora.sections = [ SoramitsuTableViewSection(rows: items) ]
            }
        }
        
        viewModel.reloadItems = { [weak self] items in
            DispatchQueue.main.async {
                self?.tableView.reloadItems(items: items)
            }
        }
        
        viewModel.viewDidLoad()
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(tableView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

extension ConfirmViewController: ConfirmViewProtocol {
    
    func dissmiss(competion: (() -> Void)?) {
        dismiss(animated: true, completion: competion)
    }
}
