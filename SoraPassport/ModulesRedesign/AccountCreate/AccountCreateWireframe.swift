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
    func proceed(on controller: UIViewController?) {
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
