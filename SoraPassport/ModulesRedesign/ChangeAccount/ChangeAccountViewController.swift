import UIKit
import Anchorage
import SoraFoundation
import SoraUIKit
import SoraUI

final class ChangeAccountViewController: SoramitsuViewController {
    
    private struct Constants {
        static let inset: CGFloat = 16
    }

    var presenter: ChangeAccountPresenterProtocol?

    private lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView(type: .plain)
        tableView.sectionHeaderHeight = 0
        tableView.sora.backgroundColor = .custom(uiColor: .clear)
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        return tableView
    }()
    
    private lazy var tableBg: SoramitsuView = {
        let view = SoramitsuView(frame: .zero)
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        view.sora.clipsToBounds = true
        view.sora.shadow = .default
        return view
    }()

    private lazy var addButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .large, type: .bleached(.primary))
        button.sora.leftImage = R.image.iconPlus()
        button.sora.cornerRadius = .circle
        button.sora.shadow = .small
        button.addTarget(nil, action: #selector(actionCreateAccount), for: .touchUpInside)
        return button
    }()

    private var viewModel: [AccountMenuItem] = []
    private var tableConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupConstraints()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        presenter?.reload()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        presenter?.endUpdating()
    }
    
    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        
        navigationItem.largeTitleDisplayMode = .never
        addCloseButton()
        
        tableBg.addSubview(tableView)
        view.addSubview(tableBg)
        view.addSubview(addButton)
    }
    
    private func setupConstraints() {
        tableBg.horizontalAnchors == view.horizontalAnchors + Constants.inset
        tableBg.topAnchor == view.soraSafeTopAnchor
        tableConstraint = tableBg.heightAnchor.constraint(equalToConstant: 0)
        tableConstraint?.isActive = true
        
        tableView.edgeAnchors == tableBg.edgeAnchors

        addButton.horizontalAnchors == view.horizontalAnchors + Constants.inset
        addButton.topAnchor == tableBg.bottomAnchor + Constants.inset
    }
    
    @objc func actionCreateAccount() {
        presenter?.addOrCreateAccount()
    }
}

extension ChangeAccountViewController: ChangeAccountViewProtocol {
    
    func update(with accountViewModels: [AccountMenuItem]) {
        self.viewModel = accountViewModels
        
        tableView.sora.sections = [SoramitsuTableViewSection(rows: viewModel)]
        
        let height = CGFloat(accountViewModels.count) * AccountMenuItem.itemHeight
        let maxHeight = view.safeAreaLayoutGuide.layoutFrame.height - 3 * Constants.inset - addButton.sora.size.height
        
        tableConstraint?.constant = height < maxHeight ? height : maxHeight
        view.layoutSubviews()
    }
}

extension ChangeAccountViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        navigationItem.title = R.string.localizable.commonAccount(preferredLanguages: languages)
        addButton.sora.title = R.string.localizable.accountAdd(preferredLanguages: languages)
    }
}
