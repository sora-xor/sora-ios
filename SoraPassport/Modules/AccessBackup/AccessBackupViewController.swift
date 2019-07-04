/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit
import SoraUI

final class AccessBackupViewController: UIViewController, AdaptiveDesignable {
    enum Mode {
        case registration
        case view
    }

    private struct Constants {
        static let heightCoeff: CGFloat = 0.7
    }

    var presenter: AccessBackupPresenterProtocol!

    @IBOutlet private var phraseLabel: UILabel!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var nextButton: RoundedButton!

    @IBOutlet private var titleTop: NSLayoutConstraint!
    @IBOutlet private var titleLeading: NSLayoutConstraint!
    @IBOutlet private var titleTralling: NSLayoutConstraint!
    @IBOutlet private var roundViewTop: NSLayoutConstraint!
    @IBOutlet private var roundViewLeading: NSLayoutConstraint!
    @IBOutlet private var roundViewTralling: NSLayoutConstraint!
    @IBOutlet private var phraseTitleTop: NSLayoutConstraint!
    @IBOutlet private var phraseTop: NSLayoutConstraint!
    @IBOutlet private var phraseLeading: NSLayoutConstraint!
    @IBOutlet private var phraseTralling: NSLayoutConstraint!
    @IBOutlet private var phraseBottom: NSLayoutConstraint!
    @IBOutlet private var saveTop: NSLayoutConstraint!
    @IBOutlet private var saveLeading: NSLayoutConstraint!
    @IBOutlet private var saveTralling: NSLayoutConstraint!
    @IBOutlet private var saveBottom: NSLayoutConstraint!
    @IBOutlet private var nextTop: NSLayoutConstraint!
    @IBOutlet private var nextBottom: NSLayoutConstraint!

    var mode: Mode = .registration

    override func viewDidLoad() {
        super.viewDidLoad()

        configurePhraseLabel()
        configureTitleLabel()
        configureNextButton()
        adjustConstraints()

        presenter.viewIsReady()
    }

    private func configureTitleLabel() {
        guard let attributedString = titleLabel.attributedText?.mutableCopy() as? NSMutableAttributedString else {
            return
        }

        let newAttributes = [NSAttributedString.Key.font: UIFont.phraseTitle]
        attributedString.addAttributes(newAttributes, range: NSRange(location: 0, length: attributedString.length))
        titleLabel.attributedText = attributedString
    }

    private func configurePhraseLabel() {
        phraseLabel.text = ""
    }

    private func configureNextButton() {
        switch mode {
        case .registration:
            nextButton.isHidden = false
        case .view:
            nextButton.isHidden = true
        }
    }

    private func adjustConstraints() {
        if isAdaptiveWidthDecreased {
            titleTop.constant *= designScaleRatio.width * Constants.heightCoeff
            titleLeading.constant *= designScaleRatio.width
            titleTralling.constant *= designScaleRatio.width
            roundViewTop.constant *= designScaleRatio.width * Constants.heightCoeff
            roundViewLeading.constant *= designScaleRatio.width
            roundViewTralling.constant *= designScaleRatio.width
            phraseTitleTop.constant *= designScaleRatio.width * Constants.heightCoeff
            phraseTop.constant *= designScaleRatio.width
            phraseLeading.constant *= designScaleRatio.width
            phraseTralling.constant *= designScaleRatio.width
            phraseBottom.constant *= designScaleRatio.width * Constants.heightCoeff
            saveTop.constant *= designScaleRatio.width * Constants.heightCoeff
            saveLeading.constant *= designScaleRatio.width
            saveTralling.constant *= designScaleRatio.width
            saveBottom.constant *= designScaleRatio.width * Constants.heightCoeff
            nextTop.constant *= designScaleRatio.width * Constants.heightCoeff
            nextBottom.constant *= designScaleRatio.width * Constants.heightCoeff
        }
    }

    // MARK: Actions

    @IBAction private func actionShare(sender: AnyObject?) {
        presenter.activateSharing()
    }

    @IBAction private func actionNext(sender: AnyObject?) {
        presenter.activateNext()
    }
}

extension AccessBackupViewController: AccessBackupViewProtocol {
    func didReceiveBackup(phrase: String) {
        phraseLabel.text = phrase
    }
}
