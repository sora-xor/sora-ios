import SoraUIKit

protocol ProfileLoginViewProtocol: ControllerBackedProtocol {
    var presenter: ProfileLoginPresenterProtocol? { get set }
    func update(model: ProfileLoginModel)
}

final class ProfileLoginView: SoramitsuViewController & ProfileLoginViewProtocol {
    var presenter: ProfileLoginPresenterProtocol?
    private var model: ProfileLoginModel?

    private lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView(type: .plain)
        tableView.sora.backgroundColor = .custom(uiColor: .clear)
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        return tableView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        addCloseButton()
        setupView()
        setupConstraints()
        presenter?.reload()
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(tableView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    func update(model: ProfileLoginModel) {
        if self.model == nil {
            tableView.sora.sections = model.sections
        } else {
            var allItems: [SoramitsuTableViewItemProtocol] = []
            model.sections.forEach({ allItems.append(contentsOf: $0.rows) })
            tableView.reloadItems(items: allItems)
        }
        navigationItem.title = model.title
        setNeedsStatusBarAppearanceUpdate()
        self.model = model
    }
}
