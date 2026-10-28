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
import SCard

protocol RedesignWalletWireframeProtocol: AlertPresentable {
    func showFullListAssets(on controller: UIViewController?,
                            assetManager: AssetManagerProtocol,
                            fiatService: FiatServiceProtocol,
                            assetViewModelFactory: AssetViewModelFactory,
                            providerFactory: BalanceProviderFactory,
                            poolsService: PoolsServiceInputProtocol,
                            networkFacade: WalletNetworkOperationFactoryProtocol?,
                            accountId: String,
                            address: String,
                            polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
                            qrEncoder: WalletQREncoderProtocol,
                            sharingFactory: AccountShareFactoryProtocol,
                            referralFactory: ReferralsOperationFactoryProtocol,
                            assetsProvider: AssetProviderProtocol,
                            marketCapService: MarketCapServiceProtocol,
                            farmingService: DemeterFarmingServiceProtocol,
                            updateHandler: ((UpdatedSection) -> Void)?)
    
    func showFullListPools(on controller: UIViewController?,
                           poolsService: PoolsServiceInputProtocol,
                           networkFacade: WalletNetworkOperationFactoryProtocol,
                           polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
                           assetManager: AssetManagerProtocol,
                           fiatService: FiatServiceProtocol,
                           poolViewModelFactory: PoolViewModelFactory,
                           providerFactory: BalanceProviderFactory,
                           operationFactory: WalletNetworkOperationFactoryProtocol,
                           assetsProvider: AssetProviderProtocol,
                           marketCapService: MarketCapServiceProtocol,
                           farmingService: DemeterFarmingServiceProtocol,
                           updateHandler: ((UpdatedSection) -> Void)?)
    
    func showAssetDetails(on viewController: UIViewController?,
                          assetInfo: AssetInfo,
                          assetManager: AssetManagerProtocol,
                          fiatService: FiatServiceProtocol,
                          assetViewModelFactory: AssetViewModelFactory,
                          poolsService: PoolsServiceInputProtocol,
                          poolViewModelsFactory: PoolViewModelFactory,
                          providerFactory: BalanceProviderFactory,
                          networkFacade: WalletNetworkOperationFactoryProtocol?,
                          accountId: String,
                          address: String,
                          polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
                          qrEncoder: WalletQREncoderProtocol,
                          sharingFactory: AccountShareFactoryProtocol,
                          referralFactory: ReferralsOperationFactoryProtocol,
                          assetsProvider: AssetProviderProtocol,
                          marketCapService: MarketCapServiceProtocol,
                          farmingService: DemeterFarmingServiceProtocol)
    
    func showPoolDetails(on viewController: UIViewController?,
                         poolInfo: PoolInfo,
                         assetManager: AssetManagerProtocol,
                         fiatService: FiatServiceProtocol,
                         poolsService: PoolsServiceInputProtocol,
                         providerFactory: BalanceProviderFactory,
                         operationFactory: WalletNetworkOperationFactoryProtocol,
                         assetsProvider: AssetProviderProtocol,
                         marketCapService: MarketCapServiceProtocol,
                         farmingService: DemeterFarmingServiceProtocol)

    func showSoraCard(on viewController: UIViewController?,
                      address: AccountAddress,
                      balanceProvider: RobinHood.SingleValueProvider<[BalanceData]>?)

    func showSoraCardExchange(on viewController: UIViewController?)

    func showManageAccount(on view: UIViewController, completion: @escaping () -> Void)
    
    func showGenerateQR(on controller: UIViewController?,
                        accountId: String,
                        address: String,
                        username: String,
                        qrEncoder: WalletQREncoderProtocol,
                        sharingFactory: AccountShareFactoryProtocol,
                        assetManager: AssetManagerProtocol?,
                        assetsProvider: AssetProviderProtocol?,
                        networkFacade: WalletNetworkOperationFactoryProtocol,
                        providerFactory: BalanceProviderFactory,
                        isScanQRShown: Bool,
                        marketCapService: MarketCapServiceProtocol,
                        closeHandler: (() -> Void)?)
    
