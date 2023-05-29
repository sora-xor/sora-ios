import Foundation
import UIKit
import SoraUIKit

protocol ContactsViewProtocol: ControllerBackedProtocol {
    func show(error: String)
}

final class ContactsViewController: SoramitsuViewController {

    public lazy var field: InputField = {
        let field = InputField()
        field.sora.state = .default
        field.textField.autocorrectionType = .no
        field.textField.returnKeyType = .done
        field.sora.buttonImage = R.image.wallet.qrScan()
        field.sora.buttonImageTintColor = .fgSecondary
        field.translatesAutoresizingMaskIntoConstraints = false
        field.sora.titleLabelText = R.string.localizable.selectAccountAddress1(preferredLanguages: .currentLocale)
        field.textField.sora.addHandler(for: .editingChanged) { [weak self] in
            let text = field.textField.text ?? ""
            self?.viewModel.search(text)
            
            field.sora.buttonImage = text.isEmpty ? R.image.wallet.qrScan() : R.image.wallet.cross()
        }
        field.button.sora.addHandler(for: .touchUpInside) { [weak self] in
            let text = field.textField.text ?? ""
            
            if text.isEmpty {
                self?.viewModel.openQR()
            } else {
                field.textField.sora.text = ""
                field.sora.buttonImage = R.image.wallet.qrScan()
                field.titleLabel.sora.isHidden = true
            }
        }
        return field
    }()
    
    private lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView()
        tableView.sora.backgroundColor = .custom(uiColor: .clear)
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        tableView.sora.context = SoramitsuTableViewContext(scrollView: tableView, viewController: self)
        tableView.sectionHeaderHeight = .zero
        tableView.keyboardDismissMode = .onDrag
        tableView.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 30, right: 0)
        return tableView
    }()

    var viewModel: ContactsViewModelProtocol

    init(viewModel: ContactsViewModelProtocol) {
        self.viewModel = viewModel
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        field.textField.becomeFirstResponder()
        setupView()
        setupConstraints()

        navigationItem.title = R.string.localizable.selectRecipient(preferredLanguages: .currentLocale)
        
        addCloseButton()

        viewModel.setupItems = { [weak self] items in
            DispatchQueue.main.async {
                self?.tableView.sora.sections = [ SoramitsuTableViewSection(rows: items) ]
            }
        }
        
        viewModel.viewDidLoad()
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(field)
        view.addSubview(tableView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            field.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            field.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            tableView.topAnchor.constraint(equalTo: field.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

extension ContactsViewController: ContactsViewProtocol {
    func show(error: String) {
        field.sora.state = .fail
        field.sora.descriptionLabelText = error
    }
}
