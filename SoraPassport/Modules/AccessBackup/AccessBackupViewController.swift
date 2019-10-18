/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraUI

final class AccessBackupViewController: AccessoryViewController {
    enum Mode {
        case registration
        case view
    }

    var presenter: AccessBackupPresenterProtocol!

    @IBOutlet private var phraseLabel: UILabel!
    @IBOutlet private var titleLabel: UILabel!

    var mode: Mode = .registration

    override func viewDidLoad() {
        super.viewDidLoad()

        shouldSetupKeyboardHandler = false

        configurePhraseLabel()

        presenter.viewIsReady()
    }

    private func configurePhraseLabel() {
        phraseLabel.text = ""
    }

    // MARK: Accessory View Controller

    override func configureAccessoryView() {
        if mode == .registration {
            super.configureAccessoryView()
        }
    }

    override func actionAccessory() {
        presenter.activateNext()
    }

    // MARK: Actions

    @IBAction private func actionShare(sender: AnyObject?) {
        presenter.activateSharing()
    }
}

extension AccessBackupViewController: AccessBackupViewProtocol {
    func didReceiveBackup(phrase: String) {
        phraseLabel.text = phrase
    }
}
