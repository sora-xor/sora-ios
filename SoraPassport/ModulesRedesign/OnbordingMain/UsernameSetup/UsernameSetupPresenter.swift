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

enum UsernameSetupMode {
    case onboarding
    case editing
    case creating
}

final class UsernameSetupPresenter {
    weak var view: UsernameSetupViewProtocol?
    var wireframe: UsernameSetupWireframeProtocol!
    var viewModel: InputViewModel!
    var successEditingBlock: (() -> Void)?
    let settingsManager = SelectedWalletSettings.shared
    var mode: UsernameSetupMode = .onboarding
    var userName: String? {
        get { settingsManager.currentAccount?.username }
        set {
            let newUserName = newValue ?? ""
            if mode == .editing,
               let account = settingsManager.currentAccount {
                settingsManager.performUpdateName(
                    account: account,
                    displayName: newUserName
                ) { _ in }
            }
        }
    }
}

extension UsernameSetupPresenter: UsernameSetupPresenterProtocol {
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
        showNewFlow()
    }
    
    func endEditing() {
        successEditingBlock?()
    }

    func activateURL(_ url: URL) {
        if let view = view {
            wireframe.showWeb(url: url,
                              from: view,
                              style: .modal)
        }
    }
}

private extension UsernameSetupPresenter {
    
    func showNewFlow() {
        wireframe.showWarning(from: view) { [weak self] in
            self?.wireframe.proceed(from: self?.view, username: self?.viewModel.inputHandler.value ?? "")
        }
    }
}
    
extension UsernameSetupPresenter: Localizable {
    func applyLocalization() {}
}
