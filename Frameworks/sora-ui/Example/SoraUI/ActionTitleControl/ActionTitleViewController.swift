/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit
import SoraUI

final class ActionTitleViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        configureTitleView()
    }

    func configureTitleView() {
        let actionTitleControl = ActionTitleControl()
        actionTitleControl.titleLabel.textColor = UIColor(red: 0.0 / 255.0, green: 50.0 / 255.0, blue: 77.0 / 255.0, alpha: 1.0)
        actionTitleControl.titleLabel.font = UIFont.boldSystemFont(ofSize: 16.0)
        actionTitleControl.titleLabel.text = "username"
        actionTitleControl.imageView.tintColor = UIColor(red: 0.0 / 255.0, green: 50.0 / 255.0, blue: 77.0 / 255.0, alpha: 1.0)
        actionTitleControl.imageView.image = UIImage(named: "iconArrowDown.png")
        actionTitleControl.sizeToFit()

        navigationItem.titleView = actionTitleControl
    }
}
