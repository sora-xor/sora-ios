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
    /// Binds a wallet authorization that has just succeeded to this account,
    /// the selected wallet and the foreground session. Call it only then.
    func makeCloudBackupAuthorization() -> AccountOptionsCloudBackupAuthorization
    func deleteBackup(authorization: AccountOptionsCloudBackupAuthorization,
                      completion: @escaping (Error?) -> Void)
    func signInToGoogleIfNeeded(authorization: AccountOptionsCloudBackupAuthorization,
                                completion: ((AccountOptionsCloudBackupPreparation) -> Void)?)
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
    /// Shows the backup password screen, which reads the wallet secret only
    /// under `authorization`, or under one `reauthorize` asks for once it
    /// has lapsed or been used.
    func setupBackupAccountPassword(on controller: AccountOptionsViewProtocol?,
                                    account: OpenBackupAccount,
                                    authorization: AccountOptionsCloudBackupAuthorization,
                                    reauthorize: @escaping AccountOptionsCloudBackupReauthorization,
                                    completion: @escaping () -> Void)
    func authorizeCloudBackup(from view: AccountOptionsViewProtocol?,
                              completion: @escaping AuthorizationCompletionBlock)
}

extension AccountOptionsWireframeProtocol {
    func dismissAfterDeletion(from view: AccountOptionsViewProtocol?) {
        back(from: view)
    }
}

protocol AccountOptionsViewFactoryProtocol: AnyObject {
	static func createView(account: AccountItem) -> AccountOptionsViewProtocol?
}
