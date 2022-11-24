/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import UIKit
import SoraKeystore

final class ChangeAccountPresenter {
    weak var view: ChangeAccountViewProtocol?
    var wireframe: ChangeAccountWireframeProtocol!
    var interactor: ChangeAccountInteractorInputProtocol!
    var endUpdatingBlock: (() -> Void)?

    private let accountViewModelFactory: AccountViewModelFactoryProtocol
    private let settingsManager: SelectedWalletSettingsProtocol
    private let eventCenter: EventCenterProtocol
    private var accounts: [AccountItem] = []
    private(set) var accountViewModels: [AccountViewModelProtocol] = []
    
    init(accountViewModelFactory: AccountViewModelFactoryProtocol,
         settingsManager: SelectedWalletSettingsProtocol,
         eventCenter: EventCenterProtocol) {
        self.accountViewModelFactory = accountViewModelFactory
        self.settingsManager = settingsManager
        self.eventCenter = eventCenter
    }
}

extension ChangeAccountPresenter: ChangeAccountPresenterProtocol {
    func setup() {
        interactor.getAccounts()
    }
    
    func selectItem(at index: Int) {
        guard settingsManager.currentAccount != accounts[index] else { return }

        for currentIndex in 0...accountViewModels.count - 1 {
            accountViewModels[currentIndex].isSelected = currentIndex == index
        }
        view?.update(with: accountViewModels)
        
        let accountItem = accounts[index]

        settingsManager.save(value: accountItem)
        eventCenter.notify(with: SelectedAccountChanged())
    }
    
    func createAccount() {
        guard let view = view?.controller else { return }

        wireframe?.showSignUp(from: view) { [weak self] in
            self?.interactor.getAccounts()
        }
    }

    func importAccount() {
        guard let view = view?.controller else { return }

        wireframe?.showAccountRestore(from: view, completion: { [weak self] in
            self?.interactor.getAccounts()
        })
    }
    
    func endUpdating() {
        endUpdatingBlock?()
    }
}

extension ChangeAccountPresenter: ChangeAccountInteractorOutputProtocol {
    func received(accounts: [AccountItem]) {
        self.accounts = accounts

        let address = settingsManager.currentAccount?.address ?? ""
        let isNeedToBottomScroll = !accountViewModels.isEmpty

        accountViewModels = accountViewModelFactory.createItem(from: accounts, selectedAccountAddress: address)
        view?.didLoad(accountViewModels: accountViewModels)

        if !isNeedToBottomScroll { return }
        view?.scrollViewToBottom()
    }
}
