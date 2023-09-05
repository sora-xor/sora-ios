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

import Foundation
import CoreData
import FearlessUtils
import SoraKeystore
import IrohaCrypto

class SelectedAccountMigrationPolicy: NSEntityMigrationPolicy {
    var isSelected: Bool = false
    var order: Int32 = 0
    private var privateKeysUsed: [Data] = []

    private lazy var addressFactory = SS58AddressFactory()

    override func createDestinationInstances(
        forSource accountItem: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {

        guard let sourceAddress = accountItem.value(forKey: "identifier") as? AccountAddress else {
            fatalError("Unexpected empty source address")
        }

        let accountId = try addressFactory.accountId(from: sourceAddress)

        if privateKeysUsed.contains(accountId) {
            return
        }

        try super.createDestinationInstances(forSource: accountItem, in: mapping, manager: manager)

        guard let metaAccount = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [accountItem]
        ).first else {
            return
        }

        privateKeysUsed.append(accountId)

        if let lookup = SettingsManager.shared.value(of: [String: Int].self, for: SettingsKey.assetList.rawValue) {
            let newOrder = lookup.keys.sorted(by: { key0, key1 in
                return lookup[key0]! < lookup[key1]!
            })

            let context = manager.destinationContext
            let settings = CDAccountSettings(entity: NSEntityDescription.entity(forEntityName: "CDAccountSettings", in: context)!, insertInto: context)
            settings.orderedAssets = newOrder as NSArray
            metaAccount.setValue(settings, forKey: "settings")
        }

        if let selectedAccount = SettingsManager.shared.value(of: AccountItem.self, for: SettingsKey.selectedAccount.rawValue) {
            let isSelected = selectedAccount.identifier == sourceAddress
            metaAccount.setValue(isSelected, forKey: "isSelected")
        }

        metaAccount.setValue(order, forKey: "order")
        order += 1

    }

    override func end(_ mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        SettingsManager.shared.removeValue(for: SettingsKey.assetList.rawValue)
        try super.end(mapping, manager: manager)
    }
}
