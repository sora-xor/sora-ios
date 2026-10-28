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
import UIKit
import SoraUIKit


protocol ScanQRWireframeProtocol {
    func showGenerateQR(on controller: UIViewController?,
                        accountId: String,
                        address: String,
                        username: String,
                        qrEncoder: WalletQREncoderProtocol,
                        sharingFactory: AccountShareFactoryProtocol,
                        assetManager: AssetManagerProtocol?,
                        assetsProvider: AssetProviderProtocol?,
                        networkFacade: WalletNetworkOperationFactoryProtocol?,
                        providerFactory: BalanceProviderFactory,
                        feeProvider: FeeProviderProtocol,
                        marketCapService: MarketCapServiceProtocol,
                        closeHandler: (() -> Void)?)
}

final class ScanQRWireframe: ScanQRWireframeProtocol {

    @MainActor
    func showGenerateQR(on controller: UIViewController?,
                        accountId: String,
                        address: String,
                        username: String,
                        qrEncoder: WalletQREncoderProtocol,
                        sharingFactory: AccountShareFactoryProtocol,
                        assetManager: AssetManagerProtocol?,
                        assetsProvider: AssetProviderProtocol?,
                        networkFacade: WalletNetworkOperationFactoryProtocol?,
                        providerFactory: BalanceProviderFactory,
                        feeProvider: FeeProviderProtocol,
                        marketCapService: MarketCapServiceProtocol,
                        closeHandler: (() -> Void)?) {
        let qrService = WalletQRService(operationFactory: WalletQROperationFactory(), encoder: qrEncoder)
       
        let viewModel = GenerateQRViewModel(
            qrService: qrService,
            sharingFactory: sharingFactory,
            accountId: accountId,
            address: address,
            username: username,
            fiatService: FiatService.shared,
            assetManager: assetManager,
            assetsProvider: assetsProvider,
            qrEncoder: qrEncoder,
            networkFacade: networkFacade,
            providerFactory: providerFactory,
            feeProvider: feeProvider,
            marketCapService: marketCapService
        )
        viewModel.closeHadler = closeHandler
        let viewController = GenerateQRViewController(viewModel: viewModel)
        viewModel.view = viewController
        viewModel.wireframe = GenerateQRWireframe(controller: viewController)

        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.navigationBar.backgroundColor = .clear
        navigationController.addCustomTransitioning()
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(navigationController)
        
        controller?.present(containerView, animated: true)
    }
}
