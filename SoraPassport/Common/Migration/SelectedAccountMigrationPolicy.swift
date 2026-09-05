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
import SSFUtils
import SoraKeystore
import IrohaCrypto

class SelectedAccountMigrationPolicy: NSEntityMigrationPolicy {
    var isSelected: Bool = false
    var order: Int32 = 0
    private var migratedAddresses: Set<String> = []

    override func createDestinationInstances(
        forSource accountItem: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {

        guard let sourceAddress = accountItem.value(forKey: "identifier") as? AccountAddress else {
            throw UserStorageMigrationError.accountInventoryMismatch
        }

        // Distinct network addresses can share one public key. Every retained
        // account is an independent inventory row and must survive migration.
        guard migratedAddresses.insert(sourceAddress).inserted else {
            throw UserStorageMigrationError.accountInventoryMismatch
        }

        try super.createDestinationInstances(forSource: accountItem, in: mapping, manager: manager)

        guard let metaAccount = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [accountItem]
        ).first else {
            throw UserStorageMigrationError.accountInventoryMismatch
        }

        if let orderedAssetIds =
            manager.userInfo?[UserStorageMigratorKeys.orderedAssetIds] as? [String] {
            let context = manager.destinationContext
            let settings = CDAccountSettings(entity: NSEntityDescription.entity(forEntityName: "CDAccountSettings", in: context)!, insertInto: context)
            settings.orderedAssets = orderedAssetIds as NSArray
            metaAccount.setValue(settings, forKey: "settings")
        }

        if let selectedAddress =
            manager.userInfo?[UserStorageMigratorKeys.selectedAddress] as? String {
            let isSelected = selectedAddress == sourceAddress
            metaAccount.setValue(isSelected, forKey: "isSelected")
        }

        let retainedOrder =
            (accountItem.value(forKey: "order") as? NSNumber)?.int32Value
                ?? order
        metaAccount.setValue(retainedOrder, forKey: "order")
        order += 1

    }

    override func end(_ mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        // This policy runs against a staging store. Mutating live preferences
        // here would violate copy-on-write migration if a later validation
        // fails, so the legacy preference remains for dual-read compatibility.
        try super.end(mapping, manager: manager)
    }
}
