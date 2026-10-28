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
import IrohaCrypto

enum SS58AddressFactoryError: Error {
    case unexpectedAddress
}

extension SS58AddressFactory {
    func extractAddressType(from address: String) throws -> SNAddressType {
        let addressTypeValue = try type(fromAddress: address)

        let addressType = SNAddressType(addressTypeValue.uint8Value)

        return addressType
    }

    func accountId(from address: String) throws -> Data {
        let addressType = try extractAddressType(from: address)
        return try accountId(fromAddress: address, type: addressType)
    }

    func addressFromAccountId(data: Data, type: SNAddressType) throws -> String {
        return try address(fromAccountId: data, type: type)
    }
}
