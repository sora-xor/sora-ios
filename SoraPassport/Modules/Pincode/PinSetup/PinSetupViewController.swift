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

class PinSetupViewController: UIViewController, AdaptiveDesignable, HiddableBarWhenPushed {

    var presenter: PinSetupPresenterProtocol!

    var mode: NeuPinView.Mode = .create

    var cancellable: Bool = false

    private let formatter: DateComponentsFormatter = {

        var calendar = Calendar.current
        calendar.locale = LocalizationManager.shared.selectedLocale

        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

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

    private lazy var updatePinRequestView: UpdateRequestPinView = {
        let view = UpdateRequestPinView()
        view.isHidden = true
        view.delegate = presenter
        view.languages = languages
        return view
    }()
    
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

    private var timer: Timer?
    private var cooldownDate: Date = .init()

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

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer?.invalidate()
        timer = nil
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
        
        updatePinRequestView.do {
            view.addSubview($0)
            $0.centerXAnchor == view.centerXAnchor
            $0.leadingAnchor == view.leadingAnchor
            $0.topAnchor == view.safeAreaLayoutGuide.topAnchor
            $0.bottomAnchor == view.safeAreaLayoutGuide.bottomAnchor
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
        guard cooldownDate.timeIntervalSinceNow <= 0 else { return }
        
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
    func showLastChanceAlert() {
        var calendar = Calendar.current
        calendar.locale = LocalizationManager.shared.selectedLocale

        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar
        formatter.unitsStyle = .abbreviated

        let time = formatter.string(from: TimeInterval(60)) ?? ""

        let title = R.string.localizable.pincodeLastTryTitle(preferredLanguages: languages)
        let message = R.string.localizable.pincodeLastTrySubtitle(time, preferredLanguages: languages)
        let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let useAction = UIAlertAction(
            title: R.string.localizable.commonOk(preferredLanguages: languages),
            style: .default) { (_: UIAlertAction) -> Void in
        }

        alertView.addAction(useAction)

        self.present(alertView, animated: true, completion: nil)
    }

    func blockUserInputUntil(date: Date) {
        self.cooldownDate = date
        pinViewStack.isUserInteractionEnabled = false

        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] _ in
            guard let self = self else { return }

            let secondsLeft = self.cooldownDate.timeIntervalSinceNow

            let cooldownText = self.formatter.string(from: secondsLeft) ?? ""
            self.titleLabel.text = R.string.localizable.pincodeLockedTitle(cooldownText, preferredLanguages: self.languages)

            guard secondsLeft <= 0 else { return }
            self.updateTitleLabelState()
            self.pinViewStack.isUserInteractionEnabled = true
            self.timer?.invalidate()
            self.timer = nil
        })
        self.timer = timer
        RunLoop.current.add(timer, forMode: .common)
    }

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
    
    func updatePinCodeSymbolsCount(with count: Int) {
        pinViewStack?.numberOfCharacters = count
    }
    
    func showUpdatePinRequestView() {
        updatePinRequestView.isHidden = false
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
