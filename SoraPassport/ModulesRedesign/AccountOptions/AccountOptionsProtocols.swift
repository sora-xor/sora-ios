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

import SSFCloudStorage

protocol AccountOptionsViewProtocol: ControllerBackedProtocol, AlertPresentable {
    func didReceive(username: String)
    func didReceive(address: String)
    func setupOptions(with backUpState: BackupState, hasEntropy: Bool)
    func showLoading()
    func hideLoading()
}

protocol AccountOptionsPresenterProtocol: AnyObject {
    func setup()
    func showPassphrase()
    func showRawSeed()
    func showJson()
    func doLogout()
    func didUpdateUsername(_ new: String)
    func copyToClipboard()
    func deleteBackup()
    func createBackup()
}

protocol AccountOptionsInteractorInputProtocol: AnyObject {
    func getMetadata() -> AccountCreationMetadata?
    func isLastAccountWithCustomNodes(completion: @escaping (Bool) -> Void)
    func logoutAndClean()
    func updateUsername(_ username: String)
    var currentAccount: AccountItem { get }
    var accountHasEntropy: Bool { get }
    func checkCurrentAccountBackedup() async -> Bool
    func deleteBackup(completion: @escaping (Error?) -> Void)
    func signInToGoogleIfNeeded(completion: ((OpenBackupAccount?) -> Void)?)
}

protocol AccountOptionsInteractorOutputProtocol: AnyObject {
    func restart()
    func close()
    func accountDeletionBlocked(message: String)
}

protocol AccountOptionsWireframeProtocol: Loadable {
    func showPassphrase(from view: AccountOptionsViewProtocol?, account: AccountItem)
    func showRawSeed(from view: AccountOptionsViewProtocol?, account: AccountItem)
    func showJson(account: AccountItem, from view: AccountOptionsViewProtocol?)
    func showRoot()
    func back(from view: AccountOptionsViewProtocol?)
    func dismissAfterDeletion(from view: AccountOptionsViewProtocol?)
    func showLogout(from view: AccountOptionsViewProtocol?, isNeedCustomNodeText: Bool, completionBlock: (() -> Void)?)
    func setupBackupAccountPassword(on controller: AccountOptionsViewProtocol?,
                                    account: OpenBackupAccount,
                                    completion: @escaping () -> Void)
}

extension AccountOptionsWireframeProtocol {
    func dismissAfterDeletion(from view: AccountOptionsViewProtocol?) {
        back(from: view)
    }
}

protocol AccountOptionsViewFactoryProtocol: AnyObject {
	static func createView(account: AccountItem) -> AccountOptionsViewProtocol?
}
