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
import RobinHood
import SoraKeystore

final class ChangeAccountViewFactory: ChangeAccountViewFactoryProtocol {
    static func changeAccountViewController(with completion: @escaping () -> Void) -> ChangeAccountViewProtocol? {
        let view = ChangeAccountViewController()
        
        let settingsManager = SelectedWalletSettings.shared
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem>
            = UserDataStorageFacade.shared.createRepository(filter: nil,
                                                              sortDescriptors: [NSSortDescriptor.accountsByOrder],
                                                              mapper: AnyCoreDataMapper(AccountItemMapper()))
        
        let operationManager = OperationManagerFacade.sharedManager


        let presenter = ChangeAccountPresenter(settingsManager: settingsManager,
                                               eventCenter: EventCenter.shared,
                                               accountRepository: AnyDataProviderRepository(accountRepository),
                                               operationManager: operationManager,
                                               serviceCoordinator: ServiceCoordinator.shared)
        
        
        let wireframe = ChangeAccountWireframe()

        view.localizationManager = LocalizationManager.shared
        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.endUpdatingBlock = completion

        return view
    }
}
