/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit
import SoraUI

final class InvitationManualInputViewController: UIViewController, AdaptiveDesignable {
    private struct Constants {
        static let bottomInset: CGFloat = 20.0
        static let verticalSpacingForDecreasedHeight: CGFloat = 0.4
    }

    var presenter: InvitationInputPresenterProtocol!

    var viewModel: CodeInputViewModelProtocol = CodeInputViewModel.invitation

    @IBOutlet private var contentView: UIView!
    @IBOutlet private var textField: UITextField!
    @IBOutlet private var nextButton: RoundedButton!

    @IBOutlet private var titleTop: NSLayoutConstraint!
    @IBOutlet private var fieldTop: NSLayoutConstraint!
    @IBOutlet private var fieldWidth: NSLayoutConstraint!
    @IBOutlet private var nextButtonWidth: NSLayoutConstraint!
    @IBOutlet private var nextButtonBottom: NSLayoutConstraint!

    private var keyboardHandler: KeyboardHandler?

    private var keyboardFrameOnFirstLayout: CGRect?
    private var isFirstLayoutCompleted: Bool = false

    // MARK: Initialization

    override func viewDidLoad() {
        super.viewDidLoad()

        adjustLayout()

        nextButton.disable()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setupKeyboardHandler()
        textField.becomeFirstResponder()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        clearKeyboardHandler()
        textField.resignFirstResponder()
    }

    override func viewDidLayoutSubviews() {
        guard !isFirstLayoutCompleted else {
            return
        }

        if let keyboardFrame = keyboardFrameOnFirstLayout {
            apply(keyboardFrame: keyboardFrame)
        }

        isFirstLayoutCompleted = true

        super.viewDidLayoutSubviews()
    }

    private func adjustLayout() {
        if isAdaptiveHeightDecreased {
            titleTop.constant *= designScaleRatio.height * Constants.verticalSpacingForDecreasedHeight
            fieldTop.constant *= designScaleRatio.height * Constants.verticalSpacingForDecreasedHeight
        } else {
            titleTop.constant *= designScaleRatio.height
            fieldTop.constant *= designScaleRatio.height
        }

        fieldWidth.constant *= designScaleRatio.width
        nextButtonWidth.constant *= designScaleRatio.width
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
        nextButtonBottom.constant = bottomInset + bottomMargin
        contentView.layoutIfNeeded()
    }

    // MARK: Actions

    @IBAction private func actionNext(sender: AnyObject) {
        textField.resignFirstResponder()

        presenter.process(viewModel: viewModel)
    }
}

extension InvitationManualInputViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        let result = viewModel.didReceiveReplacement(string, for: range)

        if viewModel.isComplete {
            nextButton.enable()
        } else {
            nextButton.disable()
        }

        return result
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if viewModel.isComplete {
            textField.resignFirstResponder()
            presenter.process(viewModel: viewModel)
            return false
        }

        return false
    }
}

extension InvitationManualInputViewController: InvitationInputViewProtocol {}

extension InvitationManualInputViewController: ErrorPresentable {
    func present(error: Error, from view: ControllerBackedProtocol?) -> Bool {
        return false
    }
}
