/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraUI

class PinSetupViewController: UIViewController, AdaptiveDesignable {
    var presenter: PinSetupPresenterProtocol!
    var mode = PinView.Mode.create

    var mainViewAccessibilityId: String? = "MainViewAccessibilityId"
    var bgViewAccessibilityId: String? = "BgViewAccessibilityId"
    var inputFieldAccessibilityId: String? = "InputFieldAccessibilityId"
    var keyPrefixAccessibilityId: String? = "KeyPrefixAccessibilityId"
    var backspaceAccessibilityId: String? = "BackspaceAccessibilityId"

    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var pinView: PinView!

    @IBOutlet private var navigationBar: UINavigationBar!

    @IBOutlet private var navigationBarTop: NSLayoutConstraint!
    @IBOutlet private var titleTopConstraint: NSLayoutConstraint!
    @IBOutlet private var pinViewTopConstraint: NSLayoutConstraint!
    @IBOutlet private var pinViewBottomConstraint: NSLayoutConstraint!

    // MARK: View Setup

    override func viewDidLoad() {
        super.viewDidLoad()

        configureNavigationBar()
        configurePinView()
        updateTitleLabelState()
        adjustLayoutConstraints()
        setupAccessibilityIdentifiers()

        presenter.start()
    }

    // MARK: Configure

    private func configureNavigationBar() {
        navigationBarTop.constant = UIApplication.shared.statusBarFrame.size.height

        navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        navigationBar.shadowImage = UIImage()
        navigationBar.delegate = self
    }

    private func updateTitleLabelState() {
        if pinView.mode == .create {
            if  pinView.creationState == .normal {
                titleLabel.text = R.string.localizable.pinsetupTitleCreate()
            } else {
                titleLabel.text = R.string.localizable.pinsetupTitleRepeat()
            }
        } else {
            titleLabel.text = R.string.localizable.pinsetupTitleEnter()
        }

    }

    private func configurePinView() {
        pinView.mode = mode
        pinView.delegate = self
    }

    // MARK: Accessibility

    private func setupAccessibilityIdentifiers() {
        view.accessibilityIdentifier = mainViewAccessibilityId
        pinView.setupInputField(accessibilityId: inputFieldAccessibilityId)
        pinView.numpadView?.setupKeysAccessibilityIdWith(format: keyPrefixAccessibilityId)
        pinView.numpadView?.setupBackspace(accessibilityId: backspaceAccessibilityId)
    }

    // MARK: Layout

    private func adjustLayoutConstraints() {
        let designScaleRatio = self.designScaleRatio

        if isAdaptiveHeightDecreased || isAdaptiveWidthDecreased {
            let scale = min(designScaleRatio.width, designScaleRatio.height)

            if let numpadView = pinView.numpadView {
                pinView.numpadView?.keyRadius *= scale

                if let titleFont = numpadView.titleFont {
                    numpadView.titleFont = UIFont(name: titleFont.fontName, size: scale * titleFont.pointSize)
                }
            }

            if let currentFieldsView = pinView.characterFieldsView {
                let font = currentFieldsView.fieldFont

                if let newFont = UIFont(name: font.fontName, size: scale * font.pointSize) {
                    currentFieldsView.fieldFont = newFont
                }
            }

            pinView.securedCharacterFieldsView?.fieldRadius *= scale
        }

        if isAdaptiveHeightDecreased {
            pinView.verticalSpacing *= designScaleRatio.height
            pinView.numpadView?.verticalSpacing *= designScaleRatio.height
            pinView.characterFieldsView?.fieldSize.height *= designScaleRatio.height
            pinView.securedCharacterFieldsView?.fieldSize.height *= designScaleRatio.height
        }

        if isAdaptiveWidthDecreased {
            pinView.numpadView?.horizontalSpacing *= designScaleRatio.width
            pinView.characterFieldsView?.fieldSize.width *= designScaleRatio.width
            pinView.securedCharacterFieldsView?.fieldSize.width *= designScaleRatio.width
        }

        titleTopConstraint.constant *= designScaleRatio.height
        pinViewTopConstraint.constant *= designScaleRatio.height
        pinViewBottomConstraint.constant *= designScaleRatio.height
    }
}

extension PinSetupViewController: PinSetupViewProtocol {
    func didRequestBiometryUsage(biometryType: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void) {
        var title: String?
        var message: String?

        switch biometryType {
        case .touchId:
            title = R.string.localizable.askTouchidTitle()
            message = R.string.localizable.askTouchidMessage()
        case .faceId:
            title = R.string.localizable.askFaceidTitle()
            message = R.string.localizable.askFaceidMessage()
        case .none:
            completionBlock(true)
            return
        }

        let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let yesAction = UIAlertAction(title: R.string.localizable.yes(),
                                      style: .default) { (_: UIAlertAction) -> Void in
            completionBlock(true)
        }

        let noAction = UIAlertAction(title: R.string.localizable.no(), style: .cancel) { (_: UIAlertAction) -> Void in
            completionBlock(false)
        }

        alertView.addAction(yesAction)
        alertView.addAction(noAction)

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
            navigationBar.pushItem(UINavigationItem(), animated: true)
        } else {
            navigationBar.popItem(animated: true)
        }
    }

    func didSelectAccessoryControl(pinView: PinView) {
        presenter.activateBiometricAuth()
    }
}

extension PinSetupViewController: UINavigationBarDelegate {
    func navigationBar(_ navigationBar: UINavigationBar, shouldPop item: UINavigationItem) -> Bool {
        pinView.resetCreationState(animated: true)
        updateTitleLabelState()
        return true
    }
}
