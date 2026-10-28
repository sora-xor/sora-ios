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
import SoraUIKit
import RobinHood

import SoraFoundation

protocol ContactsWireframeProtocol {    
    func showScanQR(on view: UIViewController?,
                    networkFacade: WalletNetworkOperationFactoryProtocol,
                    assetManager: AssetManagerProtocol,
                    qrEncoder: WalletQREncoderProtocol,
                    sharingFactory: AccountShareFactoryProtocol,
                    assetsProvider: AssetProviderProtocol?,
                    providerFactory: BalanceProviderFactory,
                    feeProvider: FeeProviderProtocol,
                    marketCapService: MarketCapServiceProtocol,
                    completion: ((ScanQRResult) -> Void)?)
}

final class ContactsWireframe: ContactsWireframeProtocol {
    @MainActor func showScanQR(on view: UIViewController?,
                    networkFacade: WalletNetworkOperationFactoryProtocol,
                    assetManager: AssetManagerProtocol,
                    qrEncoder: WalletQREncoderProtocol,
                    sharingFactory: AccountShareFactoryProtocol,
                    assetsProvider: AssetProviderProtocol?,
                    providerFactory: BalanceProviderFactory,
                    feeProvider: FeeProviderProtocol,
                    marketCapService: MarketCapServiceProtocol,
                    completion: ((ScanQRResult) -> Void)?) {
        guard let currentUser = SelectedWalletSettings.shared.currentAccount else { return }
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen

        let scanView = ScanQRViewFactory.createView(assetManager: assetManager,
                                                    currentUser: currentUser,
                                                    networkFacade: networkFacade,
                                                    qrEncoder: qrEncoder,
                                                    sharingFactory: sharingFactory,
                                                    assetsProvider: assetsProvider,
                                                    providerFactory: providerFactory,
                                                    feeProvider: feeProvider,
                                                    marketCapService: marketCapService,
                                                    completion: completion)
        containerView.add(scanView.controller)
        view?.present(containerView, animated: true)
    }
}
