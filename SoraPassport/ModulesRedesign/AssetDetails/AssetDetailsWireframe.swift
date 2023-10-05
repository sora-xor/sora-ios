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
import SCard
import UIKit
import SoraUIKit
import CommonWallet
import RobinHood
import SoraFoundation

protocol AssetDetailsWireframeProtocol {
    func showActivity(on controller: UIViewController,  assetId: String, assetManager: AssetManagerProtocol)

    func showActivityDetails(on controller: UIViewController?, model: Transaction, assetManager: AssetManagerProtocol)
    
    func showSwap(on controller: UIViewController?,
                  selectedTokenId: String,
                  assetManager: AssetManagerProtocol,
                  fiatService: FiatServiceProtocol,
                  networkFacade: WalletNetworkOperationFactoryProtocol?,
                  polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?,
                  assetsProvider: AssetProviderProtocol?,
                  marketCapService: MarketCapServiceProtocol)
    
    func showReceive(on controller: UIViewController?,
                     selectedAsset: AssetInfo,
                     accountId: String,
                     address: String,
                     qrEncoder: WalletQREncoderProtocol,
                     sharingFactory: AccountShareFactoryProtocol,
                     fiatService: FiatServiceProtocol?,
                     assetProvider: AssetProviderProtocol?,
                     assetManager: AssetManagerProtocol?)
    
    func showSend(on controller: UIViewController?,
                  selectedAsset: AssetInfo,
                  fiatService: FiatServiceProtocol?,
                  assetManager: AssetManagerProtocol?,
                  eventCenter: EventCenterProtocol,
                  providerFactory: BalanceProviderFactory,
                  networkFacade: WalletNetworkOperationFactoryProtocol?,
                  assetsProvider: AssetProviderProtocol?,
                  qrEncoder: WalletQREncoderProtocol,
                  sharingFactory: AccountShareFactoryProtocol,
                  marketCapService: MarketCapServiceProtocol)
    
    func showFrozenBalance(on controller: UIViewController?, frozenDetailViewModels: [BalanceDetailViewModel])

    func showXOne(on controller: UIViewController?, address: String, service: SCard)
    
    func showPoolDetails(on viewController: UIViewController?,
                         poolInfo: PoolInfo,
                         assetManager: AssetManagerProtocol,
                         fiatService: FiatServiceProtocol,
                         poolsService: PoolsServiceInputProtocol,
                         providerFactory: BalanceProviderFactory,
                         operationFactory: WalletNetworkOperationFactoryProtocol,
                         assetsProvider: AssetProviderProtocol?,
                         marketCapService: MarketCapServiceProtocol)
}

final class AssetDetailsWireframe: AssetDetailsWireframeProtocol {

    func showActivity(on controller: UIViewController, assetId: String, assetManager: AssetManagerProtocol) {
        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount else { return }
        let assets = assetManager.getAssetList() ?? []
        let historyService = HistoryService(operationManager: OperationManagerFacade.sharedManager,
                                            address: selectedAccount.address,
                                            assets: assets)
        
        let viewModelFactory = ActivityViewModelFactory(walletAssets: assets, assetManager: assetManager)
        let viewModel = ActivityViewModel(historyService: historyService,
                                          viewModelFactory: viewModelFactory,
                                          wireframe: ActivityWireframe(),
                                          assetManager: assetManager,
                                          eventCenter: EventCenter.shared,
                                          assetId: assetId)
        viewModel.localizationManager = LocalizationManager.shared
        viewModel.title = R.string.localizable.assetDetailsRecentActivity(preferredLanguages: .currentLocale)
        viewModel.isNeedCloseButton = true
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overCurrentContext
        
        let activityController = ActivityViewController(viewModel: viewModel)
        activityController.localizationManager = LocalizationManager.shared
        activityController.navigationItem.largeTitleDisplayMode = .never
        viewModel.view = activityController
        
        let activityNavigationController = UINavigationController(rootViewController: activityController)
        activityNavigationController.navigationBar.backgroundColor = .clear
        activityNavigationController.navigationBar.setBackgroundImage(UIImage(), for: .default)
        activityNavigationController.addCustomTransitioning()
        
        containerView.add(activityNavigationController)


        controller.present(containerView, animated: true)
    }
    
    func showActivityDetails(on controller: UIViewController?, model: Transaction, assetManager: AssetManagerProtocol) {
        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount, let aseetList = assetManager.getAssetList() else { return }

        let historyService = HistoryService(operationManager: OperationManagerFacade.sharedManager,
                                            address: selectedAccount.address,
                                            assets: aseetList)
        
        let factory = ActivityDetailsViewModelFactory(assetManager: assetManager)
        let viewModel = ActivityDetailsViewModel(model: model,
                                                 wireframe: ActivityDetailsWireframe(),
                                                 assetManager: assetManager,
                                                 detailsFactory: factory,
                                                 historyService: historyService,
                                                 lpServiceFee: LPFeeService())

        let assetDetailsController = ActivityDetailsViewController(viewModel: viewModel)
        viewModel.view = assetDetailsController
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(assetDetailsController)
        
        controller?.present(containerView, animated: true)
    }
    
