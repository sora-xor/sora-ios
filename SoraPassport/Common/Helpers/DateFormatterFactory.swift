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

protocol DateFormatterFactoryProtocol {
    static func createDateFormatter() -> DateFormatter
}

struct EventListDateFormatterFactory: DateFormatterFactoryProtocol {
    static func createDateFormatter() -> DateFormatter {
        let dateFormatterBuilder = CompoundDateFormatterBuilder(baseDate: Date())

        let today = LocalizableResource { locale in
            R.string.localizable.commonToday(preferredLanguages: LocalizationManager.shared.preferredLocalizations)
        }

        let yesterday = LocalizableResource { locale in
            R.string.localizable.commonYesterday(preferredLanguages: LocalizationManager.shared.preferredLocalizations)
        }

        let defaultFormat = R.string.localizable
            .anyYearFormat(preferredLanguages: Locale.current.rLanguages)

        let dateFormatter = dateFormatterBuilder
            .withToday(title: today)
            .withYesterday(title: yesterday)
            .withThisYear(dateFormatter: DateFormatter.sectionThisYear.localizableResource())
            .build(defaultFormat: defaultFormat)

        return dateFormatter
    }
}

struct FinishedProjectDateFormatterFactory: DateFormatterFactoryProtocol {
    static func createDateFormatter() -> DateFormatter {
        let dateFormatterBuilder = CompoundDateFormatterBuilder()

        let today = LocalizableResource { locale in
            R.string.localizable.commonToday(preferredLanguages: locale.rLanguages)
        }

        let yesterday = LocalizableResource { locale in
            R.string.localizable.commonYesterday(preferredLanguages: locale.rLanguages)
        }

        let defaultFormat = R.string.localizable
            .finishedProjectYearFormat(preferredLanguages: Locale.current.rLanguages)

        let dateFormatter = dateFormatterBuilder
            .withToday(title: today)
            .withYesterday(title: yesterday)
            .withThisYear(dateFormatter: DateFormatter.shortThisYear.localizableResource())
            .build(defaultFormat: defaultFormat)

        return dateFormatter
    }
}
