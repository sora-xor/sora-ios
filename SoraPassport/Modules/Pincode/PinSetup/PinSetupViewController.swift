import UIKit
import SoraUI
import SoraFoundation
import Anchorage
import Then

private extension PinSetupViewController {
    struct Constants {
        static let navigationBarMargin: CGFloat = 44
        static let pinViewMargin: CGFloat = 60
    }

    struct AccessibilityId {
        static let mainView     = "MainViewAccessibilityId"
        static let inputField   = "InputFieldAccessibilityId"
        static let keyPrefix    = "KeyPrefixAccessibilityId"
        static let backspace    = "BackspaceAccessibilityId"
    }
}

class PinSetupViewController: UIViewController, AdaptiveDesignable {

    var presenter: PinSetupPresenterProtocol!

    var mode: NeuPinView.Mode = .create

    var cancellable: Bool = false

    var barTitle: String {
        if mode == .securedInput { return "" }
        return mode == .create ? "" : R.string.localizable
            .profileChangePinTitle(preferredLanguages: languages).capitalized
    }

    var barButtonImage: UIImage? {
        return mode == .create ? R.image.arrowLeft() : R.image.close()
    }

    var baseDesignSize: CGSize {
        return CGSize(width: 375, height: 812)
    }

    @IBOutlet weak var pinViewStack: NeuPinView!
    @IBOutlet weak var topConstraint: NSLayoutConstraint!

    // MARK: - Controls

    private lazy var navigationBar: UINavigationBar = {
        UINavigationBar().then {
            $0.delegate = self
            $0.shadowImage = UIImage()
            $0.setBackgroundImage(UIImage(), for: .default)
            $0.tintColor = R.color.brandPMSBlack()
        }
    }()

    private lazy var cancelButtonItem: UINavigationItem = {
        UINavigationItem(title: barTitle).then {
            let barButton = UIBarButtonItem(
                image: barButtonImage, style: .plain,
                target: self, action: #selector(actionCancel)
            )

            $0.leftBarButtonItem = barButton
        }
    }()

    private lazy var backButtonItem: UINavigationItem = {
        UINavigationItem(title: barTitle).then {
            let barButton = UIBarButtonItem(
                image: barButtonImage, style: .plain,
                target: self, action: #selector(actionBack)
            )

            $0.leftBarButtonItem = barButton
        }
    }()

    private var titleLabel: UILabel = {
        UILabel().then {
            $0.font = UIFont.styled(for: .title1)
            $0.textColor = R.color.neumorphism.textDark()
        }
    }()

    private var titleSeparator: UIView = {
        UIView().then {
            $0.backgroundColor = R.color.neumorphism.separator()
            $0.widthAnchor == UIScreen.main.bounds.width
            $0.heightAnchor == 1.0
        }
    }()

    // MARK: - Constraints

    // MARK: - View Setup

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()

        setupLocalization()
        adjustLayoutConstraints()
        setupAccessibilityIdentifiers()

        presenter.start()
    }
}

private extension PinSetupViewController {

    // MARK: - Configure

    func configure() {

        view.backgroundColor = R.color.neumorphism.base()
        
        pinViewStack.delegate = self

        pinViewStack.do {
            $0.mode = mode
            $0.delegate = self
            $0.centerXAnchor == view.centerXAnchor
        }

        navigationBar.do {
            view.addSubview($0)
            $0.backgroundColor = R.color.neumorphism.base()
            $0.prefersLargeTitles = false
            $0.horizontalAnchors == view.horizontalAnchors
            $0.bottomAnchor == view.layoutMarginsGuide.topAnchor + Constants.navigationBarMargin
            $0.topAnchor == view.topAnchor + UIApplication.shared.statusBarFrame.size.height
        }

        titleLabel.do {
            view.addSubview($0)
            $0.centerXAnchor == view.centerXAnchor
            $0.centerYAnchor.constraint(equalTo: navigationBar.centerYAnchor).isActive = true
        }

        titleSeparator.do {
            view.addSubview($0)
            $0.centerXAnchor == view.centerXAnchor
            $0.topAnchor == navigationBar.bottomAnchor
        }

        if cancellable || presenter.isChangeMode {
            configureCancelButton()
        }
    }

