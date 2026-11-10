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
import SoraFoundation
import SoraKeystore
import RobinHood

final class SetupNameCreateAccountPresenter {
    weak var view: UsernameSetupViewProtocol?
    var wireframe: UsernameSetupWireframeProtocol!
    var interactor: AccountImportInteractorInputProtocol!
    var viewModel: InputViewModel!
    var completion: (() -> Void)?
    let settingsManager: SelectedWalletSettingsProtocol
    var mode: UsernameSetupMode = .onboarding
    var userName: String?

    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let eventCenter: EventCenterProtocol
    private let operationManager: OperationManagerProtocol
    
    init(accountRepository: AnyDataProviderRepository<AccountItem>,
         eventCenter: EventCenterProtocol,
         operationManager: OperationManagerProtocol,
         selectedSettings: SelectedWalletSettingsProtocol = SelectedWalletSettings.shared) {
        self.settingsManager = selectedSettings
        self.accountRepository = accountRepository
        self.eventCenter = eventCenter
        self.operationManager = operationManager
    }
}

extension SetupNameCreateAccountPresenter: UsernameSetupPresenterProtocol {
    func setup() {
        let value = mode == .creating ? "" : userName ?? ""
        
        let inputHandling = InputHandler(value: value,
                                         required: false,
                                         predicate: NSPredicate.notEmpty,
                                         processor: ByteLengthProcessor.username)
        viewModel = InputViewModel(inputHandler: inputHandling)
        view?.set(viewModel: viewModel)
    }
    
    func proceed() {
        guard let account = settingsManager.currentAccount else { return }
        
        settingsManager.performUpdateName(
            account: account,
            displayName: userName ?? ""
        ) { [weak self] result in
            DispatchQueue.main.async {
                if case .success = result {
                    self?.eventCenter.notify(with: SelectedUsernameChanged())
                }
            }
        }
        
        view?.controller.dismiss(animated: true, completion: completion)
    }
    
    func endEditing() {}

    func activateURL(_ url: URL) {
        if let view = view {
            wireframe.showWeb(url: url,
                              from: view,
                              style: .modal)
        }
    }
}
    
extension SetupNameCreateAccountPresenter: Localizable {
    func applyLocalization() {}
}
