import UIKit
import SoraFoundation
import SnapKit
import Then
import SoraUIKit

protocol InputLinkViewInput: ControllerBackedProtocol {
    func setup(with models: [CellViewModel])
    func dismiss(with completion: @escaping () -> Void)
    func pop()
}

protocol InputLinkViewOutput {
    func willMove()
}

final class InputLinkViewController: SoramitsuViewController {

    var presenter: InputLinkViewOutput
    private var models: [CellViewModel] = []
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.separatorInset = .zero
        tableView.separatorColor = .clear
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.backgroundColor = SoramitsuUI.shared.theme.palette.color(.custom(uiColor: .clear))
        tableView.estimatedRowHeight = 100
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(
            ReferrerLinkCell.self,
            forCellReuseIdentifier: ReferrerLinkCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        return tableView
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupHierarchy()
        setupLayout()
        applyLocalization()
        addObservers()
        presenter.willMove()
    }
    
    init(presenter: InputLinkViewOutput) {
        self.presenter = presenter
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        addCloseButton()
    }
    
    private func setupHierarchy() {
        view.addSubview(tableView)
    }
    
    private func setupLayout() {
        let tableViewLeadingOffset: CGFloat = 16
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.equalTo(view).offset(tableViewLeadingOffset)
            make.center.equalTo(view)
        }
    }
    
    private func addObservers() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillShow),
                                               name: UIResponder.keyboardWillShowNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHide),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)
    }

    @objc
    private func keyboardWillShow(_ notification:Notification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardSize.height, right: 0)
            
        }
    }

    @objc
    private func keyboardWillHide(_ notification:Notification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        }
    }
}

extension InputLinkViewController: InputLinkViewInput {
    func setup(with models: [CellViewModel]) {
        self.models = models
        tableView.reloadData()
    }
    
    func dismiss(with completion: @escaping () -> Void) {
        dismiss(animated: true, completion: completion)
    }
    
    func pop() {
        guard let navigationController = navigationController else { return }
        navigationController.popViewController(animated: true)
    }
}

extension InputLinkViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return models.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = models[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: viewModel.cellReuseIdentifier, for: indexPath
        ) as? Reusable else {
            fatalError("Could not dequeue cell with identifier: InputLinkTableViewCell")
        }
        cell.bind(viewModel: models[indexPath.row])
        return cell
    }
}

extension InputLinkViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        title = R.string.localizable.referralEnterLinkTitle(preferredLanguages: languages)
    }
}
