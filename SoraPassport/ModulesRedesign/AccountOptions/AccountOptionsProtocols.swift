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
    func deleteBackup(completion: @escaping (Error?) -> Void)
    func signInToGoogleIfNeeded(completion: ((OpenBackupAccount?) -> Void)?)
}

protocol AccountOptionsInteractorOutputProtocol: AnyObject {
    func restart()
    func close()
}

protocol AccountOptionsWireframeProtocol: Loadable {
    func showPassphrase(from view: AccountOptionsViewProtocol?, account: AccountItem)
    func showRawSeed(from view: AccountOptionsViewProtocol?, account: AccountItem)
    func showJson(account: AccountItem, from view: AccountOptionsViewProtocol?)
    func showRoot()
    func back(from view: AccountOptionsViewProtocol?)
    func showLogout(from view: AccountOptionsViewProtocol?, isNeedCustomNodeText: Bool, completionBlock: (() -> Void)?)
    func setupBackupAccountPassword(on controller: AccountOptionsViewProtocol?,
                                    account: OpenBackupAccount,
                                    completion: @escaping () -> Void)
}

protocol AccountOptionsViewFactoryProtocol: AnyObject {
	static func createView(account: AccountItem) -> AccountOptionsViewProtocol?
}
