/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/


import Foundation

public protocol SingleProviderIdentifierFactoryProtocol {
    func balanceIdentifierForAccountId(_ accountId: String) -> String
    func historyIdentifierForAccountId(_ accountId: String, assets: [String]) -> String
    func contactsIdentifierForAccountId(_ accountId: String) -> String

    func withdrawMetadataIdentifierForAccountId(_ accountId: String,
                                                assetId: String,
                                                optionId: String) -> String

    func transferMetadataIdentifierForAccountId(_ accountId: String,
                                                assetId: String,
                                                receiverId: String) -> String
}

public extension SingleProviderIdentifierFactoryProtocol {
    func balanceIdentifierForAccountId(_ accountId: String) -> String {
        "\(accountId)#_balance"
    }

    func historyIdentifierForAccountId(_ accountId: String, assets: [String]) -> String {
        let cacheIdentifier = assets.map({ $0 }).sorted().joined()
        return "\(accountId)#\(cacheIdentifier.hash)"
    }

    func contactsIdentifierForAccountId(_ accountId: String) -> String {
        "\(accountId)#contacts)"
    }

    func withdrawMetadataIdentifierForAccountId(_ accountId: String,
                                                assetId: String,
                                                optionId: String) -> String {
        "\(assetId)\(optionId)#withdraw-metadata"
    }

    func transferMetadataIdentifierForAccountId(_ accountId: String,
                                                assetId: String,
                                                receiverId: String) -> String {
        "\(assetId)#transfer-metadata"
    }
}

