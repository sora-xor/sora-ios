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
import SoraUIKit
import CommonWallet
import RobinHood

protocol ConfirmTransactionWireframeProtocol {
    func showActivityIndicator()
    func hideActivityIndicator()
    func showActivityDetails(on controller: UIViewController?, model: Transaction, assetManager: AssetManagerProtocol, completion: (() -> Void)?)
}

final class ConfirmTransactionWireframe: ConfirmTransactionWireframeProtocol {
    var activityIndicatorWindow: UIWindow?
    
    func showActivityIndicator() {
        activityIndicatorWindow = UIWindow(frame: UIScreen.main.bounds)
        activityIndicatorWindow?.windowLevel = UIWindow.Level.alert
        activityIndicatorWindow?.rootViewController = ActivityIndicatorViewController()
        activityIndicatorWindow?.isHidden = false
        activityIndicatorWindow?.makeKeyAndVisible()
    }
    
    func hideActivityIndicator() {
        activityIndicatorWindow?.isHidden = true
        activityIndicatorWindow = nil
    }
    
    func showActivityDetails(on controller: UIViewController?, model: Transaction, assetManager: AssetManagerProtocol, completion: (() -> Void)?) {
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
        viewModel.completion = completion

        let assetDetailsController = ActivityDetailsViewController(viewModel: viewModel)
        viewModel.view = assetDetailsController
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.completionHandler = completion
        containerView.add(assetDetailsController)
        
        controller?.present(containerView, animated: true)
    }
}
