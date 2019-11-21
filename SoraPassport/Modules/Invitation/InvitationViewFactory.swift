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

        let invitationFactory = InvitationFactory(host: ApplicationConfig.shared.invitationHostURL)
        let timerFactory = CountdownTimerFactory()
        let invitationViewModelFactory = InvitationViewModelFactory(integerFormatter: .anyInteger)

        let presenter = InvitationPresenter(invitationViewModelFactory: invitationViewModelFactory,
                                            timerFactory: timerFactory,
                                            invitationFactory: invitationFactory)

        let projectUnitService = ProjectUnitService(unit: ApplicationConfig.shared.defaultProjectUnit)
        projectUnitService.requestSigner = requestSigner

        let interator = InvitationInteractor(service: projectUnitService,
                                             customerDataProviderFacade: CustomerDataProviderFacade.shared,
                                             eventCenter: EventCenter.shared)
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
