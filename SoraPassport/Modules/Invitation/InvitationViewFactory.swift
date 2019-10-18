/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraCrypto
import SoraUI

final class InvitationViewFactory: InvitationViewFactoryProtocol {
    static func createView() -> InvitationViewProtocol? {
        guard let requestSigner = DARequestSigner.createDefault() else {
            return nil
        }

        let view = InvitationViewController(nib: R.nib.invitationViewController)
        view.changesAnimation = BlockViewAnimator(duration: 0.1, delay: 0.0, options: .curveLinear)

        let invitationFactory = InvitationFactory(host: ApplicationConfig.shared.invitationHostURL)

        let presenter = InvitationPresenter(integerNumberFormatter: NumberFormatter.anyInteger,
                                            invitationFactory: invitationFactory)

        let projectUnitService = ProjectUnitService(unit: ApplicationConfig.shared.defaultProjectUnit)
        projectUnitService.requestSigner = requestSigner

        let interator = InvitationInteractor(service: projectUnitService,
                                             customerDataProviderFacade: CustomerDataProviderFacade.shared)
        let wireframe = InvitationWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interator
        presenter.wireframe = wireframe
        interator.presenter = presenter

        presenter.logger = Logger.shared

        return view
    }
}
