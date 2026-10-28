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

import SoraFoundation


final class ScanQRViewFactory {
    static func createView(assetManager: AssetManagerProtocol,
                           currentUser: AccountItem,
                           networkFacade: WalletNetworkOperationFactoryProtocol,
                           qrEncoder: WalletQREncoderProtocol,
                           sharingFactory: AccountShareFactoryProtocol,
                           assetsProvider: AssetProviderProtocol?,
                           isGeneratedQRCodeScreenShown: Bool = false,
                           providerFactory: BalanceProviderFactory,
                           feeProvider: FeeProviderProtocol,
                           marketCapService: MarketCapServiceProtocol,
                           completion: ((ScanQRResult) -> Void)?) -> ScanQRViewProtocol {
        let qrScanServiceFactory = WalletQRCaptureServiceFactory()
        let assets = assetManager.getAssetList()?.map { asset in
            return WalletAsset(identifier: asset.assetId,
                               name: LocalizableResource<String> { _ in asset.symbol },
                               platform: LocalizableResource<String> { _ in asset.name },
                               symbol: asset.symbol,
                               precision: Int16(asset.precision),
                               modes: .all)
        } ?? []
        let localSearchEngine = InvoiceScanLocalSearchEngine(networkType: currentUser.networkType)
        
        let qrCoderFactory = WalletQRCoderFactory(networkType: currentUser.networkType,
                                                  publicKey: currentUser.publicKeyData,
                                                  username: currentUser.username,
                                                  assets: assets)
        
        let viewModel = ScanQRViewModel(networkService: WalletService(operationFactory: networkFacade),
                                        localSearchEngine: localSearchEngine,
                                        qrScanServiceFactory: qrScanServiceFactory,
                                        qrCoderFactory: qrCoderFactory,
                                        qrEncoder: qrEncoder,
                                        sharingFactory: sharingFactory,
                                        assetManager: assetManager,
                                        assetsProvider: assetsProvider,
                                        networkFacade: networkFacade,
                                        isGeneratedQRCodeScreenShown: isGeneratedQRCodeScreenShown,
                                        providerFactory: providerFactory,
                                        feeProvider: feeProvider,
                                        marketCapService: marketCapService,
                                        completion: completion)
        
        let scanView = ScanQRViewController(viewModel: viewModel)
        viewModel.view = scanView
        
        return scanView

    }
}
