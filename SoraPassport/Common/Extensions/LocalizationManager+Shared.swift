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

extension LocalizationManagerProtocol {
    var preferredLocalizations: [String]? {
        return [selectedLocalization]
    }

    var selectedLanguage: Language {
        return Language(code: selectedLocalization)
    }
    
    var isRightToLeft: Bool {
        return (selectedLocalization == "ar") || (selectedLocalization == "he") || (selectedLocalization == "fa")
    }
    
    var isArabic: Bool {
        return selectedLocalization == "ar"
    }
    
    var dateFormat: String {
        return selectedLocalization == "he" ? "HH:mm, dd MMM. YYYY" : "dd MMM. YYYY, HH:mm" 
    }
}

extension LocalizationManager {
    static let shared: LocalizationManager = {
        let manager = LocalizationManager(settings: SettingsManager.shared,
                                          key: SettingsKey.selectedLocalization.rawValue)
        manager.replaceUnavailableSelection()
        return manager
    }()

    /// A stored choice that this build does not ship is replaced: first by
    /// the same language without its region (a regional variant such as
    /// "es-CO" from an old release keeps Spanish), then by the best device
    /// language, then English. Tester builds offered Old Akkadian and Middle
    /// Egyptian, which 3.9.0 no longer ships.
    func replaceUnavailableSelection(
        preferredLanguages: [String] = Locale.preferredLanguages
    ) {
        guard !availableLocalizations.contains(selectedLocalization) else {
            return
        }
        // A manager with no stored choice picks the best available
        // localization for the given languages, matching an exact entry or
        // the same language code. The stored choice is tried first.
        let suggestion = LocalizationManager(
            settings: InMemorySettingsManager(),
            key: "selection",
            preferredLanguages: [selectedLocalization] + preferredLanguages,
            availableLocalizations: availableLocalizations
        ).selectedLocalization
        selectedLocalization = availableLocalizations.contains(suggestion)
            ? suggestion
            : "en"
    }
}
