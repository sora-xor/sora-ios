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
import SoraUIKit
import RobinHood

final class AccountTableViewItem: NSObject {

    var accountName: String
    var accountHandler: ((AccountTableViewItem) -> Void)?
    var scanQRHandler: (() -> Void)?
    var updateHandler: (() -> Void)?
    private let accountRepository: AnyDataProviderRepository<AccountItem>

    init(accountName: String) {
        self.accountName = accountName
        self.accountRepository = AnyDataProviderRepository(
            UserDataStorageFacade.shared
            .createRepository(filter: nil,
                              sortDescriptors: [],
                              mapper: AnyCoreDataMapper(AccountItemMapper()))
        )
        super.init()
        EventCenter.shared.add(observer: self)
    }
}

extension AccountTableViewItem: EventVisitorProtocol {
    func processSelectedUsernameChanged(event: SelectedUsernameChanged) {
        
        let persistentOperation = accountRepository.fetchAllOperation(with: RepositoryFetchOptions())
        
        persistentOperation.completionBlock = { [weak self] in
            guard let accounts = try? persistentOperation.extractNoCancellableResultData() else { return }
            
            let selectedAccountAddress = SelectedWalletSettings.shared.currentAccount?.address ?? ""
            let selectedAccount =  accounts.first { $0.address == selectedAccountAddress }
            var selectedAccountName = selectedAccount?.username ?? ""
            
            if selectedAccountName.isEmpty {
                selectedAccountName = selectedAccount?.address ?? ""
            }
            self?.accountName = selectedAccountName
            self?.updateHandler?()
        }

        OperationManagerFacade.runtimeBuildingQueue.addOperation(persistentOperation)
    }
}


extension AccountTableViewItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { AccountCell.self }

    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }

    var clipsToBounds: Bool { false }
    
    func itemHeight(forWidth width: CGFloat, context: SoramitsuTableViewContext?) -> CGFloat {
        40
    }
    
    func itemActionTap(with context: SoramitsuTableViewContext?) {
        accountHandler?(self)
    }
}
