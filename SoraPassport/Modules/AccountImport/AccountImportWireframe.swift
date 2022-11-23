/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import IrohaCrypto
import SoraFoundation
import SoraUI

final class AccountImportWireframe: AccountImportWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()
    
    let localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    func proceed(from view: AccountImportViewProtocol?) {
        guard let pincodeViewController = PinViewFactory.createPinSetupView()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: pincodeViewController)
    }

    func showAccountImportSourceSelector(from controller: UIViewController,
                                         title: String,
                                         sourceTypes: [AccountImportSource],
                                         selectedIndex: Int,
                                         delegate: SourceSelectorViewDelegate) {
        let view = R.nib.sourceSelectorView(owner: nil, options: nil)!
        view.localizationManager = localizationManager
        view.titleText = title
        view.sourceTypes = sourceTypes
        view.selectedSourceTypeIndex = selectedIndex
        view.delegate = delegate

        let variantsHeight: CGFloat = CGFloat(40 * sourceTypes.count)
        let topHeaderOffset: CGFloat = 20
        let headerHeight: CGFloat = 11
        let bottomHeaderOffset: CGFloat = 16
        let bottomStackViewOffset: CGFloat = 10

        let height = [variantsHeight,
                      topHeaderOffset,
                      headerHeight,
                      bottomHeaderOffset,
                      bottomStackViewOffset].reduce(0, +)

        let viewController = UIViewController()
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)
        viewController.view = view

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.neu)
        viewController.modalTransitioningFactory = factory
        viewController.modalPresentationStyle = .custom

        controller.present(viewController, animated: true)
    }
}
