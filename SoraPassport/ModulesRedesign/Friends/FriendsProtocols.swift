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

import UIKit
import XNetworking
import CommonWallet

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
