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

extension SearchData {
    static func createFromContactItem(_ contactItem: ContactItem,
                                      networkType: SNAddressType,
                                      addressFactory: SS58AddressFactory) throws -> SearchData {
        let accountId = try addressFactory.accountId(fromAddress: contactItem.peerAddress,
                                                     type: networkType)

        let contactContext = ContactContext(destination: .remote)

        return SearchData(accountId: accountId.toHex(),
                          firstName: contactItem.peerAddress,
                          lastName: contactItem.peerName ?? "",
                          context: contactContext.toContext())
    }

    static func createFromAccountItem(_ accountItem: AccountItem,
                                      addressFactory: SS58AddressFactory) throws -> SearchData {
        let accountId = try addressFactory.accountId(fromAddress: accountItem.address,
                                                     type: accountItem.networkType)

        let contactContext = ContactContext(destination: .local)

        return SearchData(accountId: accountId.toHex(),
                          firstName: accountItem.address,
                          lastName: accountItem.username,
                          context: contactContext.toContext())
    }
}
