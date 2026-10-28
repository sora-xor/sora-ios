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
