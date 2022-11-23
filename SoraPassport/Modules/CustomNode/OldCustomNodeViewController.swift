import UIKit
import Then
import SoraUI
import Anchorage
import SoraFoundation

final class OldCustomNodeViewController: UIViewController, AlertPresentable {
    var presenter: CustomNodePresenterProtocol!

    private var titleLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .title4).withSize(15.0)
            $0.textColor = R.color.neumorphism.textDark()
            $0.textAlignment = .center
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()

    lazy var chestButton: UIButton = {
        let button = UIButton()
        button.isHidden = true
        button.setImage(R.image.red_chest(), for: .normal)
        button.addTarget(self, action: #selector(chestTapped), for: .touchUpInside)
        return button
    }()

    lazy var nodeNameTextField: NeumorphismTextField = {
        NeumorphismTextField().then {
            $0.font = UIFont.styled(for: .title1)
            $0.textColor = R.color.neumorphism.textDark()
            $0.returnKeyType = .next
            $0.delegate = self
            $0.tag = TextFieldTag.name.rawValue
            $0.layer.borderWidth = 1
            $0.autocorrectionType = .no
            $0.layer.borderColor = UIColor.clear.cgColor
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.addTarget(self, action: #selector(nodeNameTextFieldDidChange), for: .editingChanged)
            $0.placeholder = R.string.localizable.referralReferralLink(preferredLanguages: .currentLocale)
        }
    }()

    private var nodeNameErrorLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .title4).withSize(11.0)
            $0.textColor = R.color.neumorphism.tint()
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()

    lazy var nodeAddressTextField: NeumorphismTextField = {
        NeumorphismTextField().then {
            $0.font = UIFont.styled(for: .title1)
            $0.textColor = R.color.neumorphism.textDark()
            $0.returnKeyType = .done
            $0.delegate = self
            $0.autocorrectionType = .no
            $0.autocapitalizationType = .none
            $0.layer.borderWidth = 1
            $0.layer.borderColor = UIColor.clear.cgColor
            $0.tag = TextFieldTag.address.rawValue
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.addTarget(self, action: #selector(nodeAddressTextFieldDidChange), for: .editingChanged)
            $0.placeholder = R.string.localizable.referralReferralLink(preferredLanguages: .currentLocale)
        }
    }()

    private var nodeAddressErrorLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .title4).withSize(11.0)
            $0.textColor = R.color.neumorphism.tint()
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }()

    var howToRunNodeButton: NeumorphismButton = {
        NeumorphismButton().then {
            $0.heightAnchor == 56
            $0.color = .clear
            $0.bottomShadowColor = .clear
            $0.topShadowColor = .clear
            $0.setTitleColor(R.color.neumorphism.tint() ?? .red, for: .normal)
            $0.font = UIFont.styled(for: .button)
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.addTarget(nil, action: #selector(howToRunTapped), for: .touchUpInside)
        }
    }()

    var submitButton: NeumorphismButton = {
        NeumorphismButton().then {
            $0.heightAnchor == 56
            $0.color = R.color.neumorphism.tint() ?? .white
            $0.colorDisabled = R.color.neumorphism.shareButtonGrey() ?? .white
            $0.font = UIFont.styled(for: .button)
            $0.isEnabled = false
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.addTarget(nil, action: #selector(submitTapped), for: .touchUpInside)
        }
    }()

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        presenter.setup()
        setupLocalization()
        configureNew()
    }

    init(presenter: CustomNodePresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
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

private extension OldCustomNodeViewController {

    func configureNew() {
        view.backgroundColor = .white

        view.addSubview(chestButton)
        view.addSubview(titleLabel)
        view.addSubview(nodeNameTextField)
        view.addSubview(nodeNameErrorLabel)
        view.addSubview(nodeAddressTextField)
        view.addSubview(nodeAddressErrorLabel)
        view.addSubview(howToRunNodeButton)
        view.addSubview(submitButton)

        chestButton.do {
            $0.topAnchor == view.topAnchor + 25
            $0.leadingAnchor == view.leadingAnchor + 9
            $0.heightAnchor == 24
            $0.widthAnchor == 24
        }

        titleLabel.do {
            $0.topAnchor == view.topAnchor + 25
            $0.leadingAnchor == view.leadingAnchor + 16
            $0.centerXAnchor == view.centerXAnchor
        }

        nodeNameTextField.do {
            $0.topAnchor == titleLabel.bottomAnchor + 25
            $0.leadingAnchor == view.leadingAnchor + 16
            $0.centerXAnchor == view.centerXAnchor
            $0.heightAnchor == 56
        }

        nodeNameErrorLabel.do {
            $0.topAnchor == nodeNameTextField.bottomAnchor + 4
            $0.leadingAnchor == nodeNameTextField.leadingAnchor + 16
            $0.centerXAnchor == nodeNameTextField.centerXAnchor
            $0.heightAnchor == 12
        }

        nodeAddressTextField.do {
            $0.topAnchor == nodeNameTextField.bottomAnchor + 16
            $0.leadingAnchor == view.leadingAnchor + 16
            $0.centerXAnchor == view.centerXAnchor
            $0.heightAnchor == 56
        }

        nodeAddressErrorLabel.do {
            $0.topAnchor == nodeAddressTextField.bottomAnchor + 4
            $0.leadingAnchor == nodeAddressTextField.leadingAnchor + 16
            $0.centerXAnchor == nodeAddressTextField.centerXAnchor
            $0.heightAnchor == 12
        }

        howToRunNodeButton.do {
            $0.centerXAnchor == view.centerXAnchor
            $0.leadingAnchor == view.leadingAnchor + 16
            $0.heightAnchor == 56
            $0.bottomAnchor == submitButton.topAnchor - 16
        }

        submitButton.do {
            $0.centerXAnchor == view.centerXAnchor
            $0.leadingAnchor == view.leadingAnchor + 16
            $0.heightAnchor == 56
            $0.bottomAnchor == view.bottomAnchor - 24
        }
    }

    private func setupLocalization() {
        titleLabel.text = R.string.localizable.selectNodeNodeDetails(preferredLanguages: languages)
        nodeNameTextField.placeholder = R.string.localizable.selectNodeNodeName(preferredLanguages: languages)
        nodeAddressTextField.placeholder = R.string.localizable.selectNodeNodeAddress(preferredLanguages: languages)
        howToRunNodeButton.setTitle(R.string.localizable.selectNodeHowToRunNode(preferredLanguages: languages) , for: .normal)
        submitButton.setTitle(R.string.localizable.commonSubmit(preferredLanguages: languages), for: .normal)
    }
}

extension OldCustomNodeViewController: UITextFieldDelegate {
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

extension OldCustomNodeViewController: CustomNodeViewProtocol {
    func updateFields(name: String, url: String) {
        nodeAddressTextField.text = url
        nodeNameTextField.text = name
        changeSubmitButton(to: true)
    }

    func showNameTextField(_ error: String) {
        nodeNameTextField.layer.borderColor = R.color.neumorphism.tint()?.cgColor
        nodeNameErrorLabel.text = error
    }

    func showAddressTextField(_ error: String) {
        nodeAddressTextField.layer.borderColor = R.color.neumorphism.tint()?.cgColor
        nodeAddressErrorLabel.text = error
    }

    func resetState() {
        nodeAddressTextField.layer.borderColor = UIColor.clear.cgColor
        nodeNameErrorLabel.text = ""
        nodeAddressErrorLabel.text = ""
    }

    func changeSubmitButton(to isEnabled: Bool) {
        submitButton.isEnabled = isEnabled

        let textColor = isEnabled ? R.color.neumorphism.base() : R.color.neumorphism.buttonTextDisabled()
        submitButton.setTitleColor(textColor, for: .normal)
    }
}

// MARK: - Localizable

extension OldCustomNodeViewController: Localizable {
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
