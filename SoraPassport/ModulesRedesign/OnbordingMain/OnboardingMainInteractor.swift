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
import RobinHood
import SSFUtils
import SoraKeystore
import SSFCloudStorage

enum OnboardingMainInteractorState {
    case initial
    case preparing(operation: BaseOperation<SupportedVersionData>)
    case prepared
    case preparingSignup(onlyVersionCheck: Bool)
    case preparingRestoration(operation: BaseOperation<SupportedVersionData>)
}

final class OnboardingMainInteractor {
    weak var presenter: OnboardingMainInteractorOutputProtocol?

    private(set) var state: OnboardingMainInteractorState = .initial

    let keystoreImportService: KeystoreImportServiceProtocol
    let backupService: CloudStorageServiceProtocol

    init(keystoreImportService: KeystoreImportServiceProtocol,
         backupService: CloudStorageServiceProtocol) {
        self.keystoreImportService = keystoreImportService
        self.backupService = backupService
    }
}

extension OnboardingMainInteractor: OnboardingMainInteractorInputProtocol {
    func setup() {
        keystoreImportService.add(observer: self)

        if keystoreImportService.definition != nil {
            presenter?.didSuggestKeystoreImport()
        }
    }
    
    func resetGoogleState() {
        backupService.disconnect()
    }
    
    func getBackupedAccounts() async throws -> [OpenBackupAccount] {
        return try await backupService.getBackupAccounts()
    }
}

extension OnboardingMainInteractor: KeystoreImportObserver {
    func didUpdateDefinition(from oldDefinition: KeystoreDefinition?) {
        if keystoreImportService.definition != nil {
            presenter?.didSuggestKeystoreImport()
        }
    }
}