    func showSend(on controller: UIViewController?,
                  selectedTokenId: String?,
                  selectedAddress: String,
                  fiatService: FiatServiceProtocol?,
                  assetManager: AssetManagerProtocol?,
                  providerFactory: BalanceProviderFactory,
                  networkFacade: WalletNetworkOperationFactoryProtocol?,
                  assetsProvider: AssetProviderProtocol,
                  qrEncoder: WalletQREncoderProtocol,
                  sharingFactory: AccountShareFactoryProtocol,
                  marketCapService: MarketCapServiceProtocol)
    
    func showReferralProgram(from view: RedesignWalletViewProtocol?,
                             walletContext: CommonWalletContextProtocol,
                             assetManager: AssetManagerProtocol)
    
    func showEditView(from view: RedesignWalletViewProtocol?,
                      poolsService: PoolsServiceInputProtocol,
                      editViewService: EditViewServiceProtocol,
                      completion: (() -> Void)?)
    
    func showAccountOptions(from view: RedesignWalletViewProtocol?,
                            account: AccountItem?)
}

final class RedesignWalletWireframe: RedesignWalletWireframeProtocol {
    
    let feeProvider: FeeProviderProtocol
    
    init(feeProvider: FeeProviderProtocol) {
        self.feeProvider = feeProvider
    }

    func showSoraCard(
        on viewController: UIViewController?,
        address: AccountAddress,
        balanceProvider: SingleValueProvider<[BalanceData]>?
    ) {
        guard let viewController else { return }
        SCard.shared?.start(in: viewController)
    }

    func showSoraCardExchange(
        on viewController: UIViewController?
    ) {
        guard let viewController else { return }
        SCard.shared?.showExchange(in: viewController)
    }

    @MainActor
    func showFullListAssets(on controller: UIViewController?,
                            assetManager: AssetManagerProtocol,
                            fiatService: FiatServiceProtocol,
                            assetViewModelFactory: AssetViewModelFactory,
                            providerFactory: BalanceProviderFactory,
                            poolsService: PoolsServiceInputProtocol,
                            networkFacade: WalletNetworkOperationFactoryProtocol?,
                            accountId: String,
                            address: String,
                            polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
                            qrEncoder: WalletQREncoderProtocol,
                            sharingFactory: AccountShareFactoryProtocol,
                            referralFactory: ReferralsOperationFactoryProtocol,
                            assetsProvider: AssetProviderProtocol,
                            marketCapService: MarketCapServiceProtocol,
                            farmingService: DemeterFarmingServiceProtocol,
                            updateHandler: ((UpdatedSection) -> Void)?) {
        let wireframe = AssetListWireframe(feeProvider: feeProvider)
        let viewModel = ManageAssetListViewModel(assetViewModelFactory: assetViewModelFactory,
                                                 fiatService: fiatService,
                                                 assetManager: assetManager,
                                                 providerFactory: providerFactory,
                                                 poolsService: poolsService,
                                                 networkFacade: networkFacade,
                                                 accountId: accountId,
                                                 address: address,
                                                 polkaswapNetworkFacade: polkaswapNetworkFacade,
                                                 qrEncoder: qrEncoder,
                                                 sharingFactory: sharingFactory,
                                                 referralFactory: referralFactory,
                                                 assetsProvider: assetsProvider,
                                                 marketCapService: marketCapService,
                                                 farmingService: farmingService, 
                                                 wireframe: wireframe,
                                                 updateHandler: updateHandler)
        
        let assetListController = ProductListViewController(viewModel: viewModel)
        viewModel.view = assetListController
                
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        let newNav = SoraNavigationController(rootViewController: assetListController)
        newNav.navigationBar.backgroundColor = .clear
        newNav.addCustomTransitioning()
        
        containerView.add(newNav)
        controller?.present(containerView, animated: true)
    }
    
