// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
