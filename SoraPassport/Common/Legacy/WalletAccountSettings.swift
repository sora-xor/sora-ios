/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public protocol WalletAccountSettingsProtocol {
    var accountId: String { get }
    var assets: [WalletAsset] { get }
    var withdrawOptions: [WalletWithdrawOption] { get }
}

public struct WalletAccountSettings: WalletAccountSettingsProtocol {
    public var accountId: String
    public var assets: [WalletAsset]
    public var withdrawOptions: [WalletWithdrawOption]

    public init(accountId: String, assets: [WalletAsset], withdrawOptions: [WalletWithdrawOption] = []) {
        self.accountId = accountId
        self.assets = assets
        self.withdrawOptions = withdrawOptions
    }
}

extension WalletAccountSettingsProtocol {
    func asset(for identifier: String) -> WalletAsset? {
        return assets.first { $0.identifier == identifier }
    }

    func withdrawOption(for identifier: String) -> WalletWithdrawOption? {
        return withdrawOptions.first { $0.identifier == identifier }
    }
}
