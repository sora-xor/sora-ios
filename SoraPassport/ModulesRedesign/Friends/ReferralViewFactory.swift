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

import SoraUI
import IrohaCrypto
import SoraKeystore
import CoreGraphics


protocol ReferralViewFactoryProtocol {
    static func createReferrerView(with referrer: String) -> UIViewController
    static func createInputLinkView(with delegate: InputLinkPresenterOutput) -> UIViewController?
    static func createInputRewardAmountView(with fee: Decimal,
                                            bondedAmount: Decimal,
                                            type: InputRewardAmountType,
                                            walletContext: CommonWalletContextProtocol,
                                            delegate: InputRewardAmountPresenterOutput) -> UIViewController?
    static func createActivityDetailsView(assetManager: AssetManagerProtocol, model: Transaction, completion: (() -> Void)?) -> UIViewController?
}

final class ReferralViewFactory: ReferralViewFactoryProtocol {
    static func createReferrerView(with referrer: String) -> UIViewController {
        let presenter = YourReferrerPresenter(referrer: referrer)
        let view = YourReferrerViewController(presenter: presenter)
        presenter.view = view
        return view
    }

    static func createInputLinkView(with delegate: InputLinkPresenterOutput) -> UIViewController? {
        let settings = SettingsManager.shared
        let keychain = Keychain()
        let chainId = Chain.sora.genesisHash()
        guard let engine = ChainRegistryFacade.sharedRegistry.getConnection(for: chainId),
              let runtimeRegistry = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: chainId),
              let selectedAccount = SelectedWalletSettings.shared.currentAccount else { return nil }


        let operationFactory = ReferralsOperationFactory(settings: settings,
                                                         keychain: keychain,
                                                         engine: engine, runtimeRegistry: runtimeRegistry,
                                                         selectedAccount: selectedAccount)

        let interactor = InputLinkInteractor(operationManager: OperationManagerFacade.sharedManager,
                                             operationFactory: operationFactory,
                                             addressFactory: SS58AddressFactory(),
                                             selectedAccountAddress: selectedAccount.address)

        let presenter = InputLinkPresenter()
        presenter.interactor = interactor
        presenter.output = delegate

        interactor.presenter = presenter

        let view = InputLinkViewController(presenter: presenter)
        presenter.view = view

        return view
    }

    static func createInputRewardAmountView(with fee: Decimal,
                                            bondedAmount: Decimal,
                                            type: InputRewardAmountType,
                                            walletContext: CommonWalletContextProtocol,
                                            delegate: InputRewardAmountPresenterOutput) -> UIViewController? {
        let settings = SettingsManager.shared
        let keychain = Keychain()
        let chainId = Chain.sora.genesisHash()
        let assetManager = ChainRegistryFacade.sharedRegistry.getAssetManager(for: chainId)

        guard let engine = ChainRegistryFacade.sharedRegistry.getConnection(for: chainId),
              let runtimeRegistry = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: chainId),
              let selectedAccount =  SelectedWalletSettings.shared.currentAccount,
              let feeAsset = assetManager.getAssetList()?.first(where: { $0.isFeeAsset }) else { return nil }
        let operationFactory = ReferralsOperationFactory(settings: settings,
                                                         keychain: keychain,
                                                         engine: engine, runtimeRegistry: runtimeRegistry,
                                                         selectedAccount: selectedAccount)

        let interactor = InputRewardAmountInteractor(networkFacade: walletContext.networkOperationFactory,
                                                     operationFactory: operationFactory,
                                                     feeAsset: feeAsset)

        let presenter = InputRewardAmountPresenter(fee: fee,
                                                   previousBondedAmount: bondedAmount,
                                                   type: type,
                                                   interactor: interactor,
                                                   feeAsset: feeAsset)
        presenter.output = delegate
        interactor.presenter = presenter

        let view = InputRewardAmountViewController(presenter: presenter)
        presenter.view = view
        
        return view
    }
    
    static func createActivityDetailsView(assetManager: AssetManagerProtocol, model: Transaction, completion: (() -> Void)?) -> UIViewController? {
        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount,
              let assetList = assetManager.getAssetList()
        else { return nil }
        
        let historyService = HistoryService(operationManager: OperationManagerFacade.sharedManager,
                                            address: selectedAccount.address,
                                            assets: assetList)
        
        let factory = ActivityDetailsViewModelFactory(assetManager: assetManager)
        let viewModel = ActivityDetailsViewModel(model: model,
                                                 wireframe: ActivityDetailsWireframe(),
                                                 assetManager: assetManager,
                                                 detailsFactory: factory,
                                                 historyService: historyService,
                                                 lpServiceFee: LPFeeService())
        viewModel.completion = completion
        
        let view = ActivityDetailsViewController(viewModel: viewModel)
        viewModel.view = view
        
        return view
    }
}
