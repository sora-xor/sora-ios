// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import SSFCloudStorage
import UIKit

final class OnboardingMainWireframe: OnboardingMainWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()
    var activityIndicatorWindow: UIWindow?
    var endAddingBlock: (() -> Void)?

    func showSignup(from view: OnboardingMainViewProtocol?, isGoogleBackupSelected: Bool) {
        guard
            let endBlock = endAddingBlock,
            let usernameSetupController = SetupAccountNameViewFactory.createViewForAdding(isGoogleBackupSelected: isGoogleBackupSelected,
                                                                                          isNeedSetupName: false,
                                                                                          endEditingBlock: endBlock)?.controller,
            let navigationController = view?.controller.navigationController
        else {
            return
        }
        
        DispatchQueue.main.async {
            navigationController.pushViewController(usernameSetupController, animated: true)
        }
    }
    
    func showAccountRestoreRedesign(from view: OnboardingMainViewProtocol?, sourceType: AccountImportSource) {
        guard
            let endBlock = endAddingBlock,
            let restorationController = AccountImportViewFactory.createViewForRedesignAdding(sourceType: sourceType, endAddingBlock: endBlock)?.controller,
            let navigationController = view?.controller.navigationController
        else {
            return
        }
        
        navigationController.pushViewController(restorationController, animated: true)
    }

    func showAccountRestore(from view: OnboardingMainViewProtocol?) {
        guard
            let endBlock = endAddingBlock,
            let restorationController = AccountImportViewFactory.createViewForAdding(endAddingBlock: endBlock)?.controller,
            let navigationController = view?.controller.navigationController
        else {
            return
        }
        
        navigationController.pushViewController(restorationController, animated: true)
    }

    func showKeystoreImport(from view: OnboardingMainViewProtocol?) {
        guard
            let navigationController = view?.controller.navigationController,
            navigationController.viewControllers.count == 1,
            navigationController.presentedViewController == nil
        else {
            return
        }
        
        showAccountRestore(from: view)
    }
    
    func showBackupedAccounts(from view: OnboardingMainViewProtocol?, accounts: [OpenBackupAccount]) {
        guard let viewController = BackupedAccountsViewFactory.createView(with: accounts, endAddingBlock: endAddingBlock)?.controller else { return }
        
        DispatchQueue.main.async {
            view?.controller.navigationController?.pushViewController(viewController, animated: true)
        }
    }
}