    func configureCancelButton() {
        navigationBar.isHidden = false
        navigationBar.pushItem(cancelButtonItem, animated: false)
    }

    func updateTitleLabelState() {
        if pinViewStack.mode == .create {
            if  pinViewStack.creationState == .normal {
                titleLabel.text = R.string.localizable
                    .pincodeSetYourPinCode(preferredLanguages: languages).capitalized
            } else {
                titleLabel.text = R.string.localizable
                    .pincodeConfirmYourPinCode(preferredLanguages: languages).capitalized
            }
        } else {
            titleLabel.text = R.string.localizable
                .pincodeEnterPinCode(preferredLanguages: languages).capitalized
        }
    }

    func setupLocalization() {
        updateTitleLabelState()
    }

    // MARK: - Accessibility

    func setupAccessibilityIdentifiers() {
        view.accessibilityIdentifier = AccessibilityId.mainView
        pinViewStack.setupInputField(accessibilityId: AccessibilityId.inputField)
        pinViewStack.numpad.setupKeysAccessibilityIdWith(format: AccessibilityId.keyPrefix)
        pinViewStack.numpad.setupBackspace(accessibilityId: AccessibilityId.backspace)
    }

    // MARK: - Layout

    func adjustLayoutConstraints() {
        topConstraint.constant = Constants.navigationBarMargin
        if UIScreen.main.bounds.size.height <= 568 {
            pinViewStack.numpad.keyRadius = 70
        }
    }

    // MARK: - Action

    @objc func actionCancel() {
        presenter.cancel()
    }

    @objc func actionBack() {
        navigationBar.popItem(animated: false)
    }
}

extension PinSetupViewController: PinSetupViewProtocol {
    func didRequestBiometryUsage(biometryType: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void) {
        var title: String?
        var message: String?

        let languages = localizationManager?.selectedLocale.rLanguages

        switch biometryType {
        case .touchId:
            title = R.string.localizable.askTouchidTitle(preferredLanguages: languages)
            message = R.string.localizable.askTouchidMessage(preferredLanguages: languages)
        case .faceId:
            title = R.string.localizable.askFaceidTitle(preferredLanguages: languages)
            message = R.string.localizable.askFaceidMessage(preferredLanguages: languages)
        case .none:
            completionBlock(true)
            return
        }

        let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let useAction = UIAlertAction(
            title: R.string.localizable.commonOk(preferredLanguages: languages),
            style: .default) { (_: UIAlertAction) -> Void in
            completionBlock(true)
        }

        let skipAction = UIAlertAction(
            title: R.string.localizable.commonDonotallow(preferredLanguages: languages),
            style: .cancel) { (_: UIAlertAction) -> Void in
            completionBlock(false)
        }

        alertView.addAction(useAction)
        alertView.addAction(skipAction)

        self.present(alertView, animated: true, completion: nil)
    }

    func didReceiveWrongPincode() {
        if mode != .create {
            pinViewStack?.reset(shouldAnimateError: true)
        }
    }

    func didChangeAccessoryState(enabled: Bool) {
        pinViewStack?.numpad.supportsAccessoryControl = enabled
    }
}

extension PinSetupViewController: NeuPinViewDelegate {

    func didCompleteInput(pinView: NeuPinView, result: String) {
        presenter.submit(pin: result)
    }

    func didChange(pinView: NeuPinView, from state: NeuPinView.CreationState) {
        updateTitleLabelState()
        if pinViewStack.creationState == .confirm {
            navigationBar.pushItem(backButtonItem, animated: false)
        } else {
            navigationBar.popItem(animated: false)
        }
    }

    func didSelectAccessoryControl(pinView: NeuPinView) {
        presenter.activateBiometricAuth()
    }

    func didFailConfirmation(pinView: NeuPinView) {
        // can return to the previous screen
    }
}

extension PinSetupViewController: UINavigationBarDelegate {
    func navigationBar(_ navigationBar: UINavigationBar, shouldPop item: UINavigationItem) -> Bool {
        pinViewStack.resetCreationState(animated: true)
        updateTitleLabelState()
        return true
    }
}

extension PinSetupViewController: Localizable {
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
