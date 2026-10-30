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
import SoraKeystore
import SoraFoundation
import SSFCloudStorage

final class EnterPasswordWireframe: CustomPresentable {
    private weak var currentController: EnterPasswordViewProtocol?
    private weak var navigationController: UINavigationController?
    private var endAddingBlock: (() -> Void)? = nil
    var activityIndicatorWindow: UIWindow?

    init(currentController: EnterPasswordViewProtocol? = nil,
         endAddingBlock: (() -> Void)? = nil) {
        self.currentController = currentController
        self.navigationController = currentController?.controller.navigationController
        self.endAddingBlock = endAddingBlock
    }
}

extension EnterPasswordWireframe: EnterPasswordWireframeProtocol {
    func openSuccessImport(importedAccountAddress: String, accounts: [OpenBackupAccount]) {
        guard let successView = AccountImportedViewFactory.createView(
            with: importedAccountAddress,
            accounts: accounts,
            endAddingBlock: endAddingBlock
        )?.controller else { return }
        currentController?.controller.navigationController?.setViewControllers([successView], animated: true)
    }

    func presentShortPhraseWarning(acknowledged: @escaping () -> Void) {
        WalletShortPhraseWarning.present(from: currentController?.controller, acknowledged: acknowledged)
    }
}
