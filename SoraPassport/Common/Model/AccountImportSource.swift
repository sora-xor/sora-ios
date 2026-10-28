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

enum AccountImportSource: CaseIterable {
    case mnemonic
    case seed
    case keystore
}

extension AccountImportSource: SourceType {
    func titleForLocale(_ locale: Locale) -> String {
        switch self {
        case .mnemonic: return R.string.localizable.commonPassphraseTitle(preferredLanguages: locale.rLanguages)
        case .seed: return R.string.localizable.commonRawSeed(preferredLanguages: locale.rLanguages)
        case .keystore: return "JSON" // for the future
        }
    }

    var descriptionText: String? {
        return nil
    }
    
    var navigationTitle: String {
        switch self {
        case .mnemonic: return R.string.localizable.onboardingEnterPassphrase(preferredLanguages: .currentLocale)
        case .seed: return R.string.localizable.onboardingEnterSeed(preferredLanguages: .currentLocale)
        case .keystore: return "JSON" // for the future
        }
    }
    
    var containerTitle: String {
        switch self {
        case .mnemonic: return R.string.localizable.recoveryEnterPassphraseTitle(preferredLanguages: .currentLocale)
        case .seed: return R.string.localizable.recoveryEnterSeedTitle(preferredLanguages: .currentLocale)
        case .keystore: return "JSON" // for the future
        }
    }
}