    @MainActor
    func showFullListPools(on controller: UIViewController?,
                           poolsService: PoolsServiceInputProtocol,
                           networkFacade: WalletNetworkOperationFactoryProtocol,
                           polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
                           assetManager: AssetManagerProtocol,
                           fiatService: FiatServiceProtocol,
                           poolViewModelFactory: PoolViewModelFactory,
                           providerFactory: BalanceProviderFactory,
                           operationFactory: WalletNetworkOperationFactoryProtocol,
                           assetsProvider: AssetProviderProtocol,
                           marketCapService: MarketCapServiceProtocol,
                           farmingService: DemeterFarmingServiceProtocol,
                           updateHandler: ((UpdatedSection) -> Void)?) {
        let viewModel = PoolListViewModel(poolsService: poolsService,
                                          assetManager: assetManager,
                                          fiatService: fiatService,
                                          poolViewModelFactory: poolViewModelFactory,
                                          providerFactory: providerFactory,
                                          operationFactory: operationFactory,
                                          assetsProvider: assetsProvider,
                                          marketCapService: marketCapService,
                                          farmingService: farmingService, 
                                          feeProvider: feeProvider,
                                          updateHandler: updateHandler)
        
        poolsService.appendDelegate(delegate: viewModel)
        
        let assetListController = ProductListViewController(viewModel: viewModel)
        viewModel.view = assetListController
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        let navigationController = UINavigationController(rootViewController: assetListController)
        navigationController.modalPresentationStyle = .fullScreen
        
        containerView.add(navigationController)
        controller?.present(containerView, animated: true)
    }
    
    @MainActor
    func showAssetDetails(on viewController: UIViewController?,
                          assetInfo: AssetInfo,
                          assetManager: AssetManagerProtocol,
                          fiatService: FiatServiceProtocol,
                          assetViewModelFactory: AssetViewModelFactory,
                          poolsService: PoolsServiceInputProtocol,
                          poolViewModelsFactory: PoolViewModelFactory,
                          providerFactory: BalanceProviderFactory,
                          networkFacade: WalletNetworkOperationFactoryProtocol?,
                          accountId: String,
                          address: String,
                          polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
                          qrEncoder: WalletQREncoderProtocol,
                          sharingFactory: AccountShareFactoryProtocol,
                          referralFactory: ReferralsOperationFactoryProtocol,
                          assetsProvider: AssetProviderProtocol,
                          marketCapService: MarketCapServiceProtocol,
                          farmingService: DemeterFarmingServiceProtocol) {
        guard let assetDetailsController = AssetDetailsViewFactory.createView(assetInfo: assetInfo,
                                                                              assetManager: assetManager,
                                                                              fiatService: fiatService,
                                                                              assetViewModelFactory: assetViewModelFactory,
                                                                              poolsService: poolsService,
                                                                              poolViewModelsFactory: poolViewModelsFactory,
                                                                              providerFactory: providerFactory,
                                                                              networkFacade: networkFacade,
                                                                              accountId: accountId,
                                                                              address: address,
                                                                              polkaswapNetworkFacade: polkaswapNetworkFacade,
                                                                              qrEncoder: qrEncoder,
                                                                              sharingFactory: sharingFactory,
                                                                              referralFactory: referralFactory,
                                                                              assetsProvider: assetsProvider,
                                                                              marketCapService: marketCapService,
                                                                              farmingService: farmingService, 
                                                                              feeProvider: feeProvider) else {
            return
        }
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(assetDetailsController)
        
        viewController?.present(containerView, animated: true)
    }
    
