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
import IrohaCrypto
import SoraUIKit
import SSFCloudStorage

final class AccountCreateWireframe {
    private var authorizationView: PinSetupViewProtocol?
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()
    var endAddingBlock: (() -> Void)?
    var activityIndicatorWindow: UIWindow?
    
    init(endAddingBlock: (() -> Void)? = nil) {
        self.endAddingBlock = endAddingBlock
    }
}

extension AccountCreateWireframe: AccountCreateWireframeProtocol {
    @MainActor func proceed(on controller: UIViewController?) {
        let view = PinViewFactory.createRedesignPinSetupView()
        
        let containerView = BlurViewController()
        containerView.isClosable = false
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(view?.controller)
        
        controller?.present(containerView, animated: true)
    }
    
    func confirm(from view: AccountCreateViewProtocol?,
                 request: AccountCreationRequest,
                 metadata: AccountCreationMetadata) {
        guard let confirmationView = AccountConfirmViewFactory.createViewForOnboardingRedesign(request: request,
                                                                                               metadata: metadata) else { return }
        view?.controller.navigationController?.pushViewController(confirmationView.controller, animated: true)
    }
    
    func setupBackupAccountPassword(on controller: AccountCreateViewProtocol?,
                                    account: OpenBackupAccount,
                                    createAccountRequest: AccountCreationRequest,
                                    createAccountService: CreateAccountServiceProtocol,
                                    mnemonic: IRMnemonicProtocol) {
        guard let setupPasswordView = SetupPasswordViewFactory.createView(with: account,
                                                                          createAccountRequest: createAccountRequest,
                                                                          createAccountService: createAccountService,
                                                                          mnemonic: mnemonic,
                                                                          entryPoint: .onboarding,
                                                                          completion: endAddingBlock)?.controller else { return }
        controller?.controller.navigationController?.pushViewController(setupPasswordView, animated: true)
    }
}

extension AccountCreateWireframe: Authorizable {
    func authorize() {
        guard let presentingController = UIApplication.shared.keyWindow?.rootViewController?.topModalViewController,
              let authorizationView = PinViewFactory.createRedesignScreenAuthorizationView(with: self, cancellable: false) else { return }

        authorizationView.controller.modalTransitionStyle = .crossDissolve
        authorizationView.controller.modalPresentationStyle = .fullScreen
        self.authorizationView = authorizationView

        presentingController.present(authorizationView.controller, animated: true, completion: nil)
    }
}

extension AccountCreateWireframe: ScreenAuthorizationWireframeProtocol {
    func showAuthorizationCompletion(with result: Bool) {
        guard result else { return }
        self.authorizationView?.controller.dismiss(animated: true)
    }
}
