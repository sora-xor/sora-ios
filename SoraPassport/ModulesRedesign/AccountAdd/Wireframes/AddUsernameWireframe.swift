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
import SoraFoundation
import SoraUIKit

final class AddUsernameWireframe: UsernameSetupWireframeProtocol {
    private(set) var localizationManager: LocalizationManagerProtocol
    private var isGoogleBackupSelected: Bool
    private var isNeedSetupName: Bool

    init(localizationManager: LocalizationManagerProtocol, isGoogleBackupSelected: Bool = false, isNeedSetupName: Bool) {
        self.localizationManager = localizationManager
        self.isGoogleBackupSelected = isGoogleBackupSelected
        self.isNeedSetupName = isNeedSetupName
    }

    var endAddingBlock: (() -> Void)?

    func proceed(from view: UsernameSetupViewProtocol?, username: String) {
        guard let accountCreation = AccountCreateViewFactory.createViewForImportAccount(
            username: username,
            isGoogleBackupSelected: isGoogleBackupSelected,
            isNeedSetupName: isNeedSetupName,
            endAddingBlock: endAddingBlock
        ) else { return }
        view?.controller.navigationController?.pushViewController(accountCreation.controller,
                                                                  animated: true)
    }
    
    func showPinCode(from view: UsernameSetupViewProtocol?) {
        let view = PinViewFactory.createRedesignPinSetupView()
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(view?.controller)
        
        view?.controller.present(containerView, animated: true)
    }
    
    func showWarning(from view: UsernameSetupViewProtocol?, completion: @escaping () -> Void) {
        let warning = AccountWarningViewController(warningType: .passphrase)
        warning.localizationManager = self.localizationManager
        warning.completion = completion
        view?.controller.navigationController?.pushViewController(warning.controller, animated: true)
    }
}
