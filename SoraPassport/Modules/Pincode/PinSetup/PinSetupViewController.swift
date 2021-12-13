import UIKit
import SoraUI
import SoraFoundation
import Anchorage
import Then

private extension PinSetupViewController {
    struct Constants {
        static let navigationBarMargin: CGFloat = 44
        static let pinViewMargin: CGFloat = 40
        static let logoBottomMargin: CGFloat = 40
        static let logoHeight: CGFloat = 88
        static let logoWidth: CGFloat = 66
    }

    struct AccessibilityId {
        static let mainView     = "MainViewAccessibilityId"
        static let bgView       = "BgViewAccessibilityId"
        static let inputField   = "InputFieldAccessibilityId"
        static let keyPrefix    = "KeyPrefixAccessibilityId"
        static let backspace    = "BackspaceAccessibilityId"
    }
}

class PinSetupViewController: UIViewController, AdaptiveDesignable {

    var presenter: PinSetupPresenterProtocol!

    var mode: PinView.Mode = .create

    var cancellable: Bool = false

    var logoPresentable: Bool {
        return mode == .securedInput && !cancellable
    }

    var barTitle: String {
        if mode == .securedInput { return "" }
        return mode == .create ? "" : R.string.localizable
            .profileChangePinTitle(preferredLanguages: languages)
    }

    var barButtonImage: UIImage? {
        return mode == .create ? R.image.arrowLeft() : R.image.close()
    }

    var baseDesignSize: CGSize {
        return CGSize(width: 375, height: 812)
    }

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
            $0.font = UIFont.styled(for: .uppercase2, isBold: true)
            $0.textColor = R.color.brandPMSBlack()
        }
    }()

    @IBOutlet private var pinView: PinView!

    // MARK: - Constraints

    private var pinViewTopConstraint: NSLayoutConstraint!
    private var pinViewBottomConstraint: NSLayoutConstraint!

    private var logoBottomConstraint: NSLayoutConstraint!
    private var logoHeightConstraint: NSLayoutConstraint!
    private var logoWidthConstraint: NSLayoutConstraint!

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

        pinView.do {
            $0.mode = mode
            $0.delegate = self
            $0.centerXAnchor == view.centerXAnchor
            pinViewBottomConstraint = (
                $0.bottomAnchor == view.bottomAnchor - Constants.pinViewMargin
            )
        }

        titleLabel.do {
            view.addSubview($0)
            $0.centerXAnchor == view.centerXAnchor
            pinViewTopConstraint = (
                pinView.topAnchor == $0.bottomAnchor + Constants.pinViewMargin
            )
        }

        navigationBar.do {
            view.addSubview($0)
            $0.prefersLargeTitles = false
            $0.horizontalAnchors == view.horizontalAnchors
            $0.bottomAnchor == view.layoutMarginsGuide.topAnchor + Constants.navigationBarMargin
            $0.topAnchor == view.topAnchor + UIApplication.shared.statusBarFrame.size.height
        }

        if cancellable || presenter.isChangeMode {
            configureCancelButton()
        }

        if logoPresentable {
            configureLogoImageView()
        }
    }

    func configureCancelButton() {
        navigationBar.isHidden = false
        navigationBar.pushItem(cancelButtonItem, animated: false)
    }

    func configureLogoImageView() {
        let imageView = UIImageView(
            image: R.image.pin.soraVertical()
        )

        imageView.do {
            view.addSubview($0)
            $0.centerXAnchor == view.centerXAnchor

            logoBottomConstraint = (
                $0.bottomAnchor == titleLabel.topAnchor - Constants.logoBottomMargin
            )

            logoHeightConstraint = (
                $0.heightAnchor == Constants.logoHeight
            )

            logoWidthConstraint = (
                $0.widthAnchor == Constants.logoWidth
            )
        }
    }

    func updateTitleLabelState() {
        if pinView.mode == .create {
            if  pinView.creationState == .normal {
                titleLabel.text = R.string.localizable
                    .pincodeSetYourPinCode(preferredLanguages: languages)
                    .uppercased()
            } else {
                titleLabel.text = R.string.localizable
                    .pincodeConfirmYourPinCode(preferredLanguages: languages)
                    .uppercased()
            }
        } else {
            titleLabel.text = R.string.localizable
                .pincodeEnterPinCode(preferredLanguages: languages)
                .uppercased()
        }

    }

    func setupLocalization() {
        updateTitleLabelState()
    }

    // MARK: - Accessibility

    func setupAccessibilityIdentifiers() {
        view.accessibilityIdentifier = AccessibilityId.mainView
        pinView.setupInputField(accessibilityId: AccessibilityId.inputField)
        pinView.numpadView?.setupKeysAccessibilityIdWith(format: AccessibilityId.keyPrefix)
        pinView.numpadView?.setupBackspace(accessibilityId: AccessibilityId.backspace)
    }

    // MARK: - Layout

    func adjustLayoutConstraints() {
        pinView.adjustLayout()

        pinViewTopConstraint.constant *= designScaleRatio.height
        pinViewBottomConstraint.constant *= designScaleRatio.height

        if logoPresentable {
            let koef: CGFloat = isAdaptiveHeightDecreased ? 1.5 : 1.0
            logoBottomConstraint.constant *= designScaleRatio.height * koef
            logoHeightConstraint.constant *= designScaleRatio.height
            logoWidthConstraint.constant *= designScaleRatio.height
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
            pinView?.reset(shouldAnimateError: true)
        }
    }

    func didChangeAccessoryState(enabled: Bool) {
        pinView?.numpadView?.supportsAccessoryControl = enabled
    }
}

