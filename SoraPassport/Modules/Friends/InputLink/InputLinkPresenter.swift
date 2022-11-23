/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

protocol InputLinkPresenterOutput: AnyObject {
    func setupReferrer(_ referrer: String)
    func showAlert(withSuccess isSuccess: Bool)
}

final class InputLinkPresenter {
    weak var view: InputLinkViewInput?
    weak var output: InputLinkPresenterOutput?
    var interactor: InputLinkInteractorInputProtocol?

    private var address: String = ""
}

extension InputLinkPresenter: InputLinkViewOutput {
    func userTappedonActivete(with text: String) {
        guard let accountId = interactor?.getAccountId(from: address)?.toHex(includePrefix: true) else { return }
        interactor?.sendSetReferrerRequest(with: accountId)
    }

    func userChangeTextField(with text: String) {
        address = text.components(separatedBy: "/").last ?? ""
        let isCurrentUser = interactor?.isCurrentUserAddress(with: address) ?? false
        let isEnableButton = !isCurrentUser && (interactor?.getAccountId(from: address) != nil)
        let state: InputLinkActivateButtonState = isEnableButton ? .enabled : .disabled
        view?.changeButton(to: state)
    }
}

extension InputLinkPresenter: InputLinkInteractorOutputProtocol {
    func setReferralRequestReceived(withSuccess isSuccess: Bool) {
        DispatchQueue.main.async {
            self.view?.dismiss { [weak self] in
                guard let self = self else { return }
                self.output?.setupReferrer(self.address)
                self.output?.showAlert(withSuccess: isSuccess)
            }
        }
    }
}
