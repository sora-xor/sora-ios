/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import FearlessUtils

protocol AccountViewModelFactoryProtocol: AnyObject {
    func createItem(from accounts: [AccountItem], selectedAccountAddress: String) -> [AccountViewModel]
}

final class AccountViewModelFactory {
    private let iconGenerator = PolkadotIconGenerator()
}

extension AccountViewModelFactory: AccountViewModelFactoryProtocol {

    func createItem(from accounts: [AccountItem], selectedAccountAddress: String) -> [AccountViewModel] {
        return accounts.map { account in
            
            let icon = try? iconGenerator.generateFromAddress(account.address)
                .imageWithFillColor(.white,
                                    size: CGSize(width: 40.0, height: 40.0),
                                    contentScale: UIScreen.main.scale)
            
            return AccountViewModel(by: account.address,
                                    isSelected: account.address == selectedAccountAddress,
                                    iconImage: icon)
        }
    }
}
