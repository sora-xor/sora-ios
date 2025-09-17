/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit
import SoraUI

final class ModalAlertPresentationViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        configureSelectButton()
    }

    private func configureSelectButton() {
        let selectItem = UIBarButtonItem(title: "Select",
                                         style: .plain,
                                         target: self,
                                         action: #selector(actionSelect))
        navigationItem.rightBarButtonItem = selectItem
    }

    // MARK

    @objc func actionSelect() {
        let view = UIView()
        view.backgroundColor = UIColor.lightGray.withAlphaComponent(0.19)

        let style = ModalAlertPresentationStyle(backgroundColor: .lightGray,
                                                backdropColor: UIColor.black.withAlphaComponent(0.19),
                                                cornerRadius: 10.0)

        let configuration = ModalAlertPresentationConfiguration(style: style,
                                                                preferredSize: CGSize(width: 250.0, height: 200.0),
                                                                completionFeedback: .success)

        let viewController = UIViewController()
        viewController.view = view
        viewController.modalTransitioningFactory = ModalAlertPresentationFactory(configuration: configuration)
        viewController.modalPresentationStyle = .custom

        present(viewController, animated: true, completion: nil)
    }
}
