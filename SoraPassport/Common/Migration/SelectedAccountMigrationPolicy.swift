/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

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
