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
import RobinHood

import SoraUIKit

protocol InputAssetAmountWireframeProtocol: AlertPresentable {
    func showChoiceBaseAsset(on controller: UIViewController?,
                             assetManager: AssetManagerProtocol,
                             fiatService: FiatServiceProtocol,
                             assetViewModelFactory: AssetViewModelFactory,
                             assetsProvider: AssetProviderProtocol?,
                             assetIds: [String],
                             marketCapService: MarketCapServiceProtocol,
                             completion: @escaping (String) -> Void)
    
    func showSelectAddress(on controller: UIViewController?,
                           assetId: String,
                           dataProvider: SingleValueProvider<[SearchData]>,
                           walletService: WalletServiceProtocol,
                           networkFacade: WalletNetworkOperationFactoryProtocol,
                           assetManager: AssetManagerProtocol,
                           qrEncoder: WalletQREncoderProtocol,
                           sharingFactory: AccountShareFactoryProtocol,
                           assetsProvider: AssetProviderProtocol?,
                           providerFactory: BalanceProviderFactory,
                           feeProvider: FeeProviderProtocol,
                           marketCapService: MarketCapServiceProtocol,
                           completion: ((ScanQRResult) -> Void)?)
    
    func showConfirmSendingAsset(on controller: UINavigationController?,
                                 assetId: String,
                                 walletService: WalletServiceProtocol,
                                 assetManager: AssetManagerProtocol,
                                 fiatService: FiatServiceProtocol,
                                 recipientAddress: String,
                                 firstAssetAmount: Decimal,
                                 fee: Decimal,
                                 assetsProvider: AssetProviderProtocol?)
}

final class InputAssetAmountWireframe: InputAssetAmountWireframeProtocol {

    @MainActor
    func showChoiceBaseAsset(on controller: UIViewController?,
                             assetManager: AssetManagerProtocol,
                             fiatService: FiatServiceProtocol,
                             assetViewModelFactory: AssetViewModelFactory,
                             assetsProvider: AssetProviderProtocol?,
                             assetIds: [String],
                             marketCapService: MarketCapServiceProtocol,
                             completion: @escaping (String) -> Void) {
        let viewModel = SelectAssetViewModel(assetViewModelFactory: assetViewModelFactory,
                                             fiatService: fiatService,
                                             assetManager: assetManager,
                                             assetsProvider: assetsProvider,
                                             assetIds: assetIds,
                                             marketCapService: marketCapService)
        viewModel.selectionCompletion = completion

        let assetListController = ProductListViewController(viewModel: viewModel)
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        
        let navigationController = UINavigationController(rootViewController: assetListController)
        navigationController.navigationBar.backgroundColor = .clear
        
        containerView.add(navigationController)
        controller?.present(containerView, animated: true)
    }
    
    @MainActor
    func showSelectAddress(on controller: UIViewController?,
                           assetId: String,
                           dataProvider: SingleValueProvider<[SearchData]>,
                           walletService: WalletServiceProtocol,
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
        let viewModelFactory = ContactsViewModelFactory(dataStorageFacade: SubstrateDataStorageFacade.shared)
        let localSearchEngine = ContactsLocalSearchEngine(networkType: currentUser.networkType, contactViewModelFactory: viewModelFactory)
        
        let settingsManager = SelectedWalletSettings.shared
        
        let viewModel = ContactsViewModel(dataProvider: dataProvider,
                                          walletService: walletService,
                                          assetId: assetId,
                                          localSearchEngine: localSearchEngine,
                                          wireframe: ContactsWireframe(),
                                          networkFacade: networkFacade,
                                          assetManager: assetManager,
                                          settingsManager: settingsManager,
                                          qrEncoder: qrEncoder,
                                          sharingFactory: sharingFactory,
                                          assetsProvider: assetsProvider,
                                          providerFactory: providerFactory,
                                          feeProvider: feeProvider,
                                          marketCapService: marketCapService
        )
        viewModel.completion = completion
        let receiveController = ContactsViewController(viewModel: viewModel)
        viewModel.view = receiveController
        
        let navigationController = UINavigationController(rootViewController: receiveController)
        navigationController.navigationBar.backgroundColor = .clear
        navigationController.addCustomTransitioning()
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(navigationController)
        
        controller?.present(containerView, animated: true)
    }
    
    func showConfirmSendingAsset(on controller: UINavigationController?,
                                 assetId: String,
                                 walletService: WalletServiceProtocol,
                                 assetManager: AssetManagerProtocol,
                                 fiatService: FiatServiceProtocol,
                                 recipientAddress: String,
                                 firstAssetAmount: Decimal,
                                 fee: Decimal,
                                 assetsProvider: AssetProviderProtocol?) {
        let viewModel = ConfirmSendingViewModel(wireframe: ConfirmWireframe(),
                                                fiatService: fiatService,
                                                assetManager: assetManager,
                                                detailsFactory: DetailViewModelFactory(assetManager: assetManager),
                                                assetId: assetId,
                                                recipientAddress: recipientAddress,
                                                firstAssetAmount: firstAssetAmount,
                                                transactionType: .outgoing,
                                                fee: fee,
                                                walletService: walletService,
                                                assetsProvider: assetsProvider)
        let view = ConfirmViewController(viewModel: viewModel)
        viewModel.view = view
        controller?.pushViewController(view, animated: true)
    }
}