    func showSwap(on controller: UIViewController?,
                  selectedTokenId: String,
                  assetManager: AssetManagerProtocol,
                  fiatService: FiatServiceProtocol,
                  networkFacade: WalletNetworkOperationFactoryProtocol?,
                  polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?,
                  assetsProvider: AssetProviderProtocol?,
                  marketCapService: MarketCapServiceProtocol) {
        guard let swapController = SwapViewFactory.createView(selectedTokenId: selectedTokenId,
                                                              selectedSecondTokenId: "",
                                                              assetManager: assetManager,
                                                              fiatService: fiatService,
                                                              networkFacade: networkFacade,
                                                              polkaswapNetworkFacade: polkaswapNetworkFacade,
                                                              assetsProvider: assetsProvider,
                                                              marketCapService: marketCapService) else { return }
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(swapController)
        
        controller?.present(containerView, animated: true)
    }
    
    func showSend(on controller: UIViewController?,
                  selectedAsset: AssetInfo,
                  fiatService: FiatServiceProtocol?,
                  assetManager: AssetManagerProtocol?,
                  eventCenter: EventCenterProtocol,
                  providerFactory: BalanceProviderFactory,
                  networkFacade: WalletNetworkOperationFactoryProtocol?,
                  assetsProvider: AssetProviderProtocol?,
                  qrEncoder: WalletQREncoderProtocol,
                  sharingFactory: AccountShareFactoryProtocol,
                  marketCapService: MarketCapServiceProtocol) {
        let viewModel = InputAssetAmountViewModel(selectedTokenId: selectedAsset.assetId,
                                                  selectedAddress: nil,
                                                  fiatService: fiatService,
                                                  assetManager: assetManager,
                                                  providerFactory: providerFactory,
                                                  networkFacade: networkFacade,
                                                  wireframe: InputAssetAmountWireframe(),
                                                  assetsProvider: assetsProvider,
                                                  qrEncoder: qrEncoder,
                                                  sharingFactory: sharingFactory,
                                                  marketCapService: marketCapService)
        let inputAmountController = InputAssetAmountViewController(viewModel: viewModel)
        viewModel.view = inputAmountController
        
        let navigationController = UINavigationController(rootViewController: inputAmountController)
        navigationController.navigationBar.backgroundColor = .clear
        navigationController.addCustomTransitioning()
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(navigationController)
        
        controller?.present(containerView, animated: true)
    }
    
    func showReceive(on controller: UIViewController?,
                     selectedAsset: AssetInfo,
                     accountId: String,
                     address: String,
                     qrEncoder: WalletQREncoderProtocol,
                     sharingFactory: AccountShareFactoryProtocol,
                     fiatService: FiatServiceProtocol?,
                     assetProvider: AssetProviderProtocol?,
                     assetManager: AssetManagerProtocol?) {
        let qrService = WalletQRService(operationFactory: WalletQROperationFactory(), encoder: qrEncoder)
        
        let viewModel = ReceiveViewModel(qrService: qrService,
                                         sharingFactory: sharingFactory,
                                         accountId: accountId,
                                         address: address,
                                         selectedAsset: selectedAsset,
                                         fiatService: fiatService,
                                         assetProvider: assetProvider,
                                         assetManager: assetManager)
        let receiveController = ReceiveViewController(viewModel: viewModel)
        viewModel.view = receiveController

        let navigationController = UINavigationController(rootViewController: receiveController)
        navigationController.navigationBar.backgroundColor = .clear
        navigationController.addCustomTransitioning()
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(navigationController)
        
        controller?.present(containerView, animated: true)
    }
    
    func showFrozenBalance(on controller: UIViewController?, frozenDetailViewModels: [BalanceDetailViewModel]) {
        let receiveController = BalanceDetailsViewController(viewModels: frozenDetailViewModels)
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(receiveController)
        
        controller?.present(containerView, animated: true)
    }

    func showXOne(on controller: UIViewController?, address: String, service: SCard) {
        let viewController = service.xOneViewController(address: address)
        controller?.present(viewController, animated: true)
    }
    
    func showPoolDetails(on viewController: UIViewController?,
                         poolInfo: PoolInfo,
                         assetManager: AssetManagerProtocol,
                         fiatService: FiatServiceProtocol,
                         poolsService: PoolsServiceInputProtocol,
                         providerFactory: BalanceProviderFactory,
                         operationFactory: WalletNetworkOperationFactoryProtocol,
                         assetsProvider: AssetProviderProtocol?,
                         marketCapService: MarketCapServiceProtocol) {
        guard let assetDetailsController = PoolDetailsViewFactory.createView(poolInfo: poolInfo,
                                                                             assetManager: assetManager,
                                                                             fiatService: fiatService,
                                                                             poolsService: poolsService,
                                                                             providerFactory: providerFactory,
                                                                             operationFactory: operationFactory,
                                                                             assetsProvider: assetsProvider,
                                                                             marketCapService: marketCapService,
                                                                             dismissHandler: nil) else {
            return
        }
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        
        let assetDetailNavigationController = UINavigationController(rootViewController: assetDetailsController)
        assetDetailNavigationController.navigationBar.backgroundColor = .clear
        assetDetailNavigationController.navigationBar.setBackgroundImage(UIImage(), for: .default)
        assetDetailNavigationController.addCustomTransitioning()
        
        containerView.add(assetDetailNavigationController)
        
        viewController?.present(containerView, animated: true)
    }
}
