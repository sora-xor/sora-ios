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
    
    func getBackupedAccounts(completion: @escaping (Result<[OpenBackupAccount], Error>) -> Void) {
        backupService.getBackupAccounts(completion: completion)
    }
}

extension OnboardingMainInteractor: KeystoreImportObserver {
    func didUpdateDefinition(from oldDefinition: KeystoreDefinition?) {
        if keystoreImportService.definition != nil {
            presenter?.didSuggestKeystoreImport()
        }
    }
}
