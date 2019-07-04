/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit
import SoraUI

final class PhoneVerificationViewController: UIViewController, AdaptiveDesignable {
    private struct Constants {
        static let bottomInset: CGFloat = 20.0
        static let verticalSpacingForDecreasedHeight: CGFloat = 0.6
    }

	var presenter: PhoneVerificationPresenterProtocol!

    var viewModel: CodeInputViewModelProtocol?

    @IBOutlet private var contentView: UIView!
    @IBOutlet private var textField: UITextField!
    @IBOutlet private var nextButton: RoundedButton!
    @IBOutlet private var resendDelayLabel: UILabel!
    @IBOutlet private var resendButton: UIButton!

    @IBOutlet private var titleTop: NSLayoutConstraint!
    @IBOutlet private var fieldTop: NSLayoutConstraint!
    @IBOutlet private var fieldWidth: NSLayoutConstraint!
    @IBOutlet private var nextButtonWidth: NSLayoutConstraint!
    @IBOutlet private var nextButtonHeight: NSLayoutConstraint!
    @IBOutlet private var nextButtonBottom: NSLayoutConstraint!
    @IBOutlet private var resendLabelTop: NSLayoutConstraint!

    private var keyboardHandler: KeyboardHandler?

    lazy var frameUpdateAnimation = BlockViewAnimator()

    private var keyboardFrameOnFirstLayout: CGRect?
    private var isFirstLayoutCompleted: Bool = false

    lazy private(set) var resendDelayTimeFormatter = TimeFormatter()

    override func viewDidLoad() {
        super.viewDidLoad()

        configureContentView()
        adjustLayout()

        presenter.viewIsReady()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setupKeyboardHandler()
        textField.becomeFirstResponder()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        updateKeyboardLayout(animated: true)
        view.setNeedsLayout()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        clearKeyboardHandler()
        textField.resignFirstResponder()

        presenter.viewDidDisappear()
    }

    override func viewDidLayoutSubviews() {
        guard !isFirstLayoutCompleted else {
            return
        }

        updateKeyboardLayout(animated: false)

        isFirstLayoutCompleted = true

        super.viewDidLayoutSubviews()
    }

    private func adjustLayout() {
        if isAdaptiveHeightDecreased {
            titleTop.constant *= designScaleRatio.height * Constants.verticalSpacingForDecreasedHeight
            fieldTop.constant *= designScaleRatio.height * Constants.verticalSpacingForDecreasedHeight
            resendLabelTop.constant *= designScaleRatio.height * Constants.verticalSpacingForDecreasedHeight
        } else {
            titleTop.constant *= designScaleRatio.height
            fieldTop.constant *= designScaleRatio.height
        }

        fieldWidth.constant *= designScaleRatio.width
        nextButtonWidth.constant *= designScaleRatio.width
    }

    private func configureContentView() {
        resendDelayLabel.isHidden = true
        resendButton.isHidden = true
        nextButton.disable()
    }

    private func updateCodeDisplay() {
        guard let viewModel = viewModel else {
            return
        }

        textField.text = viewModel.code

        if viewModel.isComplete {
            nextButton.enable()
        } else {
            nextButton.disable()
        }
    }

    // MARK: Keyboard

    private func setupKeyboardHandler() {
        keyboardHandler = KeyboardHandler()
        keyboardHandler?.animateOnFrameChange = animateKeyboardChange
    }

    private func clearKeyboardHandler() {
        keyboardHandler = nil
    }

    private func animateKeyboardChange(keyboardFrame: CGRect) {
        guard isFirstLayoutCompleted else {
            keyboardFrameOnFirstLayout = keyboardFrame
            return
        }

        apply(keyboardFrame: keyboardFrame)

        view.layoutIfNeeded()
    }

    private func updateKeyboardLayout(animated: Bool) {
        if let keyboardFrame = keyboardFrameOnFirstLayout {
            if animated {
                frameUpdateAnimation.animate(block: { self.apply(keyboardFrame: keyboardFrame) },
                                             completionBlock: nil)
            } else {
                self.apply(keyboardFrame: keyboardFrame)
            }
        }
    }

    private func apply(keyboardFrame: CGRect) {
        let localKeyboardFrame = view.convert(keyboardFrame, from: nil)
        var bottomMargin: CGFloat = 0.0

        if #available(iOS 11.0, *) {
            bottomMargin = view.safeAreaLayoutGuide.layoutFrame.maxY - localKeyboardFrame.origin.y
        } else {
            bottomMargin = view.bounds.height - localKeyboardFrame.origin.y
        }

        bottomMargin = max(0, bottomMargin)

        let bottomInset = isAdaptiveHeightDecreased ? Constants.bottomInset * designScaleRatio.height
            : Constants.bottomInset

        let potentialButtonPosition = localKeyboardFrame.origin.y - bottomInset -
            nextButtonHeight.constant

        let restrictedPosition = resendDelayLabel.frame.maxY + resendLabelTop.constant

        if potentialButtonPosition > restrictedPosition {
            nextButtonBottom.constant = bottomInset + bottomMargin
        } else {
            nextButtonBottom.constant = bottomInset
        }

        contentView.layoutIfNeeded()
    }

    // MARK: Actions

    @IBAction private func actionNext(sender: AnyObject) {
        textField.resignFirstResponder()

        guard let viewModel = viewModel else {
            return
        }

        presenter.process(viewModel: viewModel)
    }

    @IBAction private func actionResend(sender: AnyObject) {
        presenter.resendCode()
    }
}

extension PhoneVerificationViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        guard let viewModel = viewModel else {
            return true
        }

        let result = viewModel.didReceiveReplacement(string, for: range)

        if viewModel.isComplete {
            nextButton.enable()
        } else {
            nextButton.disable()
        }

        return result
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        return false
    }
}

extension PhoneVerificationViewController: PhoneVerificationViewProtocol {
    func didReceive(viewModel: CodeInputViewModelProtocol) {
        self.viewModel = viewModel

        updateCodeDisplay()
    }

    func didUpdateResendRemained(delay: TimeInterval) {
        if delay > 0.0 {
            resendDelayLabel.isHidden = false
            resendButton.isHidden = true

            do {
                let timeString = try resendDelayTimeFormatter.string(from: delay)
                resendDelayLabel.text = R.string.localizable.phoneVerificationCodeResendFormat(timeString)
            } catch {
                resendDelayLabel.text = R.string.localizable.phoneVerificationCodeResendFormat("")
            }

        } else {
            resendDelayLabel.isHidden = true
            resendButton.isHidden = false
        }
    }
}
