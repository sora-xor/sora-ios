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
import UIKit
import RobinHood
import CommonWallet
import SoraUIKit

protocol InputAssetAmountWireframeProtocol: AlertPresentable {
    func showChoiceBaseAsset(on controller: UIViewController?,
                             assetManager: AssetManagerProtocol,
                             fiatService: FiatServiceProtocol,
                             assetViewModelFactory: AssetViewModelFactory,
                             assetsProvider: AssetProviderProtocol?,
                             assetIds: [String],
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

    func showChoiceBaseAsset(on controller: UIViewController?,
                             assetManager: AssetManagerProtocol,
                             fiatService: FiatServiceProtocol,
                             assetViewModelFactory: AssetViewModelFactory,
                             assetsProvider: AssetProviderProtocol?,
                             assetIds: [String],
                             completion: @escaping (String) -> Void) {
        let marketCapService = MarketCapService(assetManager: assetManager)
        let viewModel = SelectAssetViewModel(assetViewModelFactory: assetViewModelFactory,
                                             fiatService: fiatService,
                                             assetManager: assetManager,
                                             assetsProvider: assetsProvider,
                                             assetIds: assetIds,
                                             marketCapService: marketCapService)
        viewModel.selectionCompletion = completion

        let assetListController = ProductListViewController(viewModel: viewModel)
        
        let navigationController = UINavigationController(rootViewController: assetListController)
        
        controller?.present(navigationController, animated: true)
    }
    
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
                                          feeProvider: feeProvider
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
