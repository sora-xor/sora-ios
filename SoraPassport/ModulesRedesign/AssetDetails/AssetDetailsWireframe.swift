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
import SCard
import UIKit
import SoraUIKit

import RobinHood
import SoraFoundation

protocol AssetDetailsWireframeProtocol {
    func showActivity(assetId: String)

    func showActivityDetails(model: Transaction)
    
    func showSwap()
    
    func showReceive()
    
    func showSend()
    
    func showFrozenBalance(frozenDetailViewModels: [BalanceDetailViewModel])

    func showXOne(service: SCard)
    
    func showPoolDetails(poolInfo: PoolInfo,
                         poolsService: PoolsServiceInputProtocol)
}

final class AssetDetailsWireframe: AssetDetailsWireframeProtocol {
    weak var controller: UIViewController?
    
    private let accountId: String
    private let address: String
    private var assetManager: AssetManagerProtocol
    private var fiatService: FiatServiceProtocol
    private let eventCenter: EventCenterProtocol 
    private var assetInfo: AssetInfo 
    private let providerFactory: BalanceProviderFactory 
    private let networkFacade: WalletNetworkOperationFactoryProtocol? 
    private let polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol 
    private var assetsProvider: AssetProviderProtocol 
    private var marketCapService: MarketCapServiceProtocol
    private let qrEncoder: WalletQREncoderProtocol 
    private let sharingFactory: AccountShareFactoryProtocol 
    private let farmingService: DemeterFarmingServiceProtocol
    private let feeProvider: FeeProviderProtocol
    
    init(
        accountId: String,
        address: String,
        assetManager: AssetManagerProtocol,
        fiatService: FiatServiceProtocol,
        eventCenter: EventCenterProtocol,
        assetInfo: AssetInfo,
        providerFactory: BalanceProviderFactory,
        networkFacade: WalletNetworkOperationFactoryProtocol?,
        polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
        assetsProvider: AssetProviderProtocol,
        marketCapService: MarketCapServiceProtocol,
        qrEncoder: WalletQREncoderProtocol,
        sharingFactory: AccountShareFactoryProtocol,
        farmingService: DemeterFarmingServiceProtocol,
        feeProvider: FeeProviderProtocol
    ) {
        self.accountId = accountId
        self.address = address
        self.assetManager = assetManager
        self.fiatService = fiatService
        self.eventCenter = eventCenter
        self.assetInfo = assetInfo
        self.providerFactory = providerFactory
        self.networkFacade = networkFacade
        self.polkaswapNetworkFacade = polkaswapNetworkFacade
        self.assetsProvider = assetsProvider
        self.marketCapService = marketCapService
        self.qrEncoder = qrEncoder
        self.sharingFactory = sharingFactory
        self.farmingService = farmingService
        self.feeProvider = feeProvider
    }
    

    @MainActor func showActivity(assetId: String) {
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
                                          eventCenter: eventCenter,
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


        controller?.present(containerView, animated: true)
    }
    
    @MainActor func showActivityDetails(model: Transaction) {
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
    
    @MainActor func showSwap() {
        guard let swapController = SwapViewFactory.createView(selectedTokenId: assetInfo.assetId,
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
    
    @MainActor func showSend() {
        let viewModel = InputAssetAmountViewModel(selectedTokenId: assetInfo.assetId,
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
    
    @MainActor func showReceive() {
        let qrService = WalletQRService(operationFactory: WalletQROperationFactory(), encoder: qrEncoder)
        
        let viewModel = ReceiveViewModel(qrService: qrService,
                                         sharingFactory: sharingFactory,
                                         accountId: accountId,
                                         address: address,
                                         selectedAsset: assetInfo,
                                         fiatService: fiatService,
                                         assetProvider: assetsProvider,
                                         assetManager: assetManager)
        let receiveController = ReceiveViewController(viewModel: viewModel)
        viewModel.view = receiveController

        let navigationController = UINavigationController(rootViewController: receiveController)
        navigationController.navigationBar.backgroundColor = UIColor.clear
        navigationController.addCustomTransitioning()
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(navigationController)
        
        controller?.present(containerView, animated: true)
    }
    
    @MainActor func showFrozenBalance(frozenDetailViewModels: [BalanceDetailViewModel]) {
        let receiveController = BalanceDetailsViewController(viewModels: frozenDetailViewModels)
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(receiveController)
        
        controller?.present(containerView, animated: true)
    }

    func showXOne(service: SCard) {
        let viewController = service.xOneViewController(address: address)
        controller?.present(viewController, animated: true)
    }
    
    @MainActor func showPoolDetails(poolInfo: PoolInfo,
                         poolsService: PoolsServiceInputProtocol) {
        guard let operationFactory = networkFacade,
              let assetDetailsController = PoolDetailsViewFactory.createView(poolInfo: poolInfo,
                                                                             assetManager: assetManager,
                                                                             fiatService: fiatService,
                                                                             poolsService: poolsService,
                                                                             providerFactory: providerFactory,
                                                                             operationFactory: operationFactory,
                                                                             assetsProvider: assetsProvider,
                                                                             marketCapService: marketCapService,
                                                                             farmingService: farmingService,
                                                                             feeProvider: feeProvider,
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
        
        controller?.present(containerView, animated: true)
    }
}
