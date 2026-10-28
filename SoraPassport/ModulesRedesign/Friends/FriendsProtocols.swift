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

import UIKit
import sorawallet


// MARK: - View

protocol FriendsViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func setup(with models: [CellViewModel])
    func reloadScreen(with models: [CellViewModel], updatedIndexs: [Int], isExpanding: Bool)
    func startInvitingScreen(with referrer: String)
    func showAlert(with text: String, image: UIImage?)
}

// MARK: - Presenter

protocol FriendsPresenterProtocol: AlertPresentable {
    func setup()
    func didSelectAction(_ action: FriendsPresenter.InvitationActionType)
}

// MARK: - Interactor

protocol FriendsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol FriendsInteractorOutputProtocol: AnyObject {
    func didFailLoading(error: Swift.Error)
    func didReceive(rewards: [ReferrerReward],
                    setReferrerFee: Decimal,
                    bondFee: Decimal,
                    unbondFee: Decimal,
                    referralBalance: Decimal,
                    referrer: String)
    func updateReferrer(address: String)
    func updateReferral(balance: Decimal)
    func updateReferral(rewards: [ReferrerReward])
}

// MARK: - Wireframe

protocol FriendsWireframeProtocol: SharingPresentable, AlertPresentable,
                                   ErrorPresentable, HelpPresentable {
    func showLinkInputViewController(from controller: UIViewController, delegate: InputLinkPresenterOutput)

    func showInputRewardAmountViewController(from controller: UIViewController,
                                             fee: Decimal,
                                             bondedAmount: Decimal,
                                             type: InputRewardAmountType,
                                             delegate: InputRewardAmountPresenterOutput)

    func showActivityViewController(from controller: UIViewController, shareText: String)

    func showReferrerScreen(from controller: UIViewController, referrer: String)
    
    func showActivityDetails(from controller: UIViewController?, model: Transaction, completion: (() -> Void)?)
    func setViewControllers(from controller: UIViewController?, currentController: UIViewController?, referrer: String)
}

// MARK: - Factory

protocol FriendsViewFactoryProtocol: AnyObject {
    static func createView(walletContext: CommonWalletContextProtocol,
                           assetManager: AssetManagerProtocol) -> FriendsViewProtocol?
}
