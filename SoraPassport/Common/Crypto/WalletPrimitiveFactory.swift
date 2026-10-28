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
import SoraKeystore
import SoraFoundation
import IrohaCrypto

protocol WalletPrimitiveFactoryProtocol {
    func createAccountSettings(for selectedAccount: AccountItem, assetManager: AssetManagerProtocol) throws -> WalletAccountSettingsProtocol
}

enum WalletPrimitiveFactoryError: Error {
    case missingAccountId
    case undefinedConnection
    case undefinedAssets
}

final class WalletPrimitiveFactory: WalletPrimitiveFactoryProtocol {
    let keystore: KeystoreProtocol

    init(keystore: KeystoreProtocol) {
        self.keystore = keystore
    }

    private func createAssetForInfo(_ info: AssetInfo) -> WalletAsset {

        return WalletAsset(identifier: info.assetId,
                           name: LocalizableResource<String> { _ in info.symbol },
                           platform: LocalizableResource<String> { _ in info.name },
                           symbol: info.symbol,
                           precision: Int16(info.precision),
                           modes: .all)
    }

    func createAccountSettings(for selectedAccount: AccountItem, assetManager: AssetManagerProtocol) throws -> WalletAccountSettingsProtocol {

        let assets = assetManager.getAssetList()?
            .map {createAssetForInfo($0)}

        guard let assetList = assets else {
            throw WalletPrimitiveFactoryError.undefinedAssets
        }

        let selectedConnectionType = selectedAccount.addressType

//        let totalPriceAsset = WalletAsset(identifier: WalletAssetId.usd.rawValue,
//                                          name: LocalizableResource { _ in "" },
//                                          platform: LocalizableResource { _ in "" },
//                                          symbol: "$",
//                                          precision: 2,
//                                          modes: .view)

        let accountId = try SS58AddressFactory().accountId(fromAddress: selectedAccount.address,
                                                           type: selectedConnectionType)

        return WalletAccountSettings(accountId: accountId.toHex(),
                                     assets: assetList)
    }
}
