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

protocol InputLinkPresenterOutput: AnyObject {
    func setupReferrer(_ referrer: String)
    func showAlert(withSuccess isSuccess: Bool)
    func showTransactionDetails(from controller: UIViewController?, result: Result<String, Swift.Error>, peerAddress: String, completion: (() -> Void)?)
    func moveForward(controller: UIViewController?)
}

final class InputLinkPresenter {
    weak var view: InputLinkViewInput?
    weak var output: InputLinkPresenterOutput?
    var interactor: InputLinkInteractorInputProtocol?
    weak var viewModel: ReferrerLinkViewModel?

    private var items: [CellViewModel] = []
    private var actionButtonIsEnabled: Bool = false
}

extension InputLinkPresenter: InputLinkViewOutput {
    func willMove() {
        let item = ReferrerLinkViewModel(isEnabled: actionButtonIsEnabled,
                                         interactor: interactor)
        items.append(item)
        
        DispatchQueue.main.async {
            self.view?.setup(with: self.items)
        }
        
        viewModel = item
    }
}

extension InputLinkPresenter: InputLinkInteractorOutputProtocol {
    func setReferralRequestReceived(with result: Result<String, Error>) {
        DispatchQueue.main.async {
            guard let viewModel = self.viewModel else { return }
            
            if case .success = result {
                self.output?.setupReferrer(viewModel.address)
            }
            
            self.output?.showTransactionDetails(from: self.view?.controller,
                                                result: result,
                                                peerAddress: viewModel.address,
                                                completion: {
                self.handleCompletion(result)
            })
        }
    }
    
    func handleCompletion(_ result: Result<String, Error>) {
        switch result {
        case .success:
            output?.moveForward(controller: view?.controller)
        case .failure:
            view?.pop()
        }
    }
}
