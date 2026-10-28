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

import SoraFoundation

final class AccountShareFactory: AccountShareFactoryProtocol {
    let address: String
    let assets: [WalletAsset]
    let localizationManager: LocalizationManagerProtocol

    init(address: String, assets: [WalletAsset], localizationManager: LocalizationManagerProtocol) {
        self.assets = assets
        self.address = address
        self.localizationManager = localizationManager
    }

    func createSources(for receiveInfo: ReceiveInfo, qrImage: UIImage) -> [Any] {
        let locale = localizationManager.selectedLocale

        let asset = assets.first(where: { $0.identifier == receiveInfo.assetId }) ?? assets.first
        let symbol = asset?.symbol ?? ""
        let platform = asset?.platform?.value(for: locale) ?? ""

        let message = R.string.localizable
            .walletAccountShareMessage(/*platform, symbol,*/ preferredLanguages: locale.rLanguages)

        return [qrImage, message, address]
    }
}
