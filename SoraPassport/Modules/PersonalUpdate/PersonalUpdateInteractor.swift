/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraKeystore

final class PersonalUpdateInteractor {
	weak var presenter: PersonalUpdateInteractorOutputProtocol?

    private(set) var settingsManager: SelectedWalletSettingsProtocol

    init(settingsManager: SelectedWalletSettingsProtocol) {
        self.settingsManager = settingsManager
    }
}

extension PersonalUpdateInteractor: PersonalUpdateInteractorInputProtocol {
    func setup() {
        presenter?.didReceive(username: settingsManager.currentAccount?.username)
    }

    func update(username: String?) {
        let updated = settingsManager.currentAccount?.replacingUsername(username ?? "")
        settingsManager.save(value: updated!)
        presenter?.didUpdate(username: username)
    }
}
