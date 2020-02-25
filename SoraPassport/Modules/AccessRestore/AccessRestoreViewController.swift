/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraUI
import SoraFoundation

final class AccessRestoreViewController: AccessoryViewController {
    var presenter: AccessRestorePresenterProtocol!

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var roundedView: RoundedView!
    @IBOutlet private var phraseTextView: UITextView!
    @IBOutlet private var phrasePlaceholder: UILabel!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var subtitleLabel: UILabel!

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

        presenter.load()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        phraseTextView.becomeFirstResponder()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        phraseTextView.resignFirstResponder()
    }

    private func configureTextView() {
        phraseTextView.tintColor = UIColor.inputIndicator
    }

    // MARK: Accessory Override

    override func setupLocalization() {
        super.setupLocalization()

        let languages = localizationManager?.preferredLocalizations

        title = R.string.localizable.recoveryTitle(preferredLanguages: languages)

        titleLabel.text = R.string.localizable.recoveryBodyTitle(preferredLanguages: languages)
        subtitleLabel.text = R.string.localizable.recoveryBodySubtitle(preferredLanguages: languages)
        phrasePlaceholder.text = R.string.localizable.recoveryPassphrase(preferredLanguages: languages)
    }

    override func updateBottom(inset: CGFloat) {
        super.updateBottom(inset: inset)

        var contentInset = scrollView.contentInset
        contentInset.bottom = inset
        scrollView.contentInset = contentInset
    }

    override func actionAccessory() {
        super.actionAccessory()

        phraseTextView.resignFirstResponder()
        presenter.activateAccessRestoration()
    }

    // MARK: Text View

    private func updateNextButton() {
        accessoryView?.isActionEnabled = phraseTextView.text.count > 0
    }

    private func updatePlaceholder() {
        phrasePlaceholder.isHidden = phraseTextView.text.count > 0
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
