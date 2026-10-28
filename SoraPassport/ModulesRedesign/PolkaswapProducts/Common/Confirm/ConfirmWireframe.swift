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

import RobinHood

protocol ConfirmWireframeProtocol: AlertPresentable {
    func showActivityIndicator()
    
    func hideActivityIndicator()
    
    func showActivityDetails(on controller: UIViewController?, model: Transaction, assetManager: AssetManagerProtocol, completion: (() -> Void)?)
}

final class ConfirmWireframe {
    var activityIndicatorWindow: UIWindow?
}

extension ConfirmWireframe: ConfirmWireframeProtocol {    
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
    
    @MainActor func showActivityDetails(on controller: UIViewController?, model: Transaction, assetManager: AssetManagerProtocol, completion: (() -> Void)?) {
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
