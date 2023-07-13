import UIKit
import SoraUI
import SoraFoundation
import SoraUIKit
import SnapKit

protocol InputRewardAmountViewDelegate: AnyObject {

}

protocol InputRewardAmountViewOutput: AnyObject {
    func willMove()
}

protocol InputRewardAmountViewInput: AnyObject {
    func setupTitle(with text: String)
    func setup(with models: [CellViewModel])
    func reloadCell(at indexPath: IndexPath, models: [CellViewModel])
    func dismiss(with completion: @escaping () -> Void)
}

final class InputRewardAmountViewController: SoramitsuViewController {
    
    var presenter: InputRewardAmountViewOutput
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
            InvitationsCell.self,
            forCellReuseIdentifier: InvitationsCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        return tableView
    }()
    
    init(presenter: InputRewardAmountViewOutput) {
        self.presenter = presenter
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupHierarchy()
        setupLayout()
        addObservers()
        presenter.willMove()
    }
    
    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        addCloseButton()
        addBackButton()
    }
    
    private func setupHierarchy() {
        view.addSubview(tableView)
    }
    
    private func setupLayout() {
        let tableViewLeadingOffset: CGFloat = 16
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(view)
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

extension InputRewardAmountViewController: InputRewardAmountViewInput {
    func setupTitle(with text: String) {
        title = text
    }

    func setup(with models: [CellViewModel]) {
        self.models = models
        tableView.reloadData()
    }

    func reloadCell(at indexPath: IndexPath, models: [CellViewModel]) {
        self.models = models
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }

    func dismiss(with completion: @escaping () -> Void) {
        dismiss(animated: true, completion: completion)
    }
}

extension InputRewardAmountViewController: UITableViewDelegate, UITableViewDataSource {
    
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
            fatalError("Could not dequeue cell with identifier: ChangeAccountTableViewCell")
        }
        cell.bind(viewModel: models[indexPath.row])
        return cell
    }
}

extension InputRewardAmountViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }
}
