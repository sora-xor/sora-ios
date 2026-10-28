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
    
    @MainActor func showPinCode(from view: UsernameSetupViewProtocol?) {
        let pinView = PinViewFactory.createPostImportPinView()
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(pinView?.controller)
        
        view?.controller.present(containerView, animated: true)
    }
    
    func showWarning(from view: UsernameSetupViewProtocol?, completion: @escaping () -> Void) {
        let warning = AccountWarningViewController(warningType: .passphrase)
        warning.localizationManager = self.localizationManager
        warning.completion = completion
        view?.controller.navigationController?.pushViewController(warning.controller, animated: true)
    }
}
