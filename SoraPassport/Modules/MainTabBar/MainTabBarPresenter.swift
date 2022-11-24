/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

final class MainTabBarPresenter {
	weak var view: MainTabBarViewProtocol?
	var interactor: MainTabBarInteractorInputProtocol!
	var wireframe: MainTabBarWireframeProtocol!

    var logger: LoggerProtocol?
}

extension MainTabBarPresenter: MainTabBarPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension MainTabBarPresenter: MainTabBarInteractorOutputProtocol {
    func didUserChange() {
        wireframe.recreateWalletViewController(on: view)
    }
    
    func didEndTransaction() {

    }

    func didReloadSelectedAccount() {
        wireframe.showNewWalletView(on: view)
    }

    func didReloadSelectedNetwork() {
        wireframe.showNewWalletView(on: view)
    }

    func didUpdateWalletInfo() {
        wireframe.reloadWalletContent()
    }

    func didRequestImportAccount() {
        wireframe.presentAccountImport(on: view)
    }
    func didRequestMigration(with service: MigrationServiceProtocol) {
        wireframe.presentClaim(on: view, with: service)
    }

    func didEndMigration() {
        wireframe.removeClaim(on: view)
    }

    func didReceive(deepLink: DeepLinkProtocol) {}
}
