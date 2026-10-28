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

protocol DateFormatterProviderDelegate: AnyObject {
    func providerDidChangeDateFormatter(_ provider: DateFormatterProviderProtocol)
}

protocol DateFormatterProviderProtocol: AnyObject {
    var delegate: DateFormatterProviderDelegate? { get set }
    var dateFormatter: LocalizableResource<DateFormatter> { get }
}

final class DateFormatterProvider: DateFormatterProviderProtocol {
    let dateFormatterFactory: DateFormatterFactoryProtocol.Type
    let dayChangeHandler: DayChangeHandlerProtocol

    private(set) var dateFormatter: LocalizableResource<DateFormatter>

    weak var delegate: DateFormatterProviderDelegate?

    init(dateFormatterFactory: DateFormatterFactoryProtocol.Type,
         dayChangeHandler: DayChangeHandlerProtocol) {
        self.dateFormatterFactory = dateFormatterFactory
        self.dayChangeHandler = dayChangeHandler

        dateFormatter = dateFormatterFactory.createDateFormatter().localizableResource()

        dayChangeHandler.delegate = self
    }
}

extension DateFormatterProvider: DayChangeHandlerDelegate {
    func handlerDidReceiveChange(_ handler: DayChangeHandlerProtocol) {
        dateFormatter = dateFormatterFactory.createDateFormatter().localizableResource()

        delegate?.providerDidChangeDateFormatter(self)
    }
}
