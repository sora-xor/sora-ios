/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit
import SoraUI

final class ModalSheetPresentationViewController: UIViewController {

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
        view.backgroundColor = .darkText

        let headerStyle = ModalSheetPresentationHeaderStyle(preferredHeight: 20.0,
                                                            backgroundColor: .darkText,
                                                            cornerRadius: 10.0,
                                                            indicatorVerticalOffset: 2.0,
                                                            indicatorSize: CGSize(width: 25, height: 2.0),
                                                            indicatorColor: .lightGray)
        let style = ModalSheetPresentationStyle(backdropColor: UIColor.black.withAlphaComponent(0.19),
                                                    headerStyle: headerStyle)

        let appearanceAnimator = BlockViewAnimator(duration: 0.25,
                                                   delay: 0.0,
                                                   options: [.curveEaseOut])
        let dismissalAnimator = BlockViewAnimator(duration: 0.25,
                                                  delay: 0.0,
                                                  options: [.curveLinear])

        let configuration = ModalSheetPresentationConfiguration(contentAppearanceAnimator: appearanceAnimator,
                                                                contentDissmisalAnimator: dismissalAnimator,
                                                                style: style,
                                                                extendUnderSafeArea: true,
                                                                dismissFinishSpeedFactor: 0.6,
                                                                dismissCancelSpeedFactor: 0.6)

        let viewController = UIViewController()
        viewController.preferredContentSize = CGSize(width: 0.0, height: 295.0)
        viewController.view = view
        viewController.modalTransitioningFactory = ModalSheetPresentationFactory(configuration: configuration)
        viewController.modalPresentationStyle = .custom

        present(viewController, animated: true, completion: nil)
    }
}
