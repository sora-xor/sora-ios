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
import CommonWallet
import IrohaCrypto
import RobinHood
import FearlessUtils

final class WalletNetworkFacade {
    let accountSettings: WalletAccountSettingsProtocol
    let nodeOperationFactory: WalletNetworkOperationFactoryProtocol
    let coingeckoOperationFactory: CoingeckoOperationFactoryProtocol
    let polkaswapNetworkOperationFactory: PolkaswapNetworkOperationFactoryProtocol
    let address: String
    let networkType: SNAddressType
    let totalPriceAssetId: WalletAssetId?
    let chainStorage: AnyDataProviderRepository<ChainStorageItem>
    let localStorageIdFactory: ChainStorageIdFactoryProtocol
    let txStorage: AnyDataProviderRepository<TransactionHistoryItem>
    let contactsOperationFactory: WalletContactOperationFactoryProtocol
    let accountsRepository: AnyDataProviderRepository<AccountItem>
    let assetManager: AssetManagerProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let requestFactory: StorageRequestFactoryProtocol
    let engine: JSONRPCEngine

    lazy var localStorageKeyFactory = LocalStorageKeyFactory()
    lazy var remoteStorageKeyFactory = StorageKeyFactory()

    init(accountSettings: WalletAccountSettingsProtocol,
         nodeOperationFactory: WalletNetworkOperationFactoryProtocol,
         coingeckoOperationFactory: CoingeckoOperationFactoryProtocol,
         polkaswapNetworkOperationFactory: PolkaswapNetworkOperationFactoryProtocol,
         chainStorage: AnyDataProviderRepository<ChainStorageItem>,
         localStorageIdFactory: ChainStorageIdFactoryProtocol,
         txStorage: AnyDataProviderRepository<TransactionHistoryItem>,
         contactsOperationFactory: WalletContactOperationFactoryProtocol,
         accountsRepository: AnyDataProviderRepository<AccountItem>,
         address: String,
         networkType: SNAddressType,
         assetManager: AssetManagerProtocol,
         totalPriceAssetId: WalletAssetId?,
         runtimeService: RuntimeCodingServiceProtocol,
         requestFactory: StorageRequestFactoryProtocol,
         engine: JSONRPCEngine) {
        self.accountSettings = accountSettings
        self.nodeOperationFactory = nodeOperationFactory
        self.coingeckoOperationFactory = coingeckoOperationFactory
        self.polkaswapNetworkOperationFactory = polkaswapNetworkOperationFactory
        self.address = address
        self.networkType = networkType
        self.totalPriceAssetId = totalPriceAssetId
        self.chainStorage = chainStorage
        self.localStorageIdFactory = localStorageIdFactory
        self.txStorage = txStorage
        self.contactsOperationFactory = contactsOperationFactory
        self.accountsRepository = accountsRepository
        self.assetManager = assetManager
        self.runtimeService = runtimeService
        self.requestFactory = requestFactory
        self.engine = engine
    }
}
