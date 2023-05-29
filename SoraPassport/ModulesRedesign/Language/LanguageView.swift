import SoraUIKit
import Anchorage

final class LanguageView: SoramitsuViewController & LanguageViewProtocol {
    
    private struct Constants {
        static let inset: CGFloat = 16
    }
    
    var presenter: LanguagePresenterProtocol?
    private var model: LanguageModel?
    
    private lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView(type: .plain)
        tableView.sectionHeaderHeight = 0
        tableView.sora.backgroundColor = .bgSurface
        tableView.sora.cornerMask = .top
        tableView.sora.cornerRadius = .extraLarge
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        return tableView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
        setupNavBar()
        setupView()
        setupConstraints()
        presenter?.reload()
    }
    
    private func setupNavBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = R.color.neumorphism.base()
        appearance.shadowColor = .clear
        appearance.backgroundColor = .clear
        navigationController?.navigationBar.standardAppearance = appearance
        addCloseButton()
    }
    
    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(tableView)
    }
    
    private func setupConstraints() {
        tableView.leadingAnchor == view.leadingAnchor + Constants.inset
        tableView.trailingAnchor == view.trailingAnchor - Constants.inset
        tableView.topAnchor == view.safeAreaLayoutGuide.topAnchor
        tableView.bottomAnchor == view.bottomAnchor
    }
    
    func update(model: LanguageModel) {
        tableView.sora.sections = model.sections
        navigationItem.title = model.title
        self.model = model
    }
    
}
