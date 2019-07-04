/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit
import SoraUI

final class StartupViewController: UIViewController, AdaptiveDesignable {
	var presenter: StartupPresenterProtocol!

    @IBOutlet private var loadingView: LoadingView!
    @IBOutlet private var loadingTop: NSLayoutConstraint!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var subtitleLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        adjustConstraints()

        loadingView.startAnimating()

        presenter.viewIsReady()
    }

    private func adjustConstraints() {
        loadingTop.constant *= designScaleRatio.height
    }
}

extension StartupViewController: StartupViewProtocol {
    func didUpdate(title: String, subtitle: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }
}
