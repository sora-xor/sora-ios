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


protocol GenerateQRWireframeProtocol: AnyObject {
    func showAssetSelection(
        assetManager: AssetManagerProtocol,
        fiatService: FiatServiceProtocol,
        assetViewModelFactory: AssetViewModelFactory,
        assetsProvider: AssetProviderProtocol?,
        assetIds: [String],
        marketCapService: MarketCapServiceProtocol,
        completion: @escaping (String) -> Void
    )
    
    func showReceive(selectedAsset: AssetInfo,
                     accountId: String,
                     address: String,
                     amount: AmountDecimal?,
                     qrEncoder: WalletQREncoderProtocol,
                     sharingFactory: AccountShareFactoryProtocol,
                     fiatService: FiatServiceProtocol?,
                     assetProvider: AssetProviderProtocol?,
                     assetManager: AssetManagerProtocol?)
    
    func showScanQR(on view: UIViewController,
                    networkFacade: WalletNetworkOperationFactoryProtocol,
                    assetManager: AssetManagerProtocol,
                    qrEncoder: WalletQREncoderProtocol,
                    sharingFactory: AccountShareFactoryProtocol,
                    assetsProvider: AssetProviderProtocol?,
                    providerFactory: BalanceProviderFactory,
                    feeProvider: FeeProviderProtocol,
                    marketCapService: MarketCapServiceProtocol,
                    scanCompletion: @escaping (ScanQRResult) -> Void)
    
    func showConfirmSendingAsset(on controller: UIViewController?,
                                 assetId: String,
                                 walletService: WalletServiceProtocol,
                                 assetManager: AssetManagerProtocol,
                                 fiatService: FiatServiceProtocol,
                                 recipientAddress: String,
                                 firstAssetAmount: Decimal,
                                 fee: Decimal,
                                 assetsProvider: AssetProviderProtocol?)

    @MainActor
    func showFeeEstimationError(
        on controller: UIViewController?,
        retry: @escaping () -> Void
    )
    
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
}

final class GenerateQRWireframe: GenerateQRWireframeProtocol {
    
    weak var controller: UIViewController?
    
    init(controller: UIViewController?) {
        self.controller = controller
    }
    
    @MainActor
    func showAssetSelection(
        assetManager: AssetManagerProtocol,
        fiatService: FiatServiceProtocol,
        assetViewModelFactory: AssetViewModelFactory,
        assetsProvider: AssetProviderProtocol?,
        assetIds: [String],
        marketCapService: MarketCapServiceProtocol,
        completion: @escaping (String) -> Void
    ) {
        
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
    
    func showReceive(selectedAsset: AssetInfo,
                     accountId: String,
                     address: String,
                     amount: AmountDecimal?,
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
                                         amount: amount,
                                         fiatService: fiatService,
                                         assetProvider: assetProvider,
                                         assetManager: assetManager)
        let receiveController = ReceiveViewController(viewModel: viewModel)
        viewModel.view = receiveController
        
        controller?.navigationController?.pushViewController(receiveController, animated: true)
    }
    
    @MainActor
    func showScanQR(on view: UIViewController,
                    networkFacade: WalletNetworkOperationFactoryProtocol,
                    assetManager: AssetManagerProtocol,
                    qrEncoder: WalletQREncoderProtocol,
                    sharingFactory: AccountShareFactoryProtocol,
                    assetsProvider: AssetProviderProtocol?,
                    providerFactory: BalanceProviderFactory,
                    feeProvider: FeeProviderProtocol,
                    marketCapService: MarketCapServiceProtocol,
                    scanCompletion: @escaping (ScanQRResult) -> Void) {
        guard let currentUser = SelectedWalletSettings.shared.currentAccount else { return }
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        
        let scanView = ScanQRViewFactory.createView(assetManager: assetManager,
                                                    currentUser: currentUser,
                                                    networkFacade: networkFacade,
                                                    qrEncoder: qrEncoder,
                                                    sharingFactory: sharingFactory,
                                                    assetsProvider: assetsProvider,
                                                    isGeneratedQRCodeScreenShown: true,
                                                    providerFactory: providerFactory,
                                                    feeProvider: feeProvider,
                                                    marketCapService: marketCapService,
                                                    completion: scanCompletion)
        containerView.add(scanView.controller)
        view.present(containerView, animated: true)
    }
    
    @MainActor
    func showConfirmSendingAsset(on controller: UIViewController?,
                                 assetId: String,
                                 walletService: WalletServiceProtocol,
                                 assetManager: AssetManagerProtocol,
                                 fiatService: FiatServiceProtocol,
                                 recipientAddress: String,
                                 firstAssetAmount: Decimal,
                                 fee: Decimal,
                                 assetsProvider: AssetProviderProtocol?) {
        WalletAccountCapability.preflightSend(from: controller) { [self] in
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

            let navigationController = UINavigationController(rootViewController: view)
            navigationController.navigationBar.backgroundColor = .clear
            navigationController.addCustomTransitioning()

            let containerView = BlurViewController()
            containerView.modalPresentationStyle = .overFullScreen
            containerView.add(navigationController)

            controller?.present(containerView, animated: true)
        }
    }

    @MainActor
    func showFeeEstimationError(
        on controller: UIViewController?,
        retry: @escaping () -> Void
    ) {
        let alert = UIAlertController(
            title: nil,
            message: R.string.localizable.commonErrorRetry(
                preferredLanguages: .currentLocale
            ),
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(
                title: R.string.localizable.commonCancel(
                    preferredLanguages: .currentLocale
                ),
                style: .cancel
            )
        )
        alert.addAction(
            UIAlertAction(
                title: R.string.localizable.commonRetry(
                    preferredLanguages: .currentLocale
                ),
                style: .default,
                handler: { _ in retry() }
            )
        )
        controller?.present(alert, animated: true)
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
        WalletAccountCapability.preflightSend(from: controller) { [self] in
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
    }
}