    @MainActor
    func showPoolDetails(on viewController: UIViewController?,
                         poolInfo: PoolInfo,
                         assetManager: AssetManagerProtocol,
                         fiatService: FiatServiceProtocol,
                         poolsService: PoolsServiceInputProtocol,
                         providerFactory: BalanceProviderFactory,
                         operationFactory: WalletNetworkOperationFactoryProtocol,
                         assetsProvider: AssetProviderProtocol,
                         marketCapService: MarketCapServiceProtocol,
                         farmingService: DemeterFarmingServiceProtocol) {
        guard let assetDetailsController = PoolDetailsViewFactory.createView(poolInfo: poolInfo,
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
        
        viewController?.present(containerView, animated: true)
    }
    
    @MainActor
    func showManageAccount(on view: UIViewController, completion: @escaping () -> Void) {
        guard let changeAccountView = ChangeAccountViewFactory.changeAccountViewController(with: completion) else {
            return
        }
            
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        let newNav = SoraNavigationController(rootViewController: changeAccountView.controller)
        newNav.navigationBar.backgroundColor = .clear
        newNav.addCustomTransitioning()
        
        containerView.add(newNav)
        view.present(containerView, animated: true)
    }
    
    @MainActor
    func showGenerateQR(on controller: UIViewController?,
                        accountId: String,
                        address: String,
                        username: String,
                        qrEncoder: WalletQREncoderProtocol,
                        sharingFactory: AccountShareFactoryProtocol,
                        assetManager: AssetManagerProtocol?,
                        assetsProvider: AssetProviderProtocol?,
                        networkFacade: WalletNetworkOperationFactoryProtocol,
                        providerFactory: BalanceProviderFactory,
                        isScanQRShown: Bool,
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
            marketCapService: marketCapService,
            isScanQRShown: isScanQRShown
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
    
    @MainActor
    func showSend(on controller: UIViewController?,
                  selectedTokenId: String?,
                  selectedAddress: String,
                  fiatService: FiatServiceProtocol?,
                  assetManager: AssetManagerProtocol?,
                  providerFactory: BalanceProviderFactory,
                  networkFacade: WalletNetworkOperationFactoryProtocol?,
                  assetsProvider: AssetProviderProtocol,
                  qrEncoder: WalletQREncoderProtocol,
                  sharingFactory: AccountShareFactoryProtocol,
                  marketCapService: MarketCapServiceProtocol) {
        let viewModel = InputAssetAmountViewModel(selectedTokenId: selectedTokenId,
                                                  selectedAddress: selectedAddress,
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
    
    @MainActor
    func showReferralProgram(from view: RedesignWalletViewProtocol?,
                             walletContext: CommonWalletContextProtocol,
                             assetManager: AssetManagerProtocol) {

        guard
            let friendsView = FriendsViewFactory.createView(walletContext: walletContext,
                                                            assetManager: assetManager),
            let controller = view?.controller
        else {
            return
        }
        
        let navigationController = SoraNavigationController(rootViewController: friendsView.controller)
        navigationController.navigationBar.backgroundColor = .clear
        navigationController.addCustomTransitioning()
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(navigationController)
        
        controller.present(containerView, animated: true)
    }
    
    @MainActor
    func showEditView(from view: RedesignWalletViewProtocol?,
                      poolsService: PoolsServiceInputProtocol,
                      editViewService: EditViewServiceProtocol,
                      completion: (() -> Void)?) {
        
        guard let controller = view?.controller else { return }
        
        let editView = EditViewFactory.createView(poolsService: poolsService,
                                                  editViewService: editViewService,
                                                  completion: completion)
        
        let navigationController = SoraNavigationController(rootViewController: editView)
        navigationController.navigationBar.backgroundColor = .clear
        navigationController.addCustomTransitioning()
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(navigationController)
        
        controller.present(containerView, animated: true)
    }
    
    @MainActor
    func showAccountOptions(from view: RedesignWalletViewProtocol?,
                            account: AccountItem?) {
        guard
            let account = account,
            let viewController = AccountOptionsViewFactory.createView(account: account) as? UIViewController,
            let controller = view?.controller
        else {
            return
        }
        
        let navigationController = SoraNavigationController(rootViewController: viewController)
        navigationController.navigationBar.backgroundColor = .clear
        navigationController.addCustomTransitioning()
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(navigationController)
        
        controller.present(containerView, animated: true)
    }
}
