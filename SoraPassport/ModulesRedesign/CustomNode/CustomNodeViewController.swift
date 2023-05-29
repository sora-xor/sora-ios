import UIKit
import Then
import SoraUI
import Anchorage
import SoraFoundation
import SoraUIKit

enum TextFieldTag: Int {
    case address
    case name
}

final class CustomNodeViewController: SoramitsuViewController, AlertPresentable {
    var presenter: CustomNodePresenterProtocol!

    private var containerView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.axis = .vertical
        view.sora.shadow = .default
        view.spacing = 8
        view.sora.cornerRadius = .max
        view.sora.distribution = .fill
        view.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    lazy var nodeNameTextField: InputField = {
        InputField().then {
            $0.sora.state = .default
            $0.textField.returnKeyType = .next
            $0.textField.delegate = self
            $0.textField.tag = TextFieldTag.name.rawValue
            $0.textField.sora.addHandler(for: .editingChanged) { [weak self] in
                self?.presenter.customNodeNameChange(to: self?.nodeNameTextField.textField.text ?? "")
            }
            $0.textField.autocorrectionType = .no
        }
    }()

    lazy var nodeAddressTextField: InputField = {
        InputField().then {
            $0.sora.state = .default
            $0.textField.returnKeyType = .done
            $0.textField.delegate = self
            $0.textField.autocorrectionType = .no
            $0.textField.autocapitalizationType = .none
            $0.textField.tag = TextFieldTag.address.rawValue
            $0.textField.sora.addHandler(for: .editingChanged) { [weak self] in
                self?.presenter.customNodeAddressChange(to: self?.nodeAddressTextField.textField.text ?? "")
            }
        }
    }()

    var howToRunNodeButton: SoramitsuButton = {
        SoramitsuButton(size: .large, type: .text(.primary)).then {
            $0.addTarget(nil, action: #selector(howToRunTapped), for: .touchUpInside)
        }
    }()

    var submitButton: SoramitsuButton = {
        SoramitsuButton(size: .large, type: .filled(.primary)).then {
            $0.isEnabled = false
            $0.sora.cornerRadius = .circle
            $0.addTarget(nil, action: #selector(submitTapped), for: .touchUpInside)
        }
    }()

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        presenter.setup()
        setupLocalization()
        configureNew()
    }

    init(presenter: CustomNodePresenterProtocol) {
        self.presenter = presenter
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    func nodeNameTextFieldDidChange(textField: UITextField) {
        presenter.customNodeNameChange(to: textField.text ?? "")
    }

    @objc
    func nodeAddressTextFieldDidChange(textField: UITextField) {
        presenter.customNodeAddressChange(to: textField.text ?? "")
    }

    @objc
    func chestTapped() {
        presenter.chestButtonTapped()
    }

    @objc
    func howToRunTapped() {
        presenter.howToRunButtonTapped()
    }

    @objc
    func submitTapped() {
        presenter.submitButtonTapped()
    }
}

// MARK: - Private Functions

private extension CustomNodeViewController {

    func configureNew() {
        view.addSubview(containerView)
        containerView.addArrangedSubviews([
            nodeNameTextField,
            nodeAddressTextField,
            howToRunNodeButton,
            submitButton
        ])

        containerView.do {
            $0.topAnchor == view.soraSafeTopAnchor + 8
            $0.bottomAnchor <= view.soraSafeBottomAnchor
            $0.trailingAnchor == view.trailingAnchor - 16
            $0.leadingAnchor == view.leadingAnchor + 16
        }
    }

    private func setupLocalization() {
        navigationItem.title = R.string.localizable.selectNodeNodeDetails(preferredLanguages: languages)
        
        nodeNameTextField.sora.titleLabelText = R.string.localizable.selectNodeNodeName(preferredLanguages: languages)
        nodeNameTextField.textField.sora.placeholder = R.string.localizable.selectNodeNodeName(preferredLanguages: languages)
        
        nodeAddressTextField.sora.titleLabelText = R.string.localizable.selectNodeNodeAddress(preferredLanguages: languages)
        nodeAddressTextField.textField.sora.placeholder = R.string.localizable.selectNodeNodeAddress(preferredLanguages: languages)

        howToRunNodeButton.sora.title = R.string.localizable.selectNodeHowToRunNode(preferredLanguages: languages)
        submitButton.sora.title = R.string.localizable.commonSubmit(preferredLanguages: languages)
    }
}

extension CustomNodeViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.tag == TextFieldTag.name.rawValue {
            nodeAddressTextField.becomeFirstResponder()
        }

        if textField.tag == TextFieldTag.address.rawValue {
            textField.resignFirstResponder()
        }

        return true
    }
}

// MARK: - AddCustomNodeViewProtocol

extension CustomNodeViewController: CustomNodeViewProtocol {

    func updateFields(name: String, url: String) {
        nodeAddressTextField.sora.text = url
        nodeNameTextField.sora.text = name
        changeSubmitButton(to: true)
    }

    func showNameTextField(_ error: String) {
        nodeNameTextField.sora.state = .fail
        nodeNameTextField.sora.descriptionLabelText = error
    }

    func showAddressTextField(_ error: String) {
        nodeAddressTextField.sora.state = .fail
        nodeAddressTextField.sora.descriptionLabelText = error
    }

    func resetState() {
        nodeAddressTextField.sora.state = .default
        nodeNameTextField.sora.state = .default

        nodeNameTextField.sora.descriptionLabelText = ""
        nodeAddressTextField.sora.descriptionLabelText = ""
    }

    func changeSubmitButton(to isEnabled: Bool) {
        submitButton.isEnabled = isEnabled
    }
}

// MARK: - Localizable

extension CustomNodeViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
