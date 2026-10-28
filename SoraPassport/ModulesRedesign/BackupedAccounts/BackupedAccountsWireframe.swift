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

final class BackupedAccountsWireframe: CustomPresentable {

    weak var currentController: BackupedAccountsViewController?
    var endAddingBlock: (() -> Void)?
    
    init(currentController: BackupedAccountsViewController? = nil,
         endAddingBlock: (() -> Void)? = nil) {
        self.currentController = currentController
        self.endAddingBlock = endAddingBlock
    }
    
    deinit {
        print("deinited")
    }
}

extension BackupedAccountsWireframe: BackupedAccountsWireframeProtocol {
    func openInputPassword(selectedAddress: String, backedUpAccounts: [OpenBackupAccount]) {
        guard let view = EnterPasswordViewFactory.createView(
            with: selectedAddress,
            backedUpAccounts: backedUpAccounts,
            endAddingBlock: endAddingBlock)?.controller else { return }
        currentController?.controller.navigationController?.pushViewController(view, animated: true)
    }
    
    func showCreateAccount() {
        guard let setupAccountNameView = SetupAccountNameViewFactory.createViewForOnboarding(
            mode: .creating,
            endAddingBlock: endAddingBlock
        ) else { return }
        currentController?.controller.navigationController?.pushViewController(setupAccountNameView.controller, animated: true)
    }
}