extension PinSetupViewController: PinViewDelegate {

    func didCompleteInput(pinView: PinView, result: String) {
        presenter.submit(pin: result)
    }

    func didChange(pinView: PinView, from state: PinView.CreationState) {
        updateTitleLabelState()
        if pinView.creationState == .confirm {
            navigationBar.pushItem(backButtonItem, animated: false)
        } else {
            navigationBar.popItem(animated: false)
        }
    }

    func didSelectAccessoryControl(pinView: PinView) {
        presenter.activateBiometricAuth()
    }

    func didFailConfirmation(pinView: PinView) {
        // can return to the previous screen
    }
}

extension PinSetupViewController: UINavigationBarDelegate {
    func navigationBar(_ navigationBar: UINavigationBar, shouldPop item: UINavigationItem) -> Bool {
        pinView.resetCreationState(animated: true)
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

extension PinView: AdaptiveDesignable {

    public var baseDesignSize: CGSize {
        return CGSize(width: 375, height: 812)
    }

    func adjustLayout() {
        if isAdaptiveHeightDecreased || isAdaptiveWidthDecreased {
            let scale = min(designScaleRatio.width, designScaleRatio.height)

            if let numpadView = self.numpadView {
                numpadView.keyRadius *= scale

                if let titleFont = numpadView.titleFont {
                    numpadView.titleFont = UIFont(
                        name: titleFont.fontName,
                        size: scale * titleFont.pointSize
                    )
                }
            }

            if let currentFieldsView = self.characterFieldsView {
                let font = currentFieldsView.fieldFont

                if let newFont = UIFont(name: font.fontName, size: scale * font.pointSize) {
                    currentFieldsView.fieldFont = newFont
                }
            }

            securedCharacterFieldsView?.fieldRadius *= scale
        }

        if isAdaptiveHeightDecreased {
            verticalSpacing *= designScaleRatio.height * 0.5
            numpadView?.verticalSpacing *= designScaleRatio.height
            characterFieldsView?.fieldSize.height *= designScaleRatio.height
            securedCharacterFieldsView?.fieldSize.height *= designScaleRatio.height
        }

        if isAdaptiveWidthDecreased {
            numpadView?.horizontalSpacing *= designScaleRatio.width
            characterFieldsView?.fieldSize.width *= designScaleRatio.width
            securedCharacterFieldsView?.fieldSize.width *= designScaleRatio.width
        }
    }
}
