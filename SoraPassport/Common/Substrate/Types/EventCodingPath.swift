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
import SSFUtils

struct EventCodingPath: Equatable {
    let moduleName: String
    let eventName: String

    init(moduleName: String, eventName: String) {
        self.moduleName = moduleName
        self.eventName = eventName
    }
}

extension EventCodingPath {
    static var extrinsicSuccess: EventCodingPath {
        EventCodingPath(moduleName: "System", eventName: "ExtrinsicSuccess")
    }

    static var extrinsicFailed: EventCodingPath {
        EventCodingPath(moduleName: "System", eventName: "ExtrinsicFailed")
    }

    static var balanceDeposit: EventCodingPath {
        EventCodingPath(moduleName: "Balances", eventName: "Deposit")
    }

    static var feeWitdrawn: EventCodingPath {
        EventCodingPath(moduleName: "XorFee", eventName: "FeeWithdrawn")
    }
}
