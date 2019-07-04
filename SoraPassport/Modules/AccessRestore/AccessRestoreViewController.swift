/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit
import SoraUI

final class AccessRestoreViewController: UIViewController, AdaptiveDesignable {
    private struct Constants {
        static let nextBottomMargin: CGFloat = 20.0
        static let phraseBackgroundMinimumBottomMargin: CGFloat = 20.0
    }

    var presenter: AccessRestorePresenterProtocol!

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var roundedView: RoundedView!
    @IBOutlet private var nextButton: RoundedButton!
    @IBOutlet private var phraseTextView: UITextView!
    @IBOutlet private var phrasePlaceholder: UILabel!

    @IBOutlet private var titleTop: NSLayoutConstraint!
    @IBOutlet private var nextTop: NSLayoutConstraint!
    @IBOutlet private var nextHeight: NSLayoutConstraint!
    @IBOutlet private var scrollViewBottom: NSLayoutConstraint!

    private var keyboardFrameOnFirstLayout: CGRect?
    private var isFirstLayoutCompleted: Bool = false

    private var keyboardHandler: KeyboardHandler?

    private var model: AccessRestoreViewModelProtocol? {
        didSet {
            if let existingModel = model {
                phraseTextView.text = existingModel.phrase
            } else {
                phraseTextView.text = ""
            }

            updatePlaceholder()
            updateNextButton()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureTextView()
        updatePlaceholder()
        updateNextButton()
        adjustConstraints()

        presenter.load()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setupKeyboardHandler()
        phraseTextView.becomeFirstResponder()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        clearKeyboardHandler()
        phraseTextView.resignFirstResponder()
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

    private func configureTextView() {
        phraseTextView.tintColor = UIColor.inputIndicator
    }

    private func adjustConstraints() {
        if isAdaptiveHeightDecreased {
            titleTop.constant *= designScaleRatio.height
        }
    }

    // MARK: Keyboard

    func setupKeyboardHandler() {
        keyboardHandler = KeyboardHandler()
        keyboardHandler?.animateOnFrameChange = animateKeyboardChange
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
        scrollViewBottom.constant = view.bounds.maxY - localKeyboardFrame.minY

        let localScrollKeyboardY = localKeyboardFrame.origin.y - scrollView.frame.minY
        var newNextOriginY = localScrollKeyboardY - Constants.nextBottomMargin - nextHeight.constant

        if #available(iOS 11.0, *) {
            newNextOriginY -= max(localKeyboardFrame.origin.y - view.safeAreaLayoutGuide.layoutFrame.maxY, 0)
        }

        let originLimitY = roundedView.frame.maxY + Constants.phraseBackgroundMinimumBottomMargin
        if newNextOriginY >= originLimitY {
            nextTop.constant = newNextOriginY - originLimitY + Constants.phraseBackgroundMinimumBottomMargin
        } else {
            nextTop.constant = Constants.phraseBackgroundMinimumBottomMargin
        }
    }

    func clearKeyboardHandler() {
        keyboardHandler = nil
    }

    // MARK: Text View

    private func updateNextButton() {
        if phraseTextView.text.count > 0 {
            nextButton.enable()
        } else {
            nextButton.disable()
        }
    }

    private func updatePlaceholder() {
        phrasePlaceholder.isHidden = phraseTextView.text.count > 0
    }

    // MARK: Action

    @IBAction private func actionNext(sender: AnyObject?) {
        phraseTextView.resignFirstResponder()
        presenter.activateAccessRestoration()
    }
}

extension AccessRestoreViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updatePlaceholder()
        updateNextButton()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text.rangeOfCharacter(from: CharacterSet.newlines) != nil {
            phraseTextView.resignFirstResponder()
            presenter.activateAccessRestoration()
            return false
        }

        if let model = model {
            return model.didReceiveReplacement(text, for: range)
        } else {
            return false
        }
    }
}

extension AccessRestoreViewController: AccessRestoreViewProtocol {
    func didReceiveView(model: AccessRestoreViewModelProtocol) {
        self.model = model
    }
}
