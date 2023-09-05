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
