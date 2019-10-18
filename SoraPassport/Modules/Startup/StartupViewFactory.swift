/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraKeystore

final class StartupViewFactory: StartupViewFactoryProtocol {
	static func createView() -> StartupViewProtocol? {
        guard let decentralizedResolverUrl = URL(string: ApplicationConfig.shared.didResolverUrl) else {
            Logger.shared.error("Can't create decentralized resolver url")
            return nil
        }

        let view = StartupViewController(nib: R.nib.startupViewController)
        let presenter = StartupPresenter()

        if ReachabilityManager.shared == nil {
            Logger.shared.warning("Can't initialize reachability manager")
        }

        let identityNetworkOperationFactory = DecentralizedResolverOperationFactory(url: decentralizedResolverUrl)

        let projectOperationFactory = ProjectOperationFactory()

        let interactor = StartupInteractor(settings: SettingsManager.shared,
                                           keystore: Keychain(),
                                           config: ApplicationConfig.shared,
                                           identityNetworkOperationFactory: identityNetworkOperationFactory,
                                           identityLocalOperationFactory: IdentityOperationFactory.self,
                                           accountOperationFactory: projectOperationFactory,
                                           informationOperationFactory: projectOperationFactory,
                                           operationManager: OperationManager.shared,
                                           reachabilityManager: ReachabilityManager.shared)

        interactor.logger = Logger.shared

        let wireframe = StartupWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
	}
}
