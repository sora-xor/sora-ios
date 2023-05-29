import SoraUIKit

protocol AppSettingsViewProtocol: ControllerBackedProtocol {
    var presenter: AppSettingsPresenterProtocol? { get set }
    func update(model: AppSettingsModel)
}

final class AppSettingsView: SoramitsuViewController & AppSettingsViewProtocol {
    var presenter: AppSettingsPresenterProtocol?
    private var model: AppSettingsModel?

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

    func update(model: AppSettingsModel) {
        self.model = model
        tableView.sora.sections = model.sections
        navigationItem.title = model.title
        setNeedsStatusBarAppearanceUpdate()
        
    }
}
