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
import SoraKeystore

final class SplashPresenter: SplashPresenterProtocol {
    weak var view: SplashViewProtocol?
    var interactor: SplashInteractorProtocol!
    var window: SoraWindow!
    var wireframe: SplashWireframe?

    init(window: SoraWindow) {
        self.window = window
    }

    func setupComplete() {
        DispatchQueue.main.async {
            self.view?.animate(duration: 2, completion: {
                self.wireframe?.showRoot(on: self.window)
            })
        }
    }

    func storageSpaceRequired() {
        view?.showStorageSpaceRetry { [weak self] in
            self?.interactor.retryStorageMigration()
        }
    }
    
    func showIsLoading(after duration: TimeInterval, execute: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            execute()
        }
    }
}

final class SplashWireframe {
    func showRoot(on view: SoraWindow) {
        let presenter = RootPresenterFactory.createPresenter(with: view)
        presenter.loadOnLaunch()
    }
}
